---
title: How to deploy Ansible AWX (Tower) with HTTPS
date: 2020-07-27
toc: true
description: A guide on installing Ansible and Ansible AWX (open-source clone of Ansible Tower) with HTTPS in about 10 minutes
tags:
- centos
- podman
- ansible
- homelab
- nginx

categories:
- Projects

ProjectLevel: Beginner
ProjectTime: 10 minute
subtitle: ''
author: 'James McMeeking'
authorLink: 'james@mcmk.in'
hiddenFromHomePage: false
hiddenFromSearch: false
featuredImage: 'images/deploy-ansible-awx-with-https/featured.jpg'
featuredImagePreview: 'images/deploy-ansible-awx-with-https/featured-preview.jpg'
draft: false
---

Short and sweet one this month as I've had quite a lot on my plate (buying a new house and made redundant at work due to COVID), so in between looking for jobs I've only been able to spin up a quick AWX instance but haven't had time to dig into the config much as yet. This article is essentially just a quick and simple script to install and spin up an Ansible AWX instance on a CentOS 8 Stream box, and generate a self-signed certificate and strong credentials for secure config management.

I'll put together a guide for client discovery and some proper automation workflows over the next few months, but for now this is it.

<!--more-->

## Step 0: Prepare the Environment

For this setup, I'll be using a CentOS 8 Stream box, as it's reasonably stable, fairly up to date, and integrates nicely with **ansible**, and the web admin panel **cockpit** is what we'll be doing the monitoring of the containers through. Ubuntu will probably work fine, but the commands for installations and some of the file locations will be different, so keep that in mind if you're using a different distro.

For starters, we'll become `root`:

```bash
sudo -i
```

Now we can install all of the dependencies we'll need for the management of the pod:

```bash
dnf install epel-release -y
dnf update -y
dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo
dnf install -y \
    ansible \
    git \
    cockpit \
    docker-ce --nobest \
    python2 \
    python3-pip
curl -L "https://github.com/docker/compose/releases/download/1.26.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
curl -LO http://mirror.centos.org/centos/7/extras/x86_64/Packages/cockpit-docker-195.6-1.el7.centos.x86_64.rpm
rpm -i cockpit-docker-195.6-1.el7.centos.x86_64.rpm --noverify
rm -f cockpit-docker-195.6-1.el7.centos.x86_64.rpm
pip3 install --user docker-compose
systemctl enable --now cockpit.socket docker
firewall-cmd --zone=public --add-masquerade --permanent
firewall-cmd --add-service="cockpit" --permanent
firewall-cmd --add-service="http" --permanent
firewall-cmd --add-service="https" --permanent
firewall-cmd --reload
exec $SHELL
```

## Step 1: Install AWX

We should now be able to connect to our box by heading to `https://lan.ip.of.the.box:9090` and there should be a "Containers" option once we've logged in which is where the docker containers will show up. Open the terminal to the box and we'll clone the AWX repo for the latest stable release (at time of writing that is `12.0.0`) then we'll modify the default settings and run the `install.yml` andsible playbook to setup the host:

```bash
git clone -b 12.0.0 https://github.com/ansible/awx.git
cd awx/installer
mkdir -p ~/.awx/ssl/private
chmod go-rx ~/.awx/ssl/private
openssl req -x509 -newkey rsa:4096 -keyout ~/.awx/ssl/private/privkey.pem -out ~/.awx/ssl/cert.pem -days 3650 -nodes -subj "/CN=\"$( hostname -f )\""
sed -i "s@#ssl_certificate=@ssl_certificate=$HOME/.awx/ssl/cert.pem@g" inventory
sed -i "s@#ssl_certificate_key=@ssl_certificate_key=$HOME/.awx\/ssl/private/privkey.pem@g" inventory
PGREPASS="$( openssl rand -base64 256 )"
ADMNPASS="$( openssl rand -base64 256 )"
SECRTKEY="$( openssl rand -base64 256 )"
sed -i "s@pg_password=awxpass@pg_password=${PGREPASS:0:32}@g" inventory
sed -i "s@admin_password=password@admin_password=${ADMNPASS:0:16}@g" inventory
sed -i "s@secret_key=awxsecret@secret_key=${SECRTKEY:0:64}@g" inventory
ansible-playbook -i inventory install.yml
printf '#######################################################################
Configuration Complete
#######################################################################

Your postgres password is:  %s
Your secret key is:         %s

You can now access AWX at   https://%s
Using the username:         admin
...  with password:         %s
' "${PGREPASS:0:32}" "${SECRTKEY:0:64}" "$( hostname -f )" "${ADMNPASS:0:16}"
```

That's it! Easy peasy. AWX will take a little while to configure itself depending on your system spec, but you can just navigate the to page and leave it open and it will present a login screen when the setup is finished. If you've got a reverse proxy on your network I'd suggest pointing your DNS A records at the proxy and creating a server conf file to the config to enforce HTTPS rather than using the insecure HTTP that it defaults to.

Like I said in the intro, there's more to come eventually but for now this should be enough to get started and have a play.
