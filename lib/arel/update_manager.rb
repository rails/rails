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

    def where expr
      @head.wheres << expr
      self
    end

    def set values
      @head.values = values
      self
    end
  end
end
