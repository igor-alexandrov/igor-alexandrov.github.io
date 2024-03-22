---
title: Traefik Tuning for Rails Applications (part 1)
layout: post
tags:
  - Rails
  - Traefik
  - Kamal
featured: true
hidden: true
---

For many years Nginx has been a default solution to serve as a reverse proxy for Rails applications. However, with the release of Kamal, the Rails community opened Traefik as a new reverse proxy solution. Within my 15 years of experience with Rails, I created an almost perfect configuration for Nginx that migrated through all my projects. With Traefik, I had to start from scratch.

<!--more-->

## Traefik Intro

Traefik is an Edge Router, it means that it's the door to your platform, and that it intercepts and routes every incoming request, but do not process requests itself.

When an incoming request comes to Traefik, it is getting served through the EntryPoint. Traefik can listen to multiple EntryPoints, and each EntryPoint is associated with a port and a protocol (HTTP/HTTPS, TCP, UDP). After the request is received, it is passed to the Router. Router is a rule that tells Traefik how to handle the request. It can be based on the path, the host, the headers, etc. The router will then forward the request to the appropriate service. But before a request is forwarded, it can be modified by the Middleware. Middleware is a piece of code that can modify the request or the response before it reaches the service. Middleware is the place where you can add authentication, rewrite the path, add headers, etc.

