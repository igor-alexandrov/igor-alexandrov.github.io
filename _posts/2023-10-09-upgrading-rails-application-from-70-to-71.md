---
title: Upgrading Rails application from 7.0 to 7.1
layout: post
---

On October 5th, Rails 7.1 has been released. In this article, I will show you how I upgraded one of our projects, OneTribe (https://onetribe.team/), to the new major release within one day of my holidays.

Prerequisites
OneTribe runs Ruby 3.2.2 and Rails 7.0.7, we host code on a GitHub and deploy with GitHub Actions and Kamal. I showed how to do this in my previous article: https://jetrockets.com/blog/how-to-use-basecamp-s-kamal-with-aws-and-github.

{% include image-caption.html imageurl="/assets/images/posts/2023-10-09/1.png" title="OneTribe master git branch" caption="OneTribe master git branch" %}
# Dependencies Update
I started with upgrading rails in application Gemfile.

<pre class="language-ruby"><code>
# Gemfile
gem 'pg_party'

# ...

gem 'rails', '~> 7.1.0'
gem 'rails-i18n'
</code></pre>

After this you can try to run `bundle update rails` and depending from your other dependencies it will either success or failure. It my case it failed, because `pg_party` does not support Rails 7.1 yet. The good news is that Ryan (author and maintainer of PgParty) with help of me and one more developer [managed to add support for AR 7.1](https://github.com/rkrage/pg_party/pull/79) within one evening, but didn’t release the new version of the gem yet, so I am gonna to take the code from the `main` branch.

<pre class="language-ruby"><code>
# Gemfile
gem 'pg_party', github: 'rkrage/pg_party'
</code></pre>

After solving issue with PgParty bundle succeeded. I was almost sure that application is ready for the next phase of update, but remembered that Rails 7.1 introduced composite primary keys for ActiveRecord support out of the box (you can find full list of new features and improvements [here](https://rubyonrails.org/2023/10/5/Rails-7-1-0-has-been-released)).

In OneTribe we’ve used the gem called `composite_primary_keys` (https://github.com/composite-primary-keys/composite_primary_keys). It was rather easy, I replaced `self.primary_keys = <array>` call with `self.primary_key = <array>` and removed `composite_primary_keys` from application bundle.

<pre class="language-ruby"><code>
class TimeTracking::Entry < TimeTrackingRecord
	# with composite_primary_keys
	# self.primary_keys = :id, :date

	# with ActiveRecord 7.1
  self.primary_key = [:id, :date]

  range_partition_by :date
	
	# ...
end
</code></pre>

After this, I updated Sidekiq to 6.5.11, [which added support to Rails 7.1](https://github.com/sidekiq/sidekiq/blob/v6.5.11/Changes.md#6511), and tried to start the application. However, I got an error.

{% include image-caption.html imageurl="/assets/images/posts/2023-10-09/2.png" title="ActionText Rails 7.1 error" caption="ActionText Rails 7.1 error" %}

ActionText in Rails 7.1 introduced a new HTML 5 sanitizer, which is now default and falls back to HTML 4. As a result of this change, `ActionText::ContentHelper.allowed_tags` and `.allowed_attributes` are applied at runtime and return nil during application load.

In our case, I don’t need additional tags to be added to ActionText allowed tags configuration, and I removed the initializer.

I ran the application test suit, and all specs passed successfully, meaning I can start `rails app:update`.

# Application Configuration Update

Rails has a special task `rails app:update` that can help you to update application configuration in an interactive mode. I use VS Code for development and wanted to use its merge tool, so I specified THOR_MERGE constant before running the command `THOR_MERGE="code --wait" ./bin/rails app:update` and used merge tool to track changes over files.

One notable change in 7.1 release is that `config.cache_classes` option [has been replaced](https://github.com/rails/rails/pull/44870) with `config.enable_reloading` that has inverted meaning. Both options will still work for backward compatibility, but I suggest to replace `config.cache_classes = false` with `config.enable_reloading = true` in environments configuration files.

Another new configuration option of Rails 7.1 is `config.action_controller.raise_on_missing_callback_actions` . I always try to reduce the number of callbacks used in controllers, since they can be extremely hard to maintain. However there may be situations when controller callbacks fit well (e.g. authorization check). Conditional callbacks are even a bigger hell. Before Rails 7.1 if you defined a condition with `only` or `except` option for an action that does not exist, Rails would say you nothing. Now, you can set `config.action_controller.raise_on_missing_callback_actions=true` for test and development environments and Rails will raise an exception. You can read more info in railties changelog: [https://github.com/rails/rails/blob/7-1-stable/railties/CHANGELOG.md](https://github.com/rails/rails/blob/7-1-stable/railties/CHANGELOG.md).

In my Kamal guide I showed how to create initializer, which will deal with a load balancer that terminates SSL (e.g. AWS ALB). Rails 7.1 `config.assume_ssl=true` option. This means that in environments that work behind load balancer (usually production, staging, etc) you have to enable it and delete initializer that you used in Rails 7.0.

<pre class="language-ruby"><code>
# config/environments/production.rb

# Assume all access to the app is happening through a SSL-terminating reverse proxy.
# Can be used together with config.force_ssl for Strict-Transport-Security and secure cookies.
config.assume_ssl = true

# Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
config.force_ssl = false
</code></pre>

After you merge all your configuration files and the interactive tool is finished, some tweaks can still be done.

First of all, you may notice that you will have a new file in your code base called `new_framework_defaults_7_1.rb`. It contains all Rails 7.1 default params commented, so you can enable them one by one. Another option is to change `config.load_defaults` in `config/application.rb` file to have 7.1 value and delete `new_framework_defaults_7_1.rb` , this will enable all options at once.

The last, but not the least is `config.autoload_lib` option. Before 7.1 you probably had something similar to the code below in your application that uses Zeitwerk.

<pre class="language-ruby"><code>
# config/application.rb

module OneTribe
  class Application < Rails::Application
    config.eager_load_paths << config.root.join("lib")

    Rails.autoloaders.main.ignore(
      config.root.join("lib").join("assets"),
      config.root.join("lib").join("tasks"),
      config.root.join("lib").join("middleware"),
    )

    # ...
  end
end
</code></pre>

The code above added `lib` folder to both eager load and autoload paths and excluded from autoload paths from lib that didn’t contain Ruby code or should not be reloaded or eager-loaded.

With Rails 7.1 and `config.autoload_lib` everything becomes easier. You just tell Rails to autoload everything in `lib` and provide a list of folders that should not be reloaded and eager-loaded.

<pre class="language-ruby"><code>
# config/application.rb

module OneTribe
  class Application < Rails::Application

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks middleware])

		# ...
  end
end
</code></pre>

Thats all. I reran my specs to ensure I didn’t break anything. Of course, I ran Rubocop to ensure all the changes fit the code style, created PR, and successfully upgraded OneTribe to the new Rails version.

# Conclusions

Rails 7.1 gives you many new features and abilities [https://rubyonrails.org/2023/10/5/Rails-7-1-0-has-been-released](https://rubyonrails.org/2023/10/5/Rails-7-1-0-has-been-released), but as usual, the upgrading process is smooth and straightforward.

Thanks to all the contributors, the core team, and those who tested release candidate and beta builds!
longreads
