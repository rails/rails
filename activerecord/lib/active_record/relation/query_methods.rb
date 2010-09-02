require 'active_support/core_ext/array/wrap'
require 'active_support/core_ext/object/blank'

module ActiveRecord
  module QueryMethods
    extend ActiveSupport::Concern

    attr_accessor :includes_values, :eager_load_values, :preload_values,
                  :select_values, :group_values, :order_values, :joins_values, :where_values, :having_values,
                  :limit_value, :offset_value, :lock_value, :readonly_value, :create_with_value, :from_value

    def includes(*args)
      args.reject! {|a| a.blank? }

      relation = clone
      relation.includes_values = (relation.includes_values + args).flatten.uniq if args.present?
      relation
    end

    def eager_load(*args)
      relation = clone
      relation.eager_load_values += args if args.present?
      relation
    end

    def preload(*args)
      relation = clone
      relation.preload_values += args if args.present?
      relation
    end

    def select(*args)
      if block_given?
        to_a.select {|*block_args| yield(*block_args) }
      else
        relation = clone
        relation.select_values += args if args.present?
        relation
      end
    end

    def group(*args)
      relation = clone
      relation.group_values += args.flatten if args.present?
      relation
    end

    def order(*args)
      relation = clone
      relation.order_values += args.flatten if args.present?
      relation
    end

    def reorder(*args)
      relation = clone
      relation.order_values = args if args.present?
      relation
    end

    def joins(*args)
      relation = clone

      if args.present?
        args.flatten!
        relation.joins_values += args if args.present?
      end

      relation
    end

    def where(opts, *rest)
      relation = clone

      if opts.present? && value = build_where(opts, rest)
        relation.where_values += Array.wrap(value)
      end

      relation
    end

    def having(*args)
      relation = clone

      if args.present? && value = build_where(*args)
        relation.having_values += Array.wrap(value)
      end

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
      relation.send(:apply_modules, *modules)
      relation
    end

    def reverse_order
      order_clause = arel.order_clauses.join(', ')
      relation = except(:order)

      order = order_clause.blank? ?
        "#{@klass.table_name}.#{@klass.primary_key} DESC" :
        reverse_sql_order(order_clause)

      relation.order(Arel::SqlLiteral.new(order))
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
            arel = arel.join(Arel::SqlLiteral.new(join_string))
          end
        when String
          arel = arel.join(Arel::SqlLiteral.new(join))
        else
          arel = arel.join(join)
        end
      end

      arel.joins(arel)
    end

    def build_arel
      arel = table

      arel = build_joins(arel, @joins_values) unless @joins_values.empty?

      (@where_values - ['']).uniq.each do |where|
        case where
        when Arel::SqlLiteral
          arel = arel.where(where)
        else
          sql = where.is_a?(String) ? where : where.to_sql
          arel = arel.where(Arel::SqlLiteral.new("(#{sql})"))
        end
      end

      arel = arel.having(*@having_values.uniq.select{|h| h.present?}) unless @having_values.empty?

      arel = arel.take(@limit_value) if @limit_value
      arel = arel.skip(@offset_value) if @offset_value

      arel = arel.group(*@group_values.uniq.select{|g| g.present?}) unless @group_values.empty?

      arel = arel.order(*@order_values.uniq.select{|o| o.present?}) unless @order_values.empty?

      arel = build_select(arel, @select_values.uniq)

      arel = arel.from(@from_value) if @from_value
      arel = arel.lock(@lock_value) if @lock_value

      arel
    end

    def build_where(opts, other = [])
      case opts
      when String, Array
        @klass.send(:sanitize_sql, other.empty? ? opts : ([opts] + other))
      when Hash
        attributes = @klass.send(:expand_hash_conditions_for_aggregates, opts)
        PredicateBuilder.new(table.engine).build_from_hash(attributes, table)
      else
        opts
      end
    end

    private

    def build_joins(relation, joins)
      joined_associations = []
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
          to_join << [association_relation.first, association.join_class, association.association_join.first]
          to_join << [association_relation.last, association.join_class, association.association_join.last]
        else
          to_join << [association_relation, association.join_class, association.association_join]
        end
      end

      to_join.each do |tj|
        unless joined_associations.detect {|ja| ja[0] == tj[0] && ja[1] == tj[1] && ja[2] == tj[2] }
          joined_associations << tj
          relation = relation.join(tj[0], tj[1]).on(*tj[2])
        end
      end

      relation.join(custom_joins)
    end

    def build_select(arel, selects)
      unless selects.empty?
        @implicit_readonly = false
        # TODO: fix this ugly hack, we should refactor the callers to get an ARel compatible array.
        # Before this change we were passing to ARel the last element only, and ARel is capable of handling an array
        if selects.all? {|s| s.is_a?(String) || !s.is_a?(Arel::Expression) } && !(selects.last =~ /^COUNT\(/)
          arel.project(*selects)
        else
          arel.project(selects.last)
        end
      else
        arel.project(Arel::SqlLiteral.new(@klass.quoted_table_name + '.*'))
      end
    end

    def apply_modules(modules)
      values = Array.wrap(modules)
      @extensions += values if values.present?
      values.each {|extension| extend(extension) }
    end

    def reverse_sql_order(order_query)
      order_query.split(',').each { |s|
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
