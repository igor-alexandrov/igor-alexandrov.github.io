---
title: Rails Thruster 101
layout: post
tags:
  - Ruby
  - Rails
  - DevOps
  - kamal
featured: false
hidden: false
---

While we are waiting for the Rails World 2024 conference to start and Kamal 2 to be released, I decided to make some preparations for the upcoming changes in the Rails ecosystem.

In March 2024 Basecamp team released [Thruster](https://github.com/basecamp/thruster/) a small, Go-based proxy server for Rails. While the original idea of Thruster was to provide an ability to build production-ready Rails applications from a single container for the ONCE project, it will fit perfectly to the Kamal ecosystem.

<!--more-->

## Isn't it a redundancy?

Wait? Another proxy server? Why do we need it? Allow me to explain.

It doesn't matter whether we use Traefik with Kamal v1 or kamal-proxy with Kamal v2, inside the container we still run Puma (or any other Ruby application server) that serves requests to the application. Besides this, Puma is also responsible to serving application assets – images, stylesheets, JavaScript files, etc. – to the clients. Before Kamal came into the scene, we usually had Nginx in our infrastructure schema. Nginx is a classic web server that can serve static files efficiently. Unfortunately, it is not adapted to the container-based setups as you need to manage its configuration via a config file. However, without Nginx, Puma is not the best choice to serve static files.

This is where Thruster comes into play. It wraps the Puma instance and efficiently serves static files with X-Sendfile acceleration, while Puma is responsible for the dynamic content.

Thruster also provides GZip compression which was available in Traefik [via middleware](https://doc.traefik.io/traefik/middlewares/http/compress/), but won't exist in kamal-proxy. GZip compression plays a crucial role in optimizing web performance by significantly reducing the size of files transmitted between a server and a client. By compressing assets like HTML, CSS, and JavaScript, GZIP decreases bandwidth usage and accelerates the loading times of web pages, providing users with a faster, more seamless browsing experience. This not only enhances user satisfaction but also improves search engine rankings, as faster websites tend to rank higher in search results. Additionally, reducing the size of data transfers lightens the load on servers, allowing them to handle more requests efficiently and lowering hosting costs.

A reasonable question would be “Why I cannot do a GZIP compression in Rails?”.
Technically, you can with [Rack::Deflater](https://github.com/rack/rack/blob/main/lib/rack/deflater.rb). But since Thruster is already responsible for serving public assets, it can also efficiently handle compression.

Besides a compression, Thruster also provides a basic HTTP caching of public assets and HTTP/2 support.

**With Thruster your Rails application can be treated as a black box, which can serve any kind of requests efficiently.**

## How to use?

Thruster is straightforward to use if you're already using Puma.

First, you need to add Thruster to your Gemfile:

<pre class="language-ruby"><code>
# Gemfile

gem 'thruster'

</code></pre>

Run `bundle install` and you are ready to go. Since Thruster is written in Go, platform specific binary will be downloaded and installed with the gem.

I always create binstubs to have all the necessary commands in one place:

<pre class="language-bash"><code>
$ bundle binstubs thruster
</code></pre>

By default, Thruster will listen on port 80, while Puma will stay on port 3000. Knowing this we should update our application `Dockerfile` accordingly. I assume here that your application is already dockerized. I replaced the port that is getting exposed from 3000 to 80 and added `./bin/thrust` to the default command.

<pre class="language-dockerfile"><code>
# Dockerfile

# Entrypoint prepares the database.
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

# Start server via Thruster by default, this can be overwritten at runtime
EXPOSE 80
CMD ["./bin/thrust", "./bin/rails", "server"]
</code></pre>

The last change is to update `./bin/docker-entrypoint` script. I always try to keep it as close to the [original Rails template](https://github.com/rails/rails/blob/main/railties/lib/rails/generators/rails/app/templates/docker-entrypoint.tt) as possible. Below is the final version of the script.

<pre class="language-bash"><code>
#!/bin/bash -e

# If running the rails server then create or migrate existing database
if [ "${@: -2:1}" == "./bin/rails" ] && [ "${@: -1:1}" == "server" ]; then
  ./bin/rails db:prepare
fi

exec "${@}"
</code></pre>

That is all! Thanks to the Traefik container-based configuration, it will read the exposed port from the container and route the traffic accordingly after you will deploy the changes.

After deploy will be finished, you can log in to the container and check if Thruster is running:

<pre class="language-bash"><code>
rails@docker:~$ ps aux
USER         PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
rails          1  0.0  0.3 1232848 13124 ?       Ssl  09:26   0:06 /usr/local/bundle/ruby/3.3.0/gems/thruster-0.1.8-x86_64-linux/exe/x86_64-linux/thrust ./bin/rails server
</code></pre>

## Summary

Since there are no visible cons of using Thruster in your Rails application, I highly recommend using it. It can improve the performance of your application and reduce the load on the server. It is also a good idea to use it as a preparation for the upcoming Kamal 2 release.
