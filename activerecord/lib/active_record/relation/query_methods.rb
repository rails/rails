require 'active_support/core_ext/array/wrap'
require 'active_support/core_ext/object/blank'

module ActiveRecord
  module QueryMethods
    extend ActiveSupport::Concern

    attr_accessor :includes_values, :eager_load_values, :preload_values,
                  :select_values, :group_values, :order_values, :joins_values, :where_values, :having_values,
                  :limit_value, :offset_value, :lock_value, :readonly_value, :create_with_value, :from_value

    def includes(*args)
      args.reject! { |a| a.blank? }
      clone.tap {|r| r.includes_values += args if args.present? }
    end

    def eager_load(*args)
      clone.tap {|r| r.eager_load_values += args if args.present? }
    end

    def preload(*args)
      clone.tap {|r| r.preload_values += args if args.present? }
    end

    def select(*args)
      if block_given?
        to_a.select {|*block_args| yield(*block_args) }
      else
        clone.tap {|r| r.select_values += args if args.present? }
      end
    end

    def group(*args)
      clone.tap {|r| r.group_values += args if args.present? }
    end

    def order(*args)
      clone.tap {|r| r.order_values += args if args.present? }
    end

    def reorder(*args)
      clone.tap {|r| r.order_values = args if args.present? }
    end

    def joins(*args)
      args.flatten!
      clone.tap {|r| r.joins_values += args if args.present? }
    end

    def where(*args)
      value = build_where(*args)
      clone.tap {|r| r.where_values += Array.wrap(value) if value.present? }
    end

    def having(*args)
      value = build_where(*args)
      clone.tap {|r| r.having_values += Array.wrap(value) if value.present? }
    end

    def limit(value = true)
      clone.tap {|r| r.limit_value = value }
    end

    def offset(value = true)
      clone.tap {|r| r.offset_value = value }
    end

    def lock(locks = true)
      case locks
      when String, TrueClass, NilClass
        clone.tap {|r| r.lock_value = locks || true }
      else
        clone.tap {|r| r.lock_value = false }
      end
    end

    def readonly(value = true)
      clone.tap {|r| r.readonly_value = value }
    end

    def create_with(value = true)
      clone.tap {|r| r.create_with_value = value }
    end

    def from(value = true)
      clone.tap {|r| r.from_value = value }
    end

    def extending(*modules, &block)
      modules << Module.new(&block) if block_given?
      clone.tap {|r| r.send(:apply_modules, *modules) }
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

      arel = build_joins(arel, @joins_values) if @joins_values.present?

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

      arel = arel.having(*@having_values.uniq.select{|h| h.present?}) if @having_values.present?

      arel = arel.take(@limit_value) if @limit_value.present?
      arel = arel.skip(@offset_value) if @offset_value.present?

      arel = arel.group(*@group_values.uniq.select{|g| g.present?}) if @group_values.present?

      arel = arel.order(*@order_values.uniq.select{|o| o.present?}) if @order_values.present?

      arel = build_select(arel, @select_values.uniq)

      arel = arel.from(@from_value) if @from_value.present?

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

    def build_joins(relation, joins)
      joined_associations = []
      association_joins = []

      joins = @joins_values.map {|j| j.respond_to?(:strip) ? j.strip : j}.uniq

      joins.each do |join|
        association_joins << join if [Hash, Array, Symbol].include?(join.class) && !array_of_strings?(join)
      end

      stashed_association_joins = joins.select {|j| j.is_a?(ActiveRecord::Associations::ClassMethods::JoinDependency::JoinAssociation)}

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
      if selects.present?
        @implicit_readonly = false
        # TODO: fix this ugly hack, we should refactor the callers to get an ARel compatible array.
        # Before this change we were passing to ARel the last element only, and ARel is capable of handling an array
        if selects.all? {|s| s.is_a?(String) || !s.is_a?(Arel::Expression) } && !(selects.last =~ /^COUNT\(/)
          arel.project(*selects)
        else
          arel.project(selects.last)
        end
      else
        arel.project(@klass.quoted_table_name + '.*')
      end
    end

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
