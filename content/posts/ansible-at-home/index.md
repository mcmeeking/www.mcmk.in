---
title: How to setup Ansible AWX (Tower) at home
date: 2020-06-15
toc: true
description: A guide on setting up and configuring Ansible and Ansible AWX (open-source branch of Ansible Tower) at home to manage configuration for your home lab, including off-site git repo for disaster recovery and automated host discovery.
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
featuredImage: '/images/ansible-at-home/featured.jpg'
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
sudo systemctl enable --now cockpit.socket nginx docker && \
sudo firewall-cmd --add-service="cockpit" --permanent && \
sudo firewall-cmd --reload && \
git clone -b 12.0.0 https://github.com/ansible/awx.git && \
cd awx/installer && \
exec $SHELL
```

We should now be able to connect to our box by heading to `https://lan.ip.of.the.box:9090` and there should be a "Podman Containers" option once we've logged in:

![Cockpit-podman-containers](/images/ansible-at-home/Cockpit-podman-containers.png)

Now we can install **podman-compose** which is a utility that simplifies the container config in (almost) the same way as **docker-compose**:

```bash
pip3 install podman-compose
podman-compose -h
```

Now we'll clone the AWX repo to a local folder, and setup a hacky stand-in for **docker** and **docker-compose**:

That's it for the prep.

## Step 1: Configure **podman-compose**

{{< admonition note >}}
It's worth pointing out here that some of these values may need to be different on your setup than on mine. If you're running other services which use port 
{{< /admonition >}}