To better understand how Traefik works, I provide an image from the official [Traefik documentation](https://doc.traefik.io/traefik/routing/overview/).

{% include image-caption.html imageurl="/assets/images/posts/2024-02-15/traefik-overview.png" title="Traefik Overview" caption="Traefik Overview" %}

Compared to Nginx, Traefik configuration is entirely different. Besides a traditional configuration file (which can be both in YAML and TOML formats), Traefik can be configured with dynamic configuration. It means that you can configure Traefik with a file, but also with a REST API, a Docker label, a Kubernetes annotation, etc.

Since Kamal is a Docker orchestration tool, Traefik configuration is done with Docker labels. It means that you don't need to write a configuration file, instead you should provide labels to your Docker containers. Labels work dynamically, so you don't need to reboot Traefik to apply them. At the same time, operating a Docker label can be pretty tricky, especially at the beginning.

## Traefik Dashboard

The good news, is that Traefik works pretty good with Kamal out of the box with Kamal (Kamal provides basic default configuration, which I will show later) and maybe you won't need to change anything. However if you want to take a look at how Traefik is configured, you may want to enable [web dashboard](https://doc.traefik.io/traefik/operations/dashboard/).

To do this open your Kamal config (usually `config/deploy.yml`) and add the following lines.

```yaml
# config/deploy.yml

traefik:
  args:
    api.dashboard: true
  labels:
    traefik.http.routers.dashboard.servixce: api@internal
    traefik.http.routers.dashboard.rule: "Host(`traefik.onetribe.com`)"
    traefik.http.middlewares.auth.basicauth.users: user:$2y$05$us7dsDg56EJ/qojvhLvy9OEshrzoWjGSKXziBqeiFq3Ehf1pAiGSG
    traefik.http.routers.dashboard.middlewares: auth@docker
```

If you have a separate configuration for production and staging environments, you probably will have the last two labels in your environment-specific configuration files.

```yaml
# config/deploy.production.yml

traefik:
  labels:
    traefik.http.routers.dashboard.rule: "Host(`traefik.onetribe.team`)"
    traefik.http.middlewares.auth.basicauth.users: user-production:$2y$05$us7dsDg56EJ/qojvhLvy9OEshrzoWjGSKXziBqeiFq3Ehf1pAiGSG

# config/deploy.staging.yml

traefik:
  labels:
    traefik.http.routers.dashboard.rule: "Host(`traefik.staging.onetribe.team`)"
    traefik.http.middlewares.auth.basicauth.users: user-staging:$2y$05$us7dsDg56EJ/qojvhLvy9OEshrzoWjGSKXziBqeiFq3Ehf1pAiGSG
```

Lets go line by line in `config/deploy.yml` file.

- On line _5_ `api.dashboard: true` enables Traefik Dashboard, as it is disabled by default.
- On line _7_ I defined a router that will serve the dashboard. Internal Traefik API service is called `api@internal`, I attached it do the `dashboard` router.
- Than on line _9_ I defined a rule that tells Traefik to serve the dashboard on the `traefik.onetribe.team` domain. Rule can be based [on the path, the host, the headers, etc](https://doc.traefik.io/traefik/routing/routers/#rule).
- Since I don't want to expose the dashboard to the public, I added a basic authentication middleware on lines _9_ and _10_. Traefik supports different authentication methods: [basic](https://doc.traefik.io/traefik/middlewares/http/basicauth/), [digest](https://doc.traefik.io/traefik/middlewares/http/digestauth/), [forward](https://doc.traefik.io/traefik/middlewares/http/forwardauth/), etc. I used basic authentication, as it is the easiest to configure.

Password can be encrypted with the `htpasswd` command, which is a [part of Apache toolkit](https://httpd.apache.org/docs/2.4/programs/htpasswd.html) and this is really amazing how software, which is 20 years old, is still in use. To encrypt a password for a new user, run the following command.

```bash
htpasswd -nB user
```

## Traefik Logging

Besides the visualisation of the configuration, it is important to have a good logging. Most of my Kamal projects use AWS CloudWatch for logging, so I configured Traefik to send logs to CloudWatch. To do this, I added the following lines to the `config/deploy.yml` file.

```yaml
logging:
  driver: awslogs
  options:
    awslogs-region: us-east-1
    awslogs-group: application
    awslogs-create-group: true
    tag: "{{.Name}}-{{.ID}}"
```

This will configure logging for you application containers. In example above, I used `application` as a log group, you can use any name you want. The `tag` option is important, I used container name and ID to distinguish logs from different containers. The picture below demonstarates how logs are organized in the CloudWatch.

{% include image-caption.html imageurl="/assets/images/posts/2024-02-15/cloudwatch-logs.png" title="CloudWatch Log Streams" caption="CloudWatch Log Streams" %}

As you see, besides application containers logs, I also have Traefik log stream, which includes both error and access logs (which is not the best, but it is how it is). Traefik logging can be configured by passing arguments to the Traefik container. I assume that my healthcheck requests are pretty fast, so I set the minimum duration to 50ms to filter not important data.

```yaml
traefik:
  args:
    log.format: json
    accesslog: true
    accesslog.format: json
    accesslog.filters.minduration: 50ms
```

## Middlewares 101

I already talked about middlewares earlier in this article, let's have a closer look at them. Middlewares are a piece of code that can modify the request or the response before it reaches the service. I used a basic authentication middleware to protect Traefik dashboard.

As we already know, each router has a set of settings, and `middlewares` is also a setting that accepts a list of middlewares. Each middleware should be defined with it is own labels.

```yaml
traefik.http.middlewares.<middleware_1>.basicauth.users: username:<encrypted_password>
traefik.http.middlewares.<middleware_2>.ipwhitelist.sourcerange: 127.0.0.1/32
traefik.http.routers.<router_name>.middlewares: <middleware_1>, <middleware_2>, <middleware_3>
```

**Important**, Traefik middlewares are not global. They are attached to the router, so you need to define them for each router separately.

Kamal adds a [default middleware](https://github.com/basecamp/kamal/blob/aea55480adcaf61e3eebfd49f2b8c039207ad0de/lib/kamal/configuration/role.rb#L189) to each service that uses Traefik. It is essential to know, because if you add a middleware to a router, it will replace the default middleware. If you want to add a middleware to the default middleware, you must add it to the list of middlewares.

#### WWW Redirect

Redirecting from www to non-www domain is a common practice. It is important to have a single domain for SEO and security reasons.

In Nginx I used to do this with a simple `rewrite` directive.

```nginx
server {
  server_name www.onetribe.team;
  return 301 $scheme://onetribe.team$request_uri;
}
```

To do this with Traefik, you need to configure [RedirectRegex middleware](https://doc.traefik.io/traefik/middlewares/http/redirectregex/) on the router.

```yaml
servers:
  web:
    hosts:
      - <ip_address>
    labels:
      traefik.http.routers.onetribe-web.middlewares: onetribe-web-www-redirect@docker
      traefik.http.middlewares.onetribe-web-www-redirect.redirectregex.regex: ^http://www.(.*)
      traefik.http.middlewares.onetribe-web-www-redirect.redirectregex.replacement: https://$1
```

You probably noticed that I used `http://` schema in regex. Why not `https://`? In all my configurations with Traefik I do HTTPS termination on load balancer before the request reaches Traefik, in Rails 7.1 introduced `config.assume_ssl` [option](https://api.rubyonrails.org/classes/ActionDispatch/AssumeSSL.html) to handle such configurations.

#### Compress

Almost all Nginx configurations I saw had a `gzip` directive. Compressing responses to save bandwidth and speed up the website is a good practice. Digital Ocean has an [excellent tutorial](https://www.digitalocean.com/community/tutorials/how-to-improve-website-performance-using-gzip-and-nginx-on-ubuntu-20-04), explaining how HTTP compression works and how to configure it with Nginx.

```nginx
server {
  # ...
  gzip on;
  gzip_comp_level 2;
  gzip_min_length 1000;
  gzip_proxied any;
  gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
  gzip_vary on;
  # ...
}
```

Traefik has a [Compress middleware](https://doc.traefik.io/traefik/middlewares/http/compress/) that can be used to achieve the same result.

```yaml
servers:
  web:
    hosts:
      - <ip_address>
    labels:
      traefik.http.routers.onetribe-web.middlewares: onetribe-web-compress@docker
      traefik.http.middlewares.onetribe-web-compress.compress: true
```

#### Full Example

The example below combines two middleware defined above and a middleware that is added by default by Kamal – Retry. The Retry middleware reissues requests a given number of times to a backend server if that server does not reply.

```yaml
servers:
  web:
    hosts:
      - <ip_address>
    labels:
      traefik.http.routers.onetribe-web.middlewares: onetribe-web-www-redirect@docker,onetribe-web-retry@docker,onetribe-web-compress@docker
      traefik.http.routers.onetribe-web.rule: PathPrefix(`/`)
      traefik.http.services.onetribe-web.loadbalancer.server.scheme: http

      traefik.http.middlewares.onetribe-web-www-redirect.redirectregex.regex: ^http://www.(.*)
      traefik.http.middlewares.onetribe-web-www-redirect.redirectregex.replacement: https://$1

      traefik.http.middlewares.onetribe-web-compress.compress: true

      traefik.http.middlewares.onetribe-web-retry.retry.attempts: 5
      traefik.http.middlewares.onetribe-web-retry.retry.initialinterval: 500ms
```

### Rails Assets Handling

Last, it is not about the Traefik but about the Rails configuration. With Nginx I usually didn't care about how my CSS, JS and other static assets were handled, Nginx did this for me. All required headers (like compression that we discussed above and cache control) were added by Nginx. Traefik is not a web server, it is an edge router, so it doesn't handle static assets. It means that you need to configure Rails to handle static assets properly.

Stop, Rails static files handling is slow and not efficient. And you are right, or at least you were right. Modern versions of Puma handle static assets well. Besides, in 2024, we usually use cloud storage like AWS S3 to handle user uploads, so Rails will only serve CSS and JS files, which is not a big deal for Puma.

I ended with something like this in my `config/environments/production.rb` file.

```ruby
  # config/environments/production.rb
  # ...

  config.public_file_server.enabled = true
  config.public_file_server.headers = {
    "Cache-Control" => "public, max-age=#{30.days.to_i}, must-revalidate"
  }
```

`Cache-Control` header is important, it tells the browser how long it should cache the file. In this example, I set it to 30 days. Must-revalidate tells the browser to revalidate the file after the cache expires.

With such settings, Rails will serve static files only once for each client. If you think this is not enough, you can use a CDN like Cloudflare or AWS CloudFront to cache responses from Rails and dramatically reduce the load on your server.

## Conclusion

As it usually happens with new technologies, it takes time to get used to them. Traefik is not an exception. It took me a while to understand how it works and how to configure it. At the same time, I see the benefits of using Traefik over Nginx with Rails – the main one is, of course, support of Docker out of the box. I believe this was the main reason why Basecamp decided to go with Traefik. Almost a year has passed since I switched our first project to Traefik, and I'm happy with the result. I hope you will find this article useful. Feel free to ask questions in the comments below.
