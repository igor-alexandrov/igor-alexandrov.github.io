---
title: Redirect and return in Rails controllers
layout: post
tags:
  - Ruby
  - Rails
  - Today You Learned
featured: false
hidden: false
---

Premature returning from a controller action is a common idiom in Rails applications. I [asked my followers](https://x.com/igor_alexandrov/status/1825463488954741103) in Twitter about whether they know or know how to do this correctly, and I am glad to see that most of them gave the correct answer. Let's dive into the details.

<!--more-->

Before we start, I suggest you to take a look at the post, I mentioned above, to see the answers and to try to solve the problem by yourself. If, for some reason, you can't or don't want to do this, I created a screenshot for you.

{% include image-caption.html imageurl="/assets/images/posts/2024-08-23/twitter-post.jpeg" title="Original Twitter post with answers" caption="Original Twitter post with answers" width="600px" %}

Most of those who votes made the right choice. **Correct answers were options 1 and 2**. I usually use the first one, but the second option was also correct.

To understand why the first and the second options are correct, I recommend you to read [the table of operator precedence in Ruby](https://ruby-doc.com/docs/ProgrammingRuby/language.html#table_18.4).

## && operator in options 2 and 3

Using `&&` in options 2 and 3 is a bit tricky.

``` ruby
redirect_to(sign_in_path) && return
```

In the expression above, `&&` operator get the result of `redirect_to(sign_in_path)` as the left operand and `return` as the right operand. This expression will work correct.

``` ruby
redirect_to sign_in_path && return
```

However, without explicit brackets, `&&` get the result of `sign_in_path` as the left operand and `return` as the right operand. The value of the return keyword is `nil`, so the expression above can be rewritten as:

``` ruby
redirect_to sign_in_path && nil
```

Whatever `&& nil` will return `nil`, and `redirect_to` will be called with `nil` as an argument, which finally will raise an error.

``` ruby
ActionController::ActionControllerError in TimeOffsController#new
Cannot redirect to nil!
```

## Option 4

There was no way to vote for the fourth option directly, but there were a few who said that all options were correct.

``` ruby
def show
  redirect_to sign_in_path unless current_user

  @time_off = current_user.time_offs.find(params[:id])

  render @time_off
end
```

In Rails, `redirect_to` does only sets correct response headers and status code, but it doesn't stop the execution of the action. In the example above, if `current_user` is `nil`, you will face DoubleRenderError.

``` ruby
AbstractController::DoubleRenderError in TimeOffsController#new
Render and/or redirect were called multiple times in this action.
```

## UPD. Difference between `&&` and `and`

Above in the post, I posted the link to the table of operator precedence in Ruby. Both `&&` and `and` are logical operators in Ruby, but they have different precedence, `&&` has higher precedence than `and`. This difference in precedence can lead to unexpected behavior when they are used in complex expressions.

``` ruby
# Using &&
a = true && false
b = false && true

puts a # => false
puts b # => false

# Using and
c = true and false
d = false and true

puts c # => true
puts d # => false
```

Pretty interesting, right?

In the first case `&&`, the assignment happens after evaluating the expression, so `a` and `b` are both assigned the result of the logical operation `false`.

In the second case `and`, the assignment happens before the logical operation because `and` has lower precedence than `=`. So `c` is first assigned true, and then the logical and operation is evaluated, which does not affect the assignment.

Let's take a look at the another example.

``` ruby
# Using &&
a = b = false && true
puts a # => false
puts b # => false

# Using and
c = d = false and true
puts c # => false
puts d # => false
```
With `&&`, both `a` and `b` are assigned the result of `false && true`, which is `false`.
With and, `d = false` is evaluated first (due to and's lower precedence), and then `c = d` is assigned.

You should be careful when using `and` and `&&` in complex expressions. It is better to use `&&` for logical operations, while `and` can be used to control flow.

## Conclusions

Despite the fact my post was about Ruby operator precedence, there were people who suggested that it is better to use `before_action` for such kind of checks. I agree. I will try to be more explicit in my future posts and will provide more context.

Nevertheless, I hope you learned something new. Stay tuned!