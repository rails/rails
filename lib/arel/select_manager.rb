module Arel
  class SelectManager < Arel::TreeManager
    include Arel::Crud

    def initialize engine, table = nil
      super(engine)
      @ast   = Nodes::SelectStatement.new
      @ctx    = @ast.cores.last
      from table
    end

    def initialize_copy other
      super
      @ctx = @ast.cores.last
    end

    def limit
      @ast.limit && @ast.limit.expr
    end
    alias :taken :limit

    def constraints
      @ctx.wheres
    end

    def offset
      @ast.offset && @ast.offset.expr
    end

    def skip amount
      if amount
        @ast.offset = Nodes::Offset.new(amount)
      else
        @ast.offset = nil
      end
      self
    end
    alias :offset= :skip

    ###
    # Produces an Arel::Nodes::Exists node
    def exists
      Arel::Nodes::Exists.new @ast
    end

    def as other
      create_table_alias grouping(@ast), Nodes::SqlLiteral.new(other)
    end

    def where_clauses
      if $VERBOSE
        warn "(#{caller.first}) where_clauses is deprecated and will be removed in arel 4.0.0 with no replacement"
      end
      to_sql = Visitors::ToSql.new @engine.connection
      @ctx.wheres.map { |c| to_sql.accept c }
    end

    def lock locking = Arel.sql('FOR UPDATE')
      case locking
      when true
        locking = Arel.sql('FOR UPDATE')
      when Arel::Nodes::SqlLiteral
      when String
        locking = Arel.sql locking
      end

      @ast.lock = Nodes::Lock.new(locking)
      self
    end

    def locked
      @ast.lock
    end

    def on *exprs
      @ctx.source.right.last.right = Nodes::On.new(collapse(exprs))
      self
    end

    def group *columns
      columns.each do |column|
        # FIXME: backwards compat
        column = Nodes::SqlLiteral.new(column) if String === column
        column = Nodes::SqlLiteral.new(column.to_s) if Symbol === column

        @ctx.groups.push Nodes::Group.new column
      end
      self
    end

    def from table
      table = Nodes::SqlLiteral.new(table) if String === table
      # FIXME: this is a hack to support
      # test_with_two_tables_in_from_without_getting_double_quoted
      # from the AR tests.

      case table
      when Nodes::Join
        @ctx.source.right << table
      else
        @ctx.source.left = table
      end

      self
    end

    def froms
      @ast.cores.map { |x| x.from }.compact
    end

    def join relation, klass = Nodes::InnerJoin
      return self unless relation

      case relation
      when String, Nodes::SqlLiteral
        raise if relation.blank?
        klass = Nodes::StringJoin
      end

      @ctx.source.right << create_join(relation, nil, klass)
      self
    end

    def having *exprs
      @ctx.having = Nodes::Having.new(collapse(exprs, @ctx.having))
      self
    end

    def window name
      window = Nodes::NamedWindow.new(name)
      @ctx.windows.push window
      window
    end

    def project *projections
      # FIXME: converting these to SQLLiterals is probably not good, but
      # rails tests require it.
      @ctx.projections.concat projections.map { |x|
        [Symbol, String].include?(x.class) ? SqlLiteral.new(x.to_s) : x
      }
      self
    end

    def projections
      @ctx.projections
    end

    def projections= projections
      @ctx.projections = projections
    end

    def distinct(value = true)
      if value
        @ctx.set_quantifier = Arel::Nodes::Distinct.new
      else
        @ctx.set_quantifier = nil
      end
    end

    def order *expr
      # FIXME: We SHOULD NOT be converting these to SqlLiteral automatically
      @ast.orders.concat expr.map { |x|
        String === x || Symbol === x ? Nodes::SqlLiteral.new(x.to_s) : x
      }
      self
    end

    def orders
      @ast.orders
    end

    def wheres
      warn "#{caller[0]}: SelectManager#wheres is deprecated and will be removed in Arel 4.0.0 with no replacement"
      Compatibility::Wheres.new @engine.connection, @ctx.wheres
    end

    def where_sql
      return if @ctx.wheres.empty?

      viz = Visitors::WhereSql.new @engine.connection
      Nodes::SqlLiteral.new viz.accept @ctx
    end

    def union operation, other = nil
      if other
        node_class = Nodes.const_get("Union#{operation.to_s.capitalize}")
      else
        other = operation
        node_class = Nodes::Union
      end

      node_class.new self.ast, other.ast
    end

    def intersect other
      Nodes::Intersect.new ast, other.ast
    end

    def except other
      Nodes::Except.new ast, other.ast
    end
    alias :minus :except

    def with *subqueries
      if subqueries.first.is_a? Symbol
        node_class = Nodes.const_get("With#{subqueries.shift.to_s.capitalize}")
      else
        node_class = Nodes::With
      end
      @ast.with = node_class.new(subqueries.flatten)

      self
    end

    def take limit
      if limit
        @ast.limit = Nodes::Limit.new(limit)
        @ctx.top   = Nodes::Top.new(limit)
      else
        @ast.limit = nil
        @ctx.top   = nil
      end
      self
    end
    alias limit= take

    def join_sql
      return nil if @ctx.source.right.empty?

      sql = visitor.dup.extend(Visitors::JoinSql).accept @ctx
      Nodes::SqlLiteral.new sql
    end

    def order_clauses
      visitor = Visitors::OrderClauses.new(@engine.connection)
      visitor.accept(@ast).map { |x|
        Nodes::SqlLiteral.new x
      }
    end

    def join_sources
      @ctx.source.right
    end

    def source
      @ctx.source
    end

    def joins manager
      if $VERBOSE
        warn "joins is deprecated and will be removed in 4.0.0"
        warn "please remove your call to joins from #{caller.first}"
      end
      manager.join_sql
    end

    class Row < Struct.new(:data) # :nodoc:
      def id
        data['id']
      end

      def method_missing(name, *args)
        name = name.to_s
        return data[name] if data.key?(name)
        super
      end
    end

    def to_a # :nodoc:
      warn "to_a is deprecated. Please remove it from #{caller[0]}"
      # FIXME: I think `select` should be made public...
      @engine.connection.send(:select, to_sql, 'AREL').map { |x| Row.new(x) }
    end

    # FIXME: this method should go away
    def insert values
      if $VERBOSE
        warn <<-eowarn
insert (#{caller.first}) is deprecated and will be removed in Arel 4.0.0. Please
switch to `compile_insert`
        eowarn
      end

      im = compile_insert(values)
      table = @ctx.froms

      primary_key      = table.primary_key
      primary_key_name = primary_key.name if primary_key

      # FIXME: in AR tests values sometimes were Array and not Hash therefore is_a?(Hash) check is added
      primary_key_value = primary_key && values.is_a?(Hash) && values[primary_key]
      im.into table
      # Oracle adapter needs primary key name to generate RETURNING ... INTO ... clause
      # for tables which assign primary key value using trigger.
      # RETURNING ... INTO ... clause will be added only if primary_key_value is nil
      # therefore it is necessary to pass primary key value as well
      @engine.connection.insert im.to_sql, 'AREL', primary_key_name, primary_key_value
    end

    private
    def collapse exprs, existing = nil
      exprs = exprs.unshift(existing.expr) if existing
      exprs = exprs.compact.map { |expr|
        if String === expr
          # FIXME: Don't do this automatically
          Arel.sql(expr)
        else
          expr
        end
      }

      if exprs.length == 1
        exprs.first
      else
        create_and exprs
      end
    end
  end
end
