#!/usr/bin/env bash

if [ -z ${DIR+x} ]; then
	#running by itself
	source ../../constants.sh
else
	#running from dendro_full_setup_ubuntu_server_ubuntu_16.sh
	source ./constants.sh
fi

id=$1
host=$2
port=$3

info "Setting up Redis Instance $id on host $host:$port..."
#save current dir
setup_dir=$(pwd)

#section to replace in redis service file
IFS='%'
read -r -d '' old_service_script_section << LUCHI
### BEGIN INIT INFO
# Provides:		redis-server
# Required-Start:	\$syslog \$remote_fs
# Required-Stop:	\$syslog \$remote_fs
# Should-Start:		\$local_fs
# Should-Stop:		\$local_fs
# Default-Start:	2 3 4 5
# Default-Stop:		0 1 6
# Short-Description:	redis-server - Persistent key-value db
# Description:		redis-server - Persistent key-value db
### END INIT INFO


PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
DAEMON=/usr/bin/redis-server
DAEMON_ARGS=/etc/redis/redis.conf
NAME=redis-server
DESC=redis-server

RUNDIR=/var/run/redis
PIDFILE=\$RUNDIR/redis-server.pid
LUCHI
unset IFS

#sections to replace in redis configuration file
IFS='%'
read -r -d '' old_conf_file_pid_section << LUCHI
pidfile /var/run/redis/redis-server.pid
LUCHI
unset IFS

IFS='%'
read -r -d '' old_conf_file_port_section << LUCHI
port 6379
LUCHI
unset IFS

IFS='%'
read -r -d '' old_conf_file_logfile_section << LUCHI
logfile /var/log/redis/redis-server.log
LUCHI
unset IFS

IFS='%'
read -r -d '' old_conf_file_dir_section << LUCHI
dir /var/lib/redis
LUCHI
unset IFS


setup_redis_instance()
{
  local id=$1
  local host=$2
  local port=$3
	local redis_instance_name="redis_$id_$port"

  local new_conf_file="$redis_conf_folder/$redis_instance_name.conf"
  local new_workdir="/var/run/r$redis_instance_name"
  local new_pidfile="/var/run/$redis_instance_name/$redis_instance_name.pid"
  local new_logfile="/var/log/redis/$redis_instance_name.log"
  local new_init_script_file="/etc/init.d/$redis_instance_name"

  if [ ! -d $new_workdir ]
  then
    mkdir -p $new_workdir
  fi

  #changes to conf file
  new_conf_file_pid_section="pidfile $new_pidfile"
  new_conf_file_port_section="port $port"
  new_conf_file_logfile_section="logfile $new_logfile"
  new_conf_file_dir_section="dir $new_workdir"

  #patch configuration file
  sudo cp "$redis_conf_file" "$new_conf_file" &&
  patch_file $new_conf_file	 \
          "$old_conf_file_pid_section" \
          "$new_conf_file_pid_section" \
          "$redis_instance_name-patch-pid" &&
  patch_file $new_conf_file	 \
          "$old_conf_file_port_section" \
          "$new_conf_file_port_section" \
          "$redis_instance_name-patch-logfile" &&
  patch_file $new_conf_file	 \
          "$old_conf_file_logfile_section" \
          "$new_conf_file_logfile_section" \
          "$redis_instance_name-patch-pid" &&
  patch_file $new_conf_file	 \
          "$old_conf_file_dir_section" \
          "$new_conf_file_dir_section" \
          "$redis_instance_name-patch-pid" || die "Unable to patch Redis $id's configuration file at $new_conf_file"

  #patch init script for new redis instance
IFS='%'
read -r -d '' new_service_script_section << LUCHI
### BEGIN INIT INFO
# Provides:		$redis_instance_name
# Required-Start:	\$syslog \$remote_fs
# Required-Stop:	\$syslog \$remote_fs
# Should-Start:		\$local_fs
# Should-Stop:		\$local_fs
# Default-Start:	2 3 4 5
# Default-Stop:		0 1 6
# Short-Description:	$redis_instance_name - Persistent key-value db
# Description:		$redis_instance_name - Persistent key-value db
### END INIT INFO


PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
DAEMON=$new_init_script_file
DAEMON_ARGS=$new_conf_file
NAME=$id
DESC=$id

RUNDIR=$new_workdir
PIDFILE=$new_pidfile
LUCHI
unset IFS

  printf "$old_service_script_section"
  printf "\n\n"
  printf "$new_service_script_section"

  sudo cp "$redis_init_script_file" "$new_init_script_file" &&
  patch_file $new_init_script_file	 \
          "$old_service_script_section" \
          "$new_service_script_section" \
          "$redis_instance_name-patch-service-file" \
					"sh" \
	|| die "Unable to patch the Configuration file for Redis instance $id on $host:$port."

  #start new service
  echo "$new_init_script_file start"

	#fix the line endings
	sudo apt-get --yes install dos2unix &&
	sudo dos2unix $new_init_script_file || die "Unable to convert the file into Unix Line endings."

	#mark file as executable and run it
	chmod +x $new_init_script_file
  sudo /bin/sh -c "$new_init_script_file start"
}

sudo nc "$host" "$port" < /dev/null;
server_not_listening=$?

if [[ "$server_not_listening" -ne "0" ]]
then
  setup_redis_instance $id $host $port
else
  warning "There is already a program listening on $host:$port. Stopping configuration of Redis instance $id on $host:$port."
fi

#return to previous dir
cd $setup_dir || die "Unable to return to previous directory while settting up Redis Instance Redis instance $id on $host:$port."
