#!/usr/bin/env bash
ENVS_DIR="/home/docker"
#git_conf_url="https://github.com/alexvea/lamp-conf.git"
git_conf_url="git@github.com:alexvea/lamp-conf.git"
script_name="docker_lamp_events.sh"
pid_path="/var/run/docker_lamp_events.pid"
script_path="/usr/local/scripts"
services="httpd databasesv phpfpm"


case "$1" in
start)
   $script_path/$script_name &
   echo "$script_name started"
   echo $!> $pid_path
   exit 0
   ;;
stop)
   echo "$script_name stopped"
   kill $(ps -o pid= --ppid `cat $pid_path`)
   rm $pid_path
   exit 0
   ;;
restart)
   echo "$script_name restarted"
   $0 stop
   $0 start
   ;;
status)
   if [ -e $pid_path ]; then
      echo $script_name is running, pid=`cat $pid_path`
   else
      echo $script_name is NOT running
      exit 1
   fi
   ;;
*)
  # echo "Usage: $0 {start|stop|status|restart}"
;;
esac



add_lamp_conf() {
        echo "ajout conf lamp dans l'env "$1
        for service in $services
        do
        docker stop $1-$service
        done
        rm -rf  $ENVS_DIR/$1/conf
        mkdir $ENVS_DIR/$1/conf
        sleep 2
        git clone $git_conf_url $ENVS_DIR/$1/conf
        cd $ENVS_DIR/$1/conf
        git branch -a | grep remotes/origin/$1
        sudo pwd
        if  [ $? -eq 0 ]
        then
                sudo git checkout $1
        else
                sudo git checkout -b $1
                for file in `git ls-files`
                do
                        sed -i -e "s/NOM_DE_DOMAINE/$1/g" $file
                        echo sed -i -e "s/NOM_DE_DOMAINE/$1/g" $file
                done
#               sudo git config --global user.name "Docker portainer"
#               sudo git config --global user.email "avea@sfa.fr"
                sudo git add .
                sudo git commit -m "first commit $1"
                sudo git push origin $1
        fi
        for service in $services
        do
        docker start $1-$service
        done
}

move_env_to_trash(){
        timestamp=$(date +%s)
        echo "deplacement env "$1" vers $ENVS_DIRS/trash-envs"
        mv $ENVS_DIR/$1 $ENVS_DIR/trash-envs/$1-$timestamp
}

create_linux_user(){
        echo "création user "$1
        useradd -d $ENVS_DIR/$1 $1
#       usermod -a -G apache $1 && usermod -a -G $1 apache #ajout nouvel user dans groupe apache et ajout user apache dans groupe user
}

delete_linux_user(){
        echo "suppresion user "$1
        userdel $1 && groupdel $1
}

event () {
    timestamp=$1
    event_type=$3
    container_id=$4
    service_type=$(echo $5 | cut -d'-' -f2)
    domain_name=$(echo $5 | cut -d'-' -f1)
    docker_name=$5
    docker_type=$2
    container_network_name=$5
    case $docker_type in
            "container")
                   case $service_type in
                          "httpd")
                                case $event_type in
                                 'create')
                                        id $domain_name 2> /dev/null || create_linux_user $domain_name
                                        add_lamp_conf $domain_name
                                        chown -R $domain_name:$domain_name $ENVS_DIR/$domain_name
                                        touch $ENVS_DIR/$domain_name/logs/db/mysql_error.log
                                        chmod 666 $ENVS_DIR/$domain_name/logs/db/mysql_error.log
                                 ;;
                                 'destroy')
                                        delete_linux_user $domain_name
                                        move_env_to_trash $domain_name
                                        docker network disconnect -f ${domain_name}_internal traefik
                                        docker network rm ${domain_name}_internal

                                ;;
                                esac
                          ;;
                          "traefik")
                                  case $event_type in
                                        "create")
                                                echo "ajout des network internes traefik"
                                                for network_id in `docker network ls | grep "_internal" | awk '{print $1}'`
                                                do
                                                        docker network connect $network_id traefik
                                                done
                                        ;;
                                        "destroy")
                                        ;;
                                esac
                          ;;
                   esac
            ;;
            "network")
                    case $event_type in
                            'create')
                                    echo ${docker_name} " network created"
                                    docker network connect ${docker_name} traefik
                            ;;
                            'destroy')
                                    echo ${docker_name} " network destroyed"
                            ;;
                    esac

            ;;
    esac

}


#docker events --filter 'event=create' --filter 'event=destroy' --filter 'type=container' --format '{{.Time}} {{.Action}} {{.ID}} {{.Actor.Attributes.name}}' | while read event
docker events --filter 'event=create' --filter 'event=destroy' --format '{{.Time}} {{.Type}} {{.Action}} {{.Actor.ID}} {{.Actor.Attributes.name}}' | while read event
#docker events --format="{{json .}}" | while read event
do
        echo $event
        event $event
done;
