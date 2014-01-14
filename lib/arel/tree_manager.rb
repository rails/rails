module Arel
  class TreeManager
    include Arel::FactoryMethods

    attr_reader :ast, :engine

    attr_accessor :bind_values

    def initialize engine
      @engine = engine
      @ctx    = nil
      @bind_values = []
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
