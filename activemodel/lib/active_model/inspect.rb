# frozen_string_literal: true

require "active_support/parameter_filter"

module ActiveModel
  # = Active \Model \Inspect
  #
  # Show a formatted string with relevant attributes when calling `inspect`.
  #
  #   class Person
  #     include ActiveModel::API
  #     include ActiveModel::Attributes
  #     include ActiveModel::Inspect
  #     attribute :name, :string
  #   end
  #   person = Person.new(name: "Amanda")
  #   person.inspect
  #   => "#<Person name: \"Amanda\">"
  #
  # Sensitive attributes can be filtered:
  #
  #   Person.filter_attributes = [:name]
  #   person.inspect
  #   => #<Person name: [FILTERED]>
  module Inspect
    extend ActiveSupport::Concern

    class << self
      attr_accessor :filter_attributes # :nodoc:
    end
    self.filter_attributes = []

    class InspectionMask < DelegateClass(::String)
      def pretty_print(pp)
        pp.text __getobj__
      end
    end
    private_constant :InspectionMask

    module ClassMethods
      # Returns attributes which shouldn't be exposed while calling +#inspect+.
      def filter_attributes
        if @filter_attributes.nil?
          Inspect.filter_attributes
        else
          @filter_attributes
        end
      end

      # Specifies attributes which shouldn't be exposed while calling +#inspect+.
      def filter_attributes=(filter_attributes)
        @inspection_filter = nil
        @filter_attributes = filter_attributes
      end

      def inspection_filter # :nodoc:
        @inspection_filter ||= begin
          mask = InspectionMask.new(ActiveSupport::ParameterFilter::FILTERED)
          ActiveSupport::ParameterFilter.new(filter_attributes, mask: mask)
        end
      end
    end

    # Returns the attributes as a nicely formatted string.
    def inspect # :nodoc:
      inspection = attributes.keys.filter_map do |name|
        name = name.to_s
        "#{name}: #{attribute_for_inspect(name)}"
      end.join(", ")

      "#<#{self.class} #{inspection}>"
    end

    # Returns an <tt>#inspect</tt>-like string for the value of the
    # attribute +attr_name+. String attributes are truncated up to 50
    # characters. Other attributes return the value of <tt>#inspect</tt>
    # without modification.
    #
    #   class Person
    #     include ActiveModel::Attributes
    #     include ActiveModel::Inspect
    #     attribute :name, :string
    #     attribute :created_at, :datetime
    #     attribute :tag_ids
    #   end
    #
    #   person = Person.new(name: 'David Heinemeier Hansson ' * 3)
    #
    #   person.attribute_for_inspect(:name)
    #   # => "\"David Heinemeier Hansson David Heinemeier Hansson ...\""
    #
    #   person.created_at = Time.parse("2012-10-22 00:15:07")
    #   person.attribute_for_inspect(:created_at)
    #   # => "\"2012-10-22 00:15:07.000000000 +0000\""
    #
    #   person.tag_ids = [1, 2, 3]
    #   person.attribute_for_inspect(:tag_ids)
    #   # => "[1, 2, 3]"
    def attribute_for_inspect(attr_name)
      attr_name = attr_name.to_s
      attr_name = self.class.attribute_aliases[attr_name] || attr_name
      value = _read_attribute(attr_name)
      format_for_inspect(attr_name, value)
    end

    private
      def format_for_inspect(name, value)
        if value.nil?
          value.inspect
        else
          inspected_value = if value.is_a?(String) && value.length > 50
            "#{value[0, 50]}...".inspect
          elsif value.is_a?(Date) || value.is_a?(Time)
            %("#{value.to_fs(:inspect)}")
          else
            value.inspect
          end

          inspection_filter.filter_param(name, inspected_value)
        end
      end

      def inspection_filter
        self.class.inspection_filter
      end
  end

  ActiveSupport.run_load_hooks(:active_model_inspect, Inspect)
end
