---
title: "Building a Homelab: Part 1"
description: A beginner's guide to bulding a home-lab, using cheap hardware and free and open-source tools.
date: 2020-04-28
draft: false
ProjectLevel: Beginner
ProjectTime: 2 hour
toc: true
featuredImage: images/building-a-home-lab-1/featured-image.jpg
tags:
  - ubuntu
  - kvm
  - docker
  - homelab
categories:
  - homelab
---

## Introduction

For the tinkerers and hobbyists out there who are interested in tech, there's often a limit to what you can test and experiment with on just a single computer at home. You may be limited by your operating system, or not want to potentially brick a computer you have your personal data on, or even need to test some network tool which requires a server and a client, or two servers, or 10 clients.

Unfortunately, there really isn't a lot that can be done with an old laptop, or underpowered desktop from a decade ago (although these are perfect candidates for a [Pi-Hole](https://pi-hole.net/)), but there is a lot you can do with a more powerful laptop, or desktop from within the past 5 years or so, or server which can be picked up for [under £100 online](https://www.ebay.co.uk/sch/i.html?_from=R40&_nkw=server&_sacat=0&Number%2520of%2520Processors=2&rt=nc&_oaa=1&_dcat=11211). The rest of this post will assume the following as minimum specs for the host machine which we'll be using for our lab:

| Hardware          | Minimum   | Suggested                     |
|-------------------|-----------|-------------------------------|
| RAM               | 16GB DDR3 | >64GB DDR3/DDR4 (ideally ECC) |
| Storage           | 500GB HDD | >1TB RAID5/RAID10 HDD         |
| CPU Cores         | 4 @ 2GHz+ | >8 @ 2GHz+                    |
| Network Interface | 1 x 1GbE  | >4 x 1GbE                     |
| I/O Ports         | 2 x USB2  | >2 x USB3.0                   |

Graphics are not so much of a concern since this may be a server rather than an old gaming machine, but you should have at least a VGA port so you can see what you're doing while running through the initial install.

Once you've confirmed your machine meets or exceeds the specs above (you can try it with lower-specc'd machines too, the performance just won't be as good), you can move onto the meat and potatoes of this post.

What this guide aims to do is run through the initial installation of Ubuntu Server 20.04 on your machine, configuring it as a virtualisation platform, installing helper tools to make managing VM's and containers easier, and performing some basic hardening tasks for security.

### Why Ubuntu?

This is largely a matter of personal preference, but I've opted for Ubuntu here as the host for several reasons:

Firstly, KVM is a kernel-level hypervisor - so it's essentially type-1 - meaning we're not losing out on any performance in translation from the guest to the host OS, and Ubuntu Server 20.04 has a fairly small footprint when it comes to hardware resources for the OS level itself, so we can provision VM's and containers right up to pretty much 100% of the host resources without much trouble.

What's more Ubuntu is stable, actively maintained, and can be upgraded in-place so can be safely used for the forseeable future without the need to worry about security patches and updates. Lastly, it will run on pracitcally anything without the need to manually install additional drivers/firmware.

