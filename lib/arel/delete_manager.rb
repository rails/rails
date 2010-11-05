module Arel
  class DeleteManager < Arel::TreeManager
    def initialize engine
      super
      @ast = Nodes::DeleteStatement.new
    end

    def from relation
      @ast.relation = relation
      self
    end

    def where expression
      @ast.wheres << expression
      self
    end

    def wheres= list
      @ast.wheres = list
    end
  end
end
