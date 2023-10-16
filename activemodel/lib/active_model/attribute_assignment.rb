# frozen_string_literal: true

require "active_support/core_ext/hash/keys"

module ActiveModel
  module AttributeAssignment
    include ActiveModel::ForbiddenAttributesProtection

    def self.included(base)
      base.extend ClassMethods
    end

    module ClassMethods
      # Builds an object (or multiple objects) and returns either the built object or a list of built
      # objects.
      #
      # The +attributes+ parameter can be either a Hash or an Array of Hashes. These Hashes describe the
      # attributes on the objects that are to be built.
      #
      # ==== Examples
      #   # Build a single new object
      #   User.build(first_name: 'Jamie')
      #
      #   # Build an Array of new objects
      #   User.build([{ first_name: 'Jamie' }, { first_name: 'Jeremy' }])
      #
      #   # Build a single object and pass it into a block to set other attributes.
      #   User.build(first_name: 'Jamie') do |u|
      #     u.is_admin = false
      #   end
      #
      #   # Building an Array of new objects using a block, where the block is executed for each object:
      #   User.build([{ first_name: 'Jamie' }, { first_name: 'Jeremy' }]) do |u|
      #     u.is_admin = false
      #   end
      def build(attributes = nil, &block)
        if attributes.is_a?(Array)
          attributes.collect { |attr| build(attr, &block) }
        else
          new(attributes, &block)
        end
      end
    end

    # Allows you to set all the attributes by passing in a hash of attributes with
    # keys matching the attribute names.
    #
    # If the passed hash responds to <tt>permitted?</tt> method and the return value
    # of this method is +false+ an ActiveModel::ForbiddenAttributesError
    # exception is raised.
    #
    #   class Cat
    #     include ActiveModel::AttributeAssignment
    #     attr_accessor :name, :status
    #   end
    #
    #   cat = Cat.new
    #   cat.assign_attributes(name: "Gorby", status: "yawning")
    #   cat.name # => 'Gorby'
    #   cat.status # => 'yawning'
    #   cat.assign_attributes(status: "sleeping")
    #   cat.name # => 'Gorby'
    #   cat.status # => 'sleeping'
    def assign_attributes(new_attributes)
      unless new_attributes.respond_to?(:each_pair)
        raise ArgumentError, "When assigning attributes, you must pass a hash as an argument, #{new_attributes.class} passed."
      end
      return if new_attributes.empty?

      _assign_attributes(sanitize_for_mass_assignment(new_attributes))
    end

    alias attributes= assign_attributes

    private
      def _assign_attributes(attributes)
        attributes.each do |k, v|
          _assign_attribute(k, v)
        end
      end

      def _assign_attribute(k, v)
        setter = :"#{k}="
        if respond_to?(setter)
          public_send(setter, v)
        else
          raise UnknownAttributeError.new(self, k.to_s)
        end
      end
  end
end
