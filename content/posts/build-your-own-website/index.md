---
title: How to (easily) Build Your Own Website (for free)
date: 2020-06-06
toc: true
description: A step-by-step guide to building a simple, secure, static-content website (like this one), using Amazon AWS, Hugo, NGINX, GitHub, Forestry, Cloudflare, and Let's Encrypt.
tags:
- ubuntu
- certbot
- nginx
- hugo
- git
- forestry
- docker

categories:
- Projects
ProjectLevel: Intermediate
ProjectTime: 2 hour
subtitle: ''
author: 'James McMeeking'
authorLink: 'james@mcmk.in'
hiddenFromHomePage: false
hiddenFromSearch: false
draft: false
---

{{< admonition quote "Carl Sagan" >}}
If you wish to make an apple pie from scratch, you must first create the universe.
{{< /admonition >}}

First thing's first, and the first thing we'll need here is a computer. For this build, you can use pretty much any hardware you have available as the initial resource is pretty light, but I'd recommend an AWS EC2 instance over a computer you have at home unless you have a server you can leave online 24/7, as uptime is what's important for websites and AWS tends to have a pretty good record in that department. You can also get a free EC2 t2.micro instance for starters, which is easily enough for what we'll be doing here initially, and you can expand the capacity later on as needed.

We'll also need a domain name. If you don't have one, you can technically get one for free, but I'd *highly reccommend* paying for one you like rather than using some random number generated option - they're pretty cheap.

In addition to the above, you should also have:

- Github account
- Cloudflare account
- About 2 hours free time

## Step 0: Prepare the Environment

If you don't have an AWS account, you can sign up [here](https://portal.aws.amazon.com/billing/signup#/start). Once that's done head over to your EC2 console [here](https://console.aws.amazon.com/ec2) and click "Launch Instance" then select "Ubuntu Server 18.04 LTS (HVM), SSD Volume Type":

![Ubuntu-18.04-aws-hvm](/images/build-your-own-website/Ubuntu-18.04-aws-hvm.png)

Next, with the t2.micro selected click "Review and Launch", and then "Edit Security Groups". Here we'll change the SSH rule to allow only "My IP" which will populate your current public IP address.

{{< admonition warning >}}
If you're not using a business ISP, your current public IP is likely to be dynamic, so if SSH to your webserver suddenly begins refusing your connections, bear in mind that your IP might have changed so may need updating in this security group before you can connect.

This setting will also prevent you from connecting via SSH from anywhere other than your current public IP, so it might be worth setting up a VPN if you want to ssh onto the box from other networks.
{{< /admonition >}}

We'll also add a rule for HTTP, and HTTPS traffic so our webserver can be publicly reached. Just leave the IP ranges for HTTP and HTTPS as 0.0.0.0/0 and ::/0, then click "Review and Launch":

![AWS-security-groups](/images/build-your-own-website/AWS-security-groups.png)

Now click "Launch", and you'll be asked to create a key pair if you've not already created one. You can call it whatever you want, and then download the certificate it generates. This is essentially the keys to your website kingdom, so keep it safe. I'd suggest moving it to your `~/.ssh/` directory and **chmod**'ing so it's only readable by you with something like:

```bash
mv ~/Downloads/your-key.pem ~/.ssh/
chmod go-rwx ~/.ssh/your-key.pem
```

Now we can head back to the AWS console, select "View Instances" and grab our instance' public IP. We can then use this to remote onto our instance with the following:

```bash
ssh -i ~/.ssh/your-key.pem ubuntu@the.instance.public.ip
```

As with all things, it's worth running some basic housekeeping before starting anything (if you're asked about replacing the local versions of GRUB's config I'd suggest keeping the local copy):

```bash
sudo apt update             # Update local repo db
sudo apt full-upgrade -y    # Update installed packages and remove debris
sudo ufw allow ssh          # Allow SSH via local firewall
sudo udw allow http         # Allow HTTP
sudo ufw allow https        # Allow HTTPS
sudo ufw enable             # Activate local firewall
```

## Step 1: Install **hugo**, **docker** and **nginx**

Now we're ready to pull down the apps we'll be making use of. Ubuntu 18.04 repos are a little behind the latest version of **hugo** at time of writing, so we'll be downloading the installer from their github releases page. I've written a little script you can grab from [here](pull-latest-hugo.sh) which *should* pull the latest version of the extended **hugo** Debian installer, but it's worth double checking the version you get is correct as the syntax may change in future releases.

