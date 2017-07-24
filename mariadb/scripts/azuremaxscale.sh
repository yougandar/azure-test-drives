#!/usr/bin/env bash

export PS4='+ $(date +%F_%T) '
xtrace="/tmp/xtrace_${0##*/}.out"
( umask 0077; touch "$xtrace" )
exec 9>>"$xtrace"
BASH_XTRACEFD=9
set -x

# This script is only tested on CentOS 7 with MariaDB Enterprise Cluster 10.1.

err() {
    printf '[ERROR] %s\n' "$*" >&2
}

declare -a dbs maxscale_ips

osuser=mdbe

while :; do 
    case $1 in
        --db)
            if [[ $2 ]]; then
                dbs+=( $2 )
                shift 2
                continue
            else
                err "The $1 option requires an argument"
                exit 1
            fi
            ;;
        --maxscaleip)
            if [[ $2 ]]; then
                maxscale_ips+=( $2 )
                shift 2
                continue
            else
                err "The $1 option requires an argument"
                exit 1
            fi
            ;;
        --mynodeid)
            if [[ -n $2 ]]; then
                node_id=$2
                shift 2
                continue
            else
                err "$1 requires an argument. Aborting"
                exit 1
            fi
            ;;
        --token)
            if [[ -n $2 ]]; then
                mdbetoken=$2
                shift 2
                continue
            else
                err "$1 requires an argument. Aborting"
                exit 1
            fi
            ;;
        --cnftemplate)
            if [[ $2 ]]; then
                maxscale_config_template=$2
                shift 2
                continue
            else
                err "The $1 option requires an argument"
                exit 1
            fi
            ;;
        --osuser)
            if [[ -n $2 ]]; then
                osuser=$2
                shift 2
                continue
            else
                err "$1 requires an argument. Aborting"
                exit 1
            fi
            ;;
        -?*)
            printf '[WARN] Unknown option (ignored): %s\n' "$1" >&2
            ;;
        *)
            break
    esac
    shift
done

sed -i 's/^SELINUX=.*/SELINUX=disabled/I' /etc/selinux/config
setenforce 0

if ((! ${#dbs[@]})); then
    printf '[ERROR] Some backend DB servers must be defined!\n' >&2
    exit 1
fi

for var in maxscale_config_template mdbetoken node_id maxscale_ips; do
    if ! [[ ${!var} ]]; then
        err "$var not set! Aborting."
        exit 1
    fi
done

# This causes systemd to create /var/run/maxscale on startup
[[ -e /etc/tmpfiles.d/maxscale.conf ]] || 
    echo 'd /var/run/maxscale 0755 maxscale maxscale' > /etc/tmpfiles.d/maxscale.conf


yum install -y screen tmux lsof strace wget nc curl xinetd keepalived https://downloads.mariadb.com/enterprise/"$mdbetoken"/generate/10.1/mariadb-enterprise-repository.rpm || exit
yum install -y maxscale MariaDB-client || exit

keepalived_cfg=/etc/keepalived/keepalived.conf
mv "$keepalived_cfg"{,.default}

#hostname=$(hostname -s)
master_ip=${maxscale_ips[0]}
my_ip=${maxscale_ips[node_id-1]}

if [[ $node_id = "$my_ip" ]]; then 
        keepalived_state=MASTER
        peer_ip=${maxscale_ips[1]}
        keepalived_priority=101
else
        keepalived_state=BACKUP
        peer_ip=$master_ip
        keepalived_priority=100
fi

cat <<EoCFG > "$keepalived_cfg"
vrrp_script chk_appsvc {
    script /usr/share/maxscale/keepalived-check-appsvc
    interval 1
    fall 2
    rise 2
}
vrrp_instance VI_1 {
    interface eth0 
    authentication {
        auth_type PASS
        auth_pass secr3t
    }
    virtual_router_id 51
    track_script {
        chk_appsvc
    }
    notify /usr/share/maxscale/keepalived-action
    notify_stop "/usr/share/maxscale/keepalived-action INSTANCE VI_1 STOP"

    state $keepalived_state
    priority $keepalived_priority
    nopreempt

    unicast_src_ip $my_ip
    unicast_peer {
        $peer_ip
    }
}
EoCFG

cat <<EoBASH > /usr/share/maxscale/keepalived-check-appsvc
#!/bin/bash
nc -w2 127.0.0.1 4006 </dev/null >/dev/null
EoBASH

cat <<'EoBASH' > /usr/share/maxscale/keepalived-action
#!/bin/bash
type=$1
name=$2
state=$3

case $state in
        MASTER) status=up ;;
        BACKUP|STOP|FAULT) status=down ;;
        *) printf "Unknown state '%s'. Aborting.\n" "$state" >&2; exit 1 ;;
