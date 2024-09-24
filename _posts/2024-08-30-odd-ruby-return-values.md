---
title: Odd Ruby return values
layout: post
tags:
  - Ruby
  - Rails
  - Today You Learned
featured: false
hidden: false
---

Earlier this week I published a [tweet that made some buzz](https://x.com/igor_alexandrov/status/1827955386365677774) in the community. To be honest, I didn't expect that so many people would be interested in this topic. About 29000 views and 1600 votes is quite an impressive result for 9 lines of code.

<!--more-->

The tweet was about the following code snippet:

``` ruby
class Klass
  def self.square(value)
    if value > 0
      value * value
    end
  end
end

puts Klass.square(0)
```

The question was: what is the result of the `Klass.square(0)` method call?

## TL;DR

The result of the `Klass.square(0)` method call is `nil`. From 1600 votes, about 1500 people gave the correct answer.

## Explanation

Every expression in Ruby has a value.

A conditional statement in Ruby is an expression that returns `nil` if the conditional is `false`. Ruby methods return the last expression in the method body.

So, in the code snippet above, 0 is not greater than 0, so the `if` statement returns `nil`. The `Klass.square` method returns the result of the `if` statement (because it is the last expression), which is `nil`.

Elementary, right? Yes, but since there were about 100 people who gave the wrong answer (0), even such simple things can be tricky and odd.

## More odd examples

In the comments to the tweet, [Lucian Ghinda pointed](https://x.com/lucianghinda/status/1828077212370714890) to a similar, odd example originally [found by Rob Lacey](https://x.com/braindeaf/status/1825482461591024056).

It turns out that local variable assignment in Ruby assigns nil even if the right part of the expression is not defined.

``` ruby
irb(main):001> local_var = undefined_var
(irb):1:in `<main>': undefined local variable or method `undefined_var' for main:Object (NameError)

local_var = undefined_var
            ^^^^^^^^^^^^^
  from /Users/igor/.rbenv/versions/3.2.3/lib/ruby/gems/3.2.0/gems/irb-1.13.2/exe/irb:9:in `<top (required)>'
  from /Users/igor/.rbenv/versions/3.2.3/bin/irb:25:in `load'
  from /Users/igor/.rbenv/versions/3.2.3/bin/irb:25:in `<main>'
irb(main):002> local_var
=> nil
```

To be honest, I didn't know about this behavior before.

## Why do I ask this in interviews?

In my original post, I mentioned that I ask this question in interviews. This triggered a discussion about whether it is a good idea to ask such questions in interviews.

Yes, I believe that at the beginning of your career, it is crucial to understand how the language you are working with works. It is important to know all the nuances and dive as deep as you can. Even if the candidate doesn't know the answer, which is usual and normal in entry-level positions, he can always demonstrate his thinking curve which, start discussion and try to explain the potential behavior. Focusing on how a candidate thinks and approaches problems can reveal a lot about their potential and willingness to learn, which is especially important early in their careers.

## Conclusions

Today you learned, or, I hope, you remembered, that every expression in Ruby has a value. Conditional statements in Ruby are expressions that return `nil` if the conditional is `false`.
