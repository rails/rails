module Arel
  class UpdateManager < Arel::TreeManager
    def initialize engine
      super
      @head = Nodes::UpdateStatement.new
    end

    ###
    # UPDATE +table+
    def table table
      @head.relation = table
      self
    end

    def wheres= exprs
      @head.wheres = exprs
    end

    def where expr
      @head.wheres << expr
      self
    end

    def set values
      if String === values
        @head.values = [values]
      else
        @head.values = values.map { |column,value|
          Nodes::Assignment.new(
            Nodes::UnqualifiedColumn.new(column),
            value
          )
        }
      end
      self
    end
  end
end
