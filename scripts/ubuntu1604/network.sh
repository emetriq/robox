#!/bin/bash -eux

# To allow for autmated installs, we disable interactive configuration steps.
export DEBIAN_FRONTEND=noninteractive
export DEBCONF_NONINTERACTIVE_SEEN=true

# Disable IPv6 for the current boot.
sysctl net.ipv6.conf.all.disable_ipv6=1

# Ensure IPv6 stays disabled.
printf "\nnet.ipv6.conf.all.disable_ipv6 = 1\n" >> /etc/sysctl.conf

# Set the hostname, and then ensure it will resolve properly.
if [[ "$PACKER_BUILD_NAME" =~ ^(lineage|lineageos)(-nash)?-(vmware|hyperv|libvirt|parallels|virtualbox)$ ]]; then
  printf "lineage.builder\n" > /etc/hostname
  printf "\n127.0.0.1 lineage.builder\n\n" >> /etc/hosts
elif [[ "$PACKER_BUILD_NAME" =~ ^generic-ubuntu1604-(vmware|hyperv|libvirt|parallels|virtualbox)$ ]]; then
  printf "ubuntu1604.localdomain\n" > /etc/hostname
  printf "\n127.0.0.1 ubuntu1604.localdomain\n\n" >> /etc/hosts
else
  printf "magma.builder\n" > /etc/hostname
  printf "\n127.0.0.1 magma.builder\n\n" >> /etc/hosts
fi

# Clear out the existing automatic ifup rules.
sed -i -e '/^auto/d' /etc/network/interfaces
sed -i -e '/^iface/d' /etc/network/interfaces
sed -i -e '/^allow-hotplug/d' /etc/network/interfaces

# Ensure the loopback, and default network interface are automatically enabled and then dhcp'ed.
printf "allow-hotplug eth0\n" >> /etc/network/interfaces
printf "auto lo\n" >> /etc/network/interfaces
printf "iface lo inet loopback\n" >> /etc/network/interfaces
printf "iface eth0 inet dhcp\n" >> /etc/network/interfaces

# Adding a delay so dhclient will work properly.
printf "pre-up sleep 2\n" >> /etc/network/interfaces

# Install ifplugd so we can monitor and auto-configure nics.
apt-get --assume-yes install ifplugd

# Configure ifplugd to monitor the eth0 interface.
sed -i -e 's/INTERFACES=.*/INTERFACES="eth0"/g' /etc/default/ifplugd

# Ensure the networking interfaces get configured on boot.
systemctl enable networking.service

# Ensure ifplugd also gets started, so the ethernet interface is monitored.
systemctl enable ifplugd.service

# Reboot onto the new kernel (if applicable).
$(shutdown -r +1) &

