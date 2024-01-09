# frozen_string_literal: true

require "active_support/attribute_methods"

module ActiveModel
  # Raised when an attribute is not defined.
  #
  #   class User < ActiveRecord::Base
  #     has_many :pets
  #   end
  #
  #   user = User.first
  #   user.pets.select(:id).first.user_id
  #   # => ActiveModel::MissingAttributeError: missing attribute 'user_id' for Pet
  class MissingAttributeError < NoMethodError
  end

  # = Active \Model \Attribute \Methods
  #
  # Provides a way to add prefixes and suffixes to your methods as
  # well as handling the creation of ActiveRecord::Base - like
  # class methods such as +table_name+.
  #
  # The requirements to implement +ActiveModel::AttributeMethods+ are to:
  #
  # * <tt>include ActiveModel::AttributeMethods</tt> in your class.
  # * Call each of its methods you want to add, such as +attribute_method_suffix+
  #   or +attribute_method_prefix+.
  # * Call +define_attribute_methods+ after the other methods are called.
  # * Define the various generic +_attribute+ methods that you have declared.
  # * Define an +attributes+ method which returns a hash with each
  #   attribute name in your model as hash key and the attribute value as hash value.
  #   Hash keys must be strings.
  #
  # A minimal implementation could be:
  #
  #   class Person
  #     include ActiveModel::AttributeMethods
  #
  #     attribute_method_affix  prefix: 'reset_', suffix: '_to_default!'
  #     attribute_method_suffix '_contrived?'
  #     attribute_method_prefix 'clear_'
  #     define_attribute_methods :name
  #
  #     attr_accessor :name
  #
  #     def attributes
  #       { 'name' => @name }
  #     end
  #
  #     private
  #       def attribute_contrived?(attr)
  #         true
  #       end
  #
  #       def clear_attribute(attr)
  #         send("#{attr}=", nil)
  #       end
  #
  #       def reset_attribute_to_default!(attr)
  #         send("#{attr}=", 'Default Name')
  #       end
  #   end
  module AttributeMethods
    extend ActiveSupport::Concern

    AttrNames = ActiveSupport::AttributeMethods::AttrNames

    included do
      include ActiveSupport::AttributeMethods

      self.missing_attribute_error_class = ActiveModel::MissingAttributeError
    end
  end
end
