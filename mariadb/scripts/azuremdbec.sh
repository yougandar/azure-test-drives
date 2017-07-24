#!/bin/bash

export PS4='+ $(date +%F_%T) '
xtrace="/tmp/xtrace_${0##*/}.out"
( umask 0077; touch "$xtrace" )
exec 9>>"$xtrace"
BASH_XTRACEFD=9
set -x

# This script is only tested on CentOS 7 with MariaDB Enterprise Cluster 10.1.

usage() {
    cat <<EoF
--cluster <cluster address>
--cluster-name <cluster name>
--token <download token>
--nodeaddress <node address>
--startupcmd <startup command>
--mycnftemplate <my.cnf template>
--osuser <os login user>
--appuser=<username for MariaDB account>
--apppassword=<password for MariaDB account>
--appdatabase=<database for MariaDB account>
--storagetype=<type of storage>
EoF
}

err() {
    printf '[ERROR] %s\n' "$*" >&2
}

startupcmd=start
osuser=mdbe

while :; do
    case $1 in
        --clusteraddress)
            if [[ -n $2 ]]; then
                clusteraddress=$2
                shift 2
                continue
            else
                err "$1 requires an argument. Aborting"
                exit 1
            fi
            ;;
        --cluster-name)
            if [[ -n $2 ]]; then
                clustername=$2
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
        --nodeaddress)
            if [[ -n $2 ]]; then
                nodeaddress=$2
                shift 2
                continue
            else
                err "$1 requires an argument. Aborting"
                exit 1
            fi
            ;;
        --startupcmd)
            if [[ -n $2 ]]; then
                startupcmd=$2
                shift 2
                continue
            else
                err "$1 requires an argument. Aborting"
                exit 1
            fi
            ;;
        --mycnftemplate)
            if [[ -n $2 ]]; then
                mycnftemplate=$2
                shift 2
                continue
            else
                err "$1 requires an argument. Aborting"
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
        --appuser=?*)
            appuser=${1#*=}
            ;;
        --apppassword=?*)
            apppassword=${1#*=}
            ;;
        --appdatabase=?*)
            appdatabase=${1#*=}
            ;;
        --storagetype=?*)
            storagetype=${1#*=}
            ;;
        --)              # End of all options.
            shift
            break
            ;;
        -?*)
            err "Unknown option (ignored): $1"
            ;;
        *)
            break
    esac
    shift
done

for var in clusteraddress mdbetoken nodeaddress startupcmd mycnftemplate osuser; do 
    if ! [[ ${!var} ]]; then
        err "$var not set! Aborting."
        exit 1
    fi
done

sstuser=sstuser
read -r sstpassword _ < <(sha1sum <<<"$mdbetoken/$clustername")

nodename=$(hostname)

mountpoint="/mariadata"
raidchunksize=512

raiddisk="/dev/md127"
raidpartition="/dev/md127p1"
# An set of disks to ignore from partitioning and formatting
blacklist="/dev/sda|/dev/sdb"

check_os() {
    grep -q ubuntu /proc/version && isubuntu=1
    grep -q centos /proc/version && iscentos=1
}

scan_for_new_disks() {
    # Looks for unpartitioned disks
    declare -a ret
    # devs=($(ls -1 /dev/sd*|egrep -v "${blacklist}"|egrep -v "[0-9]$"))
    devs=(/dev/sd[b-z])
    for dev in "${devs[@]}";
    do
        type=$(file -bs "$dev")
        # Check each device if there is a "1" partition.  If not,
        # "assume" it is not partitioned.
        [[ $type = data ]] && ret+=("${dev}")
    done
    printf "%s " "${ret[@]}"
}

