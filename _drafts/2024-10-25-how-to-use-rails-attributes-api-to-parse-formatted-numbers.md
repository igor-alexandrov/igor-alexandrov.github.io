
class Invoice < ApplicationRecord
  # ...

  def total_amount=(value)
    value = (value.present? ? value.gsub(/[^\d.]/, '') : nil)

    super(value)
  end

  # ...
end

class Invoice < ApplicationRecord
  # ...

  # Rails attributes API allows us to define custom types
  attribute :total_amount, DelimitedIntegerType.new

  # ...
end