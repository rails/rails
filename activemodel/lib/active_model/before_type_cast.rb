# frozen_string_literal: true

module ActiveModel
  # This module provides a way to read the value of attributes before type
  # casting and deserialization. It uses ActiveModel::AttributeMethods to define
  # attribute methods with the following suffixes:
  #
  # * +_before_type_cast+
  # * +_for_database+
  # * +_came_from_user?+
  #
  # ==== Examples
  #
  #   class Task
  #     include ActiveModel::Attributes
  #
  #     attribute :completed_at, :datetime
  #   end
  #
  #   task = Task.new
  #   task.completed_at                  # => nil
  #   task.completed_at_before_type_cast # => nil
  #   task.completed_at_for_database     # => nil
  #   task.completed_at_came_from_user?  # => false
  #
  #   task.completed_at = "1999-12-31T23:59:59-0500"
  #   task.completed_at                  # => 1999-12-31 23:59:59 -0500
  #   task.completed_at_before_type_cast # => "1999-12-31T23:59:59-0500"
  #   task.completed_at_for_database     # => 2000-01-01 04:59:59 UTC
  #   task.completed_at_came_from_user?  # => true
  #
  module BeforeTypeCast
    extend ActiveSupport::Concern

    included do
      attribute_method_suffix "_before_type_cast", "_for_database", "_came_from_user?", parameters: false
    end

    # Returns the value of the specified attribute before type casting and
    # deserialization.
    #
    #   class Task
    #     include ActiveModel::Attributes
    #
    #     attribute :completed_at, :datetime
    #   end
    #
    #   task = Task.new
    #   task.completed_at = "1999-12-31T23:59:59-0500"
    #
    #   task.completed_at                                    # => 1999-12-31 23:59:59 -0500
    #   task.read_attribute_before_type_cast("completed_at") # => "1999-12-31T23:59:59-0500"
    #
    def read_attribute_before_type_cast(attribute_name)
      attribute_before_type_cast(self.class.resolve_attribute_name(attribute_name))
    end

    # Returns the value of the specified attribute after serialization.
    #
    #   class Task
    #     include ActiveModel::Attributes
    #
    #     attribute :completed_at, :datetime
    #   end
    #
    #   task = Task.new
    #   task.completed_at = "1999-12-31T23:59:59-0500"
    #
    #   task.completed_at                                # => 1999-12-31 23:59:59 -0500
    #   task.read_attribute_for_database("completed_at") # => 2000-01-01 04:59:59 UTC
    #
    def read_attribute_for_database(attribute_name)
      attribute_for_database(self.class.resolve_attribute_name(attribute_name))
    end

    # Returns a Hash of attributes before type casting and deserialization.
    #
    #   class Task
    #     include ActiveModel::Attributes
    #
    #     attribute :completed_at, :datetime
    #   end
    #
    #   task = Task.new
    #   task.completed_at = "1999-12-31T23:59:59-0500"
    #
    #   task.attributes                  # => {"completed_at"=>1999-12-31 23:59:59 -0500}
    #   task.attributes_before_type_cast # => {"completed_at"=>"1999-12-31T23:59:59-0500"}
    #
    def attributes_before_type_cast
      @attributes.values_before_type_cast
    end

    # Returns a Hash of attributes for persisting.
    #
    #   class Task
    #     include ActiveModel::Attributes
    #
    #     attribute :completed_at, :datetime
    #   end
    #
    #   task = Task.new
    #   task.completed_at = "1999-12-31T23:59:59-0500"
    #
    #   task.attributes              # => {"completed_at"=>1999-12-31 23:59:59 -0500}
    #   task.attributes_for_database # => {"completed_at"=>2000-01-01 04:59:59 UTC}
    #
    def attributes_for_database
      @attributes.values_for_database
    end

    private
      # Dispatch target for <tt>*_before_type_cast</tt> attribute methods.
      def attribute_before_type_cast(attr_name)
        @attributes[attr_name].value_before_type_cast
      end

      # Dispatch target for <tt>*_for_database</tt> attribute methods.
      def attribute_for_database(attr_name)
        @attributes[attr_name].value_for_database
      end

      # Dispatch target for <tt>*_came_from_user?</tt> attribute methods.
      def attribute_came_from_user?(attr_name)
        @attributes[attr_name].came_from_user?
      end
  end
end
