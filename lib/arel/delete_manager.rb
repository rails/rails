module Arel
  class DeleteManager < Arel::TreeManager
    def initialize engine
      super
      @head = Nodes::DeleteStatement.new
    end

    def from relation
      @head.relation = relation
      self
    end

    def where expression
      @head.wheres << expression
      self
    end

    def wheres= list
      @head.wheres = list
    end
  end
end
