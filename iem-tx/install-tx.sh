#!/bin/bash
#
# installation script for iem-tx transmitter

## overlay config
# configure overlay by appending to /boot/config.txt file
echo "dtoverlay=hifiberry-dacplusadc" | sudo tee -a /boot/config.txt
echo "dtoverlay=pi3-disable-bt" | sudo tee -a /boot/config.txt
# disable internal soundcard by not loading its module
sudo sed -i 's/dtparam=audio=on/dtparam=audio=off/' /boot/config.txt

## boot config
# disable sdhci low-latency mode by appending sdhci_bcm2708.enable_llm=0 to kernel cmdline
sudo sed -i 's/$/ sdhci_bcm2708.enable_llm=0/' /boot/cmdline.txt

## package installation
# refresh the package database
sudo apt-get update
# change debconf default value for jackd1 package
echo jackd jackd/tweak_rt_limits boolean true | sudo debconf-set-selections
# install jack without recommendations and omitting install confirmation
sudo DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends --option Dpkg::Options::="--force-confdef" --yes jackd1
# install zita-njbridge omitting install confirmation
sudo apt-get install --yes zita-njbridge

# append swappiness and inotify config to /etc/sysctl.conf and reread file
echo "vm.swappiness=10" | sudo tee -a /etc/sysctl.conf
echo "fs.inotify.max_user_watches=524288" | sudo tee -a /etc/sysctl.conf
sudo sysctl -f /etc/sysctl.conf

## service configuration
# disable daemons not needed
sudo systemctl disable bluetooth.service
sudo systemctl disable hciuart
sudo systemctl disable dbus.service
sudo systemctl disable triggerhappy.service
# and mask them to be sure
sudo systemctl mask bluetooth.service
sudo systemctl mask hciuart
sudo systemctl mask dbus.service
sudo systemctl mask triggerhappy.service
# disable realtimepi's tracking
sudo systemctl disable usage-statistics.service

## hostapd config
# install package
sudo apt-get install --yes dnsmasq hostapd
# deactivate dhcp client for wlan0
sudo cp conf/dhcpcd.conf /etc/dhcpcd.conf
# restart dhcpcd service
sudo systemctl restart dhcpcd
# configure dnsmasq and reload service
sudo mv /etc/dnsmasq.conf /etc/dnsmasq.conf.orig
sudo cp conf/dnsmasq.conf /etc/dnsmasq.conf
sudo systemctl reload dnsmasq
# allow ipv4 forwarding
sudo sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
# create and save iptables rule
sudo iptables -t nat -A  POSTROUTING -o eth0 -j MASQUERADE
sudo sh -c "iptables-save > /etc/iptables.ipv4.nat"
# insert iptables-restore < /etc/iptables.ipv4.nat before exit 0 in /etc/rc.local
sudo sed -i 's%exit 0%iptables-restore < /etc/iptables.ipv4.nat%' /etc/rc.local
echo "exit 0" | sudo tee -a /etc/rc.local
# copy hostapd.conf for wifi network configuration
sudo cp conf/hostapd.conf /etc/hostapd/hostapd.conf
# append config path to /etc/default/hostapd
echo 'DAEMON_CONF="/etc/hostapd/hostapd.conf"' | sudo tee -a /etc/default/hostapd
# activate and start service
sudo systemctl unmask hostapd
sudo systemctl enable hostapd
sudo systemctl start hostapd

## wlan config
# change active country code in helper file
sudo sed -i 's/country=GB/#country=GB/' /boot/realtimepi-wpa-supplicant.txt
sudo sed -i 's/#country=DE/country=DE/' /boot/realtimepi-wpa-supplicant.txt

## runtime setup
# copy resource files and enable enable zita-j2n.service
sudo cp bin/* /usr/bin/
sudo cp lib/*.service /lib/systemd/system/
sudo systemctl enable zita-j2n.service

## hostname config
# change hostname and write it to /etc/hosts file
sudo hostnamectl set-hostname iem-tx
sudo sed -i 's/realtimepi/iem-tx/' /etc/hosts

sudo reboot

exit 0
