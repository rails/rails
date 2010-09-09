module Arel
  class InsertManager < Arel::TreeManager
    def initialize engine
      super
      @head = Nodes::InsertStatement.new
    end

    def into table
      @head.relation = table
      self
    end

    def columns; @head.columns end
    def values= val; @head.values = val; end

    def insert fields
      return if fields.empty?

      if String === fields
        @head.values = SqlLiteral.new(fields)
      else
        @head.relation ||= fields.first.first.relation

        values = []

        fields.each do |column, value|
          @head.columns << column
          values << value
        end
        @head.values = Nodes::Values.new values
      end
    end
  end
end
