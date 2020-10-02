# frozen_string_literal: true

class Topic
  include ActiveModel::Validations
  include ActiveModel::Validations::Callbacks
  include ActiveModel::AttributeMethods
  include ActiveSupport::NumberHelper

  attribute_method_suffix "_before_type_cast"
  define_attribute_method :price

  def self._validates_default_keys
    super | [ :message ]
  end

  attr_accessor :title, :author_name, :content, :approved, :created_at
  attr_accessor :after_validation_performed
  attr_writer :price

  after_validation :perform_after_validation

  def initialize(attributes = {})
    attributes.each do |key, value|
      send "#{key}=", value
    end
  end

  def condition_is_true
    true
  end

  def condition_is_false
    false
  end

  def perform_after_validation
    self.after_validation_performed = true
  end

  def my_validation
    errors.add :title, "is missing" unless title
  end

  def my_validation_with_arg(attr)
    errors.add attr, "is missing" unless send(attr)
  end

  def price
    number_to_currency @price
  end

  def attribute_before_type_cast(attr)
    instance_variable_get(:"@#{attr}")
  end

  private

    def five
      5
    end
end