create_raid0_ubuntu() {
    if ! dpkg -s mdadm; then 
        echo "installing mdadm"
        wget --no-cache http://mirrors.cat.pdx.edu/ubuntu/pool/main/m/mdadm/mdadm_3.2.5-5ubuntu4_amd64.deb
        dpkg -i mdadm_3.2.5-5ubuntu4_amd64.deb
    fi
    echo "Creating raid0"
    udevadm control --stop-exec-queue
    echo "yes" | mdadm --create "$raiddisk" --name=data --level=0 --chunk="$raidchunksize" --raid-devices="$diskcount" "${disks[@]}"
    udevadm control --start-exec-queue
    mdadm --detail --verbose --scan > /etc/mdadm.conf
}

create_raid0_centos() {
    yum install -y mdadm || exit
    echo "Creating raid0"
    yes | mdadm --create "$raiddisk" --name=data --level=0 --chunk="$raidchunksize" --raid-devices="$diskcount" "${disks[@]}"
    mdadm --detail --verbose --scan > /etc/mdadm.conf
}

do_partition() {
# This function creates one (1) primary partition on the
# disk, using all available space
    disk=$1
    blkid "$disk"
    echo "Partitioning disk $disk"
    if ! fdisk "$disk" <<EoCMD
n
p
1


w
EoCMD
    then 
    printf "An error occurred partitioning %s. I cannot continue." "$disk" >&2
    exit 2
fi
}

add_to_fstab() {
    uuid=$1
    mountpoint=$2
    if grep -q "$uuid" /etc/fstab
    then
        echo "Not adding $uuid to fstab again (it's already there!)"
    else
        printf "UUID=%s %s ext4 defaults,noatime 0 0\n" \
            "$uuid" "$mountpoint" >> /etc/fstab
    fi
}

