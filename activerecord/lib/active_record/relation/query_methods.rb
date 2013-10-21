require 'active_support/core_ext/array/wrap'

module ActiveRecord
  module QueryMethods
    extend ActiveSupport::Concern

    # WhereChain objects act as placeholder for queries in which #where does not have any parameter.
    # In this case, #where must be chained with #not to return a new relation.
    class WhereChain
      def initialize(scope)
        @scope = scope
      end

      # Returns a new relation expressing WHERE + NOT condition according to
      # the conditions in the arguments.
      #
      # +not+ accepts conditions as a string, array, or hash. See #where for
      # more details on each format.
      #
      #    User.where.not("name = 'Jon'")
      #    # SELECT * FROM users WHERE NOT (name = 'Jon')
      #
      #    User.where.not(["name = ?", "Jon"])
      #    # SELECT * FROM users WHERE NOT (name = 'Jon')
      #
      #    User.where.not(name: "Jon")
      #    # SELECT * FROM users WHERE name != 'Jon'
      #
      #    User.where.not(name: nil)
      #    # SELECT * FROM users WHERE name IS NOT NULL
      #
      #    User.where.not(name: %w(Ko1 Nobu))
      #    # SELECT * FROM users WHERE name NOT IN ('Ko1', 'Nobu')
      #
      #    User.where.not(name: "Jon", role: "admin")
      #    # SELECT * FROM users WHERE name != 'Jon' AND role != 'admin'
      def not(opts, *rest)
        where_value = @scope.send(:build_where, opts, rest).map do |rel|
          case rel
          when Arel::Nodes::In
            Arel::Nodes::NotIn.new(rel.left, rel.right)
          when Arel::Nodes::Equality
            Arel::Nodes::NotEqual.new(rel.left, rel.right)
          when String
            Arel::Nodes::Not.new(Arel::Nodes::SqlLiteral.new(rel))
          else
            Arel::Nodes::Not.new(rel)
          end
        end
        @scope.where_values += where_value
        @scope
      end
    end

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

    def create_with_value # :nodoc:
      @values[:create_with] || {}
    end

    alias extensions extending_values

    # Specify relationships to be included in the result set. For
    # example:
    #
    #   users = User.includes(:address)
    #   users.each do |user|
    #     user.address.city
    #   end
    #
    # allows you to access the +address+ attribute of the +User+ model without
    # firing an additional query. This will often result in a
    # performance improvement over a simple +join+.
    #
    # === conditions
    #
    # If you want to add conditions to your included models you'll have
    # to explicitly reference them. For example:
    #
    #   User.includes(:posts).where('posts.name = ?', 'example')
    #
    # Will throw an error, but this will work:
    #
    #   User.includes(:posts).where('posts.name = ?', 'example').references(:posts)
    def includes(*args)
      check_if_method_has_arguments!("includes", args)
      spawn.includes!(*args)
    end

    def includes!(*args) # :nodoc:
      args.reject! {|a| a.blank? }

      self.includes_values = (includes_values + args).flatten.uniq
      self
    end

    # Forces eager loading by performing a LEFT OUTER JOIN on +args+:
    #
    #   User.eager_load(:posts)
    #   => SELECT "users"."id" AS t0_r0, "users"."name" AS t0_r1, ...
    #   FROM "users" LEFT OUTER JOIN "posts" ON "posts"."user_id" =
    #   "users"."id"
    def eager_load(*args)
      check_if_method_has_arguments!("eager_load", args)
      spawn.eager_load!(*args)
    end

    def eager_load!(*args) # :nodoc:
      self.eager_load_values += args
      self
    end

    # Allows preloading of +args+, in the same way that +includes+ does:
    #
    #   User.preload(:posts)
    #   => SELECT "posts".* FROM "posts" WHERE "posts"."user_id" IN (1, 2, 3)
    def preload(*args)
      check_if_method_has_arguments!("preload", args)
      spawn.preload!(*args)
    end

    def preload!(*args) # :nodoc:
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
      check_if_method_has_arguments!("references", args)
      spawn.references!(*args)
    end

    def references!(*args) # :nodoc:
      args.flatten!

      self.references_values = (references_values + args.map!(&:to_s)).uniq
      self
    end

    # Works in two unique ways.
    #
    # First: takes a block so it can be used just like Array#select.
    #
    #   Model.all.select { |m| m.field == value }
    #
    # This will build an array of objects from the database for the scope,
    # converting them into an array and iterating through them using Array#select.
    #
    # Second: Modifies the SELECT statement for the query so that only certain
    # fields are retrieved:
    #
    #   Model.select(:field)
    #   # => [#<Model field:value>]
    #
    # Although in the above example it looks as though this method returns an
    # array, it actually returns a relation object and can have other query
    # methods appended to it, such as the other methods in ActiveRecord::QueryMethods.
    #
    # The argument to the method can also be an array of fields.
    #
    #   Model.select(:field, :other_field, :and_one_more)
    #   # => [#<Model field: "value", other_field: "value", and_one_more: "value">]
    #
    # You can also use one or more strings, which will be used unchanged as SELECT fields.
    #
    #   Model.select('field AS field_one', 'other_field AS field_two')
    #   # => [#<Model field: "value", other_field: "value">]
    #
    # If an alias was specified, it will be accessible from the resulting objects:
    #
    #   Model.select('field AS field_one').first.field_one
    #   # => "value"
    #
    # Accessing attributes of an object that do not have fields retrieved by a select
    # will throw <tt>ActiveModel::MissingAttributeError</tt>:
    #
    #   Model.select(:field).first.other_field
    #   # => ActiveModel::MissingAttributeError: missing attribute: other_field
    def select(*fields)
      if block_given?
        to_a.select { |*block_args| yield(*block_args) }
      else
        raise ArgumentError, 'Call this with at least one field' if fields.empty?
        spawn.select!(*fields)
      end
    end

    def select!(*fields) # :nodoc:
      self.select_values += fields.flatten
      self
    end

    # Allows to specify a group attribute:
    #
    #   User.group(:name)
    #   => SELECT "users".* FROM "users" GROUP BY name
    #
    # Returns an array with distinct records based on the +group+ attribute:
    #
    #   User.select([:id, :name])
    #   => [#<User id: 1, name: "Oscar">, #<User id: 2, name: "Oscar">, #<User id: 3, name: "Foo">
    #
    #   User.group(:name)
    #   => [#<User id: 3, name: "Foo", ...>, #<User id: 2, name: "Oscar", ...>]
    #
    #   User.group('name AS grouped_name, age')
    #   => [#<User id: 3, name: "Foo", age: 21, ...>, #<User id: 2, name: "Oscar", age: 21, ...>, #<User id: 5, name: "Foo", age: 23, ...>]
    def group(*args)
      check_if_method_has_arguments!("group", args)
      spawn.group!(*args)
    end

    def group!(*args) # :nodoc:
      args.flatten!

      self.group_values += args
      self
    end

    # Allows to specify an order attribute:
    #
    #   User.order('name')
    #   => SELECT "users".* FROM "users" ORDER BY name
    #
    #   User.order('name DESC')
    #   => SELECT "users".* FROM "users" ORDER BY name DESC
    #
    #   User.order('name DESC, email')
    #   => SELECT "users".* FROM "users" ORDER BY name DESC, email
    #
    #   User.order(:name)
    #   => SELECT "users".* FROM "users" ORDER BY "users"."name" ASC
    #
    #   User.order(email: :desc)
    #   => SELECT "users".* FROM "users" ORDER BY "users"."email" DESC
    #
    #   User.order(:name, email: :desc)
    #   => SELECT "users".* FROM "users" ORDER BY "users"."name" ASC, "users"."email" DESC
    def order(*args)
      check_if_method_has_arguments!("order", args)
      spawn.order!(*args)
    end

    def order!(*args) # :nodoc:
      args.flatten!
      validate_order_args args

      references = args.reject { |arg| Arel::Node === arg }
      references.map! { |arg| arg =~ /^([a-zA-Z]\w*)\.(\w+)/ && $1 }.compact!
      references!(references) if references.any?

      # if a symbol is given we prepend the quoted table name
      args = args.map! { |arg|
        arg.is_a?(Symbol) ?
          Arel::Nodes::Ascending.new(klass.arel_table[arg]) :
          arg
      }

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
      check_if_method_has_arguments!("reorder", args)
      spawn.reorder!(*args)
    end

    def reorder!(*args) # :nodoc:
      args.flatten!
      validate_order_args args

      self.reordering_value = true
      self.order_values = args
      self
    end

    VALID_UNSCOPING_VALUES = Set.new([:where, :select, :group, :order, :lock,
                                     :limit, :offset, :joins, :includes, :from,
                                     :readonly, :having])

    # Removes an unwanted relation that is already defined on a chain of relations.
    # This is useful when passing around chains of relations and would like to
    # modify the relations without reconstructing the entire chain.
    #
    #   User.order('email DESC').unscope(:order) == User.all
    #
    # The method arguments are symbols which correspond to the names of the methods
    # which should be unscoped. The valid arguments are given in VALID_UNSCOPING_VALUES.
    # The method can also be called with multiple arguments. For example:
    #
    #   User.order('email DESC').select('id').where(name: "John")
    #       .unscope(:order, :select, :where) == User.all
    #
    # One can additionally pass a hash as an argument to unscope specific :where values.
    # This is done by passing a hash with a single key-value pair. The key should be
    # :where and the value should be the where value to unscope. For example:
    #
    #   User.where(name: "John", active: true).unscope(where: :name)
    #       == User.where(active: true)
    #
    # Note that this method is more generalized than ActiveRecord::SpawnMethods#except
    # because #except will only affect a particular relation's values. It won't wipe
    # the order, grouping, etc. when that relation is merged. For example:
    #
    #   Post.comments.except(:order)
    #
    # will still have an order if it comes from the default_scope on Comment.
    def unscope(*args)
      check_if_method_has_arguments!("unscope", args)
      spawn.unscope!(*args)
    end

    def unscope!(*args) # :nodoc:
      args.flatten!

      args.each do |scope|
        case scope
        when Symbol
          symbol_unscoping(scope)
        when Hash
          scope.each do |key, target_value|
            if key != :where
              raise ArgumentError, "Hash arguments in .unscope(*args) must have :where as the key."
            end

            Array(target_value).each do |val|
              where_unscoping(val)
            end
          end
        else
          raise ArgumentError, "Unrecognized scoping: #{args.inspect}. Use .unscope(where: :attribute_name) or .unscope(:order), for example."
        end
      end

      self
    end

    # Performs a joins on +args+:
    #
    #   User.joins(:posts)
    #   => SELECT "users".* FROM "users" INNER JOIN "posts" ON "posts"."user_id" = "users"."id"
    #
    # You can use strings in order to customize your joins:
    #
    #   User.joins("LEFT JOIN bookmarks ON bookmarks.bookmarkable_type = 'Post' AND bookmarks.user_id = users.id")
    #   => SELECT "users".* FROM "users" LEFT JOIN bookmarks ON bookmarks.bookmarkable_type = 'Post' AND bookmarks.user_id = users.id
    def joins(*args)
      check_if_method_has_arguments!("joins", args)
      spawn.joins!(*args.compact.flatten)
    end

    def joins!(*args) # :nodoc:
      self.joins_values += args
      self
    end

    def bind(value)
      spawn.bind!(value)
    end

    def bind!(value) # :nodoc:
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
    # In the case of a belongs_to relationship, an association key can be used
    # to specify the model if an ActiveRecord object is used as the value.
    #
    #    author = Author.find(1)
    #
    #    # The following queries will be equivalent:
    #    Post.where(author: author)
    #    Post.where(author_id: author)
    #
    # This also works with polymorphic belongs_to relationships:
    #
    #    treasure = Treasure.create(name: 'gold coins')
    #    treasure.price_estimates << PriceEstimate.create(price: 125)
    #
    #    # The following queries will be equivalent:
    #    PriceEstimate.where(estimate_of: treasure)
    #    PriceEstimate.where(estimate_of_type: 'Treasure', estimate_of_id: treasure)
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
    #    User.joins(:posts).where({ posts: { published: true } })
    #
    # === no argument
    #
    # If no argument is passed, #where returns a new instance of WhereChain, that
    # can be chained with #not to return a new relation that negates the where clause.
    #
    #    User.where.not(name: "Jon")
    #    # SELECT * FROM users WHERE name != 'Jon'
    #
    # See WhereChain for more details on #not.
    #
    # === blank condition
    #
    # If the condition is any blank-ish object, then #where is a no-op and returns
    # the current relation.
    def where(opts = :chain, *rest)
      if opts == :chain
        WhereChain.new(spawn)
      elsif opts.blank?
        self
      else
        spawn.where!(opts, *rest)
      end
    end

    def where!(opts = :chain, *rest) # :nodoc:
      if opts == :chain
        WhereChain.new(self)
      else
        references!(PredicateBuilder.references(opts)) if Hash === opts

        self.where_values += build_where(opts, rest)
        self
      end
    end

    # Allows to specify a HAVING clause. Note that you can't use HAVING
    # without also specifying a GROUP clause.
    #
    #   Order.having('SUM(price) > 30').group('user_id')
    def having(opts, *rest)
      opts.blank? ? self : spawn.having!(opts, *rest)
    end

    def having!(opts, *rest) # :nodoc:
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

    def limit!(value) # :nodoc:
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

    def offset!(value) # :nodoc:
      self.offset_value = value
      self
    end

    # Specifies locking settings (default to +true+). For more information
    # on locking, please see +ActiveRecord::Locking+.
    def lock(locks = true)
      spawn.lock!(locks)
    end

    def lock!(locks = true) # :nodoc:
      case locks
      when String, TrueClass, NilClass
        self.lock_value = locks || true
      else
        self.lock_value = false
      end

      self
    end

    # Returns a chainable relation with zero records, specifically an
    # instance of the <tt>ActiveRecord::NullRelation</tt> class.
    #
    # The returned <tt>ActiveRecord::NullRelation</tt> inherits from Relation and implements the
    # Null Object pattern. It is an object with defined null behavior and always returns an empty
    # array of records without querying the database.
    #
    # Any subsequent condition chained to the returned relation will continue
    # generating an empty relation and will not fire any query to the database.
    #
    # Used in cases where a method or scope could return zero records but the
    # result needs to be chainable.
    #
    # For example:
    #
    #   @posts = current_user.visible_posts.where(name: params[:name])
    #   # => the visible_posts method is expected to return a chainable Relation
    #
    #   def visible_posts
    #     case role
    #     when 'Country Manager'
    #       Post.where(country: country)
    #     when 'Reviewer'
    #       Post.published
    #     when 'Bad User'
    #       Post.none # => returning [] instead breaks the previous code
    #     end
    #   end
    #
    def none
      extending(NullRelation)
    end

    def none! # :nodoc:
      extending!(NullRelation)
    end

    # Sets readonly attributes for the returned relation. If value is
    # true (default), attempting to update a record will result in an error.
    #
    #   users = User.readonly
    #   users.first.save
    #   => ActiveRecord::ReadOnlyRecord: ActiveRecord::ReadOnlyRecord
    def readonly(value = true)
      spawn.readonly!(value)
    end

    def readonly!(value = true) # :nodoc:
      self.readonly_value = value
      self
    end

    # Sets attributes to be used when creating new records from a
    # relation object.
    #
    #   users = User.where(name: 'Oscar')
    #   users.new.name # => 'Oscar'
    #
    #   users = users.create_with(name: 'DHH')
    #   users.new.name # => 'DHH'
    #
    # You can pass +nil+ to +create_with+ to reset attributes:
    #
    #   users = users.create_with(nil)
    #   users.new.name # => 'Oscar'
    def create_with(value)
      spawn.create_with!(value)
    end

    def create_with!(value) # :nodoc:
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
    #   Topic.select('title').from(Topic.approved)
    #   # => SELECT title FROM (SELECT * FROM topics WHERE approved = 't') subquery
    #
    #   Topic.select('a.title').from(Topic.approved, :a)
    #   # => SELECT a.title FROM (SELECT * FROM topics WHERE approved = 't') a
    #
    def from(value, subquery_name = nil)
      spawn.from!(value, subquery_name)
    end

    def from!(value, subquery_name = nil) # :nodoc:
      self.from_value = [value, subquery_name]
      self
    end

    # Specifies whether the records should be unique or not. For example:
    #
    #   User.select(:name)
    #   # => Might return two records with the same name
    #
    #   User.select(:name).distinct
    #   # => Returns 1 record per distinct name
    #
    #   User.select(:name).distinct.distinct(false)
    #   # => You can also remove the uniqueness
    def distinct(value = true)
      spawn.distinct!(value)
    end
    alias uniq distinct

    # Like #distinct, but modifies relation in place.
    def distinct!(value = true) # :nodoc:
      self.distinct_value = value
      self
    end
    alias uniq! distinct!

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
    #   scope = Model.all.extending(Pagination)
    #   scope.page(params[:page])
    #
    # You can also pass a list of modules:
    #
    #   scope = Model.all.extending(Pagination, SomethingElse)
    #
    # === Using a block
    #
    #   scope = Model.all.extending do
    #     def page(number)
    #       # pagination code goes here
    #     end
    #   end
    #   scope.page(params[:page])
    #
    # You can also use a block and a module list:
    #
    #   scope = Model.all.extending(Pagination) do
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

    def extending!(*modules, &block) # :nodoc:
      modules << Module.new(&block) if block_given?

      self.extending_values += modules.flatten
      extend(*extending_values) if extending_values.any?

      self
    end

    # Reverse the existing order clause on the relation.
    #
    #   User.order('name ASC').reverse_order # generated SQL has 'ORDER BY name DESC'
    def reverse_order
      spawn.reverse_order!
    end

    def reverse_order! # :nodoc:
      self.reverse_order_value = !reverse_order_value
      self
    end

    # Returns the Arel object associated with the relation.
    def arel
      @arel ||= with_default_scope.build_arel
    end

    # Like #arel, but ignores the default scope of the model.
    def build_arel
      arel = Arel::SelectManager.new(table.engine, table)

      build_joins(arel, joins_values.flatten) unless joins_values.empty?

      collapse_wheres(arel, (where_values - ['']).uniq)

      arel.having(*having_values.uniq.reject{|h| h.blank?}) unless having_values.empty?

      arel.take(connection.sanitize_limit(limit_value)) if limit_value
      arel.skip(offset_value.to_i) if offset_value

      arel.group(*group_values.uniq.reject{|g| g.blank?}) unless group_values.empty?

      build_order(arel)

      build_select(arel, select_values.uniq)

      arel.distinct(distinct_value)
      arel.from(build_from) if from_value
      arel.lock(lock_value) if lock_value

      arel
    end

    private

    def symbol_unscoping(scope)
      if !VALID_UNSCOPING_VALUES.include?(scope)
        raise ArgumentError, "Called unscope() with invalid unscoping argument ':#{scope}'. Valid arguments are :#{VALID_UNSCOPING_VALUES.to_a.join(", :")}."
      end

      single_val_method = Relation::SINGLE_VALUE_METHODS.include?(scope)
      unscope_code = :"#{scope}_value#{'s' unless single_val_method}="

      case scope
      when :order
        self.send(:reverse_order_value=, false)
        result = []
      else
        result = [] unless single_val_method
      end

      self.send(unscope_code, result)
    end

    def where_unscoping(target_value)
      target_value_sym = target_value.to_sym

      where_values.reject! do |rel|
        case rel
        when Arel::Nodes::In, Arel::Nodes::Equality
          subrelation = (rel.left.kind_of?(Arel::Attributes::Attribute) ? rel.left : rel.right)
          subrelation.name.to_sym == target_value_sym
        else
          raise "unscope(where: #{target_value.inspect}) failed: unscoping #{rel.class} is unimplemented."
        end
      end
    end

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
      predicates = wheres.map do |where|
        next where if ::Arel::Nodes::Equality === where
        where = Arel.sql(where) if String === where
        Arel::Nodes::Grouping.new(where)
      end

      arel.where(Arel::Nodes::And.new(predicates)) if predicates.present?
    end

    def build_where(opts, other = [])
      case opts
      when String, Array
        #TODO: Remove duplication with: /activerecord/lib/active_record/sanitization.rb:113
        values = Hash === other.first ? other.first.values : other

        values.grep(ActiveRecord::Relation) do |rel|
          self.bind_values += rel.bind_values
        end

        [@klass.send(:sanitize_sql, other.empty? ? opts : ([opts] + other))]
      when Hash
        attributes = @klass.send(:expand_hash_conditions_for_aggregates, opts)

        attributes.values.grep(ActiveRecord::Relation) do |rel|
          self.bind_values += rel.bind_values
        end

        PredicateBuilder.build_from_hash(klass, attributes, table)
      else
        [opts]
      end
    end

    def build_from
      opts, name = from_value
      case opts
      when Relation
        name ||= 'subquery'
        self.bind_values = opts.bind_values + self.bind_values
        opts.arel.as(name.to_s)
      else
        opts
      end
    end

    def build_joins(manager, joins)
      buckets = joins.group_by do |join|
        case join
        when String
          :string_join
        when Hash, Symbol, Array
          :association_join
        when ActiveRecord::Associations::JoinDependency::JoinAssociation
          :stashed_join
        when Arel::Nodes::Join
          :join_node
        else
          raise 'unknown class: %s' % join.class.name
        end
      end

      association_joins         = buckets[:association_join] || []
      stashed_association_joins = buckets[:stashed_join] || []
      join_nodes                = (buckets[:join_node] || []).uniq
      string_joins              = (buckets[:string_join] || []).map { |x| x.strip }.uniq

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

      order_query.flat_map do |o|
        case o
        when Arel::Nodes::Ordering
          o.reverse
        when String
          o.to_s.split(',').collect do |s|
            s.strip!
            s.gsub!(/\sasc\Z/i, ' DESC') || s.gsub!(/\sdesc\Z/i, ' ASC') || s.concat(' DESC')
          end
        when Symbol
          { o => :desc }
        when Hash
          o.each_with_object({}) do |(field, dir), memo|
            memo[field] = (dir == :asc ? :desc : :asc )
          end
        else
          o
        end
      end
    end

    def array_of_strings?(o)
      o.is_a?(Array) && o.all?{|obj| obj.is_a?(String)}
    end

    def build_order(arel)
      orders = order_values
      orders = reverse_sql_order(orders) if reverse_order_value

      orders = orders.uniq.reject(&:blank?).flat_map do |order|
        case order
        when Symbol
          table[order].asc
        when Hash
          order.map { |field, dir| table[field].send(dir) }
        else
          order
        end
      end

      arel.order(*orders) unless orders.empty?
    end

    def validate_order_args(args)
      args.select { |a| Hash === a  }.each do |h|
        unless (h.values - [:asc, :desc]).empty?
          raise ArgumentError, 'Direction should be :asc or :desc'
        end
      end
    end

    # Checks to make sure that the arguments are not blank. Note that if some
    # blank-like object were initially passed into the query method, then this
    # method will not raise an error.
    #
    # Example:
    #
    #    Post.references()   # => raises an error
    #    Post.references([]) # => does not raise an error
    #
    # This particular method should be called with a method_name and the args
    # passed into that method as an input. For example:
    #
    # def references(*args)
    #   check_if_method_has_arguments!("references", args)
    #   ...
    # end
    def check_if_method_has_arguments!(method_name, args)
      if args.blank?
        raise ArgumentError, "The method .#{method_name}() must contain arguments."
      end
    end
  end
end