You can grab it, make it executable, and install it with the following (although it you're just manually grabbing the .deb from the Github releases page you can just run the **dpkg** part):

```bash
cd $HOME
curl -LO https://www.mcmk.in/scripts/pull-latest-hugo.sh
chmod +x ./pull-latest-hugo.sh
./pull-latest-hugo.sh
sudo dpkg -i hugo_extended*.deb
rm hugo_extended*.deb
```

You can then run this script to download the latest **hugo** installer locally *(in theory)*, which can then be installed using `sudo dpkg -i hugo_extended*.deb`. It's not quite as easy as `sudo apt upgrade` but it's not too far off.

Our webserver engine, **nginx**, and **docker** on the other hand will do perfectly fine from the Ubuntu 18.04 repo, so we can grab them like so:

```bash
sudo apt install -y nginx docker.io
sudo systemctl status {docker.socket,nginx}
```

With confirmation that both services are online, we can move onto the configuration.

## Step 2: Configure the Local Directories

### Web Root

Your web root is the directory that your websites' content will live in. It's cleaner if it's not too nested for example `~/Documents/personal/files/website/master/hugo/` is more of a pain to type than `~/hugo/`, but this really depends on your personal preference.

In this example we're just going with `~/hugo/` so we'll create that now.

```bash
hugo new site hugo
```

You'll see that this has now created a folder `~/hugo/` with a basic directory structure and some config files, and your web root will live inside this directory under "public" (although this won't yet exist).

We can now tell **nginx** that that's where we want to serve files from, by editing the `/etc/nginx/sites-available/default` file. As we'll be using HTTPS, we'll also set the server to redirect any HTTP requests to the HTTPS version of our site. We'll be using the **nginx** wildcard character `_` to catch everything, and then redirect that to our final domain, and finally we'll use a nice 404 page from whatever theme we install rather than the standard one:

```bash
printf '# Catch all HTTP requests and redirect to HTTPS
server {
    listen 80;
    listen [::]:80 default_server;
    server_name  _;
    add_header Strict-Transport-Security "";
    return 301 https://$host$request_uri;
}

# Catch all subdomains and redirect to www.domain.tld
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2 default_server;
    return 301 https://placeholder$request_uri;
}

# HTTPS server (default server)
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name placeholder;

    root /home/ubuntu/hugo/public/;

    index index.html;

    error_page 404 /404.html;

    location / {
        # First attempt to serve request as file, then
        # as directory, then fall back to displaying a 404.
        try_files $uri $uri/ 404;
    }
}' | sudo tee /etc/nginx/sites-available/default
```

Now swap the "placeholder" for your domain. In this example, I'm using a subdomain of my own `www.demo.mcmk.in`, but you should swap that out for the domain you want people to land on when they visit your site (`www.yourdomain.com` for instance):

```bash
sudo sed -i 's/placeholder/www.demo.mcmk.in/g' /etc/nginx/sites-available/default
```

Now **nginx** will serve any requests made to our website from the `~/hugo/public/` directory.

### Repository

Now we'll initialise the git repo for the site and add a theme so things look pretty (we'll use the "Ananke" theme suggested in the [Hugo quickstart guide](https://gohugo.io/getting-started/quick-start/) as an example - there are [many more to choose from](https://themes.gohugo.io/)).

```bash
cd ~/hugo/

## Initialise the git repo
git init

## Remove the public folder from the git repo
printf "/public" >> .gitignore

## Add the theme to ~/hugo/website/themes/ananke
git submodule add https://github.com/budparr/gohugo-theme-ananke.git themes/ananke

## Tell Hugo to use the new theme
echo 'theme = "ananke"' >> config.toml
```

Now create the remote repository in GitHub and copy the URL, it's simplest to just name it after your domain name.

{{< admonition note >}}
You don't need to make the repo public if you'd rather keep it private. The rest of the process works just as well with the repo being set as a private one.

I personally find it preferable to keep the repo public as it's a reminder that you shouldn't be putting things in this directory you don't want people to access (no webserver engine is bulletproof, there's always a chance there could be an exploit that allows access to unintended directories).

I'd also note that GitHub could always be comprimised too, so there's no guarantee that private repos will provide perfect secrecy either.
{{< /admonition >}}

Once the GitHub repo is live, copy the remote url for SSH and head back to the terminal to our AWS box, and enter:

```bash
cd ~/hugo/
git remote add origin git@github.com:mcmeeking/www.demo.mcmk.in.git # Replace the URL with the one you copied
git add .
git commit -m "Initial Commit"
ssh-keygen -t rsa -b 4096 -f $HOME/.ssh/id_rsa -N '' # Generate an SSH key for us to use to push to the repo
```