esac

printf %s "$status" > /var/run/maxscale/maxscale.status
EoBASH

cat <<'EoBASH' > /usr/share/maxscale/maxscale-xinetd
#!/bin/bash
status_file=/var/run/maxscale/maxscale.status
if ! state=$(<"$status_file"); then
        printf "ERROR: could not read from status file %s. Aborting.\n" "$status_file" >&2
        exit 1
fi

case $state in
        up) msg="200 OK" ;;
        down) msg="503 Service Unavailable" ;;
        *) msg="500 Internal Error" ;;
esac

cat <<EoHTTP
HTTP/1.1 $msg
Content-Type: text/plain

$msg

EoHTTP

EoBASH

cat <<EoXINETD > /etc/xinetd.d/maxscalecheck
# default: on
# description: maxscalecheck
service maxscalecheck
{
        flags           = REUSE
        socket_type     = stream
        port            = 9200
        wait            = no
        user            = nobody
        server          = /usr/share/maxscale/maxscale-xinetd
        log_on_failure  += USERID
        disable         = no
        only_from       = 0.0.0.0/0
        per_source      = UNLIMITED 
}
EoXINETD

echo 'maxscalecheck        9200/tcp' >> /etc/services

chmod +x /usr/share/maxscale/keepalived-check-appsvc /usr/share/maxscale/keepalived-action /usr/share/maxscale/maxscale-xinetd

systemctl restart xinetd
systemctl restart keepalived

maxpassdir=/var/lib/maxscale/data
mkdir -p "$maxpassdir"
maxkeys "$maxpassdir"
chown -R maxscale.maxscale "$maxpassdir"
monitorpassword=maxscalemonitoruserpassword
encmonitorpassword=$(maxpasswd "$maxpassdir" "$monitorpassword" | head -n1)


unset server_defs

for ((i=0;i<${#dbs[@]};i++)); do
    server_id=db$((i+1))
    IFS=: read -r addr port <<<"${dbs[i]}"
    printf -v server_defs '
%s
[%s]
type=server
address=%s
port=%i
protocol=MySQLBackend
' \
    "$server_defs" "$server_id" "$addr" "$port"
    servers+=( "$server_id" )

done

server_list=$(IFS=,; printf %s "${servers[*]}")

server_version=$(yum --disablerepo=\* --enablerepo=mariadb-enterprise-main info installed MariaDB-server | awk -F': ' '/^Version/{print $2}')

if ! curl -sS "$maxscale_config_template" | sed -e "s/##server_list##/$server_list/g" \
    -e "s/##maxscalemonitor_pass##/${encmonitorpassword}/g" \
    -e "s/##server_version_string##/${server_version}-MariaDB Enterprise Cluster/g" \
    > /etc/maxscale.cnf 
then
    err "failed to update MaxScale config from template. Aborting."
    exit 1
fi

echo "$server_defs" >> /etc/maxscale.cnf

chkconfig maxscale on
service maxscale restart

maxadminpass=$(dd if=/dev/urandom bs=1 count=15 2>/dev/null | base64)

# Try a few times to set the password...
for ((i=0;i<10;i++)); do 
    echo "attempt $i"
    pgrep maxscale && 
        nc -w 1 127.0.0.1 6603 < /dev/null &&
        maxadmin -u admin -pmariadb add user admin "$maxadminpass" &&
        break
    sleep 1
done


cat > /home/"$osuser"/.my.cnf <<EoCNF
[client]
protocol=tcp
EoCNF


printf %s '
Host 10.0.1.* mdbec-db?
        StrictHostKeyChecking=no
' >> /etc/ssh/ssh_config

echo "Setup complete!"

#(
#    yum -y remove hypervkvpd.x86_64
#    yum -y install microsoft-hyper-v
#) </dev/null >/dev/null 2>&1 &
#disown $!
