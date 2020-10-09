# frozen_string_literal: true

module ActiveRecord
  class QueryComposer
    delegate :[], to: :arel_table

    def initialize(model)
      @model = model
      @arel_table = model.arel_table
      @reflections = model._reflections
      define_attribute_accessors
    end

    def method_missing(name, *_args)
      if reflections.key?(name.to_s)
        self.class.new(reflections[name.to_s].klass)
      else
        super
      end
    end

    private
      attr_reader :model, :arel_table, :reflections

      def define_attribute_accessors
        model.attribute_names.each do |attr|
          define_singleton_method attr do
            arel_table[attr]
          end
        end
      end
  end
end