configure_disks() {
    [[ -e $mountpoint ]] && return

    disks=($(scan_for_new_disks))
    echo "Disks are ${disks[*]}"
    diskcount=${#disks[@]}
    echo "Disk count is $diskcount"
    if ((diskcount>1));
    then
        ((iscentos)) && create_raid0_centos
        ((isubuntu)) && create_raid0_ubuntu
        do_partition "$raiddisk"
        partition="$raidpartition"
    else
        disk="${disks[0]}"
        do_partition "$disk"
        partition=$(fdisk -l "$disk" | grep -A 1 Device | tail -n 1 | awk '{print $1}')
    fi

    echo "Creating filesystem on $partition."
    mkfs -t ext4 -E lazy_itable_init=1 "$partition"
    mkdir -p "$mountpoint"
    read -r uuid fs_type < <(blkid -u filesystem "$partition" | awk -F "[= ]" '{print $3" "$5}' | tr -d "\"")
    add_to_fstab "$uuid" "$mountpoint"
    echo "Mounting disk $partition on $mountpoint"
    mount "$mountpoint"
}

open_ports() {
    iptables -A INPUT -p tcp -m tcp --dport 3306 -j ACCEPT
    iptables -A INPUT -p tcp -m tcp --dport 4444 -j ACCEPT
    iptables -A INPUT -p tcp -m tcp --dport 4567 -j ACCEPT
    iptables -A INPUT -p tcp -m tcp --dport 4568 -j ACCEPT
    iptables -A INPUT -p tcp -m tcp --dport 9200 -j ACCEPT
    iptables-save
}

disable_apparmor_ubuntu() {
    /etc/init.d/apparmor teardown
    update-rc.d -f apparmor remove
}

disable_selinux_centos() {
    sed -i 's/^SELINUX=.*/SELINUX=disabled/I' /etc/selinux/config
    setenforce 0
}

activate_secondnic_centos() {
    if [ -n "$secondnic" ];
    then
        cp /etc/sysconfig/network-scripts/ifcfg-eth0 "/etc/sysconfig/network-scripts/ifcfg-${secondnic}"
        sed -i "s/^DEVICE=.*/DEVICE=${secondnic}/I" "/etc/sysconfig/network-scripts/ifcfg-${secondnic}"
        defaultgw=$(ip route show |sed -n "s/^default via //p")
        declare -a gateway=(${defaultgw// / })
        sed -i "\$aGATEWAY=${gateway[0]}" /etc/sysconfig/network
        service network restart
    fi
}

configure_network() {
    open_ports
    if ((iscentos)); then
        activate_secondnic_centos
        disable_selinux_centos
    elif ((isubuntu)); then
        disable_apparmor_ubuntu
    fi
}

create_mycnf() {
    wget "$mycnftemplate" -O /etc/my.cnf || exit

    memfree=$(awk '/^MemFree/{print $2}' < /proc/meminfo)
    innodb_buffer_pool_size=$(bc <<<"scale=0; $memfree * 1024 * 0.7")
    innodb_buffer_pool_size=${innodb_buffer_pool_size%%.*}

    sed_cmds=(
        -e "s#^(wsrep_cluster_address)=.*#\1=gcomm://${clusteraddress}#I" 
        -e "s/^(wsrep_node_address)=.*/\1=${nodeaddress}/I" 
        -e "s/^(wsrep_node_name)=.*/\1=${nodename}/I" 
        -e "s/^(wsrep_sst_auth)=.*/\1=${sstuser}:${sstpassword}/I" 
        -e "s#^(wsrep_provider)=.*#\1=/usr/lib64/galera/libgalera_smm.so#I" 
        -e 's/^(innodb.buffer.pool.size)/#\1/I'
        -e "s/^##(innodb_buffer_pool_size)##/\1=$innodb_buffer_pool_size/I" 
        -e "s/^##(wsrep_cluster_name)##/\1=${clustername}/I" 
    )

    if [[ $storagetype = Premium* ]]; then
        sed_cmds+=(
            -e "s/^(innodb_io_capacity)=.*/\1=5000/I"
            -e "s/^(innodb_flush_neighbors)=.*/\1=0/I"
        )
    fi

    find /etc/my.cnf /etc/my.cnf.d/ -name '*.cnf' -exec \
        sed -i -E "${sed_cmds[@]}" {} +
}

install_mysql_ubuntu() {
    if dpkg -s percona-xtradb-cluster-56 ;
    then
        return
    fi
    echo "Installing MariaDB Enterprise Cluster"

    export DEBIAN_FRONTEND=noninteractive
    curl "https://downloads.mariadb.com/enterprise/$mdbetoken/generate/10.1/mariadb-enterprise-repository.deb" > /tmp/mariadb-enterprise-repository.deb
    dpkg -i /tmp/mariadb-enterprise-repository.deb
    apt-get update
    apt-get -q -y install mariadb-server xinetd socat percona-xtrabackup || exit
}

install_mysql_centos() {
    echo "Installing MariaDB Enterprise Cluster"
    yum install -y "https://downloads.mariadb.com/enterprise/$mdbetoken/generate/10.1/mariadb-enterprise-repository.rpm" || exit
    yum -y install xinetd socat percona-xtrabackup || exit
    mv /etc/my.cnf.d/mariadb-enterprise.cnf{,.old}
}

configure_mysql() {
    [[ -e /etc/init.d/mysql ]] && /etc/init.d/mysql status && return
    if ((isubuntu)); then 
        apt-get -y install wget || exit
    elif ((iscentos)); then
        # yum -y upgrade || exit
        yum -y install wget bc || exit
    fi

    create_mycnf

    groupadd -r mysql
    useradd -M -r --home /var/lib/mysql --shell /sbin/nologin --comment "MySQL server" --gid mysql mysql

    rm -rf /var/lib/mysql

    mkdir -p "$mountpoint/mysql"
    chown mysql.mysql "$mountpoint/mysql"
    if ! ln -sfT "$mountpoint/mysql" /var/lib/mysql ; then
        err 'Could not create symbolic link for datadir. Aborting'
        exit 1
    fi

    # If we are not the bootstrap node, we won't even bother setting up privilege tables
    [[ $startupcmd == "bootstrap" ]] || install -d -o mysql -g mysql /var/lib/mysql/mysql
    [[ -e /var/lib/mysql/mysql ]] || mysql_install_db --user=mysql

    mkdir -p /etc/systemd/system/mariadb.service.d/
    printf '[Service]\nTimeoutSec=0\n' > /etc/systemd/system/mariadb.service.d/disable_timeout.conf
    systemctl daemon-reload

    if ((iscentos)); then 
        install_mysql_centos || exit
    elif ((isubuntu)); then
        install_mysql_ubuntu || exit
    else
        echo 'ERROR: unsupported OS type' >&2
        exit 1
    fi

    systemctl stop mariadb

    sstmethod=$(sed -n "s/^wsrep_sst_method=//p" /etc/my.cnf)
    if [[ $sstmethod == "mysqldump" ]]; #requires root privilege for sstuser on every node
    then
        /etc/init.d/mysql bootstrap
        {
            echo "
                CREATE USER '${sstuser}'@'localhost' IDENTIFIED BY '${sstpassword}';
                GRANT ALL PRIVILEGES ON *.* TO '${sstuser}'@'localhost';
                CREATE USER '${sstuser}'@'%' IDENTIFIED BY '${sstpassword]}';
                GRANT ALL PRIVILEGES ON *.* TO '${sstuser}'@'10.0.1.%';
                FLUSH PRIVILEGES;" 
        } | mysql 
        /etc/init.d/mysql stop
    fi
    if [[ $startupcmd == "bootstrap" ]];
    then
        galera_new_cluster
        myrootpass=$(dd if=/dev/urandom bs=1 count=15 2>/dev/null | base64)
        printf '%s\n' "[client]" "user=root" "password=$myrootpass" >> "/home/$osuser/.my.cnf"
        {
            [[ $sstmethod != "mysqldump" ]] && echo "
                CREATE USER '${sstuser}'@'localhost' IDENTIFIED BY '${sstpassword}';
                GRANT RELOAD, LOCK TABLES, REPLICATION CLIENT ON *.* TO '${sstuser}'@'localhost';"
            [[ $appdatabase ]] && echo "CREATE DATABASE \`$appdatabase\`;"
            [[ $appuser ]] && echo "CREATE USER '$appuser'@'%' IDENTIFIED BY '$apppassword';"
            [[ $appuser && $appdatabase ]] && echo "GRANT ALL PRIVILEGES ON \`$appdatabase\`.* TO '$appuser'@'%';"
            echo "
                UPDATE mysql.user SET password=PASSWORD('$myrootpass') WHERE user='root';
                CREATE USER 'maxscalemonitor'@'10.0.1.%' identified by 'maxscalemonitoruserpassword';
                GRANT SELECT ON mysql.user TO 'maxscalemonitor'@'10.0.1.%';
                GRANT SELECT ON mysql.db TO 'maxscalemonitor'@'10.0.1.%';
                GRANT SELECT ON mysql.tables_priv TO 'maxscalemonitor'@'10.0.1.%';
                GRANT REPLICATION CLIENT, SHOW DATABASES ON *.* TO 'maxscalemonitor'@'10.0.1.%';
                DELETE FROM mysql.user WHERE user='';
                DELETE FROM mysql.db WHERE user='';
                FLUSH PRIVILEGES;"
        } | mysql
    else
        systemctl start mariadb.service
    fi

    systemctl enable mariadb.service
}

allow_passwordssh() {
	grep -q '^PasswordAuthentication yes' /etc/ssh/sshd_config && return
    sed -i "s/^#PasswordAuthentication.*/PasswordAuthentication yes/I" /etc/ssh/sshd_config
    sed -i "s/^PasswordAuthentication no.*/PasswordAuthentication yes/I" /etc/ssh/sshd_config
	systemctl reload sshd
}

# This function is meant to execute asynchronously after the install finishes!
do_async_post() {
    (
        yum -y remove hypervkvpd.x86_64
        yum -y install microsoft-hyper-v
    ) </dev/null >/dev/null 2>&1 &
    disown $!
}

check_os
if (( ! iscentos ))
then
    echo "unsupported operating system"
    exit 1 
else
    configure_network
    configure_disks
    configure_mysql
    echo "Setup complete!"

    #do_async_post
fi
