# frozen_string_literal: true

module Arel # :nodoc: all
  class InsertManager < Arel::TreeManager
    def initialize(table = nil)
      super()
      @ast = Nodes::InsertStatement.new(table)
    end

    def into(table)
      @ast.relation = table
      self
    end

    def columns; @ast.columns end
    def values=(val); @ast.values = val; end

    def select(select)
      @ast.select = select
    end

    def insert(fields)
      return if fields.empty?

      if String === fields
        @ast.values = Nodes::SqlLiteral.new(fields)
      else
        @ast.relation ||= fields.first.first.relation

        values = []

        fields.each do |column, value|
          @ast.columns << column
          values << value
        end
        @ast.values = create_values(values)
      end
      self
    end

    def create_values(values)
      Nodes::ValuesList.new([values])
    end

    def create_values_list(rows)
      Nodes::ValuesList.new(rows)
    end
  end
end
