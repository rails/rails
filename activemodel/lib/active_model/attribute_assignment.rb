# frozen_string_literal: true

require "active_support/core_ext/hash/keys"

module ActiveModel
  module AttributeAssignment
    include ActiveModel::ForbiddenAttributesProtection

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

    # Like `BasicObject#method_missing`, `#attribute_writer_missing` is invoked
    # when `#assign_attributes` is passed an unknown attribute name.
    #
    # By default, `#attribute_writer_missing` raises an UnknownAttributeError.
    #
    #   class Rectangle
    #     include ActiveModel::AttributeAssignment
    #
    #     attr_accessor :length, :width
    #
    #     def attribute_writer_missing(name, value)
    #       Rails.logger.warn "Tried to assign to unknown attribute #{name}"
    #     end
    #   end
    #
    #   rectangle = Rectangle.new
    #   rectangle.assign_attributes(height: 10) # => Logs "Tried to assign to unknown attribute 'height'"
    def attribute_writer_missing(name, value)
      raise UnknownAttributeError.new(self, name)
    end

    private
      def _assign_attributes(attributes)
        attributes.each_pair do |k, v|
          _assign_attribute(k, v)
        end
      end

      def _assign_attribute(k, v)
        setter = :"#{k}="
        public_send(setter, v)
      rescue NoMethodError
        if respond_to?(setter)
          raise
        else
          attribute_writer_missing(k.to_s, v)
        end
      end
  end
end
