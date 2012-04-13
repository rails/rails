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
                  :uniq_value, :references_values, :extending_values

    alias extensions extending_values

    def includes(*args)
      args.empty? ? self : clone.includes!(*args)
    end

    def includes!(*args)
      args.reject! {|a| a.blank? }

      self.includes_values = (includes_values + args).flatten.uniq
      self
    end

    def eager_load(*args)
      args.blank? ? self : clone.eager_load!(*args)
    end

    def eager_load!(*args)
      self.eager_load_values += args
      self
    end

    def preload(*args)
      args.blank? ? self : clone.preload!(*args)
    end

    def preload!(*args)
      self.preload_values += args
      self
    end

    # Used to indicate that an association is referenced by an SQL string, and should
    # therefore be JOINed in any query rather than loaded separately.
    #
    # For example:
    #
    #   User.includes(:posts).where("posts.name = 'foo'")
    #   # => Doesn't JOIN the posts table, resulting in an error.
    #
    #   User.includes(:posts).where("posts.name = 'foo'").references(:posts)
    #   # => Query now knows the string references posts, so adds a JOIN
    def references(*args)
      args.blank? ? self : clone.references!(*args)
    end

    def references!(*args)
      self.references_values = (references_values + args.flatten.map(&:to_s)).uniq
      self
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
    # Accessing attributes of an object that do not have fields retrieved by a select
    # will throw <tt>ActiveModel::MissingAttributeError</tt>:
    #
    #   >> Model.select(:field).first.other_field
    #   => ActiveModel::MissingAttributeError: missing attribute: other_field
    def select(value = Proc.new)
      if block_given?
        to_a.select { |*block_args| value.call(*block_args) }
      else
        clone.select!(value)
      end
    end

    def select!(value = Proc.new)
      if block_given?
        # TODO: test
        to_a.select! { |*block_args| value.call(*block_args) }
      else
        self.select_values += Array.wrap(value)
        self
      end
    end

    def group(*args)
      args.blank? ? self : clone.group!(*args)
    end

    def group!(*args)
      self.group_values += args.flatten
      self
    end

    def order(*args)
      args.blank? ? self : clone.order!(*args)
    end

    def order!(*args)
      args       = args.flatten

      references = args.reject { |arg| Arel::Node === arg }
                       .map { |arg| arg =~ /^([a-zA-Z]\w*)\.(\w+)/ && $1 }
                       .compact
      references!(references) if references.any?

      self.order_values += args
      self
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
      args.blank? ? self : clone.reorder!(*args)
    end

    def reorder!(*args)
      self.reordering_value = true
      self.order_values = args.flatten
      self
    end

    def joins(*args)
      args.compact.blank? ? self : clone.joins!(*args)
    end

    def joins!(*args)
      args.flatten!

      self.joins_values += args
      self
    end

    def bind(value)
      clone.bind!(value)
    end

    def bind!(value)
      self.bind_values += [value]
      self
    end

    def where(opts, *rest)
      opts.blank? ? self : clone.where!(opts, *rest)
    end

    def where!(opts, *rest)
      references!(PredicateBuilder.references(opts)) if Hash === opts

      self.where_values += build_where(opts, rest)
      self
    end

    def having(opts, *rest)
      opts.blank? ? self : clone.having!(opts, *rest)
    end

    def having!(opts, *rest)
      references!(PredicateBuilder.references(opts)) if Hash === opts

      self.having_values += build_where(opts, rest)
      self
    end

    def limit(value)
      clone.limit!(value)
    end

    def limit!(value)
      self.limit_value = value
      self
    end

    def offset(value)
      clone.offset!(value)
    end

    def offset!(value)
      self.offset_value = value
      self
    end

    def lock(locks = true)
      clone.lock!(locks)
    end

    def lock!(locks = true)
      case locks
      when String, TrueClass, NilClass
        self.lock_value = locks || true
      else
        self.lock_value = false
      end

      self
    end

    # Returns a chainable relation with zero records, specifically an
    # instance of the NullRelation class.
    #
    # The returned NullRelation inherits from Relation and implements the
    # Null Object pattern so it is an object with defined null behavior:
    # it always returns an empty array of records and does not query the database.
    #
    # Any subsequent condition chained to the returned relation will continue
    # generating an empty relation and will not fire any query to the database.
    #
    # Used in cases where a method or scope could return zero records but the
    # result needs to be chainable.
    #
    # For example:
    #
    #   @posts = current_user.visible_posts.where(:name => params[:name])
    #   # => the visible_posts method is expected to return a chainable Relation
    #
    #   def visible_posts
    #     case role
    #     when 'Country Manager'
    #       Post.where(:country => country)
    #     when 'Reviewer'
    #       Post.published
    #     when 'Bad User'
    #       Post.none # => returning [] instead breaks the previous code
    #     end
    #   end
    #
    def none
      NullRelation.new(@klass, @table)
    end

    def readonly(value = true)
      clone.readonly!(value)
    end

    def readonly!(value = true)
      self.readonly_value = value
      self
    end

    def create_with(value)
      clone.create_with!(value)
    end

    def create_with!(value)
      self.create_with_value = value ? create_with_value.merge(value) : {}
      self
    end

    def from(value)
      clone.from!(value)
    end

    def from!(value)
      self.from_value = value
      self
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
      clone.uniq!(value)
    end

    def uniq!(value = true)
      self.uniq_value = value
      self
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
    def extending(*modules, &block)
      if modules.any? || block
        clone.extending!(*modules, &block)
      else
        self
      end
    end

    def extending!(*modules, &block)
      modules << Module.new(&block) if block_given?

      self.extending_values = modules.flatten
      extend(*extending_values) if extending_values.any?

      self
    end

    def reverse_order
      clone.reverse_order!
    end

    def reverse_order!
      self.reverse_order_value = !reverse_order_value
      self
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
