# frozen_string_literal: true

module Arel
  class TreeManager
    include Arel::FactoryMethods

    attr_reader :ast

    def initialize
      @ctx = nil
    end

    def to_dot
      collector = Arel::Collectors::PlainString.new
      collector = Visitors::Dot.new.accept @ast, collector
      collector.value
    end

    def to_sql(engine = Table.engine)
      collector = Arel::Collectors::SQLString.new
      collector = engine.connection.visitor.accept @ast, collector
      collector.value
    end

    def initialize_copy(other)
      super
      @ast = @ast.clone
    end

    def where(expr)
      if Arel::TreeManager === expr
        expr = expr.ast
      end
      @ctx.wheres << expr
      self
    end
  end
end
