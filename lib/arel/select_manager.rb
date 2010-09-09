module Arel
  class SelectManager < Arel::TreeManager
    include Arel::Crud

    def initialize engine
      super
      @head   = Nodes::SelectStatement.new
      @ctx    = @head.cores.last
    end

    def lock locking = true
      # FIXME: do we even need to store this?  If locking is +false+ shouldn't
      # we just remove the node from the AST?
      @head.lock = Nodes::Lock.new
      self
    end

    def on *exprs
      @ctx.froms.last.constraint = Nodes::On.new(collapse(exprs))
      self
    end

    def group *columns
      columns.each do |column|
        # FIXME: backwards compat
        column = Nodes::SqlLiteral.new(column) if String === column

        @ctx.groups.push Nodes::Group.new column
      end
      self
    end

    def from table
      @ctx.froms << table
      self
    end

    def join relation, klass = Nodes::InnerJoin
      return self unless relation

      case relation
      when String, Nodes::SqlLiteral
        raise if relation.blank?
        from Nodes::StringJoin.new(@ctx.froms.pop, relation)
      else
        from klass.new(@ctx.froms.pop, relation, nil)
      end
    end

    def having expr
      @ctx.having = Nodes::Having.new(expr)
      self
    end

    def project *projections
      # FIXME: converting these to SQLLiterals is probably not good, but
      # rails tests require it.
      @ctx.projections.concat projections.map { |x|
        String == x.class ? SqlLiteral.new(x) : x
      }
      self
    end

    def where expr
      @ctx.wheres << expr
      self
    end

    def order *expr
      # FIXME: We SHOULD NOT be converting these to SqlLiteral automatically
      @head.orders.concat expr.map { |x|
        String === x ? Nodes::SqlLiteral.new(x) : x
      }
      self
    end

    def wheres
      Compatibility::Wheres.new @engine, @ctx.wheres
    end

    def take limit
      @head.limit = limit
      self
    end

    def join_sql
      viz = Visitors::JoinSql.new @engine
      Nodes::SqlLiteral.new viz.accept @ctx
    end

    def order_clauses
      Visitors::OrderClauses.new(@engine).accept(@head).map { |x|
        Nodes::SqlLiteral.new x
      }
    end

    def joins manager
      manager.join_sql
    end

    def to_a
      raise NotImplementedError
    end

    private
    def collapse exprs
      return exprs.first if exprs.length == 1

      right = exprs.pop
      left  = exprs.pop

      right = Nodes::And.new left, right
      exprs.reverse.inject(right) { |memo,expr| Nodes::And.new(expr, memo) }
    end
  end
end
