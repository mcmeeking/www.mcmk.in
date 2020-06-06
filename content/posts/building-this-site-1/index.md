---
title: How to Build This Website
date: '2019-08-31T11:46:23.000+00:00'
lastmod: 
toc: true
hiddenFromSearch: false
images: 
tags:
- ubuntu
- letsencrypt
- nginx
- hugo
- git
description: A step-by-step guide to building a simple static content website (like
  this one), using Hugo, NGINX, and Let's Encrypt for TLS.
categories:
- Projects
ProjectLevel: Intermediate
ProjectTime: 3 hour
subtitle: ''
author: ''
authorLink: ''
hiddenFromHomePage: false
featuredImage: ''
math: false
lightgallery: false
license: ''
draft: true

---
> If you wish to make an apple pie from scratch, you must first create the universe.
> <cite>Carl Sagan</cite>

First thing's first, and the first thing I want to go over is how this site is put together. Not so much as a definitive guide to building a self-hosted website, but more of a reminder for my future self which may be useful to others. As such this post assumes an awareness of **nginx**, markdown, and **git** along with basic knowledge of HTML, TLS, DNS, and Docker.

In this guide, I'll be using a fresh install of Ubuntu 20.04 running on the homelab host from my \[first post\](/posts/building-a-home-lab-1/).

## Step 0: Prepare the Environment

For the setup of a self-hosted, public-facing, website we first need to make sure that people on the internet will be able to reach what we want them to reach, but _only_ what we want them to reach. Hugo and Nginx will take care of the permissions for us, but it's a good idea to turn your system's firewall on and disable SSH/Remote Login (if it's enabled) through your system preferences before you forward any ports to your router.

All of the tools we're going to use are open-source and publicly available to download and use, but the only tool which comes pre-packaged in macOS is `git`.

There are a number of ways to install the other two, but my preferred route is to use Homebrew ([`brew`](https://brew.sh/)), so we'll begin by installing that.

Before we can install Homebrew, we need to install Apple's XCode developer tools. If you think you already have these on your system you can skip this step (Homebrew will attempt a download anyway if it can't find them).

**Note:** You should _NEVER_ blindly paste commands into your terminal and execute them without an understanding of what they are doing and verifying that they come from a trustworthy source. The rest of this guide will assume you've vetted the commands appropriately and are happy with the risks.

## Step 1: Install XCode Tools and Homebrew

Open the Terminal app, and enter:

```bash
xcode-select --install
```

You'll be prompted to install the tools for your system, which can take some time depending on your internet connection. Once that's complete you can install Homebrew with:

```bash
ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
```

You'll be prompted for your account/admin password, but the script will fail if you run it as `root` or with the `sudo` prefix.

## Step 2: Install `nginx` and `hugo`

Now that we have our package manager, we can begin installing the open-source engines that will power our website. You'll notice `certbot` is also being installed, but more on this later.

```bash
brew install nginx hugo certbot
```

One nice feature of Homebrew that it is quite verbose during installation, and will tell you what it's installing as it runs through dependencies so you can get an idea of what's happening.

## Step 3: Create Your Web Root

Your web root is the directory that your websites content will live in. It's cleaner if it's not too nested for example `~/Documents/personal/files/website/master/hugo/` is more of a pain to type than `~/hugo/`, but this really depends on your personal preference.

In this example we're just going with `~/hugo/` so we'll create that now.

```bash
mkdir ~/hugo
```

You'll now find a folder named "hugo" has been created in your Home directory.

Now we'll populate that with by telling `hugo` to build us a site in that directory.

```bash
cd ~/hugo
hugo new site website
```

You'll see that this has now created a folder called "website" in the `~/hugo/` directory. This is your web root directory.

## Step 4: Create the Site

Now we'll initialise the git repo for the site and add a theme so things look nice and pretty (we'll use the "Ananke" theme suggested in the [Hugo quickstart guide](https://gohugo.io/getting-started/quick-start/) as an example - there are [many more to choose from](https://themes.gohugo.io/)).

```bash
cd ~/hugo/website

## Initialise the git repo
git init

## Remove the public folder from the git repo
echo "/public" >> .gitignore

## Add the theme to ~/hugo/website/themes/ananke
git submodule add https://github.com/budparr/gohugo-theme-ananke.git themes/ananke

## Tell Hugo to use the new theme
echo 'theme = "ananke"' >> config.toml
```

Now that that's done, we can create our first post:

```bash
cd ~/hugo/website

## Creates "My First Post" in ~/hugo/website/content/posts/my-first-post.md
hugo new posts/my-first-post.md
```

And now we'll test to make sure everything's working.

```bash
cd ~/hugo/website

## Run a lightweight webserver in "draft" mode
hugo server -D
```

Now you can open a web browser and head to [http://localhost:1313/](http://localhost:1313/) and you should be greeted by something like this...

![New Website Screenshot](new-site.png)

Congratulations! You've just created a new blog.

The first post can be edited or deleted by modifying the `~/hugo/website/posts/my-first-post.md` file and new files can be added into the `~/hugo/website/posts/` directory to create new posts. The default format is markdown, but you can use HTML if you prefer.

For now, we're going to move onto publishing the site to the great wide world and you can revisit the intricacies of posting later on.

## Step 5: Configure Nginx

Now we're going to get started on the Nginx configuration. Nginx, for those unfamiliar with it, is a HTTP(S) web server and reverse proxy - similar to Apache (which is the web server built into the macOS Server app).

First up, we'll modify the default config so that it's pointing to our webroot. We don't want _everything_ to be accessible from the internet, so we'll just point it to the "public" directory inside.

The default config file is `/usr/local/etc/nginx/nginx.conf`, open it in your favourite text editor and replace this:

```conf
    #gzip  on;
```

with...

```conf
    gzip on;
```

this...

```conf
server {
    listen       8080;
    server_name  localhost;
```

with...

```conf
server {
    root /absolute/path/to/your/hugo/website/public ## Replace this with your actual path
    listen       80 default_server;
    server_name  _;
```

and this...

```conf
location / {
    root   html;
    index  index.html index.htm;
}

#error_page  404              /404.html;
```

with...

```conf
location / {
    try_files $uri $uri/ =404;
}

error_page  404              /404.html;
```

## Step 6: Activate

We want to be sure that `nginx` starts running on boot, not just when we're logged into the computer.

To accomplish this, we'll use `brew`'s built-in services function. The `sudo` prefix allows us to bind to port 80:

```bash
sudo brew services nginx start
```

You can check it's working by visiting [http://localhost](http://localhost), which should present you with the same page you were presented with earlier.

## Step 7: Port Forwarding

Finally, we need to make our site visible to the great wide-world. For now, we'll just forward port 80 on our machine to the firewall on our router.

The admin panel for your router will probably be either [http://192.168.0.1](http://192.168.0.1), or [http://192.168.1.1](http://192.168.1.1). The default login details will probably be on a label directly on the hub.

Once that's done, you can check it's working with the following command:

```bash
echo $(curl -s -o /dev/null -w "%{http_code}" http://$(curl -s ipinfo.io/ip))
```

Which should output:

```bash
200
```

The HTTP 200 code means we got a valid response back from the server. You can visit the site by heading to your public IP address in a browser, but it's not a very pretty or secure way of hosting a site. We'll look at setting up a domain name, securing things with SSL, and managing it all with git in the next post.