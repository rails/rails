# frozen_string_literal: true

module Arel # :nodoc: all
  class TreeManager
    include Arel::FactoryMethods

    module StatementMethods
      def take(limit)
        @ast.limit = Nodes::Limit.new(Nodes.build_quoted(limit)) if limit
        self
      end

      def offset(offset)
        @ast.offset = Nodes::Offset.new(Nodes.build_quoted(offset)) if offset
        self
      end

      def order(*expr)
        @ast.orders = expr
        self
      end

      def key=(key)
        @ast.key = Nodes.build_quoted(key)
      end

      def key
        @ast.key
      end

      def wheres=(exprs)
        @ast.wheres = exprs
      end

      def where(expr)
        @ast.wheres << expr
        self
      end
    end

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
