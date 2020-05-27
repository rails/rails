# frozen_string_literal: true

module ActiveRecord
  class QueryComposer
    delegate :[], to: :arel_table

    def initialize(model)
      @model = model
      @arel_table = model.arel_table
      @reflections = model._reflections
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
  end
end
