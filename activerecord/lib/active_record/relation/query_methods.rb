require 'active_support/core_ext/array/wrap'
require 'active_support/core_ext/object/blank'

module ActiveRecord
  module QueryMethods
    extend ActiveSupport::Concern

    attr_accessor :includes_values, :eager_load_values, :preload_values,
                  :select_values, :group_values, :order_values, :reorder_flag, :joins_values, :where_values, :having_values,
                  :limit_value, :offset_value, :lock_value, :readonly_value, :create_with_value, :from_value

    def includes(*args)
      args.reject! {|a| a.blank? }

      return clone if args.empty?

      relation = clone
      relation.includes_values = (relation.includes_values + args).flatten.uniq
      relation
    end

    def eager_load(*args)
      relation = clone
      relation.eager_load_values += args unless args.blank?
      relation
    end

    def preload(*args)
      relation = clone
      relation.preload_values += args unless args.blank?
      relation
    end

    def select(value = Proc.new)
      if block_given?
        to_a.select {|*block_args| value.call(*block_args) }
      else
        relation = clone
        relation.select_values += Array.wrap(value)
        relation
      end
    end

    def group(*args)
      relation = clone
      relation.group_values += args.flatten unless args.blank?
      relation
    end

    def order(*args)
      relation = clone
      relation.order_values += args.flatten unless args.blank?
      relation
    end

    def reorder(*args)
      ActiveSupport::Deprecation.warn "reorder is deprecated. Please use except(:order).order(...) instead", caller
      relation = clone
      unless args.blank?
        relation.order_values = args
        relation.reorder_flag = true
      end
      relation
    end

    def joins(*args)
      relation = clone

      args.flatten!
      relation.joins_values += args unless args.blank?

      relation
    end

    def where(opts, *rest)
      relation = clone
      relation.where_values += build_where(opts, rest) unless opts.blank?
      relation
    end

    def having(*args)
      relation = clone
      relation.having_values += build_where(*args) unless args.blank?
      relation
    end

    def limit(value)
      relation = clone
      relation.limit_value = value
      relation
    end

    def offset(value)
      relation = clone
      relation.offset_value = value
      relation
    end

    def lock(locks = true)
      relation = clone

      case locks
      when String, TrueClass, NilClass
        relation.lock_value = locks || true
      else
        relation.lock_value = false
      end

      relation
    end

    def readonly(value = true)
      relation = clone
      relation.readonly_value = value
      relation
    end

    def create_with(value)
      relation = clone
      relation.create_with_value = value
      relation
    end

    def from(value)
      relation = clone
      relation.from_value = value
      relation
    end

    def extending(*modules, &block)
      modules << Module.new(&block) if block_given?

      relation = clone
      relation.send(:apply_modules, modules.flatten)
      relation
    end

    def reverse_order
      order_clause = arel.order_clauses.join(', ')
      relation = except(:order)

      order = order_clause.blank? ?
        "#{@klass.table_name}.#{@klass.primary_key} DESC" :
        reverse_sql_order(order_clause)

      relation.order(Arel.sql(order))
    end

    def arel
      @arel ||= build_arel
    end

    def custom_join_sql(*joins)
      arel = table.select_manager

      joins.each do |join|
        next if join.blank?

        @implicit_readonly = true

        case join
        when Array
          join = Arel.sql(join.join(' ')) if array_of_strings?(join)
        when String
          join = Arel.sql(join)
        end

        arel.join(join)
      end

      arel.join_sql
    end

    def build_arel
      arel = table

      arel = build_joins(arel, @joins_values) unless @joins_values.empty?

      arel = collapse_wheres(arel, (@where_values - ['']).uniq)

      arel = arel.having(*@having_values.uniq.reject{|h| h.blank?}) unless @having_values.empty?

      arel = arel.take(connection.sanitize_limit(@limit_value)) if @limit_value
      arel = arel.skip(@offset_value) if @offset_value

      arel = arel.group(*@group_values.uniq.reject{|g| g.blank?}) unless @group_values.empty?

      arel = arel.order(*@order_values.uniq.reject{|o| o.blank?}) unless @order_values.empty?

      arel = build_select(arel, @select_values.uniq)

      arel = arel.from(@from_value) if @from_value
      arel = arel.lock(@lock_value) if @lock_value

      arel
    end

    private

    def collapse_wheres(arel, wheres)
      equalities = wheres.grep(Arel::Nodes::Equality)

      groups = equalities.group_by do |equality|
        equality.left
      end

      groups.each do |_, eqls|
        test = eqls.inject(eqls.shift) do |memo, expr|
          memo.or(expr)
        end
        arel = arel.where(test)
      end

      (wheres - equalities).each do |where|
        where = Arel.sql(where) if String === where
        arel = arel.where(Arel::Nodes::Grouping.new(where))
      end
      arel
    end

    def build_where(opts, other = [])
      case opts
      when String, Array
        [@klass.send(:sanitize_sql, other.empty? ? opts : ([opts] + other))]
      when Hash
        attributes = @klass.send(:expand_hash_conditions_for_aggregates, opts)
        PredicateBuilder.new(table.engine).build_from_hash(attributes, table)
      else
        [opts]
      end
    end

    def build_joins(relation, joins)
      association_joins = []

      joins = @joins_values.map {|j| j.respond_to?(:strip) ? j.strip : j}.uniq

      joins.each do |join|
        association_joins << join if [Hash, Array, Symbol].include?(join.class) && !array_of_strings?(join)
      end

      stashed_association_joins = joins.grep(ActiveRecord::Associations::ClassMethods::JoinDependency::JoinAssociation)

      non_association_joins = (joins - association_joins - stashed_association_joins)
      custom_joins = custom_join_sql(*non_association_joins)

      join_dependency = ActiveRecord::Associations::ClassMethods::JoinDependency.new(@klass, association_joins, custom_joins)

      join_dependency.graft(*stashed_association_joins)

      @implicit_readonly = true unless association_joins.empty? && stashed_association_joins.empty?

      to_join = []

      join_dependency.join_associations.each do |association|
        if (association_relation = association.relation).is_a?(Array)
          to_join << [association_relation.first, association.join_type, association.association_join.first]
          to_join << [association_relation.last, association.join_type, association.association_join.last]
        else
          to_join << [association_relation, association.join_type, association.association_join]
        end
      end

      to_join.uniq.each do |left, join_type, right|
        relation = relation.join(left, join_type).on(*right)
      end

      relation.join(custom_joins)
    end

    def build_select(arel, selects)
      unless selects.empty?
        @implicit_readonly = false
        arel.project(*selects)
      else
        arel.project(Arel::SqlLiteral.new(@klass.quoted_table_name + '.*'))
      end
    end

    def apply_modules(modules)
      unless modules.empty?
        @extensions += modules
        modules.each {|extension| extend(extension) }
      end
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
