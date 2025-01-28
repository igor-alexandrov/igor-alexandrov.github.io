---
title: Rails String#upcase_first VS capitalize and titleize
layout: post
tags:
  - Rails
  - Ruby
  - Today You Learned
featured: false
hidden: false
---

What comes in your mind when you have a task to make the first letter of a string uppercase? You might think about using `capitalize` method, or `titleize` method.

In one of my recent projects, we've been asked to ensure first capital letter in first and last name of a user. Sounds simple right? We've used Rails 7.1 normalization API together with `String#titleize`.

<!--more-->

```ruby
normalizes :first_name, with: ->(value) { value.capitalize }
normalizes :last_name, with: ->(value) { value.capitalize }
```

This worked well until we've got a user with a last name written like `mcCartney`. The result was not as expected, as well as the result of `String#titleize` method.

```ruby
"mcCartney".titleize # => "Mc Cartney"
"mcCartney".capitalize # => "Mccartney"
```

The good news is that Rails has a solution for almost every problem, you just should know about them. In this case, the solution is `String#upcase_first` method, that has been [introduced in Rails 5.0](https://github.com/rails/rails/blob/5-0-stable/activesupport/CHANGELOG.md).

```ruby
"mcCartney".upcase_first # => "McCartney"
```

To make everything clear, let's take a look at the source code of these methods. I will start with `titleize`. For Rails 7.1, you can find the source code [here](https://github.com/rails/rails/blob/v7.1.0/activesupport/lib/active_support/inflector/methods.rb#L192).

```ruby
# activesupport/lib/active_support/inflector/methods.rb
def titleize(word, keep_id_suffix: false)
  humanize(underscore(word), keep_id_suffix: keep_id_suffix).gsub(/\b(?<!\w['’`()])[a-z]/) do |match|
    match.capitalize
  end
end
```

The key part of this method is the `gsub` call with regex pattern. This pattern is used to match lowercase letters at the beginning of words, except when those letters are preceded by a word character followed by punctuation like an apostrophe or parentheses.

`String#capitalize` method is a part of Ruby core library, so its source code is written in C. You can find it [here](https://github.com/ruby/ruby/blob/v3_3_0/string.c#L7718). Intead of pasting C code here, I will show you the implementation of this method [from a Crystal language](https://github.com/crystal-lang/crystal/blob/1.12.0/src/string.cr#L1469), that is very readable for Ruby developers. The method is a bit more complex than `titleize`, but it's still simple. It returns a new `String` with the first letter converted to uppercase and every subsequent letter converted to lowercase.

```crystal
def capitalize(options : Unicode::CaseOptions = :none) : String
  return self if empty?

  if single_byte_optimizable? && (options.none? || options.ascii?)
    return String.new(bytesize) do |buffer|
      bytesize.times do |i|
        byte = to_unsafe[i]

        buffer[i] = if byte >= 0x80
                      byte
                    elsif i.zero?
                      byte.unsafe_chr.upcase.ord.to_u8!
                    else
                      byte.unsafe_chr.downcase.ord.to_u8!
                    end
      end
      {@bytesize, @length}
    end
  end

  String.build(bytesize) { |io| capitalize io, options }
end
```

And finally, the implementation of `upcase_first` method.

```ruby
# activesupport/lib/active_support/inflector/methods.rb
def upcase_first(string)
  string.length > 0 ? string[0].upcase.concat(string[1..-1]) : +""
end
```

As you can see, `upcase_first` method is the simplest one. It just returns a new string with the first letter converted to uppercase and the rest of the string remains the same.

To finalize this post, I want to show you the performance comparison of these methods. I've created a simple benchmark that compares the performance of `titleize`, `capitalize`, and `upcase_first` methods. The result is quite predictable, `upcase_first` and `capitalize` are the fastest, and `titleize` is the slowest one. The difference is significant and you should know about it when you have to deal with a large amount of data.

``` ruby
# demos/titleize_capitalize_upcase_first.rb
require 'benchmark'
require 'active_support/core_ext/string/inflections'

n = 100_000

Benchmark.bm(20) do |x|
  x.report("#titleize") do
    n.times { "mcCartney".titleize }
  end

  x.report("#capitalize") do
    n.times { "mcCartney".capitalize }
  end

  x.report("#upcase_first") do
    n.times { "mcCartney".upcase_first }
  end
end
```

``` bash
➜  igor-alexandrov.github.io git:(main) ✗ ruby demos/titleize_capitalize_upcase_first.rb
                           user     system      total        real
#titleize              0.572192   0.004364   0.576556 (  0.578087)
#capitalize            0.017191   0.000084   0.017275 (  0.017498)
#upcase_first          0.021698   0.000100   0.021798 (  0.021906)
```

## Today you learned

There are at least three options to make the first letter of a string uppercase in Rails. They are similar to each other, but have different implementations and performance characteristics. Stay tuned!
