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
    def values; @head.values end

    def insert fields
      return if fields.empty?

      @head.relation ||= fields.first.first.relation

      fields.each do |column, value|
        @head.columns << column
        @head.values << value
      end
    end
  end
end
