---
title: Rails enums, complete guide
layout: post
tags:
  - Ruby
  - Rails
  - Today You Learned
featured: false
hidden: true
---

Enums were [introduced in Rails 4.1](https://guides.rubyonrails.org/4_1_release_notes.html#active-record-enums) and are a great way to store predefined values in the database.

Rails 5.0 introduced [`_prefix`](https://github.com/rails/rails/pull/19813) and [`_suffix `](https://github.com/rails/rails/pull/20999) options.

Rails 6.0 added [negative scopes](https://github.com/rails/rails/pull/35381) and ability to [disable scopes generation](https://github.com/rails/rails/pull/34605) with `_scopes: false` option. Also enum values [became frozen](https://github.com/rails/rails/pull/34517).







