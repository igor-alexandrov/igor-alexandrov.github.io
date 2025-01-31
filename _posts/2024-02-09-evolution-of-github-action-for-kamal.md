---
title: Evolution of GitHub Action for Kamal
description: Discover the evolution of a GitHub Action for Kamal in this insightful blog post by Igor Aleksandrov. Learn how to streamline your deployment workflow, automate tasks, and optimize your CI/CD pipeline with Kamal and GitHub Actions.
layout: post
tags:
  - Ruby
  - DevOps
  - GitHub
render_with_liquid: false
---

Right after my first try of Kamal (MRSK) in the spring of 2023, I understood that an ideal use case would be running it as a GitHub Action. Almost a year passed, and my 30-line action has grown and become full-featured, configurable, and reusable. In this post, I will share the evolution of the action and the lessons learned.

<!--more-->

Before we start, let me remind you what Kamal is. Kamal is a Ruby library created by 37signals to orchestrate the deployment of Docker containers. Before switching to Kamal, I had a bunch of scripts and technologies to deploy my applications. Kamal allowed me to simplify the deployment process and make it more reliable. Also, there were already some GitHub workflows to run lints and tests. In this article, I will mention only the deployment part.

## First Try

In my initial article about Kamal, I already posted the first version of the GitHub Action. It was a simple action that used the `ruby/setup-ruby` action to install Ruby, then `webfactory/ssh-agent` to configure SSH agent, then prepared AWS crednetials and then run the `kamal envify` and `kamal deploy` command. The code is below.

<pre><code class="language-yaml">
name: Kamal

on:
  push:
    branches:
      - main

jobs:
  spec:
    uses: ./.github/workflows/specs.yml
  lint:
    uses: ./.github/workflows/lint_code.yml

  build_and_deploy:
    needs: [spec, lint]
    runs-on: ubuntu-latest
    timeout-minutes: 20
    outputs:
      image: ${{ steps.build.outputs.image }}
    env:
      RAILS_ENV: production
    steps:
      - uses: actions/checkout@v3
        with:
          ref: ${{ github.event.workflow_run.head_branch }}

      - uses: webfactory/ssh-agent@v0.7.0
        with:
          ssh-private-key: ${{ secrets.SSH_PRIVATE_KEY }}

      - uses: ruby/setup-ruby@v1
        env:
          BUNDLE_GEMFILE: ./kamal/Gemfile
        with:
          ruby-version: 3.2.2
          bundler-cache: true

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v2
        with:
          driver-opts: image=moby/buildkit:master

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v1
        with:
          aws-access-key-id    : ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region           : us-east-1
          mask-aws-account-id  : 'true'

      - name: Login to Amazon ECR
        id  : login-ecr
        uses: aws-actions/amazon-ecr-login@v1

      - name: Kamal Envify
        id  : kamal-envify
        env :
          KAMAL_REGISTRY_PASSWORD: ${{ steps.login-ecr.outputs.docker_password_YOUR_AWS_ACCOUNT_ID_dkr_ecr_YOUR_AWS_REGION_amazonaws_com }}
          DATABASE_URL: ${{ secrets.DATABASE_URL }}
          REDIS_URL: ${{ secrets.REDIS_URL }}
          RAILS_MASTER_KEY: ${{ secrets.RAILS_MASTER_KEY }}
          DOCKER_BUILDKIT: 1
          BUNDLE_GEMFILE: ./kamal/Gemfile
        run: |
          ./bin/kamal envify

      - name: Kamal Deploy
        id: kamal-deploy
        run: |
          ./bin/kamal deploy
</code></pre>

There are several things to pay attention to. First, at lines _27-29_, I setup SSH agent to be able to connect to the instances and run Docker commands, SSH private key is stored in the GitHub secrets, which is a convenient way to store sensitive data.

On lines _38-41_ I setted up Docker Buildx, and it was very important to download Buildkit from the repository `master` branch. At the moment of spring-winter of 2023, Buildkit didn't support cache manifests for AWS ECR, and I had to use the `master` branch to get the feature ([Issue #876](https://github.com/aws/containers-roadmap/issues/876)).

On lines _43-53_, I configured AWS credentials and logged in to Amazon ECR. It is not the most secure way to login to AWS, but definitely was the easiest way to do it at that time.

This setup had several drawbacks.

- The first and the most important, the action was not reusable. To configure deploy to another environment, I had to copy-paste the action completely.

- Besides that, the action didn't provide an ability to run deploy without running specs and lints. It was not a big deal, but sometimes I wanted to run deploy separately.

