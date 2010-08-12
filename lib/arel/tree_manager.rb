module Arel
  class TreeManager
    def initialize engine
      @engine         = engine
      @statement_list = []

      # default to Select
      @statement_list << Nodes::Select.new
    end

    def from table
      @statement_list.last.froms << table
      self
    end

    def project projection
      @statement_list.last.projections << projection
      self
    end

    def where expr
      @statement_list.last.wheres << expr
      self
    end

    def to_sql
      viz = Visitors::ToSql.new @engine
      viz.accept @statement_list.last
    end
  end
end
