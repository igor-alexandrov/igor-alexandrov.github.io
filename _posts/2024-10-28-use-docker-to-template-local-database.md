---
title: Use Docker to template local database
layout: post
tags:
  - Docker
  - DevOps
  - Captain Speaks
featured: true
hidden: false
featured_image: /assets/images/docker-mark-blue.png
---

How often do you reset your local development database? Depending on the task I am working on, I can do this even ten times a day. The reasons can be different. You or your teammate pushed an irreversible migration, which is of course not the best practice, but happens in the real life. Or you simply corrupted the data while implementing some new functionality.

## TL;DR

Resetting a local development database is a common task that can take a lot of time when the database dump is large. When you need to reset your local development database, you can use Docker to template it. This will save you a lot of time when your database dump is large.

The repository with the scripts is available [here](https://github.com/igor-alexandrov/docker-db-template).

## The Problem

When your project DB size is 100Mb, it is not a problem to run `psql -d project_development < project_development.sql` to restore the database. But what if your project database dump is 50 GB or 100 GB? This is a common size of the database for the project that does have some real clients.

On my Mac M1 Pro, it usually takes about 30 minutes to restore a 50GB dump from the SQL data file. Resetting such a database two times a day can cost you your lunchtime. Sounds so-so.

<pre class="language-bash"><code>
➜  backend git:(invoices) ✗ time psql -d safari_development_1 -f ~/Downloads/safari_development.sql

psql -d safari_development -f ~/Downloads/safari_development.sql  38.48s user 121.23s system 9% cpu 27:49.06 total
</code></pre>

Having the dump in the binary format will make it significantly smaller (8 GB instead of 50), but still, it will take a lot of time to restore it.

<pre class="language-bash"><code>
➜  backend git:(master) time pg_restore -d safari_development ~/Downloads/safari_development.dump

pg_restore -d safari_development ~/Downloads/safari_development.dump  180.61s user 75.97s system 13% cpu 30:39.12 total
</code></pre>

How to speed things up?

## General Idea

The general idea is elementary – **somehow avoid restoring the database dump**.

A similar approach works in the database replication. When your master database goes down for whatever reason, you can immediately switch to the slave database, which will become the master. You don’t need to wait while you will restore the dump from the backup.

How can we avoid restoring dump when working locally? The idea is to have a template of the database somewhere and simply copy this template instead of restoring the dump with `psql` or `pg_restore`.


<figure>
  <figcaption>PostgreSQL Templates</figcaption>

  <em>
    PostgreSQL has a built-in <a href="https://www.postgresql.org/docs/current/manage-ag-templatedbs.html">template system</a>. These templates allow users to replicate the structure, schema, and any data stored in them into newly created databases. By default, PostgreSQL provides two templates: <code>template0</code> and <code>template1</code>. This feature helps standardize new databases and streamline the creation process across multiple instances. However, since during the initialization of the database all the objects from the template are reinitialized again, it still takes quite a lot of time to run.
  </em>

  <pre class="language-bash"><code>
    ➜  backend git:(master) time createdb -T safari_development_template safari_development
    createdb -T safari_development_template safari_development  0.00s user 0.01s system 0% cpu 17:34.90 total
  </code></pre>
</figure>

What does it mean with PostgreSQL? This means we should have a full copy of our PostgreSQL cluster on the disk and copy it every time we want to “restore” the database. With PostgreSQL (or any else database except the SQLite) that is installed on directly your host machine, this can be a rather tricky task. You will have to worry about management of PostgreSQL config files, environment variables and tons of other stuff. Believe me, this won’t make you development efficient.

This is where Docker comes in place. My idea was to have two versions of the database – the template and the current working version, and to have an ability to quickly copy the template to the current version.

## Implementation

Before going into the detail, I want to quickly walk through the main Docker concepts that I used in this implementation. The first one is the Docker image. The image is a read-only blueprint with instructions for creating a Docker container. The second one is the Docker container. The container is a runnable instance of an image. Containers and images are managed with `docker container` and `docker image` [commands](https://docs.docker.com/reference/cli/docker/container/) [accordingly](https://docs.docker.com/reference/cli/docker/image/). The third one is the Docker volume. The volume is a persistent data storage mechanism that allows data to exist beyond the lifecycle of a container.

<figure>
  <figcaption>Docker Volumes 101</figcaption>

  <em>
    A key feature of a Docker container is its <strong>temporary nature</strong>. When a container is deleted, any changes made to its file system are lost. To address this, Docker uses volumes. The concept is to store data on the host machine’s file system rather than within the container itself, ensuring it persists beyond the container’s lifecycle.
  </em>
</figure>

Dealing with a Docker volume is straightforward. Once the volume is created, it can be attached to the container. When the container is deleted, the volume is still there. You can attach the volume to another container and continue working with the data. Volumes are managed with the `docker volume` [command](https://docs.docker.com/reference/cli/docker/volume/).

Lets take a look the small script below.

<pre class="language-bash"><code>
#!/bin/bash

set -e

# Create a volume
docker volume create safari-development-template

# Start a container with the PostgreSQL database and attach the volume
docker run --name safari-development-template \
  -p 5432:5432 \
  -e POSTGRES_USER=igor \
  -e POSTGRES_DB=safari_development \
  -e POSTGRES_HOST_AUTH_METHOD=trust \
  -v safari-development-template:/var/lib/postgresql/data \
  -d postgres:17
</code></pre>

What does it do? It creates a volume with the name `safari-development-template` and starts a container with the PostgreSQL database. The container is named `safari-development-template` and exposes the port 5432. The database name is `safari_development` and the user is `igor`. The volume `safari-development-template` is attached to the container.

Once the container is up, I can restore the database dump into it.

<pre class="language-bash"><code>
psql -d safari_development \
  -h localhost \
  -p 5432 < safari_development.sql
</code></pre>

After about 30 minutes, the database has been restored. With [Docker Desktop](https://www.docker.com/products/docker-desktop/), I can see the volume with its size.

{% include image-caption.html imageurl="/assets/images/posts/2024-10-27/docker-volumes-listing.png" title="Docker Volumes Listing" caption="Docker Volumes Listing" width="600px" %}

The setup we have now is pretty standard. Our database is running in the container and the data is stored on the host machine. Such a setup allows us to do local development. Unfortunately, from the time perspective, it is not anyhow different the restoring the database dump directly on the host machine.

Now let's move to the interesting part. Firstly, we need to create another volume that will be used for the working database. This can be done similar to the template volume creation.

<pre class="language-bash"><code>
docker volume create safari-development
</code></pre>

So now we have two volumes: `safari-development-template` and `safari-development`. The first one has the data and the second one is empty. The idea is to copy the data from the first volume to the second one. Docker doesn't provide a direct way to copy the data between the volumes, but the data can be copied between the volumes that are attached to the container. With this idea in mind I decided to use the smallest possible Docker image that has the `cp` command.

The `busybox` [image](https://hub.docker.com/_/busybox) is the best choice for this. It is only 4 MB in size and has many common UNIX utilities. To copy the data between the volumes, I  started a container with the `busybox` image and attached both volumes to it to run the `cp` command.

<pre class="language-bash"><code>
docker container run --rm -it \
    -v safari-development-template:/from \
    -v safari-development:/to \
    busybox sh -c "cd /from ; cp -av . /to"
</code></pre>

<figure>
  <figcaption>BusyBox</figcaption>

  <em>
    <a href="https://busybox.net/" target="_blank" rel="noopener noreferrer">BusyBox</a> was created by Bruce Perens in 1995 to address the need for a compact, efficient tool set for embedded systems running Linux. At the time, most Unix utilities were too large and complex for the limited resources of embedded devices. Perens designed BusyBox to combine essential Unix tools into a single, space-saving binary, allowing developers to run key commands in environments with minimal memory and storage.
    <br/><br/>
    The BusyBox Docker image is a streamlined Linux environment optimized for lightweight, containerized applications, testing, and quick tasks where minimalism is essential. This design allows BusyBox to deliver essential commands (like <code>ls</code>, <code>cp</code>, and <code>ping</code>) in a fraction of the space required by standard Linux distributions, making the Docker image often just a 5 Mb in size.
  </em>
</figure>

Once the image is downloaded, it takes about **40 seconds** to copy the data between the volumes. The time is significantly less than the time it takes to restore the database dump. The data is copied, and we can start the container with the working database with the command below.

<pre class="language-bash"><code>
docker run --name safari-development \
  -p 5432:5432 \
  -e POSTGRES_USER=igor \
  -e POSTGRES_DB=safari_development \
  -e POSTGRES_HOST_AUTH_METHOD=trust \
  -v safari-development:/var/lib/postgresql/data \
  -d postgres:17
</code></pre>

Now I can connect to the database and start working on the feature. When I need to reset the database, I can simply stop the container and copy the data from the template volume to the working volume again within less than a minute. This approach saves me a lot of time almost every day.

To make the process easier and more automated, I created a couple of scripts that can be used to create the template and to switch between the volumes. The repository with the scripts is available [here](https://github.com/igor-alexandrov/docker-db-template)

## Usage

To create a template database use `docker-db-create-template.sh`, I usually put to the `bin` directory of the Rails project. The script that accepts two required parameters:
* `project_name`, which is safari in our case
* `file_path`, path to the database dump (currently in SQL format)

<pre class="language-bash"><code>
➜  backend git:(master) ✗ ./bin/docker-db-create-template.sh safari ~/Downloads/safari_development.sql
Stopping container safari-development-template                  done
Deleting container safari-development-template                  done
Removing existing volume safari-development-template            done
Creating new volume safari-development-template                 done
Starting container safari-development-template                  done
	Loading /Users/igor/Downloads/safari_development.sql...
into safari_development                                         done

Database safari_development is running on port 5432

What to do next:
1. Run migrations
2. Start Rails server
3. Change the data the way you want it to be in the template
4. Stop Rails server
5. Stop the database container with the command: docker stop safari-development-template
6. Run ./bin/docker-db-use-template.sh safari to use the template
Elapsed time: 1542 seconds
</code></pre>

Now you can connect to your database on the port 5432. Do whatever preparations in the template you need. Usually this can include creating yourself a user or any other data modifications that you will need later.

When you are done with, stop your container with `docker stop safari-development-template` command.

It is time to use your template.

<pre class="language-bash"><code>
➜  backend git:(master) ./bin/docker-db-use-template.sh safari
Stopping container safari-development                             done
Deleting container safari-development                             done
Removing existing volume safari-development                       done
Creating new volume safari-development                            done
Copying data from safari-development-template                     done
Starting container safari-development                             done

Database safari_development is running on port 5432
Elapsed time: 46 seconds
</code></pre>

Only 46 seconds and are ready to go. Start the Rails app again and work on your feature. Each time you will need to reset the database to the template simply run `./bin/docker-db-use-template.sh safari` again.

## Conclusions
There are two main takeaways from this post. The first is that you should try to be as effective as possible. When I see that some task takes a lot of time, I try to find a way to speed it up. It is true for my work as developer, CTO, and even true for my personal life. Time is the most valuable resource that we have.

The second is that creating a tooling around your daily tasks can save you a lot of time. I have many scripts that I use every day. They are not perfect, but they do the job. I am excited to share them with you. For any clarifications or suggestions, feel free to reach me out on [X](https://x.com/igor_alexandrov).
