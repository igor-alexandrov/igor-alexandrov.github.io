---
title: "Deploy with Kamal 2 and GitHub Action – a complete guide"
layout: post
tags:
  - Ruby
  - Rails
  - DevOps
featured: false
hidden: false
---

Kamal 2 has been released about a week ago during the Rails World 2024. It is a major release with a lot of changes. I already published a couple of posts covering the [applications deployment with Kamal and Github Actions](https://jetrockets.com/blog/how-to-use-basecamp-s-kamal-with-aws-and-github), describing the [evolution of GitHub Action to run Kamal](https://igor.works/blog/evolution-of-github-action-for-kamal) and tuning the [Trafik proxy to run Rails](https://igor.works/blog/traefik-tunning-for-rails-applications-part-1). In this article I will try to cover to things based on my previous knowledge and new Kamal 2 features: how to upgrade your existing deploy to Kamal 2 or deploy fresh app with it and how to run your deploy with GitHub Actions.

<!--more-->

## TL;DR

If you feel yourself confident with Kamal, you can follow the official [upgrade guide](https://kamal-deploy.org/docs/upgrading/overview/) if you are upgrading from Kamal 1 to Kamal 2 or if you are Kamal for the first time, you can follow the [getting started guide](https://kamal-deploy.org/docs/installation/).

I prepared a GitHub repository that includes samples of Kamal 2 configuration and GitHub Actions workflow. You can find it [here](https://github.com/igor-alexandrov/kamal-github-actions).


## Pre Kamal-2 Overview

To understand what I had at the beginning here is brief overview of the project that I have. It is Rails 7.2 application, that is being deployed with Kamal 1.8. The deployment was implemented with GitHub Actions and I host on DigitalOcean. I use managed PostgreSQL database and DigitalOcean Spaces for storing the assets. Speaking on the accessories, I use PgHero deployed to the same host as the application.

## Prequisites

I recommend upgrading you kamal to 1.9 before upgrading to 2.0. There are several reasons why this is important:

1. During the `kamal upgrade` command Kamal assumes that you are running the latest version of Kamal 1 and relies on the naming conventions of the containers.
2. Kamal 1.9 includes `kamal downgrade` command that will help you to rollback the changes if something goes wrong.

``` bash
➜  onetribe git:(kamal-2) ✗ bundle update kamal

...

Installing dotenv 3.1.4 (was 2.8.1)
Fetching dotenv-rails 3.1.4 (was 2.8.1)
Fetching kamal 2.0.0.rc2 (was 1.8.3)
Installing dotenv-rails 3.1.4 (was 2.8.1)
Installing kamal 2.0.0.rc2 (was 1.8.3)
Bundle updated!
```


``` bash
➜  onetribe git:(kamal-2) ✗ ./bin/kamal version
2.0.0.rc2
```

```
mv config/deploy.yml config/deploy.v1.yml
mv config/deploy.production.yml config/deploy.production.v1.yml
```

➜  jetrockets git:(kamal-2) ./bin/kamal init
Config file already exists in config/deploy.yml (remove first to create a new one)
Created .kamal/secrets file
Created sample hooks in .kamal/hooks


``` bash
➜  onetribe git:(kamal-2) ✗ ./bin/kamal init
```


Removed

builder:
  multiarch: false

Added:

builder:
  arch: amd64


healthcheck configuration went under proxy section.


!!!!!!!!
secrets-common



Traefik wasn't a perfect solution for Kamal. Of course after long years of using Nginx with its multi page boilerplate configs and moreover after using Apache before Nginx, Traefik seemed like a breath of fresh air. Its container auto discovery feature perfectly aligned with the Kamal's Docker orchestration logic. However there were things that could be improved.


Stop, but Kamal already has a proxy server, why do we need another one? Kamal is a Docker orchestration tool. To simplify things Kamal it makes `docker run` and `docker stop` calls, of course with a lot of additional logic. But the main idea is to run and stop Docker containers. Container itself exposes a port, which is usually 3000 if we are talking about Rails applications. So, if we have multiple containers running on the same host, we need to have a reverse proxy to route the traffic to the correct container. This is where the Traefik proxy comes into play. It listens to the Docker events and updates the routing table accordingly.

As I mentioned earlier, in Kamal 2 Traefik will be replaced by a custom written proxy server called kamal-proxy. The are a lot of reasons for this change, I will cover them in one of the next posts. The main difference between Traefik and kamal-proxy, is that Traefik besides the routing logic, also has a lot of features provided by [its middleware](https://doc.traefik.io/traefik/middlewares/overview/). This allows Traefik to modify requests and responses, add headers, etc. While its configuration is not as complex as in Nginx and of course it is good to have such features, in the Kamal context, we don't need them. While allowing to do things that Kamal wasn't originally designed for like integrating Let’s Encrypt or adding basic auth, or even making redirects from www to non-www, it also makes the proxy server more complex and harder to maintain. Besides this Kamal is a imperative tool, where you define all the steps what will be executed, while Traefik is declarative. This means that you define the desired state and Traefik will try to achieve it. While Traefik is doing its job, Kamal used to do a polling to check if the desired state is achieved.

The new `kamal-proxy` will be deeply integrated to the needs of Kamal. The only thing it will do is to route the traffic to the correct container.
