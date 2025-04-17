---
title: Kamal locks and GitHub Actions concurrency
description:
layout: post
tags:
  - Docker
  - Rails
  - Captain Speaks
  - DevOps
featured: false
hidden: false
featured_image: /assets/images/docker-mark-blue.png
---

When your deployments are automated and while the development process grows in complexity, you may find yourself needing to manage multiple deployments simultaneously. This is where concurrency comes into play.

Kamal sets up a lock on the each host while deploying to it