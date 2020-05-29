# frozen_string_literal: true

module ActiveRecord
  module Table
    mattr_accessor :base

    extend self

    ##
    # Contains class methods corresponding to a table's columns, lazily evaluated
    # at call time. Returns instances of <tt>Arel::Attributes::Attribute</tt>.
    #
    # Available through a Model::Table interface:
    #
    # Developer::Table.id.class #=> Arel::Attributes::Attribute

    def method_missing(method_name, *args, &block)
      send(:define_method, method_name) do
        base.arel_attribute(method_name)
      end
      send(method_name)
    end

    def respond_to_missing?(method_name, include_private = false)
      columns.find { |c| c.name == method_name.to_s } || super
    end

    def columns
      base.connection.columns(base.table_name)
    end
  end
end
