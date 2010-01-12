module ActiveRecord
  module QueryMethods
    extend ActiveSupport::Concern

    included do
      (ActiveRecord::Relation::ASSOCIATION_METHODS + ActiveRecord::Relation::MULTI_VALUE_METHODS).each do |query_method|
        attr_accessor :"#{query_method}_values"

        class_eval <<-CEVAL
          def #{query_method}(*args)
            spawn.tap do |new_relation|
              new_relation.#{query_method}_values ||= []
              value = args.size > 1 ? [args] : Array.wrap(args)
              new_relation.#{query_method}_values += value
            end
          end
        CEVAL
      end

      ActiveRecord::Relation::SINGLE_VALUE_METHODS.each do |query_method|
        attr_accessor :"#{query_method}_value"

        class_eval <<-CEVAL
          def #{query_method}(value = true)
            spawn.tap do |new_relation|
              new_relation.#{query_method}_value = value
            end
          end
        CEVAL
      end
    end

    def lock(locks = true)
      relation = spawn
      case locks
      when String, TrueClass, NilClass
        spawn.tap {|new_relation| new_relation.lock_value = locks || true }
      else
        spawn.tap {|new_relation| new_relation.lock_value = false }
      end
    end

    def reverse_order
      order_clause = arel.send(:order_clauses).join(', ')
      relation = except(:order)

      if order_clause.present?
        relation.order(reverse_sql_order(order_clause))
      else
        relation.order("#{@klass.table_name}.#{@klass.primary_key} DESC")
      end
    end

    def arel
      @arel ||= build_arel
    end

    def build_arel
      arel = table

      @joins_values.each do |j|
        next if j.blank?

        @implicit_readonly = true

        case j
        when Relation::JoinOperation
          arel = arel.join(j.relation, j.join_class).on(j.on)
        when Hash, Array, Symbol
          if @klass.send(:array_of_strings?, j)
            arel = arel.join(j.join(' '))
          else
            arel = arel.join(@klass.send(:build_association_joins, j))
          end
        else
          arel = arel.join(j)
        end
      end

      @where_values.each do |where|
        if conditions = build_where(where)
          arel = conditions.is_a?(String) ? arel.where(conditions) : arel.where(*conditions)
        end
      end

      @having_values.each do |where|
        if conditions = build_where(where)
          arel = conditions.is_a?(String) ? arel.having(conditions) : arel.having(*conditions)
        end
      end

      arel = arel.take(@limit_value) if @limit_value.present?
      arel = arel.skip(@offset_value) if @offset_value.present?

      @group_values.each do |g|
        arel = arel.group(g) if g.present?
      end

      @order_values.each do |o|
        arel = arel.order(o) if o.present?
      end

      @select_values.each do |s|
        @implicit_readonly = false
        arel = arel.project(s) if s.present?
      end

      arel = arel.from(@from_value) if @from_value.present?

      case @lock_value
      when TrueClass
        arel = arel.lock
      when String
        arel = arel.lock(@lock_value)
      end

      arel
    end

    def build_where(*args)
      return if args.blank?

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

      conditions
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