- The action didn't provide an ability to run deploy to another branch.

- Sometimes I wanted to restart Traefik container. This cound be done from the local machine, but for me it would be better to do it from the action.

## Action's File Structure

Together with JetRockets DevOps team we incrementally improved the action, added new features, and made it more configurable. Finally we come the set of actions that can be used in almost any project.

For a better understanding of the changes, let's look at the directory structure of the actions first.

<pre><code class="language-">
.github/
├─ workflows/
   ├─ build_deploy/
      ├─ action.yaml
   ├─ pre-build/
      ├─ action.yaml
   ├─ 01.build_deploy_production.yaml
   ├─ 02.build_deploy_staging.yaml
   ├─ 03.database_backup.yaml
   ├─ 04.build_deploy_manually.yaml
   ├─ 05.validate_pull_request.yaml
   ├─ 06.kamal_run_command.yaml
   ├─ _lint.yaml
   ├─ _specs.yaml
</code></pre>

You may notice two directories, `build_deploy` and `pre-deploy`, both have file `action.yaml` inside. These are [composite actions](https://docs.github.com/en/actions/creating-actions/creating-a-composite-action) that include all the necessary steps to build and deploy the application. Also, some workflows are named with a leading underscore. These are reusable workflows that consist of several jobs and steps.

How are Composite Actions different from Reusable Workflows?

- Composite Actions allow you to bundle multiple existing workflow steps into a single action.
- A Composite Action cannot be used without a repo checkout while Reusable Workflows can be used without a checkout.
- A Reusable Workflow can include multiple jobs and multiple steps within those jobs. However, Composite Actions can only have one job.
- Reusable Workflow can use Secrets by declaring them to a workflow via parameters while Composite Actions cannot use Secrets in a flexible way.

Files with numeric prefixes are main workflow definitions that call the reusable workflows and composite actions. They cover the most common usecases for a modern Rails project: deploy to production and staging, database backup, manual deploy, pull request validation, and Kamal command execution.

## Pre Build Action

Lets start with the `pre-build` action. It is a composite action that includes all the necessary steps to prepare the environment for the build and deploy action. The file is below.

<pre><code class="language-yaml">
# pre-build/action.yml

name: Pre-Build

inputs:
  database-url:
    type: string
  redis-url:
    type: string
  rails-master-key:
    type: string
  aws_role_access:
    type: string
  ssh_private_key:
    type: string
  environment:
    type: string

runs:
  using: composite
  steps:
    - uses: webfactory/ssh-agent@v0.8.0
      with:
        ssh-private-key: ${{ inputs.ssh-private-key }}

    - uses: ruby/setup-ruby@v1
      env:
        BUNDLE_GEMFILE: ./Gemfile
      with:
        ruby-version: .ruby-version
        bundler-cache: true

    - name: Set up Docker Buildx
      uses: docker/setup-buildx-action@v3

    - name: aws-cred-configure
      uses: aws-actions/configure-aws-credentials@v4
      with:
        role-to-assume   : ${{ inputs.aws-role-access }}
        role-session-name: samplerolesession
        aws-region       : es-east-1
        mask-aws-account-id: 'true'

    - name: login-to-aws-ecr
      id: login-ecr
      uses: aws-actions/amazon-ecr-login@v2
      with:
        mask-password: 'true'

    - name: Kamal Envify
      shell: bash
      id  : kamal-envify
      env :
        KAMAL_REGISTRY_PASSWORD: ${{ steps.login-ecr.outputs.docker_password_AWS_ACCOUNT_ID_dkr_ecr_eu_west_2_amazonaws_com }}
        DATABASE_URL: ${{ inputs.database-url }}
        REDIS_URL: ${{ inputs.redis-url }}
        RAILS_MASTER_KEY: ${{ inputs.rails-master-key }}
        DOCKER_BUILDKIT: 1
      run: |
        ./bin/kamal envify --destination=${{ inputs.environment }}
</code></pre>

Lets walk line by line through the file. Lines _5-17_ describe the inputs of the action and are not interesting to us. The first step is to setup SSH agent, and it is the same as in the first version of the action. However, as you may see, it uses `ssh-private-key` from the action inputs, which allows us to use the action in different environments. After that, I setup Ruby, and it is also the same as in the first version of the action.

Docker Buildx setup step differs from the initial workflow definition. It has been updated to the version 3 and now [supports AWS ECR image cache](https://github.com/aws/containers-roadmap/issues/876) out the box, so we don't need to define `driver-opts` anymore.

The next step is to configure AWS credentials. It is completely different from what I initially had. Instead of `access-key-id` and `secret-access-key` authentication, I switched to the UIDC role-based authentication, which is more secure and GitHub [advises to use it](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services). If you need a more detailed explanation of how to configure OpenID Connect in AWS, I suggest you read this [excellent guide](https://medium.com/israeli-tech-radar/openid-connect-and-github-actions-to-authenticate-with-amazon-web-services-9a66b3b88e92). After the authentication is done, I login to Amazon ECR on lines _44-48_.

The final step is to run `kamal-envify`, which prepares environment variables for the deployment. The command is the same as in the first version of the action, but I added the `--destination` flag to the command, which allows me to deploy to different environments.

## Build & Deploy Action

The next composite action is defined in `build_deploy` folder and it is relatively simple.

<pre><code class="language-yaml">
# build-deploy/action.yml
name: Build & Deploy

inputs:
  environment:
    type: string

runs:
  using: composite
  steps:
    - name: Kamal Deploy
      shell: bash
      id: kamal-deploy
      run: |
        ./bin/kamal deploy --destination=${{ inputs.environment }}

    - name: Kamal Release
      shell: bash
      if: ${{ cancelled() }}
      run: |
        ./bin/kamal lock release --destination=${{ inputs.environment }}
</code></pre>

Since all preparations are done in `pre-build`, when this action starts, I am ready to run the `kamal deploy` command with the selected environment.

Kamal creates a lock file before starting the build and deployment process. Usually lock is released when deployment is finished, but if the deployment is cancelled, the lock is not released. And next workflow run will fail. To avoid this, I added the `kamal lock release` command to the action. Later this article, we will use this small hack to handle concurrent deployments correctly.

## Workflow Definitions

The main workflow definitions are very simple. They just call the composite action together with reusable workflows and pass the necessary parameters. Below is the example of the `01.build_deploy_production.yaml` file.

<pre><code class="language-yaml">
# 01.build_deploy_production.yaml
name: 01. Build & Deploy Production

permissions:
  id-token: write
  contents: read

on:
  release:
    types: [published]

jobs:
  spec:
    uses: ./.github/workflows/_specs.yaml
    secrets: inherit

  lint:
    uses: ./.github/workflows/_lint_code.yaml
    secrets: inherit

  build_and_deploy:
    name: build-deploy-production
    concurrency:
      group: production_environment
      cancel-in-progress: true
    environment:
      name: production
      url: https://onetribe.team
    needs:
      - spec
      - lint
    runs-on: ubuntu-latest
    timeout-minutes: 20
    steps:
      - uses: actions/checkout@v4
        with:
          ref: ${{ github.event.workflow_run.head_branch }}

      - name: Pre Build
        uses: ./.github/workflows/pre-build
        with:
          database-url: ${{ secrets.DATABASE_URL_PRODUCTION_ADMIN }}
          redis-url: ${{ secrets.REDIS_URL_PRODUCTION_ADMIN }}
          rails-master-key: ${{ secrets.RAILS_MASTER_KEY }}
          aws-role-access: ${{ secrets.AWS_ROLE_ACCESS }}
          ssh-private-key: ${{ secrets.SSH_PRIVATE_KEY }}
          environment: production

      - name: Build & Deploy
        uses: ./.github/workflows/build-deploy
        with:
          environment: production
</code></pre>

The `concurrency` section in lines _23-25_ deserves attention in the file. It allows me to run only one deployment at a time. GitHub has a great [documentation section](https://docs.github.com/en/actions/using-jobs/using-concurrency) that covers all possible use cases. If a deployment is already running, it will be canceled, and the `"Kamal Release"` step from the previous workflow run will be executed. This is an essential feature because it allows me to avoid concurrent deployments and handle them correctly.

Staging deploy is defined in the `02.build_deploy_staging.yaml` file and is similar to production, except for the event that starts the workflow: for staging deploy I use the `push` event to GIT `staging` branch, instead of the `release`.

<pre><code class="language-yaml">
# 02.build_deploy_staging.yaml
name: 02. Build Staging

permissions:
  id-token: write
  contents: read

on:
  push:
    branches:
      - staging

# ...
</code></pre>

In this article I will not cover database backup workflow, defined in the `03.database_backup.yaml` file, because it is not related to the theme of the article. However lets look at `04.deploy_manually.yaml`, `05.validate_pull_request.yaml`, and `06.kamal_run_command.yaml` files.

The `04.build_deploy_manually.yaml` file is below.

<pre><code class="language-yaml">
# 04.build_deploy_manually.yaml
name: 04. Deploy Manually

permissions:
  id-token: write
  contents: read

on:
  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment'
        required: true
        default: 'staging'
        type: choice
        options:
          - production
          - staging

jobs:
  build-production:
    name: deploy-production
    concurrency:
      group: production_environment
      cancel-in-progress: true
    environment:
      name: production
      url: https://onetribe.team
    if: ${{ github.event.inputs.environment == 'production' }}
    runs-on: ubuntu-latest
    timeout-minutes: 20
    steps:
      - uses: actions/checkout@v4
        with:
          ref: ${{ github.event.workflow_run.head_branch }}

      - name: Pre Build
        uses: ./.github/workflows/pre-build
        with:
          database-url: ${{ secrets.DATABASE_URL_PRODUCTION_ADMIN }}
          redis-url: ${{ secrets.REDIS_URL_PRODUCTION_ADMIN }}
          rails-master-key: ${{ secrets.RAILS_MASTER_KEY }}
          aws-role-access: ${{ secrets.AWS_ROLE_ACCESS }}
          ssh-private-key: ${{ secrets.SSH_PRIVATE_KEY }}
          environment: production

      - name: Build and Deploy
        uses: ./.github/workflows/build-deploy
        with:
          environment: production

  build-staging:
    name: deploy-staging
    concurrency:
      group: staging_environment
      cancel-in-progress: true

    # ...
    # staging deploy is similar to production, described above and I will not show it completely.
</code></pre>

Pull request validation is defined in the `05.validate_pull_request.yaml`, it is the most small and simple workflow. It runs specs and lints, triggered by the `pull_request` event and also can be triggered manually.

<pre><code class="language-yaml">
# 05.validate_pull_request.yaml
name: 05. Validate Pull Request

permissions:
  id-token: write
  contents: read

on:
  pull_request:
  workflow_dispatch:

jobs:
  spec:
    uses: ./.github/workflows/_specs.yaml
    secrets: inherit

  lint:
    uses: ./.github/workflows/_lint_code.yaml
    secrets: inherit
</code></pre>

The last workflow that I want to cover in this article is the `06.kamal_run_command.yaml` file. Sometimes I need to restart the Traefik container or maybe start or stop accessory containers. I can do it from the local machine, but this requires environment setup and is not always convenient. This workflow allows me to run any command from the list of predefined commands.

<pre><code class="language-yaml">
name: 06. Kamal run command

permissions:
  id-token: write
  contents: read

on:
  workflow_dispatch:
    inputs:
      command:
        description: 'Commands'
        required: true
        type: choice
        options:
          - traefik reboot --rolling
          - accessory reboot pg_hero
      environment:
        description: 'Environment'
        required: true
        type: choice
        options:
          - staging
          - production

jobs:
  kamal_run_command:
    name: Kamal run command
    runs-on: ubuntu-latest
    timeout-minutes: 20
    concurrency:
      group: ${{ github.event.inputs.environment }}_environment
      cancel-in-progress: false
    environment:
      name: ${{ github.event.inputs.environment }}
    steps:
      - uses: actions/checkout@v4
        with:
          ref: ${{ github.event.workflow_run.head_branch }}

      - uses: ./.github/workflows/pre-build
        name: Pre Build
        with:
          database-url: ${{ github.event.inputs.environment == 'production' && secrets.DATABASE_URL_PRODUCTION || secrets.DATABASE_URL_STAGING }}
          redis-url: ${{ github.event.inputs.environment == 'production' && secrets.REDIS_URL_PRODUCTION || secrets.REDIS_URL_STAGING }}
          rails-master-key: ${{ secrets.RAILS_MASTER_KEY }}
          aws-role-access: ${{ secrets.AWS_ROLE_ACCESS }}
          ssh-private-key: ${{ secrets.SSH_PRIVATE_KEY }}
          environment: ${{ github.event.inputs.environment }}

      - name: kamal ${{ github.event.inputs.command }} --destination=${{ github.event.inputs.environment }}
        run: |
          ./bin/kamal ${{ github.event.inputs.command }} --destination=${{ github.event.inputs.environment }}
</code></pre>

## Conclusion

The action has grown from a simple 30-line action to a set of reusable workflows and composite actions. It is now full-featured, configurable, and reusable. It allows me to run deploy to different environments, run deploy without running specs and lints, and restart Traefik container and accessories.

I use this or similar setup of workflows for about six months and what can I say? It covers all my needs and can be easily adopted for any new features. I hope this article will help you to build your own action and workflows. If you have any questions, feel free to ask me in the comments.
