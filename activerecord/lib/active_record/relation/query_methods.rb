require 'active_support/core_ext/array/wrap'
require 'active_support/core_ext/object/blank'

module ActiveRecord
  module QueryMethods
    extend ActiveSupport::Concern

    attr_accessor :includes_values, :eager_load_values, :preload_values,
                  :select_values, :group_values, :order_values, :joins_values,
                  :where_values, :having_values, :bind_values,
                  :limit_value, :offset_value, :lock_value, :readonly_value, :create_with_value,
                  :from_value, :reordering_value, :reverse_order_value,
                  :uniq_value

    def includes(*args)
      args.reject! {|a| a.blank? }

      return self if args.empty?

      relation = clone
      relation.includes_values = (relation.includes_values + args).flatten.uniq
      relation
    end

    def eager_load(*args)
      return self if args.blank?

      relation = clone
      relation.eager_load_values += args
      relation
    end

    def preload(*args)
      return self if args.blank?

      relation = clone
      relation.preload_values += args
      relation
    end

    # Works in two unique ways.
    #
    # First: takes a block so it can be used just like Array#select.
    #
    #   Model.scoped.select { |m| m.field == value }
    #
    # This will build an array of objects from the database for the scope,
    # converting them into an array and iterating through them using Array#select.
    #
    # Second: Modifies the SELECT statement for the query so that only certain
    # fields are retrieved:
    #
    #   >> Model.select(:field)
    #   => [#<Model field:value>]
    #
    # Although in the above example it looks as though this method returns an
    # array, it actually returns a relation object and can have other query
    # methods appended to it, such as the other methods in ActiveRecord::QueryMethods.
    #
    # The argument to the method can also be an array of fields.
    #
    #   >> Model.select([:field, :other_field, :and_one_more])
    #   => [#<Model field: "value", other_field: "value", and_one_more: "value">]
    #
    # Any attributes that do not have fields retrieved by a select
    # will raise a ActiveModel::MissingAttributeError when the getter method for that attribute is used:
    #
    #   >> Model.select(:field).first.other_field
    #   => ActiveModel::MissingAttributeError: missing attribute: other_field
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
      return self if args.blank?

      relation = clone
      relation.group_values += args.flatten
      relation
    end

    def order(*args)
      return self if args.blank?

      relation = clone
      relation.order_values += args.flatten
      relation
    end

    # Replaces any existing order defined on the relation with the specified order.
    #
    #   User.order('email DESC').reorder('id ASC') # generated SQL has 'ORDER BY id ASC'
    #
    # Subsequent calls to order on the same relation will be appended. For example:
    #
    #   User.order('email DESC').reorder('id ASC').order('name ASC')
    #
    # generates a query with 'ORDER BY id ASC, name ASC'.
    #
    def reorder(*args)
      return self if args.blank?

      relation = clone
      relation.reordering_value = true
      relation.order_values = args.flatten
      relation
    end

    def joins(*args)
      return self if args.compact.blank?

      relation = clone

      args.flatten!
      relation.joins_values += args

      relation
    end

    def bind(value)
      relation = clone
      relation.bind_values += [value]
      relation
    end

    def where(opts, *rest)
      return self if opts.blank?

      relation = clone
      relation.where_values += build_where(opts, rest)
      relation
    end

    def having(opts, *rest)
      return self if opts.blank?

      relation = clone
      relation.having_values += build_where(opts, rest)
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
      relation.create_with_value = value ? create_with_value.merge(value) : {}
      relation
    end

    def from(value)
      relation = clone
      relation.from_value = value
      relation
    end

    # Specifies whether the records should be unique or not. For example:
    #
    #   User.select(:name)
    #   # => Might return two records with the same name
    #
    #   User.select(:name).uniq
    #   # => Returns 1 record per unique name
    #
    #   User.select(:name).uniq.uniq(false)
    #   # => You can also remove the uniqueness
    def uniq(value = true)
      relation = clone
      relation.uniq_value = value
      relation
    end

    # Used to extend a scope with additional methods, either through
    # a module or through a block provided.
    #
    # The object returned is a relation, which can be further extended.
    #
    # === Using a module
    #
    #   module Pagination
    #     def page(number)
    #       # pagination code goes here
    #     end
    #   end
    #
    #   scope = Model.scoped.extending(Pagination)
    #   scope.page(params[:page])
    #
    # You can also pass a list of modules:
    #
    #   scope = Model.scoped.extending(Pagination, SomethingElse)
    #
    # === Using a block
    #
    #   scope = Model.scoped.extending do
    #     def page(number)
    #       # pagination code goes here
    #     end
    #   end
    #   scope.page(params[:page])
    #
    # You can also use a block and a module list:
    #
    #   scope = Model.scoped.extending(Pagination) do
    #     def per_page(number)
    #       # pagination code goes here
    #     end
    #   end
    def extending(*modules)
      modules << Module.new(&Proc.new) if block_given?

      return self if modules.empty?

      relation = clone
      relation.send(:apply_modules, modules.flatten)
      relation
    end

    def reverse_order
      relation = clone
      relation.reverse_order_value = !relation.reverse_order_value
      relation
    end

    def arel
      @arel ||= with_default_scope.build_arel
    end

    def build_arel
      arel = table.from table

      build_joins(arel, @joins_values) unless @joins_values.empty?

      collapse_wheres(arel, (@where_values - ['']).uniq)

      arel.having(*@having_values.uniq.reject{|h| h.blank?}) unless @having_values.empty?

      arel.take(connection.sanitize_limit(@limit_value)) if @limit_value
      arel.skip(@offset_value.to_i) if @offset_value

      arel.group(*@group_values.uniq.reject{|g| g.blank?}) unless @group_values.empty?

      order = @order_values
      order = reverse_sql_order(order) if @reverse_order_value
      arel.order(*order.uniq.reject{|o| o.blank?}) unless order.empty?

      build_select(arel, @select_values.uniq)

      arel.distinct(@uniq_value)
      arel.from(@from_value) if @from_value
      arel.lock(@lock_value) if @lock_value

      arel
    end

    private

    def custom_join_ast(table, joins)
      joins = joins.reject { |join| join.blank? }

      return [] if joins.empty?

      @implicit_readonly = true

      joins.map do |join|
        case join
        when Array
          join = Arel.sql(join.join(' ')) if array_of_strings?(join)
        when String
          join = Arel.sql(join)
        end
        table.create_string_join(join)
      end
    end

    def collapse_wheres(arel, wheres)
      equalities = wheres.grep(Arel::Nodes::Equality)

      arel.where(Arel::Nodes::And.new(equalities)) unless equalities.empty?

      (wheres - equalities).each do |where|
        where = Arel.sql(where) if String === where
        arel.where(Arel::Nodes::Grouping.new(where))
      end
    end

    def build_where(opts, other = [])
      case opts
      when String, Array
        [@klass.send(:sanitize_sql, other.empty? ? opts : ([opts] + other))]
      when Hash
        attributes = @klass.send(:expand_hash_conditions_for_aggregates, opts)
        PredicateBuilder.build_from_hash(table.engine, attributes, table)
      else
        [opts]
      end
    end

    def build_joins(manager, joins)
      buckets = joins.group_by do |join|
        case join
        when String
          'string_join'
        when Hash, Symbol, Array
          'association_join'
        when ActiveRecord::Associations::JoinDependency::JoinAssociation
          'stashed_join'
        when Arel::Nodes::Join
          'join_node'
        else
          raise 'unknown class: %s' % join.class.name
        end
      end

      association_joins         = buckets['association_join'] || []
      stashed_association_joins = buckets['stashed_join'] || []
      join_nodes                = (buckets['join_node'] || []).uniq
      string_joins              = (buckets['string_join'] || []).map { |x|
        x.strip
      }.uniq

      join_list = join_nodes + custom_join_ast(manager, string_joins)

      join_dependency = ActiveRecord::Associations::JoinDependency.new(
        @klass,
        association_joins,
        join_list
      )

      join_dependency.graft(*stashed_association_joins)

      @implicit_readonly = true unless association_joins.empty? && stashed_association_joins.empty?

      # FIXME: refactor this to build an AST
      join_dependency.join_associations.each do |association|
        association.join_to(manager)
      end

      manager.join_sources.concat join_list

      manager
    end

    def build_select(arel, selects)
      unless selects.empty?
        @implicit_readonly = false
        arel.project(*selects)
      else
        arel.project(@klass.arel_table[Arel.star])
      end
    end

    def apply_modules(modules)
      unless modules.empty?
        @extensions += modules
        modules.each {|extension| extend(extension) }
      end
    end

    def reverse_sql_order(order_query)
      order_query = ["#{quoted_table_name}.#{quoted_primary_key} ASC"] if order_query.empty?

      order_query.map do |o|
        case o
        when Arel::Nodes::Ordering
          o.reverse
        when String, Symbol
          o.to_s.split(',').collect do |s|
            s.strip!
            s.gsub!(/\sasc\Z/i, ' DESC') || s.gsub!(/\sdesc\Z/i, ' ASC') || s.concat(' DESC')
          end
        else
          o
        end
      end.flatten
    end

    def array_of_strings?(o)
      o.is_a?(Array) && o.all?{|obj| obj.is_a?(String)}
    end

  end
end
