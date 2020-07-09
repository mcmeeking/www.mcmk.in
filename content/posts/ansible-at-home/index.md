---
title: How to setup Ansible AWX (Tower) at home
date: 2020-06-15
toc: true
description: A guide on installing and configuring Ansible and Ansible AWX (open-source clone of Ansible Tower) at home to manage configuration for your home lab, including off-site git repo for disaster recovery.
tags:
- centos
- podman
- ansible
- homelab
- git
- nginx

categories:
- Projects
ProjectLevel: Intermediate
ProjectTime: 2 hour
subtitle: ''
author: 'James McMeeking'
authorLink: 'james@mcmk.in'
hiddenFromHomePage: false
hiddenFromSearch: true
draft: true
---

<!--more-->

This is going to be the first live project I've written about so far (live as-in not something I've done already), so hopefully it will be reasonably straighforward to read and follow but I'll be working out a lot of this stuff as we go too so bear in mind this is probably not going to be a "best-practice" deployment. The plan is for this to "just work and do what we need it to do" so with that out of the way let's get started...

## Step 0: Prepare the Environment

For this setup, I'll be using a CentOS 8 Stream box, as it's reasonably stable, fairly up to date, and integrates nicely with **ansible**, and the web admin panel **cockpit** is what we'll be doing the monitoring of the containers through. Ubuntu will probably work fine, but the commands for installations and some of the file locations will be different, so keep that in mind if you're using a different distro.

For starters, we'll install all of the dependencies we'll need for the management of the pod:

```bash
sudo dnf update -y && \
sudo dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo && \
sudo dnf install -y \
    ansible \
    git \
    cockpit \
    docker-ce --nobest \
    python2 \
    python3-pip && \
sudo curl -L "https://github.com/docker/compose/releases/download/1.26.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose && \
sudo chmod +x /usr/local/bin/docker-compose && \
curl -LO http://mirror.centos.org/centos/7/extras/x86_64/Packages/cockpit-docker-195.6-1.el7.centos.x86_64.rpm && \
sudo rpm -i cockpit-docker-195.6-1.el7.centos.x86_64.rpm --noverify && \
rm cockpit-docker-195.6-1.el7.centos.x86_64.rpm && \
sudo pip3 install --user docker-compose && \
sudo systemctl enable --now cockpit.socket docker && \
sudo firewall-cmd --zone=public --add-masquerade --permanent
sudo firewall-cmd --add-service="cockpit" --permanent && \
sudo firewall-cmd --reload && \
exec $SHELL
```

## Step 1: Install AWX

We should now be able to connect to our box by heading to `https://lan.ip.of.the.box:9090` and there should be a "Containers" option once we've logged in which is where the docker containers will show up. Open the terminal to the box and we'll clone the AWX repo for the latest stable release (at time of writing that is `12.0.0`) then we'll modify the default settings and run the `install.yml` andsible playbook to setup the host:

```bash
git clone -b 12.0.0 https://github.com/ansible/awx.git && \
cd awx/installer && \
mkdir -p ~/.awx/ssl/private && \
chmod go-rx ~/.awx/ssl/private && \
openssl req -x509 -newkey rsa:4096 -keyout ~/.awx/ssl/private/privkey.pem -out ~/.awx/ssl/cert.pem -days 3650 -nodes -subj "/CN=\"$( hostname -f )\"" && \
sed -i "s@#ssl_certificate=@ssl_certificate=$HOME/.awx/ssl/cert.pem@g" inventory && \
sed -i "s@#ssl_certificate_key=@ssl_certificate_key=$HOME/.awx\/ssl/private/privkey.pem@g" inventory && \
PGREPASS="$( openssl rand -base64 256 )" && \
ADMNPASS="$( openssl rand -base64 256 )" && \
SECRTKEY="$( openssl rand -base64 256 )" && \
sed -i "s@pg_password=awxpass@pg_password=${PGREPASS:0:32}@g" inventory && \
sed -i "s@admin_password=password@admin_password=${ADMNPASS:0:16}@g" inventory && \
sed -i "s@secret_key=awxsecret@secret_key=${SECRTKEY:0:64}@g" inventory && \
sudo ansible-playbook -i inventory install.yml && \
printf '#######################################################################
Configuration Complete
#######################################################################

Your postgres password is:  %s
Your secret key is:         %s

You can now access AWX at   https://%s
Using the username:         admin
Ans the password:           %s
' "${PGREPASS:0:32}" "${SECRTKEY:0:64}" "$( hostname -f )" "${ADMNPASS:0:16}"
```

That's it! Easy peasy. If you've got a reverse proxy on your network I'd suggest pointing your DNS A records at the proxy and creating a server conf file to the config to enforce HTTPS rather than using the insecure HTTP that it defaults to. You can use this conf for **nginx** if so:

## Step 2: Configure AWX

Now we're ready to setup our AWX instance. The default username and password are `admin` and `password`, so we'll start by changing those. Head to the admin user 

![AWX-]