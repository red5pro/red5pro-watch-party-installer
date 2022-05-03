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
# /etc/iptables/rules.v4:
# -A INPUT -p udp --dport 3478 -j ACCEPT
# -A INPUT -p udp --dport 25000:49999 -j ACCEPT
# -A INPUT -p tcp -m state --state NEW -m tcp --dport 22 -j ACCEPT
# -A INPUT -p tcp -m state --state NEW -m tcp --dport 80 -j ACCEPT
# -A INPUT -p tcp -m state --state NEW -m tcp --dport 443 -j ACCEPT
# -A INPUT -p tcp -m state --state NEW -m tcp --dport 1935 -j ACCEPT
# -A INPUT -p tcp -m state --state NEW -m tcp --dport 3478 -j ACCEPT
# -A INPUT -p tcp -m state --state NEW -m tcp --dport 5080 -j ACCEPT
# -A INPUT -p tcp -m state --state NEW -m tcp --dport 6262 -j ACCEPT
# -A INPUT -p tcp -m state --state NEW -m tcp --dport 8443 -j ACCEPT
# -A INPUT -p tcp -m state --state NEW -m tcp --dport 8554 -j ACCEPT
#
# usage:
# ./r5watchinstall.sh $FQDN
# example: 
# ./r5watchinstall.sh watchparty.example.org
#

FQDN=$1
# $FQDN validation
if [ -z "$FQDN" ]; then
  echo "usage: r5watchinstall.sh FQDN"
  echo "example: ./r5watchinstall.sh watchparty.example.org"
  exit 1
fi
WATCHBRANCH=$2

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
  exit 2
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
  exit 3
fi

# update ports for netinsight compatibility
if [ -d /usr/local/red5pro/conf ]; then
  echo "... configuring udp ports for netinsight compatbility ..."
  # 10.3 moved the port configuration to network.properties
  if [ ! -f /usr/local/red5pro/conf/network.properties ]; then
    sed -i 's/port.min=.*/port.min=25000/g' /usr/local/red5pro/conf/webrtc-plugin.properties
    sed -i 's/port.max=.*/port.max=49999/g' /usr/local/red5pro/conf/webrtc-plugin.properties
  else
    sed -i 's/port.min=.*/port.min=25000/g' /usr/local/red5pro/conf/network.properties
    sed -i 's/port.max=.*/port.max=49999/g' /usr/local/red5pro/conf/network.properties
  fi
  systemctl restart red5pro
else
  echo "... red5pro installation failed ..."
  exit 4
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
  exit 5
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
  sed -i 's/#TURNSERVER_ENABLED=1/TURNSERVER_ENABLED=1/g' /etc/default/coturn
  systemctl enable coturn
  systemctl restart coturn
else
  echo "... coturn server already installed ..."
fi
if [ ! -f /etc/turnserver.conf ]; then
  echo "... coturn server installation failed ..."
  exit 6
fi

# configure red5 for local coturn server
if [ -d /usr/local/red5pro/webapps/live/script ]; then
  echo "... configuring red5pro for local coturn ..."
  sed -i 's/stun.address.*/stun.address='"$FQDN"':3478/g' /usr/local/red5pro/conf/webrtc-plugin.properties
  # 10.3 added new settings location
  if [ ! -f /usr/local/red5pro/conf/network.properties ]; then
    sed -i 's/var iceServers.*/var iceServers = [{ urls: "stun:'"$FQDN"':3478" }];/g' /usr/local/red5pro/webapps/live/script/r5pro-publisher-failover.js
    sed -i 's/var iceServers.*/var iceServers = [{ urls: "stun:'"$FQDN"':3478" }];/g' /usr/local/red5pro/webapps/live/script/r5pro-subscriber-failover.js
    sed -i 's/var iceServers.*/var iceServers = [{ urls: "stun:'"$FQDN"':3478" }];/g' /usr/local/red5pro/webapps/live/script/r5pro-viewer-failover.js
  else
    sed -i 's/stun.address.*/stun.address='"$FQDN"':3478/g' /usr/local/red5pro/conf/network.properties
  fi
  systemctl restart red5pro
else
  echo "... red5pro not installed properly webapps/live/script is missing ..."
  exit 7
fi

# install watch party
if [ ! -d /usr/local/red5pro/webapps/root ]; then
  echo "... red5pro not installed properly webapps/root missing ..."
  exit 8
fi
if [ ! -d /usr/local/red5pro/webapps/root/red5pro-watch-party ]; then
  echo "... installing watch party ..."
  cd /usr/local/red5pro/webapps/root
  if [ ! -z "$WATCHBRANCH" ]; then
    echo "... installing branch $WATCHBRANCH ..."
    git clone -b $WATCHBRANCH https://github.com/red5pro/red5pro-watch-party.git
  else
    git clone https://github.com/red5pro/red5pro-watch-party.git
  fi
  cd ~
  if [ -d /usr/local/red5pro/webapps/root/red5pro-watch-party ]; then
    sed -i 's/your-host-here/'"$FQDN"'/g' /usr/local/red5pro/webapps/root/red5pro-watch-party/index.js
    sed -i 's/your-host-here/'"$FQDN"'/g' /usr/local/red5pro/webapps/root/red5pro-watch-party/static/script/testbed-config.js
    sed -i 's/iceServers.*/iceServers: [{ urls: "stun:'"$FQDN"':3478" }],/g' /usr/local/red5pro/webapps/root/red5pro-watch-party/index.js
    sed -i '0,/"stun:.*"/s/"stun:.*"/"stun:'"$FQDN"':3478"/' /usr/local/red5pro/webapps/root/red5pro-watch-party/static/script/testbed-config.js
  else
    echo "... watch party installation failed ..."
    exit 9
  fi
else
  echo "... watch party already installed ..."
fi
if [ ! -d /usr/local/red5pro/webapps/root/red5pro-watch-party ]; then
  echo "... watch party installation failed ..."
  exit 10
fi

# install conference host
if [ ! -d /usr/local/red5pro-conference-host ]; then
  echo "... installing conference host ..."
  cd /usr/local
  git clone https://github.com/red5pro/red5pro-conference-host.git
  cd /usr/local/red5pro-conference-host
  echo "... configuring conference host security ..."
  sed -i 's/const useSSL.*/const useSSL = true/g' /usr/local/red5pro-conference-host/index.js
  sed -i 's/\.\/cert\/certificate.crt/\/etc\/letsencrypt\/archive\/'"$FQDN"'\/fullchain1.pem/g' /usr/local/red5pro-conference-host/index.js
  sed -i 's/\.\/cert\/privateKey.key/\/etc\/letsencrypt\/archive\/'"$FQDN"'\/privkey1.pem/g' /usr/local/red5pro-conference-host/index.js
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
  exit 11
fi

echo "... installation complete ..."
