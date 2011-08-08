module Arel
  class TreeManager
    # FIXME: Remove this.
    include Arel::Relation
    include Arel::FactoryMethods

    attr_reader :ast, :engine

    def initialize engine
      @engine = engine
      @ctx    = nil
    end

    def to_dot
      Visitors::Dot.new.accept @ast
    end

    def visitor
      engine.connection.visitor
    end

    def to_sql
      visitor.accept @ast
    end

    def initialize_copy other
      super
      @ast = @ast.clone
    end

    def where expr
      if Arel::TreeManager === expr
        expr = expr.ast
      end
      @ctx.wheres << expr
      self
    end
  end
end