Compare that to other free type-1 hypervisors like VMware's ESXi (vSphere) and Microsoft's Hyper-V, where hardware support and updates can be flakey and hard to find, and an Ubuntu 20.04 KVM host becomes a clear candidate for a DIY lab cobbled together from old or refurbished equipment on a shoestring budget (and arguably, for enterprise and SMB's too).

([ProxMox](https://www.proxmox.com/en/) gets an honorable mention as it's essentially similar, but I've found Ubuntu 20.04 and Cockpit to be easier to use in general, and you can still dive into the nuts and bolts more easily if needed.)

## Step 0: Burning the Installer

You'll need a copy of Ubuntu 20.04 before starting, which you can get from here:

<https://releases.ubuntu.com/20.04/>

In the demo I'll be using the Server image as we'll be doing most of the management through the web portal anyway, but if you'd prefer a GUI, the Desktop image is essentially similar for our purposes.

The ISO image will then need to be burnt to either a USB or DVD so you can boot to it on your server. This can be done using:

USB:
- Windows - <https://rufus.ie>
- MacOS/Linux - <https://www.balena.io/etcher>

DVD:
- Windows - File Explorer
- Mac - Finder

Once that's done we can move onto the install.

## Step 1: The Install

First up, we need to boot into the newly created installer. If it's a completely new (or newly refurbished) machine with no bootable OS installed, the machine should boot to your installer when connected as soon as it's finished its power-onn self-test (POST). If this doesn't happen, or there's an OS already installed which we're removing, you'll need to get into the boot menu.

Frustratingly, how this works is not standardised, and the timeout for the instructions on getting in can be quite short, so it's usually best acheived by just spamming the function keys on your keyboard as soon as you power the machine on, and then waiting to see what comes up on screen. Often, you'll be sent into the BIOS, but from here you can usually navigate to a boot-order menu, and then move USB (or DVD) to the top, then save and exit.

If you're really struggling, you can google the make and model of your machine with the phrase "boot menu" at the end and you'll usually find a guide online.

You'll know when you've booted into the installer when you see a screen like this:

![boot-screen](images/building-a-home-lab-1/Ubuntu-boot.png)

From here, select your language, and then "Install Ubuntu Server" which will begin booting into the installer, after which you'll be asked to confirm the language again and optionally download an updated installer (which I recommend doing), and finally will be brought to the locale selection screen where you select your keyboard layout:

![locale-screen](images/building-a-home-lab-1/Ubuntu-locale.png)

Select the locale for your keyboard using the arrow and enter (or space) keys, and hit "Done". Next you'll be brought to the network setup screen:

![network-screen](images/building-a-home-lab-1/Ubuntu-networksetup.png)

For the sake of keeping things simple, we'll just leave this as DHCP for now and reconfigure it once we're in the OS. This is where you'd normally setup a static IP for the system dring install though, and you can even configure network bonds and bridges from here too, so it's worth experiementing a little here in the future.

For the sake of brevity, for now just select "Done" and then "Done" again on the proxy configuration and archive mirror screens to get to the guided storage configuration screen:

![storage-screen](images/building-a-home-lab-1/Ubuntu-storagesetup.png)

Make sure to select the checkbox to setup a Logical Volume Management (LVM) group, as this will help us in the future if we ever need to expand the local storage in the future. If you're using a multi-disk system, you can also setup a software RAID volume in the next screen, but it's a bit more involved than what we're looking to cover in this guide so I'm leaving it out. A single disk is usually fine for an OS disk in any case (for home environments like this anyway - not in production), we'll cover creating a software RAID storage pool for the VM's later on which is probably the best move for beginners at least.

The next screen will simply show you a confirmation page with the changes the installer is about to make to the disk, note that **this will wipe all of the data on the disk you've selected**, so it's worth double checking you have the right one.

Once you're happy, select "Done", and then when prompted, select "Continue" to format the disk ready for the OS:

![confirm-erase](images/building-a-home-lab-1/Ubuntu-formatdisk.png)

This will bring you to the profile setup screen, where you can enter the server hostname, your username, and your passwod. Pop whatever details in you like, noting that this is your primary admin account, so the password should be secure but memorable, and then continue to the next screen.

Make sure you check the box to install OpenSSH Server on the system:

![install-ssh](images/building-a-home-lab-1/Ubuntu-ssh-install.png)

Don't worry about the identity import for now, and select "Done", then "Done" again as we'll be handling the software installs ourselves so don't need anything pre-packaged.

You'll now see the OS install log as it's running through the install (and maybe upgrade) of the system. This may take some time, so you can just leave this for 10 minutes or so, and then come back and reboot the machine when the process has finished:

![install-complete](images/building-a-home-lab-1/Ubuntu-installdone.png)

## Step 2: Configure Cockpit

Once the installation is complete, and the system has rebooted you should be greeted by this (just hit <kbd>Ctrl</kbd>+<kbd>C</kbd> a few times if you have a bunch of crap over the screen - this is just the Ubuntu cloud config which usually loads after the system boots):

![login-screen](images/building-a-home-lab-1/Ubuntu-login.png)

At this point, for the sake of easy management, I suggest remotely logging into the server via `ssh`. If you're on Windows and need an SSH client, you can install the native powershell module using [this guide](https://www.howtogeek.com/336775/how-to-enable-and-use-windows-10s-built-in-ssh-commands/).

Depending on your network setup, you *should* be able to just use the following:

```bash
# replace 'james' and 'big-poppa' with your server username and hostname respectively
ssh james@big-poppa.local
```

If that fails, you might need to grab the IP address from the host, which you can do by logging into it directly:

![logged-in](images/building-a-home-lab-1/Ubuntu-loggedin.png)

From there on your other system you just enter:

```bash
# replace 'james' and '10.211.55.28' with the server username and IP address respectively
ssh james@10.211.55.28
```

Alternatively, you can just enter the following commands directly on the machine itself, it's just easier to copy and paste them rather than typing them out.

We can now install and activate Cockpit and the modules which will be useful for our homelab:

```bash
sudo apt install -y cockpit \
    cockpit-pcp \
    cockpit-storaged \
    cockpit-machines \
    cockpit-packagekit \
    docker \
    docker-compose \
    network-manager \
    firewalld \
    tuned \
    vim && \
curl -LO https://launchpad.net/ubuntu/+source/cockpit/215-1~ubuntu19.10.1/+build/18889196/+files/cockpit-docker_215-1~ubuntu19.10.1_all.deb && \
sudo dpkg --install cockpit-docker_215-1~ubuntu19.10.1_all.deb && \
sudo rm cockpit-docker_215-1~ubuntu19.10.1_all.deb && \
sudo service cockpit start && \
sudo systemctl enable --now {cockpit.socket,docker,libvirtd} && \
sudo firewall-cmd --add-service=cockpit --permanent && \
sudo systemctl status {cockpit.socket,docker,libvirtd} && \
sleep 10 && \
sudo shutdown -r now
```

{{< admonition note >}}
Since I originally wrote this, `cockpit-docker` has become unavailable on the default Focal Fossa repo. I'll write a post in the future to swap docker out for podman when `cockpit-podman` is ported to Ubuntu.
{{< /admonition >}}

You should now see something like this before the system goes down for a reboot:

![services-running](images/building-a-home-lab-1/services-running.png)

We can now continue the configuration through the web panel, which will be the main way we interact with this server from here on out.

## Step 3: Host Configuration

### Networking

Open a browser window on your computer and navigate to the IP address or hostname.local of the server followed by the port, which is `9090`. In the example above, my host IP was `10.211.55.28` so the address for this would look like:

`https://10.211.55.28:9090/`

Just ignore the certificate warning, this is because the system generates one during the install and it's not known to our other machine. Once you're past that you'll be greeted by a login screen for the cockpit web service - which you can access using the credentials created during the install:

![cockpit-dash](images/building-a-home-lab-1/cockpit-dash.png)

From here we'll open the Terminal pane which will give us a shell on the box, which we'll use to configure the host to optimise it for hosting VM's and for management through Cockpit.

For starters, we'll make sure that `/etc/sysctl.conf` is configured to allowing network traffic from our VM's on the hosts network:

```bash
echo 'net.bridge.bridge-nf-call-ip6tables = 0
net.bridge.bridge-nf-call-iptables = 0
net.bridge.bridge-nf-call-arptables = 0' | sudo tee -a /etc/sysctl.conf && \
sudo sysctl -p 1> /dev/null
```

Which should output what was `echo`'d, meaning they've been applied.

We'll also just add a `crontab` entry to apply this each boot, as Ubuntu's cloud config sometimes messes with this:

```bash
(sudo crontab -l 2>/dev/null; echo "@reboot sleep 30 ; sysctl -p") | sudo crontab -
```

Now we can setup our network interfaces to allow Cockpit to manage them via the NetworkManager API:

{{< admonition note >}}
That this will reboot the system, and change in network management will probably cause the system to forget its DHCP lease, so if you couldn't use the hostname.local before, you'll need to log into the system locally again to confirm the new IP.
{{< /admonition >}}

```bash
sudo mv /etc/netplan/* ./ && \
echo '# Let NetworkManager manage all devices on this system
network:
  version: 2
  renderer: NetworkManager' | sudo tee /etc/netplan/01-network-manager-all.yaml && \
sudo systemctl disable systemd-networkd && \
sudo systemctl enable --now NetworkManager && \
sudo service NetworkManager status && \
sudo netplan apply && \
sleep 5
sudo shutdown -r now
```

Once your system comes back up (and you've found the new IP if your DHCP lease changed), head back to the web panel and log in, then navigate to the Networking pane:

![cockpit-networking](images/building-a-home-lab-1/Cockpit-networking.png)

From here we can set a static IP, and create a network bridge for our VM's. Make a note of the current active interface (highlighted below), and then click "Add Bridge".

![active-link](images/building-a-home-lab-1/Cockpit-active-iface.png)

You should then see a menu with a list of interfaces to add to the bridge along with the option to enable spanning-tree protocol. Here we want to select our currently active interface, along with enabling spanning-tree protocol (the default STP settings are fine for a home network).

Applying the settings may take a little while, but once it's done, head back to the main networking panel and you should see that the interface you added has been replaced by `bridge0`. We can now configure a static IP for our new bridge, so we don't have to log into the server locally again if the DHCP address changes.

To do this, simply select the `bridge0` interface from the list, then click the "Automatic (DHCP)" link next to IPv4, set the address to manual and enter your desired IP address, followed by the gateway (your router's IP, usually something like `192.168.0.1` or `192.168.1.1` if your DHCP address was `192.168.0.X` or `192.168.1.X` respectively). For home networks, the prefix length will almost always be `24`.

I would highly recommend using custom DNS servers too, in the example below I've set mine to Cloudflare's `1.1.1.1` with Google's `8.8.8.8` as a fallback:

![static-ip](images/building-a-home-lab-1/Cockpit-static-ip.png)

After hitting "Apply" you'll need to wait a few seconds for the new interface to come online, and then head over to your new IP address followed by `:9090` again to reconnect to the web panel (you'll need to log in again as well).

### Storage

Now we're up and running with the web panel, you may have noticed that we only have about 4GB of storage on the root volume. This is because Ubuntu doesn't provision the full disk by default when it sets up an LVM group, we can double check this by heading to the Storage panel where we can see the active disk, and the storage capacity (the active disk is `/dev/sda`, since the `/boot` volume is on `/dev/sda2` - we'll verify this in a minute):

![storage-config](images/building-a-home-lab-1/Cockpit-lvmstorage.png)

{{< admonition note >}}
Your logical volume should also be `/dev/ubuntu-vg/ubuntu-lv`, if it's not, make a note of it.
{{< /admonition >}}

so we can head over to the Terminal pane again to expand the default storage group to cover the entirety of our OS disk. We'll first double check that the disk we found in Cockpit is the right one:

```bash
lsblk
```

should output something like:

```bash{hl_lines=[3,7]}
NAME                      MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
...
sda                         8:0    0   64G  0 disk 
├─sda1                      8:1    0    1M  0 part 
├─sda2                      8:2    0    1G  0 part /boot
└─sda3                      8:3    0   63G  0 part 
  └─ubuntu--vg-ubuntu--lv 253:0    0    4G  0 lvm  /
...
```

We can see from this that `/dev/sda` is in fact the correct disk for us to be expanding the LV into and `/dev/sda3` is the volume we're expanding into directly. With that confirmed, we'll resize our logical volume like so:

```bash
# Keep running this until you have no free extents on the disk (you may need to change the '100000' as the disk fills up)
sudo lvm lvresize -l +100000 -r /dev/ubuntu-vg/ubuntu-lv /dev/sda3
```

Once that's done, we can head back over to the storage pane and verify that our changes have been applied:

![cockpit-lv-resized](images/building-a-home-lab-1/Cockpit-lvmresized.png)

### VM Storage

{{< admonition tip >}}
If you don't have additional storage for the virtual machines, just ignore this section and move onto the [VM Networking](#vm-networking) section
{{< /admonition >}}

We'll start by making the mount point for the VM storage pool:

```bash
sudo mkdir -p /media/vm_pool
```

Then we'll move on to configuring the storage volume, which we can do through Cockpit. Head over to the Storage pane and select the additional block device:

![cockpit-additional-storage](images/building-a-home-lab-1/Cockpit-additional.png)

Click "Create Partition Table", then "Format". Now select "Create Partition" and just call it "vm_pool" to keep things simple. Set the mount point to the one we created:

![cockpit-vm-poool](images/building-a-home-lab-1/Cockpit-vm-pool.png)

Create the partition, and it should mount automatically, if it doesn't just mount it using the UI. Now we can setup the VM pool using `virsh`. First, we'll create the storage XML:

```bash
printf "<pool type='dir'>
  <name>default</name>
  <target>
    <path>/media/vm_pool</path>
    <permissions>
      <mode>0755</mode>
      <owner>0</owner>
      <group>0</group>
    </permissions>
  </target>
</pool>" > default.xml
```

From there we can define the storage pool:

```bash
sudo virsh pool-define --file default.xml && \
sudo virsh pool-start default && \
sudo virsh pool-autostart default && \
rm default.xml
```

Now we can see this in the Virtual Machine pane:

![libvirt-pool](images/building-a-home-lab-1/Libvirt-pool.png)

As it's called "default", VM's we build through Cockpit will automatically be assigned to this pool.

### VM Networking

For the networking, we'll keep it simple and just create a default and semi-isolated VLAN, for this we'll create a couple of XML's again to define the networks:

```bash
sudo virsh net-destroy default && \
sudo virsh net-undefine default && \
printf "<network>
  <name>default</name>
  <forward dev='bridge0' mode='bridge' />
</network>" > default.xml && \
sudo virsh net-define --file default.xml && \
sudo virsh net-autostart default && \
sudo virsh net-start default && \
rm default.xml
```

```bash
printf "<network>
  <name>semi-isolated</name>
  <forward mode='nat'/>
  <ip address='10.0.0.1'>
    <dhcp>
      <range start='10.0.0.100' end='10.0.0.200'/>
    </dhcp>
  </ip>
</network>" > semi-isolated.xml && \
sudo virsh net-define --file semi-isolated.xml && \
sudo virsh net-autostart semi-isolated && \
sudo virsh net-start semi-isolated && \
rm semi-isolated.xml
```

We should now see those VM VLAN's in Cockpit:

![libvirt-vlans](images/building-a-home-lab-1/Libvirt-network.png)

### Security Hardening

Now we can begin hardening the security of the system, we'll start with the `/etc/ssh/sshd_config`.

First, we'll need to create an SSH ID if we don't already have one:

{{< admonition note >}}
The two following commands should be executed on your **main machine, NOT the server**.
{{< /admonition >}}

```bash
ssh-keygen -t rsa -b 4096 -f $HOME/.ssh/id_rsa -N ''
```

If you're presented with the option to overwrite, just enter "no" or "n" and we'll use your existing ID.

Next, copy your SSH public-key to the authorised keys on the host machine:

```bash
# Replace 'james' and '10.211.55.29' with your username and host IP address respectively
ssh-copy-id james@10.211.55.29
```

Now we can restrict SSH access to lock-down remote access policies:

```bash
echo '#Include /etc/ssh/sshd_config.d/*.conf
# Authentication:
LoginGraceTime 2m
PermitRootLogin no
StrictModes yes
PasswordAuthentication no
PubkeyAuthentication yes
PermitEmptyPasswords no
ChallengeResponseAuthentication no
UsePAM yes
X11Forwarding no
PrintMotd no
AcceptEnv LANG LC_*

# override default of no subsystems
Subsystem sftp	/usr/lib/openssh/sftp-server

# Kerberos options
#KerberosAuthentication no
#KerberosOrLocalPasswd yes
#KerberosTicketCleanup yes
#KerberosGetAFSToken no

# GSSAPI options
#GSSAPIAuthentication no
#GSSAPICleanupCredentials yes
#GSSAPIStrictAcceptorCheck yes
#GSSAPIKeyExchange no' | sudo tee /etc/ssh/sshd_config && \
sudo service sshd restart
```

This prevents `root` login via SSH, and blocks empty passwords, as well as username-password style authentication (so only machines with your `~/.ssh/id_rsa` key will be able to access this machine via SSH).

Next, we'll modify the automated-upgrades config file:

```bash
sudo sed -i 's/\/\/.*\"${distro_id}:${distro_codename}-updates\";/        \"${distro_id}:${distro_codename}-updates\";/' /etc/apt/apt.conf.d/50unattended-upgrades && \
sudo sed -i 's/\/\/Unattended-Upgrade::AutoFixInterruptedDpkg "true";/Unattended-Upgrade::AutoFixInterruptedDpkg "true";/' /etc/apt/apt.conf.d/50unattended-upgrades && \
sudo sed -i 's/\/\/Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";/Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";/' /etc/apt/apt.conf.d/50unattended-upgrades && \
sudo sed -i 's/\/\/Unattended-Upgrade::Remove-Unused-Dependencies "false";/Unattended-Upgrade::Remove-Unused-Dependencies "true";/' /etc/apt/apt.conf.d/50unattended-upgrades && \
sudo sed -i 's/\/\/Unattended-Upgrade::Automatic-Reboot "false";/Unattended-Upgrade::Automatic-Reboot "false";/' /etc/apt/apt.conf.d/50unattended-upgrades && \
sudo sed -i 's/\/\/Unattended-Upgrade::Automatic-Reboot-Time "02:00";/Unattended-Upgrade::Automatic-Reboot-Time "02:00";/' /etc/apt/apt.conf.d/50unattended-upgrades && \
sudo sed -i 's/\/\/ Unattended-Upgrade::OnlyOnACPower "true";/Unattended-Upgrade::OnlyOnACPower "true";/' /etc/apt/apt.conf.d/50unattended-upgrades
```

The above configures automatic upgrades for the system, which will install every day at 2AM and the machine will reboot on it's own if it needs to.

## Step 4: Tinker

We're now in a place where you're basic homelab is set up and ready to rock. If you're happy to just play with it then you're all set. If you'd like to run through a couple of simple tasks to get you started, the next article will go through setting up a `pihole` DNS and DHCP server for network-wide ad-blocking, and confguring `ansible` and AWX for automating the deployment of VM's. I'll also look to put together a `docker-compose` guide later to cover simple container orchestration and management.
