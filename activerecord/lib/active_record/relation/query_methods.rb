require 'active_support/core_ext/array/wrap'
require 'active_support/core_ext/object/blank'

module ActiveRecord
  module QueryMethods
    extend ActiveSupport::Concern

    included do
      (ActiveRecord::Relation::ASSOCIATION_METHODS + ActiveRecord::Relation::MULTI_VALUE_METHODS).each do |query_method|
        attr_accessor :"#{query_method}_values"

        next if [:where, :having].include?(query_method)
        class_eval <<-CEVAL, __FILE__
          def #{query_method}(*args, &block)
            new_relation = clone
            new_relation.send(:apply_modules, Module.new(&block)) if block_given?
            value = Array.wrap(args.flatten).reject {|x| x.blank? }
            new_relation.#{query_method}_values += value if value.present?
            new_relation
          end
        CEVAL
      end

      [:where, :having].each do |query_method|
        class_eval <<-CEVAL, __FILE__
          def #{query_method}(*args, &block)
            new_relation = clone
            new_relation.send(:apply_modules, Module.new(&block)) if block_given?
            value = build_where(*args)
            new_relation.#{query_method}_values += Array.wrap(value) if value.present?
            new_relation
          end
        CEVAL
      end

      ActiveRecord::Relation::SINGLE_VALUE_METHODS.each do |query_method|
        attr_accessor :"#{query_method}_value"

        class_eval <<-CEVAL, __FILE__
          def #{query_method}(value = true, &block)
            new_relation = clone
            new_relation.send(:apply_modules, Module.new(&block)) if block_given?
            new_relation.#{query_method}_value = value
            new_relation
          end
        CEVAL
      end
    end

    def extending(*modules)
      new_relation = clone
      new_relation.send :apply_modules, *modules
      new_relation
    end

    def lock(locks = true, &block)
      relation = clone
      relation.send(:apply_modules, Module.new(&block)) if block_given?

      case locks
      when String, TrueClass, NilClass
        clone.tap {|new_relation| new_relation.lock_value = locks || true }
      else
        clone.tap {|new_relation| new_relation.lock_value = false }
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

    def custom_join_sql(*joins)
      arel = table
      joins.each do |join|
        next if join.blank?

        @implicit_readonly = true

        case join
        when Hash, Array, Symbol
          if array_of_strings?(join)
            join_string = join.join(' ')
            arel = arel.join(join_string)
          end
        else
          arel = arel.join(join)
        end
      end
      arel.joins(arel)
    end

    def build_arel
      arel = table

      joined_associations = []
      association_joins = []

      joins = @joins_values.map {|j| j.respond_to?(:strip) ? j.strip : j}.uniq

      joins.each do |join|
        association_joins << join if [Hash, Array, Symbol].include?(join.class) && !array_of_strings?(join)
      end

      stashed_association_joins = joins.select {|j| j.is_a?(ActiveRecord::Associations::ClassMethods::JoinDependency::JoinAssociation)}

      non_association_joins = (joins - association_joins - stashed_association_joins).reject {|j| j.blank?}
      custom_joins = custom_join_sql(*non_association_joins)

      join_dependency = ActiveRecord::Associations::ClassMethods::JoinDependency.new(@klass, association_joins, custom_joins)

      join_dependency.graft(*stashed_association_joins)

      @implicit_readonly = true unless association_joins.empty? && stashed_association_joins.empty?

      to_join = []

      join_dependency.join_associations.each do |association|
        if (association_relation = association.relation).is_a?(Array)
          to_join << [association_relation.first, association.join_class, association.association_join.first]
          to_join << [association_relation.last, association.join_class, association.association_join.last]
        else
          to_join << [association_relation, association.join_class, association.association_join]
        end
      end

      to_join.each do |tj|
        unless joined_associations.detect {|ja| ja[0] == tj[0] && ja[1] == tj[1] && ja[2] == tj[2] }
          joined_associations << tj
          arel = arel.join(tj[0], tj[1]).on(*tj[2])
        end
      end

      arel = arel.join(custom_joins)

      @where_values.uniq.each do |where|
        next if where.blank?

        case where
        when Arel::SqlLiteral
          arel = arel.where(where)
        else
          sql = where.is_a?(String) ? where : where.to_sql
          arel = arel.where(Arel::SqlLiteral.new("(#{sql})"))
        end
      end

      @having_values.uniq.each do |h|
        arel = h.is_a?(String) ? arel.having(h) : arel.having(*h)
      end

      arel = arel.take(@limit_value) if @limit_value.present?
      arel = arel.skip(@offset_value) if @offset_value.present?

      arel = arel.group(*@group_values.uniq.select{|g| g.present?})

      arel = arel.order(*@order_values.uniq.select{|o| o.present?}.map(&:to_s))

      selects = @select_values.uniq

      quoted_table_name = @klass.quoted_table_name

      if selects.present?
        selects.each do |s|
          @implicit_readonly = false
          arel = arel.project(s) if s.present?
        end
      else
        arel = arel.project(quoted_table_name + '.*')
      end

      arel = @from_value.present? ? arel.from(@from_value) : arel.from(quoted_table_name)

      case @lock_value
      when TrueClass
        arel = arel.lock
      when String
        arel = arel.lock(@lock_value)
      end if @lock_value.present?

      arel
    end

    def build_where(*args)
      return if args.blank?

      opts = args.first
      case opts
      when String, Array
        @klass.send(:sanitize_sql, args.size > 1 ? args : opts)
      when Hash
        attributes = @klass.send(:expand_hash_conditions_for_aggregates, opts)
        PredicateBuilder.new(table.engine).build_from_hash(attributes, table)
      else
        opts
      end
    end

    private

    def apply_modules(modules)
      values = Array.wrap(modules)
      @extensions += values if values.present?
      values.each {|extension| extend(extension) }
    end

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

    def array_of_strings?(o)
      o.is_a?(Array) && o.all?{|obj| obj.is_a?(String)}
    end

  end
end
