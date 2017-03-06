#!/bin/bash
Usage(){
    echo "This script is to setup password-less ssh login from current host to a given remote host."
    #echo "`basename $0` [-h <Remote Hostname>] [-u <username to login>] [-p <password to login>]"
}

if [ "$1" == "" ]; then
    Usage
    exit 1
fi

while [ "$1" != "" ]; do
    case $1 in
    -s  )    shift
          SCRIPTURL=$1
          ;;
    -h  )    shift
        REMOTE_HOST=$1
        ;;
    -u  )    shift
        USERNAME=$1
        ;;
    -p  )   shift
        PASSWORD=$1
        ;;
	-j  )   shift
        JPASSWORD=$1
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


### Check variables
[[ "$REMOTE_HOST" == "" ]] && echo "[ERROR] -h option is required." && exit 1
[[ "$USERNAME" == "" ]] && echo "[ERROR] -u option is required. " && exit 1
[[ "$PASSWORD" == "" ]] && echo "[ERROR] -p option is required. " && exit 1


###Install expect & maven packages
apt-get install -y expect maven
[[ "$?" != "0" ]] && echo "[ERROR] Packages are not install" && exit 1


###Download the actual script
curl "https://aztdrepo.blob.core.windows.net/cloudbees/scripts/sshscript.sh" > /var/lib/jenkins/sshscript.sh
[[ "$?" != "0" ]] && echo "[ERROR] Authentication script download failed" && exit 1


###update script with required permissions
dos2unix /var/lib/jenkins/sshscript.sh && chmod +x /var/lib/jenkins/sshscript.sh
#curl "https://sattaarmdep.blob.core.windows.net/satta-arm-dep/arm-templates/cb-jenkins/config.xml" > /var/lib/jenkins/config.xml
#cd /var/lib/jenkins/
#dos2unix config.xml && chmod +x config.xml
#curl -X POST -H "Content-Type:application/xml" -d @config.xml "http://localhost/createItem?name=CloudTryPipeline1" --user admin:$JPASSWORD
[[ "$?" != "0" ]] && echo "[ERROR] Packages are not install" && exit 1


###Executing the authentication script
sudo -H -u jenkins bash /var/lib/jenkins/sshscript.sh -h $REMOTE_HOST -u $USERNAME -p $PASSWORD
[[ "$?" != "0" ]] && echo "[ERROR] Execution of authentication script failed" && exit 1

sudo -H -u jenkins ssh $USERNAME@$REMOTE_HOST 'sudo usermod -a -G tomcat '$USERNAME''
sudo -H -u jenkins ssh $USERNAME@$REMOTE_HOST 'sudo chmod 777 /home/'$USERNAME'/stack/apache-tomcat/webapps'
