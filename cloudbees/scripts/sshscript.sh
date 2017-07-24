#!/bin/bash

Usage(){
    echo "This script is to setup password-less ssh login from current host to a given remote host."
    echo "`basename $0` [-h <Remote Hostname>] [-u <username to login>] [-p <password to login>]"
}

if [ "$1" == "" ]; then
    Usage
    exit 1
fi

while [ "$1" != "" ]; do
    case $1 in
    -h  )    shift
        REMOTE_HOST=$1
        ;;
    -u  )    shift
        USERNAME=$1
        ;;
    -p  )   shift
        PASSWORD=$1
        ;;
    -q  )    shift
        MODE="QUIET"
        ;;
        -help )         Usage
                        exit 1
                        ;;
        * )             Usage
                        exit 1
    esac
    shift
done

### check expect
which expect > /dev/null 2>&1
[[ "$?" != "0" ]] && echo "[ERROR] You don't have expect installed." && exit 1

### Check variables
[[ "$REMOTE_HOST" == "" ]] && echo "[ERROR] -h option is required." && exit 1
[[ "$USERNAME" == "" ]] && echo "[ERROR] -u option is required. " && exit 1
[[ "$PASSWORD" == "" ]] && echo "[ERROR] -p option is required. " && exit 1


#printf "Are you sure $USERNAME/$PASSWORD is correct login credential for $REMOTE_HOST? If not, $USERNAME might be banned after running this script. [NO/yes]: "
#[[ "$MODE" == "" ]] && read input && [[ "$input" != "yes" ]] && exit 0



### Check if id_rsa.pub is already there in ~/.ssh
ID_RSA="$HOME/.ssh/id_rsa.pub"

if [ ! -f "$ID_RSA" ]; then
    ### Not yet run ssh-keygen
    SSH_KEYGEN=`which ssh-keygen`
expect <<- DONE
  spawn $SSH_KEYGEN -t rsa
  expect "Enter file in which to save the key*"
  send -- "\r"
  expect "Enter passphrase (empty for no passphrase):*"
  send -- "\r"
  expect "Enter same passphrase again:*"
  send -- "\r"

  expect eof
DONE
fi

[[ ! -f "$ID_RSA" ]] && echo "[ERROR] $ID_RSA not found" && exit 1

### check remote host ~/.ssh dir
cmd="ssh $USERNAME@$REMOTE_HOST ls .ssh"
expect <<- DONE
  spawn $cmd
  expect {
      "*yes/no*"    { send "yes\r"; exp_continue }
      "*password*"  { send "$PASSWORD\r" ; exp_continue}
  }

DONE

[[ "$?" == "255" ]] && echo "[ERROR] Failed to login, please check if the given username and password are correct." && exit 1

if [ "$?" != "0" ]; then
    ### mkdir ~/.ssh
cmd="ssh $USERNAME@$REMOTE_HOST mkdir .ssh"
expect <<- DONE
  spawn $cmd
  expect {
      "*yes/no*"    { send "yes\r"; exp_continue }
      "*password*"  { send "$PASSWORD\r" ; exp_continue}
  }

DONE

### give 700 permission to .ssh
cmd="ssh $USERNAME@$REMOTE_HOST chmod 700 .ssh"
expect <<- DONE
  spawn $cmd
  expect {
      "*yes/no*"    { send "yes\r"; exp_continue }
      "*password*"  { send "$PASSWORD\r" ; exp_continue}
  }

DONE

cmd="ssh $USERNAME@$REMOTE_HOST touch .ssh/authorized_keys"
expect <<- DONE
  spawn $cmd
  expect {
      "*yes/no*"    { send "yes\r"; exp_continue }
      "*password*"  { send "$PASSWORD\r" ; exp_continue}
  }

DONE

fi

### remove possible already exist entry in ~/.ssh/authorized_keys
WHOAMI="`whoami`@`hostname`"
cmd="ssh $USERNAME@$REMOTE_HOST \"sed '/$WHOAMI/d' .ssh/authorized_keys > .ssh/authorized_keys.1; mv .ssh/authorized_keys.1 .ssh/authorized_keys\""
expect <<- DONE
  spawn $cmd
  expect {
      "*yes/no*"    { send "yes\r"; exp_continue }
      "*password*"  { send "$PASSWORD\r" ; exp_continue}
  }

DONE

### scp id_rsa.pub over to remote host
cmd="scp $ID_RSA $USERNAME@$REMOTE_HOST:.ssh/id_rsa-`hostname`.pub"
expect <<- DONE
  spawn $cmd
  expect {
      "*yes/no*"    { send "yes\r"; exp_continue }
      "*password*"  { send "$PASSWORD\r" ; exp_continue}
  }

DONE

[[ "$?" != "0" ]] && echo "[ERROR] Failed to scp $ID_RSA to remote host." && exit 1

cmd="ssh $USERNAME@$REMOTE_HOST cat .ssh/id_rsa-`hostname`.pub >> .ssh/authorized_keys"
expect <<- DONE
  spawn $cmd
  expect {
      "*yes/no*"    { send "yes\r"; exp_continue }
      "*password*"  { send "$PASSWORD\r" ; exp_continue}
  }

DONE

[[ "$?" != "0" ]] && echo "[ERROR] Failed to append id_rsa to remote host." && exit 1

cmd="ssh $USERNAME@$REMOTE_HOST chmod 644 .ssh/authorized_keys"
expect <<- DONE
  spawn $cmd
  expect {
      "*yes/no*"    { send "yes\r"; exp_continue }
      "*password*"  { send "$PASSWORD\r" ; exp_continue}
  }

DONE

ssh $USERNAME@$REMOTE_HOST ls > /dev/null 2>&1

[[ "$?" != "0" ]] && echo "[ERROR] passwordless login setup failed." && exit 1
echo "[COMPLETE] passwordless ssh from `hostname` to $REMOTE_HOST has been established."
