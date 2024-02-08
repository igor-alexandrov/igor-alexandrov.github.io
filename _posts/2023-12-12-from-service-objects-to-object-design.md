---
title: From Service Objects to Object Design
layout: post
tags:
  - Ruby
  - Software-Design
  - Object-Oriented-Programming
featured: false
hidden: false
---

As technology evolves and our understanding of scalable and maintainable code deepens, optimizing software architecture becomes paramount. In the realm of Ruby programming, the concept of Service Objects has long been a cornerstone in managing complex business logic. A couple of days ago, I got an email from OneTribe’s AppSignal that included information about the issue that I already have seen several times and didn’t have enough time and willingness to work on it.

<!--more-->

## TL;DR;

Service objects were discussed many times by several authors. Usually, they are a code smell, and I will not try to explain why again. I will show a practical example of refactoring a service object into an object-orientated code.

I will not try to blame anybody; probably, it was me who clicked the “Approve” button on the PR that introduced the code listed below. Anyway, I believe it is always better to return and work on your mistakes.

## The sign of the poor design

The issue was relatively small and easy. OneTribe integrates with Slack, which includes a status change feature: when somebody takes time off, Slack user status will be updated with an emoji and text accordingly.

Besides having a OneTribe application for production, we have another one – that is used for development and testing; since it is not published, it works only with our workspace, and its tokens are getting revoked every X months (I don’t remember exactly), which causes an exception when we try to use revoked token for API calls. This exception is not handled anyhow and is raised directly to AppSignal.

