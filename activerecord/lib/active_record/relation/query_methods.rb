module ActiveRecord
  module QueryMethods

    def preload(*associations)
      spawn.tap {|r| r.preload_associations += Array.wrap(associations) }
    end

    def includes(*associations)
      spawn.tap {|r| r.includes_associations += Array.wrap(associations) }
    end

    def eager_load(*associations)
      spawn.tap {|r| r.eager_load_associations += Array.wrap(associations) }
    end

    def readonly(status = true)
      spawn.tap {|r| r.readonly = status }
    end

    def select(selects)
      if selects.present?
        relation = spawn(@relation.project(selects))
        relation.readonly = @relation.joins(relation).present? ? false : @readonly
        relation
      else
        spawn
      end
    end

    def from(from)
      from.present? ? spawn(@relation.from(from)) : spawn
    end

    def having(*args)
      return spawn if args.blank?

      if [String, Hash, Array].include?(args.first.class)
        havings = @klass.send(:merge_conditions, args.size > 1 ? Array.wrap(args) : args.first)
      else
        havings = args.first
      end

      spawn(@relation.having(havings))
    end

    def group(groups)
      groups.present? ? spawn(@relation.group(groups)) : spawn
    end

    def order(orders)
      orders.present? ? spawn(@relation.order(orders)) : spawn
    end

    def lock(locks = true)
      case locks
      when String
        spawn(@relation.lock(locks))
      when TrueClass, NilClass
        spawn(@relation.lock)
      else
        spawn
      end
    end

    def reverse_order
      relation = spawn
      relation.instance_variable_set(:@orders, nil)

      order_clause = @relation.send(:order_clauses).join(', ')
      if order_clause.present?
        relation.order(reverse_sql_order(order_clause))
      else
        relation.order("#{@klass.table_name}.#{@klass.primary_key} DESC")
      end
    end

    def limit(limits)
      limits.present? ? spawn(@relation.take(limits)) : spawn
    end

    def offset(offsets)
      offsets.present? ? spawn(@relation.skip(offsets)) : spawn
    end

    def on(join)
      spawn(@relation.on(join))
    end

    def joins(join, join_type = nil)
      return spawn if join.blank?

      join_relation = case join
      when String
        @relation.join(join)
      when Hash, Array, Symbol
        if @klass.send(:array_of_strings?, join)
          @relation.join(join.join(' '))
        else
          @relation.join(@klass.send(:build_association_joins, join))
        end
      else
        @relation.join(join, join_type)
      end

      spawn(join_relation).tap { |r| r.readonly = true }
    end

    def where(*args)
      return spawn if args.blank?

      builder = PredicateBuilder.new(Arel::Sql::Engine.new(@klass))

      conditions = if [String, Array].include?(args.first.class)
        merged = @klass.send(:merge_conditions, args.size > 1 ? Array.wrap(args) : args.first)
        Arel::SqlLiteral.new(merged) if merged
      elsif args.first.is_a?(Hash)
        attributes = @klass.send(:expand_hash_conditions_for_aggregates, args.first)
        builder.build_from_hash(attributes, table)
      else
        args.first
      end

      conditions.is_a?(String) ? spawn(@relation.where(conditions)) : spawn(@relation.where(*conditions))
    end

    private

    def reverse_sql_order(order_query)
      order_query.to_s.split(/,/).each { |s|
        if s.match(/\s(asc|ASC)$/)
          s.gsub!(/\s(asc|ASC)$/, ' DESC')
        elsif s.match(/\s(desc|DESC)$/)
          s.gsub!(/\s(desc|DESC)$/, ' ASC')
        else
          s.concat(' DESC')
        end
      }.join(',')
    end

  end
end
