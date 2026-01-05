# frozen_string_literal: true

module ActiveModel
  # = Active \Model \Inspection
  #
  # Provides a human-readable representation of your model instances through
  # the +inspect+ and +pretty_print+ methods.
  #
  # This module requires that the including class has an +@attributes+ instance
  # variable (as provided by ActiveModel::Attributes) and responds to
  # +attribute_names+.
  #
  # == Configuration
  #
  # The inspection output can be customized through two class attributes:
  #
  # * +filter_attributes+ - An array of attribute names whose values should be
  #   masked in the output. Useful for sensitive data like passwords.
  #
  # * +attributes_for_inspect+ - An array of attribute names to include in
  #   the output, or +:all+ to show all attributes (default).
  #
  # == Example
  #
  #   class Person
  #     include ActiveModel::Model
  #     include ActiveModel::Attributes
  #
  #     attribute :name, :string
  #     attribute :age, :integer
  #     attribute :password, :string
  #   end
  #
  #   person = Person.new(name: "Alice", age: 30, password: "secret")
  #   person.inspect
  #   # => "#<Person name: \"Alice\", age: 30, password: \"secret\">"
  #
  #   Person.filter_attributes = [:password]
  #   person.inspect
  #   # => "#<Person name: \"Alice\", age: 30, password: [FILTERED]>"
  #
  #   Person.attributes_for_inspect = [:name]
  #   person.inspect
  #   # => "#<Person name: \"Alice\">"
  #
  module Inspection
    extend ActiveSupport::Concern

    included do
      class_attribute :attributes_for_inspect, instance_accessor: false, default: :all
    end

    module ClassMethods
      # Returns an array of attribute names whose values should be masked in
      # the output of +inspect+.
      #
      #   Person.filter_attributes = [:password]
      #   Person.filter_attributes # => [:password]
      def filter_attributes
        if defined?(@filter_attributes)
          @filter_attributes
        elsif superclass.respond_to?(:filter_attributes)
          superclass.filter_attributes
        else
          []
        end
      end

      # Specifies attributes whose values should be masked in the output of
      # +inspect+.
      #
      #   Person.filter_attributes = [:password]
      #   Person.new(password: "secret").inspect
      #   # => "#<Person password: [FILTERED]>"
      def filter_attributes=(attributes)
        @inspection_filter = nil
        @filter_attributes = attributes
      end

      # Returns the inspection filter used to mask sensitive attributes.
      def inspection_filter # :nodoc:
        if defined?(@filter_attributes)
          @inspection_filter ||= begin
            mask = InspectionMask.new(ActiveSupport::ParameterFilter::FILTERED)
            ActiveSupport::ParameterFilter.new(@filter_attributes, mask: mask)
          end
        elsif superclass.respond_to?(:inspection_filter)
          superclass.inspection_filter
        else
          @inspection_filter ||= begin
            mask = InspectionMask.new(ActiveSupport::ParameterFilter::FILTERED)
            ActiveSupport::ParameterFilter.new([], mask: mask)
          end
        end
      end
    end

    # Returns the attributes of the model as a nicely formatted string.
    #
    #   Person.new(name: "Alice", age: 30).inspect
    #   # => "#<Person name: \"Alice\", age: 30>"
    #
    # The attributes can be limited by setting +.attributes_for_inspect+.
    #
    #   Person.attributes_for_inspect = [:name]
    #   Person.new(name: "Alice", age: 30).inspect
    #   # => "#<Person name: \"Alice\">"
    def inspect
      inspect_with_attributes(attributes_for_inspect)
    end

    # Returns all attributes of the model as a nicely formatted string,
    # ignoring +.attributes_for_inspect+.
    #
    #   Person.attributes_for_inspect = [:name]
    #   person = Person.new(name: "Alice", age: 30)
    #
    #   person.inspect
    #   # => "#<Person name: \"Alice\">"
    #
    #   person.full_inspect
    #   # => "#<Person name: \"Alice\", age: 30>"
    def full_inspect
      inspect_with_attributes(all_attributes_for_inspect)
    end

    # Takes a PP and prettily prints this model to it, allowing you to get a
    # nice result from <tt>pp model</tt> when pp is required.
    def pretty_print(pp)
      return super if custom_inspect_method_defined?
      pp.object_address_group(self) do
        if @attributes
          attr_names = attributes_for_inspect.select { |name| @attributes.key?(name.to_s) }
          pp.seplist(attr_names, proc { pp.text "," }) do |attr_name|
            attr_name = attr_name.to_s
            pp.breakable " "
            pp.group(1) do
              pp.text attr_name
              pp.text ":"
              pp.breakable
              value = attribute_for_inspect(attr_name)
              pp.text value
            end
          end
        else
          pp.breakable " "
          pp.text "not initialized"
        end
      end
    end

    # Returns a formatted string for the given attribute, suitable for use in
    # +inspect+ output.
    #
    # Long strings are truncated, dates and times are formatted with
    # +to_fs(:inspect)+, and filtered attributes show +[FILTERED]+.
    #
    #   person = Person.new(name: "Alice " * 20, created_at: Time.now)
    #   person.attribute_for_inspect(:name)
    #   # => "\"Alice Alice Alice Alice Alice Alice Alice Alice A...\""
    #   person.attribute_for_inspect(:created_at)
    #   # => "\"2024-01-15 10:30:00 +0000\""
    def attribute_for_inspect(attr_name)
      attr_name = attr_name.to_s
      value = @attributes.fetch_value(attr_name)
      format_for_inspect(attr_name, value)
    end

    private
      class InspectionMask < DelegateClass(::String)
        def pretty_print(pp)
          pp.text __getobj__
        end
      end
      private_constant :InspectionMask

      def inspection_filter
        self.class.inspection_filter
      end

      def inspect_with_attributes(attributes_to_list)
        inspection = if @attributes
          attributes_to_list.filter_map do |name|
            name = name.to_s
            if @attributes.key?(name)
              "#{name}: #{attribute_for_inspect(name)}"
            end
          end.join(", ")
        else
          "not initialized"
        end

        "#<#{self.class} #{inspection}>"
      end

      def attributes_for_inspect
        self.class.attributes_for_inspect == :all ? all_attributes_for_inspect : self.class.attributes_for_inspect
      end

      def all_attributes_for_inspect
        return [] unless @attributes
        attribute_names
      end

      def format_for_inspect(name, value)
        if value.nil?
          value.inspect
        else
          inspected_value = if value.is_a?(String) && value.length > 50
            "#{value[0, 50]}...".inspect
          elsif value.is_a?(Date) || value.is_a?(Time)
            if value.respond_to?(:to_fs)
              %("#{value.to_fs(:inspect)}")
            else
              %("#{value}")
            end
          else
            value.inspect
          end

          inspection_filter.filter_param(name, inspected_value)
        end
      end

      def custom_inspect_method_defined?
        self.class.instance_method(:inspect).owner != ActiveModel::Inspection
      end
  end
end
