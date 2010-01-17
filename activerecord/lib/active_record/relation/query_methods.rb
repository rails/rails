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
              value = Array.wrap(args.flatten).reject {|x| x.blank? }
              new_relation.#{query_method}_values += value if value.present?
            end
          end
        CEVAL
      end

      [:where, :having].each do |query_method|
        class_eval <<-CEVAL
          def #{query_method}(*args)
            spawn.tap do |new_relation|
              new_relation.#{query_method}_values ||= []
              value = build_where(*args)
              new_relation.#{query_method}_values += [*value] if value.present?
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

      joined_associations = []
      association_joins = []

      joins = @joins_values.map {|j| j.respond_to?(:strip) ? j.strip : j}.uniq

      # Build association joins first
      joins.each do |join|
        association_joins << join if [Hash, Array, Symbol].include?(join.class) && !@klass.send(:array_of_strings?, join)
      end

      if association_joins.any?
        join_dependency = ActiveRecord::Associations::ClassMethods::JoinDependency.new(@klass, association_joins.uniq, nil)
        to_join = []

        join_dependency.join_associations.each do |association|
          if (association_relation = association.relation).is_a?(Array)
            to_join << [association_relation.first, association.association_join.first]
            to_join << [association_relation.last, association.association_join.last]
          else
            to_join << [association_relation, association.association_join]
          end
        end

        to_join.each do |tj|
          unless joined_associations.detect {|ja| ja[0] == tj[0] && ja[1] == tj[1] }
            joined_associations << tj
            arel = arel.join(tj[0]).on(*tj[1])
          end
        end
      end

      joins.each do |join|
        next if join.blank?

        @implicit_readonly = true

        case join
        when Relation::JoinOperation
          arel = arel.join(join.relation, join.join_class).on(*join.on)
        when Hash, Array, Symbol
          if @klass.send(:array_of_strings?, join)
            join_string = join.join(' ')
            arel = arel.join(join_string)
          end
        else
          arel = arel.join(join)
        end
      end

      @where_values.uniq.each do |w|
        arel = w.is_a?(String) ? arel.where(w) : arel.where(*w)
      end

      @having_values.uniq.each do |h|
        arel = h.is_a?(String) ? arel.having(h) : arel.having(*h)
      end

      arel = arel.take(@limit_value) if @limit_value.present?
      arel = arel.skip(@offset_value) if @offset_value.present?

      @group_values.uniq.each do |g|
        arel = arel.group(g) if g.present?
      end

      @order_values.uniq.each do |o|
        arel = arel.order(o) if o.present?
      end

      selects = @select_values.uniq

      if selects.present?
        selects.each do |s|
          @implicit_readonly = false
          arel = arel.project(s) if s.present?
        end
      elsif joins.present?
        arel = arel.project(@klass.quoted_table_name + '.*')
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

      builder = PredicateBuilder.new(table.engine)

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
