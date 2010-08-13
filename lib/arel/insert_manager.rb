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
  end
end
