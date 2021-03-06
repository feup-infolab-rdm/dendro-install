#!/usr/bin/env bash

if [ -z ${DIR+x} ]; then
	#running by itself
	source ../constants.sh
else
	#running from dendro_full_setup_ubuntu_server_ubuntu_16.sh
	source ./constants.sh
fi

#save current dir
setup_dir=$(pwd)

# # =====================
# # = PM2 Service setup =
# # =====================
#
# info "Setting up PM2 Daemon auto start for supporting Dendro in production...\n"
#
# #generate pm2 autostart command
# CREATE_SERVICE_COMMAND=$(sudo su $dendro_user_name -c "source ~/.bash_profile > /dev/null; nvm use $node_version > /dev/null; pm2 startup | tail -n 1")
#
# #create service command
# info "Running command to load pm2 process manager daemon: $CREATE_SERVICE_COMMAND ..."
#
# # load nvm, run service with the right node version
# export NVM_DIR="$HOME/.nvm" &&
# [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
# eval "nvm use $node_version && $CREATE_SERVICE_COMMAND"

# ==================================
# = Set up dendro instance service =
# ==================================

info "Setting up $dendro_service_name Dendro service...\n"

#stop current service if present
info "Stopping $dendro_service_name service..."
sudo systemctl stop $dendro_service_name > /dev/null

#setup auto-start dendro service
sudo rm -rf $dendro_startup_item_file
sudo touch $dendro_startup_item_file
sudo chmod 0655 $dendro_startup_item_file

#create startup scripts folder...
sudo mkdir -p "$dendro_startup_scripts_path"

printf "Dendro Running Service Command:"
printf "\n"
printf "$dendro_startup_script"
printf "\n"

#build startup script file
sudo rm -rf $dendro_startup_script &&
sudo cp $setup_dir/Services/dendro_startup_script_template.sh $dendro_startup_script &&
sudo sed -i "s;%DENDRO_INSTALLATION_PATH%;$dendro_installation_path;g" $dendro_startup_script &&
sudo sed -i "s;%DENDRO_SERVICE_NAME%;$dendro_service_name;g" $dendro_startup_script &&
sudo sed -i "s;%DENDRO_LOG_FILE%;$dendro_log_file;g" $dendro_startup_script &&
sudo sed -i "s;%NODE_VERSION%;$node_version;g" $dendro_startup_script || die "Unable to build the startup script at $dendro_startup_script"

#build stop script file
sudo rm -rf $dendro_stop_script &&
sudo cp $setup_dir/Services/dendro_stop_script_template.sh $dendro_stop_script &&
sudo sed -i "s;%DENDRO_INSTALLATION_PATH%;$dendro_installation_path;g" $dendro_stop_script &&
sudo sed -i "s;%DENDRO_SERVICE_NAME%;$dendro_service_name;g" $dendro_stop_script &&
sudo sed -i "s;%NODE_VERSION%;$node_version;g" $dendro_stop_script || die "Unable to build the stop script at $dendro_stop_script"

#build reload script file
sudo rm -rf $dendro_reload_script &&
sudo cp $setup_dir/Services/dendro_reload_script_template.sh $dendro_reload_script &&
sudo sed -i "s;%DENDRO_INSTALLATION_PATH%;$dendro_installation_path;g" $dendro_reload_script &&
sudo sed -i "s;%DENDRO_SERVICE_NAME%;$dendro_service_name;g" $dendro_reload_script &&
sudo sed -i "s;%NODE_VERSION%;$node_version;g" $dendro_reload_script || die "Unable to build the reload script at $dendro_stop_script"

#restore ownership of the startup files to dendro user
sudo chown -R $dendro_user_name:$dendro_user_group $dendro_startup_scripts_path &&
sudo chmod +x $dendro_startup_script &&
sudo chmod +x $dendro_stop_script &&
sudo chmod +x $dendro_reload_script  || die "Unable to change permissions of the startup script at $dendro_startup_scripts_path"

if [[ "$environment" == "production" ]]; then
	printf "[Unit]
	Description=Dendro Service (${active_deployment_setting})
	Wants=network-online.target
	After=network.target network-online.target
	[Service]
	WorkingDirectory=$dendro_installation_path
	User=$dendro_user_name
	Group=$dendro_user_group
	Type=forking
	ExecStart=$dendro_startup_script
	ExecStop=$dendro_stop_script
	ExecReload=$dendro_reload_script
	TimeoutSec=infinity,
	PIDFile=$dendro_installation_path/running.pid
	[Install]
	WantedBy=multi-user.target network-online.target\n" | sudo tee $dendro_startup_item_file
else
	printf "[Unit]
	Description=Dendro Service (${active_deployment_setting})
	[Service]
	Type=simple
	Restart=on-failure
	RestartSec=5s
	TimeoutStartSec=infinity
	User=$dendro_user_name
	Group=$dendro_user_group
	RuntimeMaxSec=infinity
	KillMode=control-group
	ExecStart=$dendro_startup_script
	PIDFile=${dendro_installation_path}/running.pid
	[Install]
	WantedBy=multi-user.target\n" | sudo tee $dendro_startup_item_file
fi

sudo chmod 0655 $dendro_startup_item_file
sudo systemctl daemon-reload
sudo systemctl enable $dendro_service_name
sudo systemctl start $dendro_service_name

cd $setup_dir || die "Error returning to setup folder"

success "Finished setting up Dendro service.\n"
