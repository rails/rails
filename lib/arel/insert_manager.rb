# frozen_string_literal: true
module Arel
  class InsertManager < Arel::TreeManager
    def initialize
      super
      @ast = Nodes::InsertStatement.new
    end

    def into table
      @ast.relation = table
      self
    end

    def columns; @ast.columns end
    def values= val; @ast.values = val; end

    def select select
      @ast.select = select
    end

    def insert fields
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
        @ast.values = create_values values, @ast.columns
      end
    end

    def create_values values, columns
      Nodes::Values.new values, columns
    end
  end
end
