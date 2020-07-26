# frozen_string_literal: true

module Arel # :nodoc: all
  class TreeManager
    include Arel::FactoryMethods

    module LockMethods
      extend self

      def build_lock_node(locking)
        case locking
        when true
          locking = Arel.sql("FOR UPDATE")
        when Arel::Nodes::SqlLiteral
        when String
          locking = Arel.sql locking
        end

        Nodes::Lock.new(locking)
      end

      def build_subselect(key, o)
        Nodes::SelectStatement.new.tap do |stmt|
          core             = stmt.cores.first
          core.froms       = o.relation
          core.wheres      = o.wheres
          core.projections = [key]
        end
      end

      def use_tmp_table(subselect, quoted_key_name)
        Nodes::SelectStatement.new.tap do |stmt|
          core = stmt.cores.last
          core.froms = Nodes::Grouping.new(subselect).as("__active_record_temp")
          core.projections = [Arel.sql(quoted_key_name)]
        end
      end
    end

    module StatementMethods
      def lock(locking = Arel.sql("FOR UPDATE"), connection = Table.engine.connection)
        stmt = LockMethods.build_subselect(@ast.key, @ast)
        stmt.lock = LockMethods.build_lock_node(locking)
        if connection.adapter_name == "Mysql2"
          stmt = LockMethods.use_tmp_table(stmt, connection.quote_column_name(key.name))
        end
        @ast.wheres = [Nodes::In.new(@ast.key, [stmt])]
        self
      end

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
