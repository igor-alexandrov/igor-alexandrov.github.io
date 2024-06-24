---
title: Override accepts_nested_attributes in Rails
layout: post
tags:
  - Rails
  - Ruby
  - Today You Learned
featured: false
hidden: false
---

Among other great features of ActiveRecord in Rails, I find `accepts_nested_attributes_for` is one of the most useful. It was introduced in [Rails 2.3](https://guides.rubyonrails.org/2_3_release_notes.html#nested-attributes) and allows you to save attributes on associated records through the parent.

If you are not familiar with `accepts_nested_attributes_for` method, I suggest you read the [official documentation](https://api.rubyonrails.org/classes/ActiveRecord/NestedAttributes/ClassMethods.html) before reading this article.

There are some options that you can pass to `accepts_nested_attributes_for` method. Lets quickly go through them.

1. `:update_only` - If you want to update the existing record only and not create new one, you can pass `update_only: true` to the method. This works only for one-to-one association.

2. `:reject_if` - You can pass a proc to `:reject_if` option to reject the nested attributes if they don't meet the criteria. For example, if you want to reject the nested attributes if the `name` attribute is blank, you can do it like this:

```ruby
accepts_nested_attributes_for :comments, reject_if: proc { |attributes| attributes['name'].blank? }
```

3. `:allow_destroy` - If you want to destroy the associated record by passing `_destroy: 1` in the nested attributes, you can pass `allow_destroy: true` to the method.

4. `:limit` - If you want to limit the number of nested attributes that can be submitted.

But what if you want to want to identify the nested model by some other attribute than `id`? Let me show you an example.

```ruby
# app/models/work.rb
class Work < ApplicationRecord
  belongs_to :inventory, autosave: true

  accepts_nested_attributes_for :inventory
end

# app/models/inventory.rb
class Inventory < ApplicationRecord
  belongs_to :work

  validates :barcode_data, uniqueness: true, allow_blank: true
end

# == Schema Information
#
# Table name: inventories
#
#  id                    :bigint           not null, primary key
#  barcode_data          :string
#
# Indexes
#
#  index_inventories_on_barcode_data       (barcode_data) UNIQUE
```

Example above consists of two models where `Work` has an `Inventory`. Inventory model has a `barcode_data` column which is unique, but can be blank. To make this example easier, I didn't include other `Inventory` attributes, some of them can also can identify it. There are also tables and models to track barcode history, but they are also not relevant to this example.

Now, I want to create a new work with inventory and `barcode_data`. Below is the list of params that will be passed to `Work.create` method.

```ruby
{
  work: {
    inventory_attributes: {
      barcode_data: '1234567890'
    }
  }
}
```

For the first time, when the barcode is not present in the database, it will create a new barcode record with `data: '1234567890'`. When I pass the same set of params again to `Work.create` method I will get a `ActiveRecord::RecordNotUnique` error because the inventory with `barcode_data: '1234567890'` already exists in the database, which makes total sense because `accepts_nested_attributes_for` uses `id` to identify the persisted nested model.

Instead of getting error I want to find the existing inventory record by `barcode_data` and update it. To achieve this, I need to override the `inventory_attributes=` method in the `Work` model.

```ruby
# app/models/work.rb

class Work < ApplicationRecord
  belongs_to :inventory, autosave: true

  accepts_nested_attributes_for :inventory

  def inventory_attributes=(inventory_attributes)
    barcode_data = inventory_attributes["barcode_data"]

    if (inventory = Inventory.find_by(barcode_data: barcode_data))
      self.inventory = inventory
    else
      self.build_inventory
    end

    self.inventory.assign_attributes(inventory_attributes)
  end
end
```

That's it. Now, when I pass the same set of params to `Work.create` method, it will find the existing inventory record by `barcode_data` and update it.

## Today you learned

**Almost every internal, built-in feature on Rails can be overriden.** And, yes, don't do this unless you really need it, usually there is a way to achieve the desired behavior without overriding. But, if you need to hack – do it, but remember to test it properly.