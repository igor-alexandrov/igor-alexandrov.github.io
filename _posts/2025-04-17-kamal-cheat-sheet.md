---
title: Kamal cheat sheet
description:
layout: post
tags:
  - Docker
  - Rails
  - DevOps
  - Kamal
featured: false
hidden: false
---

I use Kamal on a daily basis to deploy all the apps I maintain. Below is a list of commands I use frequently. This is not an exhaustive list, but it covers the most common tasks I usually perform.

<!--more-->

<pre class="language-bash"><code>
# Init command is used to create the config and secrets files once after Kamal is added to the app.
$ kamal init

# Install Docker on all target hosts
$ kamal server

# Aliases
# Kamal defines `kamal shell` out of the box, I usually add `kamal console` to quickly access the Rails console.
$ kamal shell [-d production]
# app exec -i --reuse "bin/rails console"
$ kamal console [-d production]

# Deploy app [to the staging environment]
$ kamal deploy [-d staging]

# Rollback app [to the VERSION] [in the staging environment]
$ kamal rollback [VERSION] [-d staging]

# Building images
# Most of the time you won't use the `kamal build` command directly,
# since it primarily used by `kamal deploy` and `kamal redeploy`.
# However, you can also use it to build the app image without pushing it, which is useful for testing.
$ kamal build dev

# Below are several commands to read the logs of the app and its accessories.
$ kamal app logs [--roles=web -n 100 -f]
$ kamal app logs [--primary -n 100 -f]
$ kamal app logs [--hosts=&lt;ip_address&gt; -n 100 -f]
$ kamal audit
# Show logs for the PgHero accessory [for the staging environment]
$ kamal accessory logs pghero [-d staging]
# Show logs for the proxy server [for the staging environment]
$ kamal proxy logs [-d staging]

# Show combined config (including secrets) [for the staging environment]. Can be useful to debug and in case you forgot your server ip-address.
$ kamal config [-d staging]

# Print secrets to stdout [for the staging environment]
$ kamal secrets print [-d staging]

# Show details about all containers grouped by role [for the staging environment]
$ kamal details [-d staging]

# Show details only about the app containers [for the staging environment], [for the web role]
$ kamal app details [-d staging] [--roles=web]

# Show details only about the PgHero accessory containers [for the staging environment]
./bin/kamal accessory details pghero -d staging
</code></pre>

To see all available commands, run `kamal help`. If you prefer to save this cheat sheet as an image, [use this link](/assets/images/posts/2025-04-17/kamal-cheat-sheet.png).
