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
        relation.select_values += [value]
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
      order_clause = arel.order_clauses

      order = order_clause.empty? ?
        "#{@klass.table_name}.#{@klass.primary_key} DESC" :
        reverse_sql_order(order_clause).join(', ')

      except(:order).order(Arel::SqlLiteral.new(order))
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
          sql = where.is_a?(String) ? where : where.to_sql(table.engine)
          arel = arel.where(Arel::SqlLiteral.new("(#{sql})"))
        end
      end

      arel = arel.having(*@having_values.uniq.reject{|h| h.blank?}) unless @having_values.empty?

      arel = arel.take(@limit_value) if @limit_value
      arel = arel.skip(@offset_value) if @offset_value

      arel = arel.group(*@group_values.uniq.reject{|g| g.blank?}) unless @group_values.empty?

      arel = arel.order(*@order_values.uniq.reject{|o| o.blank?}) unless @order_values.empty?

      arel = build_select(arel, @select_values.uniq)

      arel = arel.from(@from_value) if @from_value
      arel = arel.lock(@lock_value) if @lock_value

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

    private

    def build_joins(relation, joins)
      association_joins = []

      joins = joins.map {|j| j.respond_to?(:strip) ? j.strip : j}.uniq

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

      to_join.uniq.each do |left, join_class, right|
        relation = relation.join(left, join_class).on(*right)
      end

      relation.join(custom_joins)
    end

    def build_select(arel, selects)
      unless selects.empty?
        @implicit_readonly = false
        # TODO: fix this ugly hack, we should refactor the callers to get an Arel compatible array.
        # Before this change we were passing to Arel the last element only, and Arel is capable of handling an array
        case select = selects.last
        when Arel::Expression, Arel::SqlLiteral
          arel.project(select)
        when /^COUNT\(/
          arel.project(Arel::SqlLiteral.new(select))
        else
          arel.project(*selects)
        end
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
      order_query.join(', ').split(',').collect { |s|
        if s.match(/\s(asc|ASC)$/)
          s.gsub(/\s(asc|ASC)$/, ' DESC')
        elsif s.match(/\s(desc|DESC)$/)
          s.gsub(/\s(desc|DESC)$/, ' ASC')
        else
          s + ' DESC'
        end
      }
    end

    def array_of_strings?(o)
      o.is_a?(Array) && o.all?{|obj| obj.is_a?(String)}
    end

  end
end
