module Arel
  class InsertManager < Arel::TreeManager
    def initialize engine
      super
      @ast = Nodes::InsertStatement.new
    end

    def into table
      @ast.relation = table
      self
    end

    def columns; @ast.columns end
    def values= val; @ast.values = val; end

    def insert fields
      return if fields.empty?

      if String === fields
        @ast.values = SqlLiteral.new(fields)
      else
        @ast.relation ||= fields.first.first.relation

        values = []

        fields.each do |column, value|
          @ast.columns << column
          values << value
        end
        @ast.values = Nodes::Values.new values, @ast.columns
      end
    end
  end
end
