---
title: Validate belongs_to association in Rails
layout: post
tags:
  - Rails
  - Ruby
  - Today You Learned
featured: false
hidden: false
---

Eight years ago, Rails 5 made the `belongs_to` association required by default. This solved a lot of problems with orphaned records in the database. But sometimes, you need to have an optional association, which may lead to situations that you don't expect.

<!--more-->

First of all, yes, having an optional `belongs_to` brings denormalization to the database, but sometimes, it's necessary. But besides denormalization, association validation can introduce bugs into your application. Let's see how to validate an association in Rails. Let's look at the example below.

```ruby
# app/models/work/delivery.rb
class Work::Delivery < ApplicationRecord
  # ...

  belongs_to :inventory, optional: true

  with_options if: -> { equipment? } do
    validates :inventory_id, presence: true
  end

  # == Schema Information
  #
  # Table name: work_deliveries
  #
  #  id                  :bigint           not null, primary key
  #  type                :string           not null
  #  ppe_items           :jsonb            not null
  #  inventory_id        :bigint
  #  created_at          :datetime         not null
  #  updated_at          :datetime         not null
  #
  # Indexes
  #
  #  index_work_deliveries_on_inventory_id         (inventory_id)
  #
  # Foreign Keys
  #  fk_rails_87309fb446  (inventory_id => inventories.id)
  #
end

# app/models/inventory.rb
class Inventory < ApplicationRecord
  has_many :work_deliveries, class_name: 'Work::Delivery'

  # ...
end
```

In the example above, we have a `Work::Delivery` model that has an optional association with `Inventory`. But if the `Work::Delivery` is of type `equipment` the `inventory` should be present. To achieve this the author of the code used the `with_options` method to validate the `inventory_id` only if the `equipment?` method returns `true`.

Those, who start using Rails don't see any problem with this code. Presence of the `inventory_id` is validated when needed. The problem is that the author validated presence of the model attribute, not the association. And this can lead to bugs in the application.

Let me give you an example.

``` ruby
# factories.rb
factory :inventory do
  # ...
end

factory :work_delivery, class_name: "Work::Delivery" do
  # ...

  trait :equipment do
    type { "equipment" }
    inventory
  end
end
```

The factory looks correct, let's try to build the `Work::Delivery` with the `:equipment` trait.

``` ruby
delivery = FactoryBot.build(:work_delivery, :equipment)
delivery.valid? # => false
delivery.errors.full_messages # => ["Inventory must exist"]
delivery.inventory # => Inventory
```

The `inventory` association is created, but the `delivery` is not valid. The error message is `Inventory must exist`. But the `inventory` association is present. Wow, what's going on?

The problem is that instead of validating the `inventory` association the code validates the `inventory_id`. And the `inventory_id` is not present.

## Today you learned

When you validate associations in Rails – **always validate the association, not the foreign key**.

```ruby
# app/models/work/delivery.rb
class Work::Delivery < ApplicationRecord
  # ...

  belongs_to :inventory, optional: true

  with_options if: -> { equipment? } do
    validates :inventory, presence: true
  end
end
```