Below is the excerpt from the code that caused the `Slack::Web::Api::Errors::TokenRevoked` exception. TimeOff class implements a time off object and has different states, and the day it starts, it becomes a “current” time off; at the beginning of this day (for the user's time zone), we update the user Slack status.

<pre><code class="language-ruby">
# app/workers/time_off/starts_today_worker.rb

class TimeOff::StartTodayWorker
  include ApplicationWorker

  urgency :low
  sidekiq_options retry: false

  def perform
    timezones = Utils::TimeZone.all_for_hour(8)
    dates = Utils::TimeZone.dates_in_timezones(8)

    return if timezones.blank?

    TimeOff
      .approved
      .starts_on(dates)
      .member_timezone_in(timezones)
      .find_each do |time_off|
        time_off.deliver_start_today_notification
        time_off.change_slack_status
      end
  end
end


# app/models/time_off.rb
class TimeOff < ApplicationRecord
  # ...

	def change_slack_status
    if slack_authorization.present? && (type.status_text.present? || type.status_emoji.present?)
      ::Slack::StatusChangeService.new(authorization: slack_authorization).call(
        status: type.status_text,
        emoji: type.status_emoji,
        expiration: member.time_in_timezone(end_date + 1.day).to_i
      )
    end
  end
end
```
</code></pre>

What is wrong with this code? Method `change_slack_status` is defined in `TimeOff` class. What does it mean? What Slack status did it change? The body of the method also asks a lot of questions. What is `slack_authorization`, and why is it an attribute or a method of `TimeOff` instance?

Where should I put the rescue block for `Slack::Web::Api::Errors::TokenRevoked` exception? To the `TimeOff` class? And what this rescue block should do? It should probably nilify the token that has been used for API calls. But the token belongs to the user, not the the time off. It would be weird to remove associations from the user in the rescue block inside `TimeOff` class (this will violate the [Law of Demeter](https://avdi.codes/demeter-its-not-just-a-good-idea-its-the-law/#demeter)).

But the biggest question goes to the `Slack::StatusChangeService` object.

## Service Objects in Ruby

The strengths of object-oriented programming lie in its capacity to imbue objects with both behavior and data, thereby equipping them with potent functionalities. Additionally, this approach facilitates a more coherent alignment of objects with the underlying concepts in the domain model, resulting in more easily understandable code for developers.

<pre><code class="language-ruby">
# app/services/slack/status_change_service.rb

class Slack::StatusChangeService
  extend Dry::Initializer[undefined: false]

  option :authorization

  def call(status:, emoji:, expiration:)
    client.users_profile_set(profile: profile_params(status, emoji, expiration))
  end

  protected

  def client
    @client ||= ::Slack::Web::Client.new(token: authorization.payload['authed_user']['access_token'])
  end

  def profile_params(status, emoji, expiration)
    params = {
      status_text: status,
      status_emoji: emoji,
      status_expiration: expiration
    }

    params.to_json
  end
end
</code></pre>

Service objects deprive us of these advantages and may lead to other code problems.

1. **Potential for God Objects**: Service objects can evolve into "God objects" aware of too many aspects of the system, leading to tightly coupled code that's hard to extend or modify without affecting other parts of the application.
2. **Obfuscation of Business Logic**: In some instances, excessive use of service objects can scatter the business logic across multiple small classes, making it hard to comprehend the entire flow of the application.
3. **Maintenance Overhead**: When a codebase is riddled with numerous service objects, maintaining, updating, and debugging them can become challenging. This can increase the cognitive load for developers trying to understand the code.
4. **Reduced Readability and Discoverability**: An abundance of service objects might make it difficult for new project developers to understand where to find specific functionality, affecting code discoverability and readability.

## Refactoring

My approach to refactoring involves identifying distinct responsibilities within the service object and extracting them into separate classes or modules. The class above implements a request to Slack API to change member status – icon and text shown next to the member name. OneTribe uses it to notify team members about current timeoffs visually.

What objects are we working with? Time off is the most obvious, and we already know about it. Time off belongs to Member, which represents a user from the company and has already been implemented. However, there is one more type that has been missed – SlackStatus. Let's try to implement it.

<pre><code class="language-ruby">
# app/lib/member/slack_status.rb

# Value object that represents a Slack status to be set for a member.
class Member::SlackStatus < Data.define(:status_text, :status_emoji, :status_expiration)
  def initialize(status_text:, status_emoji:, status_expiration: nil)
    super
  end

  def as_json
    {
      status_text: status_text,
      status_emoji: status_emoji,
      status_expiration: status_expiration
    }.compact
  end
end
</code></pre>

Now, we can return the correct status from the TimeOff class.

<pre><code class="language-ruby">
# app/models/time_off.rb

class TimeOff < ApplciationRecord
  # ...

  def slack_status
    if type.status_text.present? || type.status_emoji.present?
      Member::SlackStatus.new(
        status_text: type.status_text,
        status_emoji: type.status_emoji,
        status_expiration: member.time_in_timezone(end_date + 1.day).to_i
      )
    end
  end
end
</code></pre>

So instead of `TimeOff#change_slack_status` that changes somebody’s Slack status, we got `TimeOff#slack_status` that returns the `Member::SlackStatus` of the selected time off or nil. Now `TimeOff#slack_status` deals with `TimeOff` (self), `Member::SlackStatus` and `NilClass`. We can eliminate nil values entirely. Let’s rewrite the code above.

<pre><code class="language-ruby">
# app/lib/member/slack_status.rb

# Value object that represents a Slack status to be set for a member.
# It is used in TimeOff::StartTodayWorker to set the status for a member that has a time off starting today.
class Member::SlackStatus < Data.define(:status_text, :status_emoji, :status_expiration)
  def initialize(status_text:, status_emoji:, status_expiration: nil)
    super(
      status_text: status_text || OneTribe::EMPTY_STRING,
      status_emoji: status_emoji || OneTribe::EMPTY_STRING,
      status_expiration: status_expiration
    )
  end

  # Initialize new Member::SlackStatus we empty string status_text and status_emoji.
  def self.default
    new(status_text: OneTribe::EMPTY_STRING, status_emoji: OneTribe::EMPTY_STRING)
  end

  def ==(other)
    (status_text == other.status_text) && (status_emoji == other.status_emoji)
  end

  def default?
    self == self.class.default
  end

  def as_json
    {
      status_text: status_text,
      status_emoji: status_emoji,
      status_expiration: status_expiration
    }.compact
  end
end
</code></pre>

With this final edits, we can simplify `TimeOff#slack_status`.

<pre><code class="language-ruby">
# app/models/time_off.rb

class TimeOff < ApplciationRecord
  # ...

  def slack_status
    Member::SlackStatus.new(
      status_text: type.status_text,
      status_emoji: type.status_emoji,
      status_expiration: member.time_in_timezone(end_date + 1.day).to_i
    )
  end
end
</code></pre>

Finally, we can implement status change methods in the `Member` class.

<pre><code class="language-ruby">
# app/models/member.rb

class Member < ApplicationRecord
  # ...

  def set_slack_status(status, force: false)
    return unless slack_client
    return if status.default? && !force

    slack_client.users_profile_set(profile: status.to_json)
  rescue Slack::Web::Api::Errors::TokenRevoked => _e
    slack_authorization.destroy!

    false
  end

  def reset_slack_status
    set_slack_status(Member::SlackStatus.default, force: true)
  end

	# ...

	private

  def slack_client
    if slack_authorization
      ::Slack::Web::Client.new(
        token: slack_authorization.payload['authed_user']['access_token']
      )
    end
  end
end
</code></pre>

The final change will be in a worker that has already been seen at the beginning of this text.

<pre><code class="language-ruby">
# app/workers/time_off/starts_today_worker.rb

class TimeOff::StartTodayWorker
  # ...

  def perform
    timezones = Utils::TimeZone.all_for_hour(8)
    dates = Utils::TimeZone.dates_in_timezones(8)

    return if timezones.blank?

    TimeOff
      .approved
      .starts_on(dates)
      .member_timezone_in(timezones)
      .find_each do |time_off|
        time_off.deliver_start_today_notification
        time_off.member.set_slack_status(time_off.slack_status)
      end
  end
end
</code></pre>

Let’s go through the list of changes that were made:

- We’ve implemented the new type – `Member::SlackStatus` , which is now used only to represent the status created from the time off. However, it does not matter which part of the system instantiates this object; it will still be relevant.
- `Slack::StatusChangeService` has been removed. The most significant and visible change is removing a part of the code that does not follow object-orientated principles and guidelines.
- The code that has been used to change the status has been moved from the `TimeOff` class to `Member`; now, this part of the code follows the Law of Demeter.
- Last, I’ve managed to fix the issue with revoked Slack tokens.

## Conclusions

In conclusion, refactoring service objects in Ruby presents a crucial opportunity to enhance a codebase's maintainability, scalability, and overall quality. Through careful analysis and thoughtful restructuring, developers can effectively break down monolithic service objects into smaller, more focused classes or modules. This process allows for better adherence to the Single Responsibility Principle (SRP), improving code readability and facilitating more straightforward maintenance.

Keeping it simple often works wonders!
