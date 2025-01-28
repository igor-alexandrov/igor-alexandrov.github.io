---
title: Upgrading Rails application from 7.1 to 7.2
layout: post
tags:
  - Ruby
  - Rails
featured: false
hidden: false
---

On August 9th, [Rails 7.2 was released](https://edgeguides.rubyonrails.org/7_2_release_notes.html), bringing a host of new features and improvements to the framework. Ten months ago, I demonstrated [how to upgrade a Rails application from 7.0 to 7.1](https://igor.works/blog/upgrading-rails-application-from-70-to-71), which was well-received by the community. Today, I will take you through the process of upgrading OneTribe from Rails 7.1 to 7.2. This upgrade not only ensures compatibility with the latest Rails enhancements but also allows me to better understand new Rails functionalities and performance optimizations. Let’s dive into the upgrade process and explore what Rails 7.2 has to offer.

<!--more-->

## Prerequisites

OneTribe runs Ruby 3.3.4 and Rails 7.1.3, which is good because Rails 7.2 requires Ruby 3.1.0 or newer. Nothing changed in code hosting and deployment, we still use GitHub and GitHub Actions with Kamal.

## Dependencies Update

The first you do to upgrade Rails is to change the version in the Gemfile.

```ruby
# Gemfile
# ...
gem "rails", "~> 7.2.0"
# ...
```
Than you do `bundle update rails` and either you will be see that everything is fine or you will see that something is wrong. In my case, I got an error that `pg_party` does not support Rails 7.2 yet. I checked the [gem's repository](https://github.com/rkrage/pg_party) and saw that there was already a PR with support for Rails 7.2, but it has not yet been merged. I decided to use the code from the PR.

```ruby
# Gemfile
# ...
gem "pg_party", github: "marcoroth/pg_party", branch: "rails-7.2"
# ...
gem "rails", "~> 7.2.0"
# ...
```

After I fixed the issue, I tried to run specs with `./bin/rspec` and got a strange error.

```shell
An error occurred while loading ./spec/workers/member/next_birthday_worker_spec.rb.
Failure/Error: require File.expand_path('../config/environment', __dir__)

NameError:
  undefined method `validate_find_options' for class `#<Class:ActiveRecord::Base>'
# ./config/application.rb:22:in `<top (required)>'
# ./config/environment.rb:4:in `require_relative'
# ./config/environment.rb:4:in `<top (required)>'
# ./spec/rails_helper.rb:6:in `<top (required)>'
# ./spec/workers/member/next_birthday_worker_spec.rb:3:in `<top (required)>'
```

I ran `./bin/rspec -b` to see the backtrace and found that the error was caused by the `acts_as_paranoid` gem. We used very old version of the gem, so I updated it to the latest version and bundled.

I found out that I didn't migrate the database when I fetched the latest changes from the repository. I ran `./bin/rails db:migrate` and got another error.

``` shell
➜  onetribe git:(rails-7-2) ✗ ./bin/rails db:migrate
Rodauth::Rails.authenticated has been deprecated in favor of Rodauth::Rails.authenticate, which additionally requires existence of the account record.
bin/rails aborted!
NoMethodError: undefined method `with_connection' for an instance of ActiveRecord::ConnectionAdapters::PostgreSQLAdapter (NoMethodError)

        pool.with_connection do |connection|
            ^^^^^^^^^^^^^^^^
Did you mean?  raw_connection

Tasks: TOP => db:schema:dump
(See full trace by running task with --trace)
```

To debug this I again used  `--backtrace` option.

```shell
➜  onetribe git:(rails-7-2) ✗ ./bin/rails db:migrate --backtrace
Rodauth::Rails.authenticated has been deprecated in favor of Rodauth::Rails.authenticate, which additionally requires existence of the account record.
bin/rails aborted!
NoMethodError: undefined method `with_connection' for an instance of ActiveRecord::ConnectionAdapters::PostgreSQLAdapter (NoMethodError)

        pool.with_connection do |connection|
            ^^^^^^^^^^^^^^^^
Did you mean?  raw_connection
/Users/igor/.rbenv/versions/3.3.0/lib/ruby/gems/3.3.0/gems/activerecord-7.2.0/lib/active_record/schema_dumper.rb:45:in `dump'
/Users/igor/.rbenv/versions/3.3.0/lib/ruby/gems/3.3.0/gems/hairtrigger-1.0.0/lib/tasks/hair_trigger.rake:18:in `block (4 levels) in <main>'
/Users/igor/.rbenv/versions/3.3.0/lib/ruby/gems/3.3.0/gems/hairtrigger-1.0.0/lib/tasks/hair_trigger.rake:17:in `open'
/Users/igor/.rbenv/versions/3.3.0/lib/ruby/gems/3.3.0/gems/hairtrigger-1.0.0/lib/tasks/hair_trigger.rake:17:in `block (3 levels) in <main>'
```

Backtrace helps quickly identify the issue. In my case it was the `hairtrigger` gem that was outdated and not compatible with Rails 7.2.

Finally, I was able to migrate and run specs successfully with `./bin/rspec`.

## Third-party Deprecations

During RSpec run I saw a couple of deprecation warnings and decided to fix them before going further.

```shell
DEPRECATION WARNING: ActiveRecord::ConnectionAdapters::ConnectionPool#connection is deprecated
and will be removed in Rails 8.0. Use #lease_connection instead.
```

I don't use `connection` directly in the code, so the message was caused by some gem. The problem was that I had no idea which gem caused the warning. How would you handle this? I found out that [starting from a Rails 7.1](https://guides.rubyonrails.org/7_1_release_notes.html#add-rails-application-deprecators) there is a `Rails.application.deprecators` API, which can be extremely useful in this case.

I updated my `config/application.rb` file to include the following code:

```ruby
# config/application.rb

module OneTribe
  class Application < Rails::Application
    # ...
    deprecators.debug = true if ENV["DEPRECATION_DEBUG"]
  end
end
```

Then I ran the specs with `DEPRECATION_DEBUG=true ./bin/rspec` and saw the following output:

```shell
DEPRECATION WARNING: ActiveRecord::ConnectionAdapters::ConnectionPool#connection is deprecated
and will be removed in Rails 8.0. Use #lease_connection instead.
 (called from load at ./bin/rspec:27)
/Users/igor/.rbenv/versions/3.3.0/lib/ruby/gems/3.3.0/gems/test-prof-1.3.3.1/lib/test_prof/before_all/adapters/active_record.rb:15:in `block in all_connections'
  /Users/igor/.rbenv/versions/3.3.0/lib/ruby/gems/3.3.0/gems/test-prof-1.3.3.1/lib/test_prof/before_all/adapters/active_record.rb:13:in `map'
  /Users/igor/.rbenv/versions/3.3.0/lib/ruby/gems/3.3.0/gems/test-prof-1.3.3.1/lib/test_prof/before_all/adapters/active_record.rb:13:in `all_connections'
  /Users/igor/.rbenv/versions/3.3.0/lib/ruby/gems/3.3.0/gems/test-prof-1.3.3.1/lib/test_prof/before_all/adapters/active_record.rb:36:in `begin_transaction'
  /Users/igor/.rbenv/versions/3.3.0/lib/ruby/gems/3.3.0/gems/test-prof-1.3.3.1/lib/test_prof/before_all.rb:24:in `block in begin_transaction'
```

Now everything was clear. The warning was caused by the `test-prof` gem. I decided to ignore it for now and continue with the upgrade.

## Rails Deprecations

Another deprecation warning I saw was:

```shell
➜  onetribe git:(rails-7-2) ✗ ./bin/rspec

DEPRECATION WARNING: Defining enums with keyword arguments is deprecated and will be removed
in Rails 8.0. Positional arguments should be used instead:

enum :role, {:employee=>"employee", :manager=>"manager", :administrator=>"administrator"}
 (called from <class:Member> at /Users/igor/workspace/onetribe/app/models/member.rb:14)
```

In mid-February 2024, there was a [PR that deprecated defining enums with keyword arguments](https://github.com/rails/rails/pull/50987). Before it was possible to define enums like this:

```ruby
# app/models/time_off/slot.rb


class TimeOff::Slot < ApplicationRecord
  # ...

  enum allocation_type: { general: 0, extra: 1, auto: 2 }, _prefix: :allocation_type
end
```

With this change you should define enums like this:

```ruby
# app/models/time_off/slot.rb

class TimeOff::Slot < ApplicationRecord
  # ...

  enum :allocation_type, { general: 0, extra: 1, auto: 2 }, prefix: :allocation_type
end
```

This new syntax eliminates the need to prefix options with an underscore.

For some reason, this change wasn't mentioned in the Rails 7.2 release notes, but it's good to know about it.

## Application Configuration Update

Rails has a special task `rails app:update` that can help you to update application configuration in an interactive mode. I use VS Code for development and wanted to use its merge tool, so as in the previous update, I specified THOR_MERGE constant before running the command `THOR_MERGE="code --wait" ./bin/rails app:update` and used merge tool (`m` option) to track changes over files.

During the update I found only one notable configration change.

Annotation of views with filesnames is now anabled by default in development. This setting is handled by `config.action_view.annotate_rendered_view_with_filenames = true` in `config/environments/development.rb`.

``` html
<h3 class="mb-4 text-lg font-medium text-center">
  Team Schedule
</h3>

<!-- BEGIN app/views/companies/time_offs/shared/_monthly_calendar.html.slim -->
<div id="monthly_calendar">
  <!-- ... -->
</div>
<!-- END app/views/companies/time_offs/shared/_monthly_calendar.html.slim -->
```

With this setting enabled, you will see comments like this in the HTML source of the page. I am not sure if it's useful, but it's good to know about it.

## App Defaults

After you merge all the changes, you can run the specs again to make sure everything is fine. Now it is time to make sure that your application is ready to run with Rails default settings, applied to every new Rails 7.2 application.

This can be done in two steps. In `config/initializers` there should be a new file named `new_framework_defaults_7_2.rb`. It includes all Rails 7.2 default params commented, so you can enable them one by one and make sure that your specs are still green and your application is still working.

After after, you can change `config.load_defaults` in `config/application.rb` file to have `7.2` value and delete `new_framework_defaults_7_2.rb`. This will enable all options at once.

## Development Container

One new feature of Rails 7.2 that deserves to be mentioned in this text is format support of Docker development containers. Yes, nobody prevented you from using dev container before Rails 7.2, but now you can generate container configuration for new apps with `rails new myapp --devcontainer` command. This will create a new Rails app with the `.devcontainer` folder that includes `devcontainer.json`, `Dockerfile` and `docker-compose.yml` files.

For applications that were upgrade you can use `./bin/rails devcontainer` console command to generate the same files.

## Conclusions

Since 7.2 is a minor release, there are not many changes and new features, however the [Release Notes are rather long](https://edgeguides.rubyonrails.org/7_2_release_notes.html). I will not cover everything here, but I suggest you to read them. Maybe I will write a separate post about some of the new features.

Stay tuned!