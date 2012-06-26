require 'active_support/core_ext/array/wrap'
require 'active_support/core_ext/object/blank'

module ActiveRecord
  module QueryMethods
    extend ActiveSupport::Concern

    Relation::MULTI_VALUE_METHODS.each do |name|
      class_eval <<-CODE, __FILE__, __LINE__ + 1
        def #{name}_values                   # def select_values
          @values[:#{name}] || []            #   @values[:select] || []
        end                                  # end
                                             #
        def #{name}_values=(values)          # def select_values=(values)
          raise ImmutableRelation if @loaded #   raise ImmutableRelation if @loaded
          @values[:#{name}] = values         #   @values[:select] = values
        end                                  # end
      CODE
    end

    (Relation::SINGLE_VALUE_METHODS - [:create_with]).each do |name|
      class_eval <<-CODE, __FILE__, __LINE__ + 1
        def #{name}_value                    # def readonly_value
          @values[:#{name}]                  #   @values[:readonly]
        end                                  # end
      CODE
    end

    Relation::SINGLE_VALUE_METHODS.each do |name|
      class_eval <<-CODE, __FILE__, __LINE__ + 1
        def #{name}_value=(value)            # def readonly_value=(value)
          raise ImmutableRelation if @loaded #   raise ImmutableRelation if @loaded
          @values[:#{name}] = value          #   @values[:readonly] = value
        end                                  # end
      CODE
    end

    def create_with_value
      @values[:create_with] || {}
    end

    alias extensions extending_values

    def includes(*args)
      args.empty? ? self : spawn.includes!(*args)
    end

    def includes!(*args)
      args.reject! {|a| a.blank? }

      self.includes_values = (includes_values + args).flatten.uniq
      self
    end

    def eager_load(*args)
      args.blank? ? self : spawn.eager_load!(*args)
    end

    def eager_load!(*args)
      self.eager_load_values += args
      self
    end

    def preload(*args)
      args.blank? ? self : spawn.preload!(*args)
    end

    def preload!(*args)
      self.preload_values += args
      self
    end

    # Used to indicate that an association is referenced by an SQL string, and should
    # therefore be JOINed in any query rather than loaded separately.
    #
    #   User.includes(:posts).where("posts.name = 'foo'")
    #   # => Doesn't JOIN the posts table, resulting in an error.
    #
    #   User.includes(:posts).where("posts.name = 'foo'").references(:posts)
    #   # => Query now knows the string references posts, so adds a JOIN
    def references(*args)
      args.blank? ? self : spawn.references!(*args)
    end

    def references!(*args)
      args.flatten!

      self.references_values = (references_values + args.map!(&:to_s)).uniq
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
        spawn.select!(value)
      end
    end

    def select!(value)
      self.select_values += Array.wrap(value)
      self
    end

    def group(*args)
      args.blank? ? self : spawn.group!(*args)
    end

    def group!(*args)
      args.flatten!

      self.group_values += args
      self
    end

    def order(*args)
      args.blank? ? self : spawn.order!(*args)
    end

    def order!(*args)
      args.flatten!

      references = args.reject { |arg| Arel::Node === arg }
      references.map! { |arg| arg =~ /^([a-zA-Z]\w*)\.(\w+)/ && $1 }.compact!
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
    def reorder(*args)
      args.blank? ? self : spawn.reorder!(*args)
    end

    def reorder!(*args)
      args.flatten!

      self.reordering_value = true
      self.order_values = args
      self
    end

    def joins(*args)
      args.compact.blank? ? self : spawn.joins!(*args)
    end

    def joins!(*args)
      args.flatten!

      self.joins_values += args
      self
    end

    def bind(value)
      spawn.bind!(value)
    end

    def bind!(value)
      self.bind_values += [value]
      self
    end

    # Returns a new relation, which is the result of filtering the current relation
    # according to the conditions in the arguments.
    #
    # #where accepts conditions in one of several formats. In the examples below, the resulting
    # SQL is given as an illustration; the actual query generated may be different depending
    # on the database adapter.
    #
    # === string
    #
    # A single string, without additional arguments, is passed to the query
    # constructor as a SQL fragment, and used in the where clause of the query.
    #
    #    Client.where("orders_count = '2'")
    #    # SELECT * from clients where orders_count = '2';
    #
    # Note that building your own string from user input may expose your application
    # to injection attacks if not done properly. As an alternative, it is recommended
    # to use one of the following methods.
    #
    # === array
    #
    # If an array is passed, then the first element of the array is treated as a template, and
    # the remaining elements are inserted into the template to generate the condition.
    # Active Record takes care of building the query to avoid injection attacks, and will
    # convert from the ruby type to the database type where needed. Elements are inserted
    # into the string in the order in which they appear.
    #
    #   User.where(["name = ? and email = ?", "Joe", "joe@example.com"])
    #   # SELECT * FROM users WHERE name = 'Joe' AND email = 'joe@example.com';
    #
    # Alternatively, you can use named placeholders in the template, and pass a hash as the
    # second element of the array. The names in the template are replaced with the corresponding
    # values from the hash.
    #
    #   User.where(["name = :name and email = :email", { name: "Joe", email: "joe@example.com" }])
    #   # SELECT * FROM users WHERE name = 'Joe' AND email = 'joe@example.com';
    #
    # This can make for more readable code in complex queries.
    #
    # Lastly, you can use sprintf-style % escapes in the template. This works slightly differently
    # than the previous methods; you are responsible for ensuring that the values in the template
    # are properly quoted. The values are passed to the connector for quoting, but the caller
    # is responsible for ensuring they are enclosed in quotes in the resulting SQL. After quoting,
    # the values are inserted using the same escapes as the Ruby core method <tt>Kernel::sprintf</tt>.
    #
    #   User.where(["name = '%s' and email = '%s'", "Joe", "joe@example.com"])
    #   # SELECT * FROM users WHERE name = 'Joe' AND email = 'joe@example.com';
    #
    # If #where is called with multiple arguments, these are treated as if they were passed as
    # the elements of a single array.
    #
    #   User.where("name = :name and email = :email", { name: "Joe", email: "joe@example.com" })
    #   # SELECT * FROM users WHERE name = 'Joe' AND email = 'joe@example.com';
    #
    # When using strings to specify conditions, you can use any operator available from
    # the database. While this provides the most flexibility, you can also unintentionally introduce
    # dependencies on the underlying database. If your code is intended for general consumption,
    # test with multiple database backends.
    #
    # === hash
    #
    # #where will also accept a hash condition, in which the keys are fields and the values
    # are values to be searched for.
    #
    # Fields can be symbols or strings. Values can be single values, arrays, or ranges.
    #
    #    User.where({ name: "Joe", email: "joe@example.com" })
    #    # SELECT * FROM users WHERE name = 'Joe' AND email = 'joe@example.com'
    #
    #    User.where({ name: ["Alice", "Bob"]})
    #    # SELECT * FROM users WHERE name IN ('Alice', 'Bob')
    #
    #    User.where({ created_at: (Time.now.midnight - 1.day)..Time.now.midnight })
    #    # SELECT * FROM users WHERE (created_at BETWEEN '2012-06-09 07:00:00.000000' AND '2012-06-10 07:00:00.000000')
    #
    # === Joins
    #
    # If the relation is the result of a join, you may create a condition which uses any of the
    # tables in the join. For string and array conditions, use the table name in the condition.
    #
    #    User.joins(:posts).where("posts.created_at < ?", Time.now)
    #
    # For hash conditions, you can either use the table name in the key, or use a sub-hash.
    #
    #    User.joins(:posts).where({ "posts.published" => true })
    #    User.joins(:posts).where({ :posts => { :published => true } })
    #
    # === empty condition
    #
    # If the condition returns true for blank?, then where is a no-op and returns the current relation.
    def where(opts, *rest)
      opts.blank? ? self : spawn.where!(opts, *rest)
    end

    # #where! is identical to #where, except that instead of returning a new relation, it adds
    # the condition to the existing relation.
    def where!(opts, *rest)
      references!(PredicateBuilder.references(opts)) if Hash === opts

      self.where_values += build_where(opts, rest)
      self
    end

    def having(opts, *rest)
      opts.blank? ? self : spawn.having!(opts, *rest)
    end

    def having!(opts, *rest)
      references!(PredicateBuilder.references(opts)) if Hash === opts

      self.having_values += build_where(opts, rest)
      self
    end

    # Specifies a limit for the number of records to retrieve.
    #
    #   User.limit(10) # generated SQL has 'LIMIT 10'
    #
    #   User.limit(10).limit(20) # generated SQL has 'LIMIT 20'
    def limit(value)
      spawn.limit!(value)
    end

    def limit!(value)
      self.limit_value = value
      self
    end

    # Specifies the number of rows to skip before returning rows.
    #
    #   User.offset(10) # generated SQL has "OFFSET 10"
    #
    # Should be used with order.
    #
    #   User.offset(10).order("name ASC")
    def offset(value)
      spawn.offset!(value)
    end

    def offset!(value)
      self.offset_value = value
      self
    end

    def lock(locks = true)
      spawn.lock!(locks)
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
      scoped.extending(NullRelation)
    end

    def readonly(value = true)
      spawn.readonly!(value)
    end

    def readonly!(value = true)
      self.readonly_value = value
      self
    end

    def create_with(value)
      spawn.create_with!(value)
    end

    def create_with!(value)
      self.create_with_value = value ? create_with_value.merge(value) : {}
      self
    end

    # Specifies table from which the records will be fetched. For example:
    #
    #   Topic.select('title').from('posts')
    #   #=> SELECT title FROM posts
    #
    # Can accept other relation objects. For example:
    #
    #   Topic.select('title').from(Topics.approved)
    #   # => SELECT title FROM (SELECT * FROM topics WHERE approved = 't') subquery
    #
    #   Topics.select('a.title').from(Topics.approved, :a)
    #   # => SELECT a.title FROM (SELECT * FROM topics WHERE approved = 't') a
    #
    def from(value, subquery_name = nil)
      spawn.from!(value, subquery_name)
    end

    def from!(value, subquery_name = nil)
      self.from_value = [value, subquery_name]
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
      spawn.uniq!(value)
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
        spawn.extending!(*modules, &block)
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

    # Reverse the existing order clause on the relation.
    #
    #   User.order('name ASC').reverse_order # generated SQL has 'ORDER BY name DESC'
    def reverse_order
      spawn.reverse_order!
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

      build_joins(arel, joins_values) unless joins_values.empty?

      collapse_wheres(arel, (where_values - ['']).uniq)

      arel.having(*having_values.uniq.reject{|h| h.blank?}) unless having_values.empty?

      arel.take(connection.sanitize_limit(limit_value)) if limit_value
      arel.skip(offset_value.to_i) if offset_value

      arel.group(*group_values.uniq.reject{|g| g.blank?}) unless group_values.empty?

      order = order_values
      order = reverse_sql_order(order) if reverse_order_value
      arel.order(*order.uniq.reject{|o| o.blank?}) unless order.empty?

      build_select(arel, select_values.uniq)

      arel.distinct(uniq_value)
      arel.from(build_from) if from_value
      arel.lock(lock_value) if lock_value

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
        PredicateBuilder.build_from_hash(table.engine, opts, table)
      else
        [opts]
      end
    end

    def build_from
      opts, name = from_value
      case opts
      when Relation
        name ||= 'subquery'
        opts.arel.as(name.to_s)
      else
        opts
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