Before we can push the files remotely, we'll need to copy the SSH key we just created up to our GitHub account. Copy the output of `cat ~/.ssh/id_rsa.pub` to https://github.com/settings/keys/new.

Once added, you can now push the repo using:

```bash
cd ~/hugo/
git push -u origin master
```

You should now see your files in the GitHub repo you created (empty folders are ignored, so don't worry if it doesn't match up exactly), if there's files there it means it worked which means we're ready to move onto the next step.

## Step 3: Configure TLS

Now we're going to get started on the **nginx** TLS configuration. First up, we'll replace the default `/etc/nginx/nginx.conf` file with a hardened template from Mozilla with a few minor modifications to help with caching and performance:

The default config file is `/usr/local/etc/nginx/nginx.conf`, open it in your favourite text editor and replace this:

```bash
printf "user www-data;
worker_processes auto;
pid /run/nginx.pid;
include /etc/nginx/modules-enabled/*.conf;

events {
    worker_connections 768;
}

http {
    ##
    # Basic Settings
    ##

    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    server_tokens off;
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    ##
    # SSL Settings
    ##

    ssl_certificate /etc/letsencrypt/live/placeholder/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/placeholder/privkey.pem;
    ssl_session_timeout 1d;
    ssl_session_cache shared:MozSSL:10m;  # about 40000 sessions
    ssl_session_tickets off;

    add_header Strict-Transport-Security 'max-age=63072000; includeSubDomains; preload';
    add_header X-Content-Type-Options nosniff;
    add_header Set-Cookie '\$sent_http_set_cookie; HttpOnly; Secure;';
    add_header Referrer-Policy 'no-referrer-when-downgrade';
    add_header X-Frame-Options SAMEORIGIN always;
    add_header X-XSS-Protection \"1; mode=block\" always;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers on;

    ssl_stapling on;
    ssl_stapling_verify on;

    resolver 1.1.1.1 valid=300s;
    resolver_timeout 15s;

    ##
    # Logging Settings
    ##

    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;

    ##
    # Gzip Settings
    ##

    gzip on;
    gzip_proxied any;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;

    ##
    # Virtual Host Configs
    ##

    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
}" | sudo tee /etc/nginx/nginx.conf
```

Now again, just swap "placeholder" for your domain:

```bash
sudo sed -i 's/placeholder/www.demo.mcmk.in/g' /etc/nginx/nginx.conf
```

Now that **nginx** is set to look for TLS certificates in `/etc/letsencrypt`, we should probably make sure there are some. First though, we need to configure cloudflare to return our webserver when someone searches for our domain name.

### Cloudflare

You first need to add your domain to Cloudflare, they have several guides on how to do this for various different registrars. This step can be instant, or can take several hours (or even days, depending on your registrar), so I won't go into details here but once this is done you can begin to create your pointer records for your site.

For simplicities' sake, we'll just use some basic A records which should look like this (you can find your AWS public IP quickly by running `curl ipinfo.io/ip` from the AWS box):

```conf
Type    Name    Content                 TTL     Proxy status
A       *       your.aws.public.ip      Auto    DNS Only
A       www     your.aws.public.ip      Auto    DNS Only
A       @       your.aws.public.ip      Auto    DNS Only
```

This will catch any request to "yourdomain.tld", "anything.yourdomain.tld", and "www.yourdomain.tld" and point them all to your AWS webserver. The default TTL is 300 seconds - or 5 minutes - so that's generally how long changes take to propagate to the internet at large (although it's usually faster), and the "DNS Only" status means we don't want to use Cloudflare's Content Delivery Network as it messes with the security headers we're adding to **nginx**.

We'll also need an API key for your Cloudflare account to use **certbot** with the **cloudflare-dns** extension which we'll discuss later. For now, head to your profile page on Cloudflare and then navigate to the "API Tokens" page and create a token.

Select "Custom Token" and then use the following settings, making sure to *swap "1.2.3.4" for your AWS public IP*:

![Cloudflare-token-settings](/images/build-your-own-website/Cloudflare-token-settings.png)

Now move onto the summary and create the token, then copy it so we can store it on our AWS box. As with your private key for the AWS box SSH, this needs to be kept as secure as possible as it allows anyone with it to make changes to your DNS records.

We'll store it in a file on the AWS box in the `/etc/letsencrypt/` directory:

```bash
sudo mkdir /etc/letsencrypt/
printf '# Cloudflare API token used by Certbot
dns_cloudflare_api_token = YOUR-TOKEN-GOES-HERE' | sudo tee /etc/letsencrypt/cloudflare.ini
sudo chmod 600 /etc/letsencrypt/cloudflare.ini
```

