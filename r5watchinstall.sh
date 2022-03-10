#!/bin/bash
#
# r5watchinstall.sh
#
# Watch Party Install Script
#
# port requirements:
# tcp: 22,80,443,1935,3478,5080,6262,8443,8554
# udp: 3478,25000-49999
#
# usage:
# ./r5watchinstall.sh $FQDN
# example: 
# ./r5watchinstall.sh watchparty.red5.net
#

FQDN=$1
# TODO: add $FQDN validation here

echo "... updating system ..."
apt update
apt upgrade -y

# install red5pro installer
if [ ! -d /root/red5pro-installer ]; then
  echo "... installing red5pro installer ..."
  cd /root
  git clone https://github.com/red5pro/red5pro-installer.git
fi
if [ ! -d /root/red5pro-installer ]; then
  echo "... red5pro installer failed ..."
  exit
fi

# install red5pro using installer
if [ ! -d /usr/local/red5pro ]; then
  echo "... installing red5pro ..."
  read -p "... press key to continue ... " -n1 -s
  cd /root/red5pro-installer
  ./red5proInstaller.sh
  cd ~
else
  echo "... red5pro already installed ..."
fi
if [ ! -d /usr/local/red5pro ]; then
  echo "... red5pro installation failed ..."
  exit
fi

# update ports for netinsight compatibility
if [ -d /usr/local/red5pro/conf ]; then
  echo "... configuring udp ports for netinsight compatbility ..."
  sed -i 's/port.min=.*/port.min=25000/g' /usr/local/red5pro/conf/webrtc-plugin.properties
  sed -i 's/port.max=.*/port.max=49999/g' /usr/local/red5pro/conf/webrtc-plugin.properties
  systemctl restart red5pro
else
  echo "... red5pro installation failed ..."
  exit
fi

# install ssl certificate
if [ ! -d /etc/letsencrypt/archive ]; then
  echo "... install ssl cert ..."
  read -p "... press key to continue ... " -n1 -s
  cd /root/red5pro-installer
  ./red5proInstaller.sh
  cd ~
fi
if [ ! -d /etc/letsencrypt/archive ]; then
  echo "... install ssl cert failed ..."
  exit
fi

# install coturn server
if [ ! -f /etc/turnserver.conf ]; then
  echo "... installing coturn server ..."
  apt install -y coturn
  echo "" >> /etc/turnserver.conf
  echo "listening-ip=0.0.0.0" >> /etc/turnserver.conf
  echo "external-ip=$FQDN" >> /etc/turnserver.conf
  echo "realm=red5.net" >> /etc/turnserver.conf
  echo "listening-port=3478" >> /etc/turnserver.conf
  systemctl enable turnserver
  systemctl restart turnserver
else
  echo "... coturn server already installed ..."
fi
if [ ! -f /etc/turnserver.conf ]; then
  echo "... coturn server installation failed ..."
  exit
fi

# configure red5 for local coturn server
if [ -d /usr/local/red5pro/webapps/live/script ]; then
  echo "... configuring red5pro for local coturn ..."
  sed -i 's/var iceServers.*/var iceServers = [{ urls: "stun:$FQDN:3478" }]/g' /usr/local/red5pro/webapps/live/script/r5pro-publisher-failover.js
  sed -i 's/var iceServers.*/var iceServers = [{ urls: "stun:$FQDN:3478" }]/g' /usr/local/red5pro/webapps/live/script/r5pro-subscriber-failover.js
  sed -i 's/var iceServers.*/var iceServers = [{ urls: "stun:$FQDN:3478" }]/g' /usr/local/red5pro/webapps/live/script/r5pro-viewer-failover.js
  systemctl restart red5pro
else
  echo "... red5pro not installed properly webapps/live/script is missing ..."
  exit
fi

# install watch party
if [ -d /usr/local/red5pro/webapps/root ]; then
  echo "... red5pro not installed properly webapps/root missing ..."
  exit
fi
if [ ! -d /usr/local/red5pro/webapps/root/red5pro-watch-party ]; then
  echo "... installing watch party ..."
  cd /usr/local/red5pro/webapps/root
  git clone https://github.com/red5pro/red5pro-watch-party.git
  cd ~
  if [ -d /usr/local/red5pro/webapps/root/red5pro-watch-party ]; then
    sed -i 's/your-host-here/$FQDN/g' /usr/local/red5pro/webapps/root/red5pro-watch-party/index.js
    sed -i 's/your-host-here/$FQDN/g' /usr/local/red5pro/webapps/root/red5pro-watch-party/static/script/testbed-config.js
    sed -i 's/port: 443/port: 8443/g' /usr/local/red5pro/webapps/root/red5pro-watch-party/index.js
    sed -i 's/iceServers.*/iceServers = [{ urls: "stun:$FQDN:3478" }],/g' /usr/local/red5pro/webapps/root/red5pro-watch-party/index.js
  else
    echo "... watch party installation failed ..."
	  exit
  fi
else
  echo "... watch party already installed ..."
fi
if [ ! -d /usr/local/red5pro/webapps/root/red5pro-watch-party ]; then
  echo "... watch party installation failed ..."
  exit
fi

# install conference host
if [ ! -d /usr/local/red5pro-conference-host ]; then
  echo "... installing conference host ..."
  cd /usr/local
  git clone https://github.com/red5pro/red5pro-conference-host.git
  cd /usr/local/red5pro-conference-host
  echo "... configuring conference host security ..."
  sed -i 's/const useSSL.*/const useSSL = true/g' /usr/local/red5pro-conference-hostindex.js
  sed -i 's/\/cert\/certificate.crt/\/etc\/letsencrypt\/archive\/$FQDN\/fullchain1.pem/g' /usr/local/red5pro-conference-host/index.js
  sed -i 's/\/cert\/privateKey.key/\/etc\/letsencrypt\/archive\/$FQDN\/privkey1.pem/g' /usr/local/red5pro-conference-host/index.js
  sed -i 's/port = 443/port = 8443/g' /usr/local/red5pro-conference-host/index.js
  echo "... installing conference host node application ..."
  apt install npm -y
  npm install index.js
  npm audit fix
  echo "... configuring conference host as a service ..."
  npm install pm2 -g
  pm2 start index.js
  pm2 save
  pm2 startup systemd
  cd ~
else
  echo "... red5pro conference host already installed ..."
fi
if [ ! -d /usr/local/red5pro-conference-host ]; then
  echo "... red5pro conference host installation failed ..."
  exit
fi