Now we'll run our **docker certbot** image with the following to request a new cert for our domain (make sure to swap "yourdomain.tld" for your actual domain):

```bash
sudo docker run -it \
    --rm \
    --name certbot \
    --net host \
    -v /etc/letsencrypt/:/etc/letsencrypt/ \
    certbot/dns-cloudflare \
    certonly --dns-cloudflare --dns-cloudflare-credentials /etc/letsencrypt/cloudflare.ini --dns-cloudflare-propagation-seconds 120 --domain yourdomain.tld --domain *.yourdomain.tld --agree-tos --email you@yourdomain.tld --dns-cloudflare-propagation-seconds 60
```

{{< admonition info >}}
If this fails, double check the command you entered contains the right domain and email address, and then double check your Cloudflare A records are configured with the correct IP address, and that you can reach the default **nginx** page if you navigate to your domain in a browser before trying again.

If everything is correct, try modifying the "--dns-cloudflare-propagation-seconds 60" option to a higher number (say, 120) as it's likely to be a propagation issue.
{{< /admonition >}}

Once it's successfully run, we'll create a quick **cron** entry to ensure the cert is automatically renewed as needed without our intervention:

```bash
(sudo crontab -l 2>/dev/null; echo "00 00 * * *    /usr/bin/docker run -it --rm --name certbot --net host -v /etc/letsencrypt/:/etc/letsencrypt/ certbot/dns-cloudflare renew --dns-cloudflare --dns-cloudflare-credentials /etc/letsencrypt/cloudflare.ini --dns-cloudflare-propagation-seconds 60 >> /var/log/letsencrypt.log 2>&1") | sudo crontab -
```

This will run nightly at midnight, and output to a log file `/var/log/letsencrypt.log` so you can check the reasons for failure if you ever start getting emails from Let's Encrypt saying your cert is due to expire soon. Otherwise, so long as you post to your website every month or two (which refreshes **nginx**) you no longer need to worry about untrusted site errors scaring people away from your content, **certbot** is smart enough to know when a cert needs renewal and will only run when needed.

## Step 4: Content Management

So now we have our website, config, and TLS configured, and we're almost ready to rock. The only things we need now are an easy way to post content, and an automated solution for deploying it.

### Forestry

We'll start off with the CMS, and for this I recommend [Forestry](https://forestry.io/). I personally prefer working directly with a local git repo and raw markdown, but I've used Forestry previously and their service is both free and easy to use.

Essentially, it handles the **git** and raw markdown for you, so you can make changes through their interface, test it in a demo environment, and then "save" the changes which commit and push the changes to your GitHub repo.

Setup is simple and easy too, just create an account (you can just use your GitHub account), click "Add Site", "Hugo", and select "GitHub" as your provider. Forestry will authenticate with Oauth to your git account, and you can then select the repo of your website (if you made a private one, just click "Not showing private repos. Click here to grant access"), then import site. You'll be guided through some additional configuration of the interface, and you're ready to start creating.

### Automated Deployment

The final thing for us to take care of now is automating the deployment of the website to our AWS box, so any changes we make in Forestry (or to the git repo in general) are pulled, merged, and built on the AWS box without us having to manually remote onto it and perform those actions ourselves.

I've put together a short [bash script](build-site.sh) which takes care of this which you can drop on your AWS box and set to run regularly like so:

```bash
sudo curl -L https://www.mcmk.in/scripts/build-site.sh -o /usr/local/bin/build-site
sudo chmod +x /usr/local/bin/build-site
printf "00 00 * * *    /usr/bin/docker run -it --rm --name certbot --net host -v /etc/letsencrypt/:/etc/letsencrypt/ certbot/dns-cloudflare renew --dns-cloudflare --dns-cloudflare-credentials /etc/letsencrypt/cloudflare.ini --dns-cloudflare-propagation-seconds 60 >> /var/log/letsencrypt.log 2>&1\n*/5 * * * *    /usr/local/bin/build-site >> /var/log/build-site.log\n" | sudo crontab -
```

As before, this outputs the log to `/var/log/build-site.log` so if there are any errors you know where to look first (the rest is just so we don't replace the existing **cron** job).

## Step 5: Create!

With the **cron** entry above, any changes you made already in Forestry will be pulled down within 5 minutes, and the site will be refreshed. From here on out any changes you make either in Forestry, or directly to the GitHub repo, will be pulled and published within 5 minutes.

Congratulations on building your website, have fun!
