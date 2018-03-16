# frozen_string_literal: true

require "active_record/relation/from_clause"
require "active_record/relation/query_attribute"
require "active_record/relation/where_clause"
require "active_record/relation/where_clause_factory"
require "active_model/forbidden_attributes_protection"

module ActiveRecord
  module QueryMethods
    extend ActiveSupport::Concern

    include ActiveModel::ForbiddenAttributesProtection

    # WhereChain objects act as placeholder for queries in which #where does not have any parameter.
    # In this case, #where must be chained with #not to return a new relation.
    class WhereChain
      include ActiveModel::ForbiddenAttributesProtection

      def initialize(scope)
        @scope = scope
      end

      # Returns a new relation expressing WHERE + NOT condition according to
      # the conditions in the arguments.
      #
      # #not accepts conditions as a string, array, or hash. See QueryMethods#where for
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
        opts = sanitize_forbidden_attributes(opts)

        where_clause = @scope.send(:where_clause_factory).build(opts, rest)

        @scope.references!(PredicateBuilder.references(opts)) if Hash === opts
        @scope.where_clause += where_clause.invert
        @scope
      end
    end

    FROZEN_EMPTY_ARRAY = [].freeze
    FROZEN_EMPTY_HASH = {}.freeze

    Relation::VALUE_METHODS.each do |name|
      method_name = \
        case name
        when *Relation::MULTI_VALUE_METHODS then "#{name}_values"
        when *Relation::SINGLE_VALUE_METHODS then "#{name}_value"
        when *Relation::CLAUSE_METHODS then "#{name}_clause"
        end
      class_eval <<-CODE, __FILE__, __LINE__ + 1
        def #{method_name}                   # def includes_values
          get_value(#{name.inspect})         #   get_value(:includes)
        end                                  # end

        def #{method_name}=(value)           # def includes_values=(value)
          set_value(#{name.inspect}, value)  #   set_value(:includes, value)
        end                                  # end
      CODE
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
    # performance improvement over a simple join.
    #
    # You can also specify multiple relationships, like this:
    #
    #   users = User.includes(:address, :friends)
    #
    # Loading nested relationships is possible using a Hash:
    #
    #   users = User.includes(:address, friends: [:address, :followers])
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
    #
    # Note that #includes works with association names while #references needs
    # the actual table name.
    def includes(*args)
      check_if_method_has_arguments!(:includes, args)
      spawn.includes!(*args)
    end

    def includes!(*args) # :nodoc:
      args.reject!(&:blank?)
      args.flatten!

      self.includes_values |= args
      self
    end

    # Forces eager loading by performing a LEFT OUTER JOIN on +args+:
    #
    #   User.eager_load(:posts)
    #   # SELECT "users"."id" AS t0_r0, "users"."name" AS t0_r1, ...
    #   # FROM "users" LEFT OUTER JOIN "posts" ON "posts"."user_id" =
    #   # "users"."id"
    def eager_load(*args)
      check_if_method_has_arguments!(:eager_load, args)
      spawn.eager_load!(*args)
    end

    def eager_load!(*args) # :nodoc:
      self.eager_load_values += args
      self
    end

    # Allows preloading of +args+, in the same way that #includes does:
    #
    #   User.preload(:posts)
    #   # SELECT "posts".* FROM "posts" WHERE "posts"."user_id" IN (1, 2, 3)
    def preload(*args)
      check_if_method_has_arguments!(:preload, args)
      spawn.preload!(*args)
    end

    def preload!(*args) # :nodoc:
      self.preload_values += args
      self
    end

    # Use to indicate that the given +table_names+ are referenced by an SQL string,
    # and should therefore be JOINed in any query rather than loaded separately.
    # This method only works in conjunction with #includes.
    # See #includes for more details.
    #
    #   User.includes(:posts).where("posts.name = 'foo'")
    #   # Doesn't JOIN the posts table, resulting in an error.
    #
    #   User.includes(:posts).where("posts.name = 'foo'").references(:posts)
    #   # Query now knows the string references posts, so adds a JOIN
    def references(*table_names)
      check_if_method_has_arguments!(:references, table_names)
      spawn.references!(*table_names)
    end

    def references!(*table_names) # :nodoc:
      table_names.flatten!
      table_names.map!(&:to_s)

      self.references_values |= table_names
      self
    end

    # Works in two unique ways.
    #
    # First: takes a block so it can be used just like <tt>Array#select</tt>.
    #
    #   Model.all.select { |m| m.field == value }
    #
    # This will build an array of objects from the database for the scope,
    # converting them into an array and iterating through them using
    # <tt>Array#select</tt>.
    #
    # Second: Modifies the SELECT statement for the query so that only certain
    # fields are retrieved:
    #
    #   Model.select(:field)
    #   # => [#<Model id: nil, field: "value">]
    #
    # Although in the above example it looks as though this method returns an
    # array, it actually returns a relation object and can have other query
    # methods appended to it, such as the other methods in ActiveRecord::QueryMethods.
    #
    # The argument to the method can also be an array of fields.
    #
    #   Model.select(:field, :other_field, :and_one_more)
    #   # => [#<Model id: nil, field: "value", other_field: "value", and_one_more: "value">]
    #
    # You can also use one or more strings, which will be used unchanged as SELECT fields.
    #
    #   Model.select('field AS field_one', 'other_field AS field_two')
    #   # => [#<Model id: nil, field: "value", other_field: "value">]
    #
    # If an alias was specified, it will be accessible from the resulting objects:
    #
    #   Model.select('field AS field_one').first.field_one
    #   # => "value"
    #
    # Accessing attributes of an object that do not have fields retrieved by a select
    # except +id+ will throw ActiveModel::MissingAttributeError:
    #
    #   Model.select(:field).first.other_field
    #   # => ActiveModel::MissingAttributeError: missing attribute: other_field
    def select(*fields)
      if block_given?
        if fields.any?
          raise ArgumentError, "`select' with block doesn't take arguments."
        end

        return super()
      end

      raise ArgumentError, "Call `select' with at least one field" if fields.empty?
      spawn._select!(*fields)
    end

    def _select!(*fields) # :nodoc:
      fields.flatten!
      fields.map! do |field|
        klass.attribute_alias?(field) ? klass.attribute_alias(field).to_sym : field
      end
      self.select_values += fields
      self
    end

    # Allows to specify a group attribute:
    #
    #   User.group(:name)
    #   # SELECT "users".* FROM "users" GROUP BY name
    #
    # Returns an array with distinct records based on the +group+ attribute:
    #
    #   User.select([:id, :name])
    #   # => [#<User id: 1, name: "Oscar">, #<User id: 2, name: "Oscar">, #<User id: 3, name: "Foo">]
    #
    #   User.group(:name)
    #   # => [#<User id: 3, name: "Foo", ...>, #<User id: 2, name: "Oscar", ...>]
    #
    #   User.group('name AS grouped_name, age')
    #   # => [#<User id: 3, name: "Foo", age: 21, ...>, #<User id: 2, name: "Oscar", age: 21, ...>, #<User id: 5, name: "Foo", age: 23, ...>]
    #
    # Passing in an array of attributes to group by is also supported.
    #
    #   User.select([:id, :first_name]).group(:id, :first_name).first(3)
    #   # => [#<User id: 1, first_name: "Bill">, #<User id: 2, first_name: "Earl">, #<User id: 3, first_name: "Beto">]
    def group(*args)
      check_if_method_has_arguments!(:group, args)
      spawn.group!(*args)
    end

    def group!(*args) # :nodoc:
      args.flatten!

      self.group_values += args
      self
    end

    # Allows to specify an order attribute:
    #
    #   User.order(:name)
    #   # SELECT "users".* FROM "users" ORDER BY "users"."name" ASC
    #
    #   User.order(email: :desc)
    #   # SELECT "users".* FROM "users" ORDER BY "users"."email" DESC
    #
    #   User.order(:name, email: :desc)
    #   # SELECT "users".* FROM "users" ORDER BY "users"."name" ASC, "users"."email" DESC
    #
    #   User.order('name')
    #   # SELECT "users".* FROM "users" ORDER BY name
    #
    #   User.order('name DESC')
    #   # SELECT "users".* FROM "users" ORDER BY name DESC
    #
    #   User.order('name DESC, email')
    #   # SELECT "users".* FROM "users" ORDER BY name DESC, email
    def order(*args)
      check_if_method_has_arguments!(:order, args)
      spawn.order!(*args)
    end

    # Same as #order but operates on relation in-place instead of copying.
    def order!(*args) # :nodoc:
      preprocess_order_args(args)

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
      check_if_method_has_arguments!(:reorder, args)
      spawn.reorder!(*args)
    end

    # Same as #reorder but operates on relation in-place instead of copying.
    def reorder!(*args) # :nodoc:
      preprocess_order_args(args)

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
    # One can additionally pass a hash as an argument to unscope specific +:where+ values.
    # This is done by passing a hash with a single key-value pair. The key should be
    # +:where+ and the value should be the where value to unscope. For example:
    #
    #   User.where(name: "John", active: true).unscope(where: :name)
    #       == User.where(active: true)
    #
    # This method is similar to #except, but unlike
    # #except, it persists across merges:
    #
    #   User.order('email').merge(User.except(:order))
    #       == User.order('email')
    #
    #   User.order('email').merge(User.unscope(:order))
    #       == User.all
    #
    # This means it can be used in association definitions:
    #
    #   has_many :comments, -> { unscope(where: :trashed) }
    #
    def unscope(*args)
      check_if_method_has_arguments!(:unscope, args)
      spawn.unscope!(*args)
    end

    def unscope!(*args) # :nodoc:
      args.flatten!
      self.unscope_values += args

      args.each do |scope|
        case scope
        when Symbol
          if !VALID_UNSCOPING_VALUES.include?(scope)
            raise ArgumentError, "Called unscope() with invalid unscoping argument ':#{scope}'. Valid arguments are :#{VALID_UNSCOPING_VALUES.to_a.join(", :")}."
          end
          set_value(scope, DEFAULT_VALUES[scope])
        when Hash
          scope.each do |key, target_value|
            if key != :where
              raise ArgumentError, "Hash arguments in .unscope(*args) must have :where as the key."
            end

            target_values = Array(target_value).map(&:to_s)
            self.where_clause = where_clause.except(*target_values)
          end
        else
          raise ArgumentError, "Unrecognized scoping: #{args.inspect}. Use .unscope(where: :attribute_name) or .unscope(:order), for example."
        end
      end

      self
    end

    # Performs a joins on +args+. The given symbol(s) should match the name of
    # the association(s).
    #
    #   User.joins(:posts)
    #   # SELECT "users".*
    #   # FROM "users"
    #   # INNER JOIN "posts" ON "posts"."user_id" = "users"."id"
    #
    # Multiple joins:
    #
    #   User.joins(:posts, :account)
    #   # SELECT "users".*
    #   # FROM "users"
    #   # INNER JOIN "posts" ON "posts"."user_id" = "users"."id"
    #   # INNER JOIN "accounts" ON "accounts"."id" = "users"."account_id"
    #
    # Nested joins:
    #
    #   User.joins(posts: [:comments])
    #   # SELECT "users".*
    #   # FROM "users"
    #   # INNER JOIN "posts" ON "posts"."user_id" = "users"."id"
    #   # INNER JOIN "comments" "comments_posts"
    #   #   ON "comments_posts"."post_id" = "posts"."id"
    #
    # You can use strings in order to customize your joins:
    #
    #   User.joins("LEFT JOIN bookmarks ON bookmarks.bookmarkable_type = 'Post' AND bookmarks.user_id = users.id")
    #   # SELECT "users".* FROM "users" LEFT JOIN bookmarks ON bookmarks.bookmarkable_type = 'Post' AND bookmarks.user_id = users.id
    def joins(*args)
      check_if_method_has_arguments!(:joins, args)
      spawn.joins!(*args)
    end

    def joins!(*args) # :nodoc:
      args.compact!
      args.flatten!
      self.joins_values += args
      self
    end

    # Performs a left outer joins on +args+:
    #
    #   User.left_outer_joins(:posts)
    #   => SELECT "users".* FROM "users" LEFT OUTER JOIN "posts" ON "posts"."user_id" = "users"."id"
    #
    def left_outer_joins(*args)
      check_if_method_has_arguments!(__callee__, args)
      spawn.left_outer_joins!(*args)
    end
    alias :left_joins :left_outer_joins

    def left_outer_joins!(*args) # :nodoc:
      args.compact!
      args.flatten!
      self.left_outer_joins_values += args
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
    # constructor as an SQL fragment, and used in the where clause of the query.
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
    # the values are inserted using the same escapes as the Ruby core method +Kernel::sprintf+.
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
      if :chain == opts
        WhereChain.new(spawn)
      elsif opts.blank?
        self
      else
        spawn.where!(opts, *rest)
      end
    end

    def where!(opts, *rest) # :nodoc:
      opts = sanitize_forbidden_attributes(opts)
      references!(PredicateBuilder.references(opts)) if Hash === opts
      self.where_clause += where_clause_factory.build(opts, rest)
      self
    end

    # Allows you to change a previously set where condition for a given attribute, instead of appending to that condition.
    #
    #   Post.where(trashed: true).where(trashed: false)
    #   # WHERE `trashed` = 1 AND `trashed` = 0
    #
    #   Post.where(trashed: true).rewhere(trashed: false)
    #   # WHERE `trashed` = 0
    #
    #   Post.where(active: true).where(trashed: true).rewhere(trashed: false)
    #   # WHERE `active` = 1 AND `trashed` = 0
    #
    # This is short-hand for <tt>unscope(where: conditions.keys).where(conditions)</tt>.
    # Note that unlike reorder, we're only unscoping the named conditions -- not the entire where statement.
    def rewhere(conditions)
      unscope(where: conditions.keys).where(conditions)
    end

    # Returns a new relation, which is the logical union of this relation and the one passed as an
    # argument.
    #
    # The two relations must be structurally compatible: they must be scoping the same model, and
    # they must differ only by #where (if no #group has been defined) or #having (if a #group is
    # present). Neither relation may have a #limit, #offset, or #distinct set.
    #
    #    Post.where("id = 1").or(Post.where("author_id = 3"))
    #    # SELECT `posts`.* FROM `posts` WHERE ((id = 1) OR (author_id = 3))
    #
    def or(other)
      unless other.is_a? Relation
        raise ArgumentError, "You have passed #{other.class.name} object to #or. Pass an ActiveRecord::Relation object instead."
      end

      spawn.or!(other)
    end

    def or!(other) # :nodoc:
      incompatible_values = structurally_incompatible_values_for_or(other)

      unless incompatible_values.empty?
        raise ArgumentError, "Relation passed to #or must be structurally compatible. Incompatible values: #{incompatible_values}"
      end

      self.where_clause = self.where_clause.or(other.where_clause)
      self.having_clause = having_clause.or(other.having_clause)
      self.references_values += other.references_values

      self
    end

    # Allows to specify a HAVING clause. Note that you can't use HAVING
    # without also specifying a GROUP clause.
    #
    #   Order.having('SUM(price) > 30').group('user_id')
    def having(opts, *rest)
      opts.blank? ? self : spawn.having!(opts, *rest)
    end

    def having!(opts, *rest) # :nodoc:
      opts = sanitize_forbidden_attributes(opts)
      references!(PredicateBuilder.references(opts)) if Hash === opts

      self.having_clause += having_clause_factory.build(opts, rest)
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
    # on locking, please see ActiveRecord::Locking.
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

    # Returns a chainable relation with zero records.
    #
    # The returned relation implements the Null Object pattern. It is an
    # object with defined null behavior and always returns an empty array of
    # records without querying the database.
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
    #   # the visible_posts method is expected to return a chainable Relation
    #
    #   def visible_posts
    #     case role
    #     when 'Country Manager'
    #       Post.where(country: country)
    #     when 'Reviewer'
    #       Post.published
    #     when 'Bad User'
    #       Post.none # It can't be chained if [] is returned.
    #     end
    #   end
    #
    def none
      spawn.none!
    end

    def none! # :nodoc:
      where!("1=0").extending!(NullRelation)
    end

    # Sets readonly attributes for the returned relation. If value is
    # true (default), attempting to update a record will result in an error.
    #
    #   users = User.readonly
    #   users.first.save
    #   => ActiveRecord::ReadOnlyRecord: User is marked as readonly
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
    # You can pass +nil+ to #create_with to reset attributes:
    #
    #   users = users.create_with(nil)
    #   users.new.name # => 'Oscar'
    def create_with(value)
      spawn.create_with!(value)
    end

    def create_with!(value) # :nodoc:
      if value
        value = sanitize_forbidden_attributes(value)
        self.create_with_value = create_with_value.merge(value)
      else
        self.create_with_value = FROZEN_EMPTY_HASH
      end

      self
    end

    # Specifies table from which the records will be fetched. For example:
    #
    #   Topic.select('title').from('posts')
    #   # SELECT title FROM posts
    #
    # Can accept other relation objects. For example:
    #
    #   Topic.select('title').from(Topic.approved)
    #   # SELECT title FROM (SELECT * FROM topics WHERE approved = 't') subquery
    #
    #   Topic.select('a.title').from(Topic.approved, :a)
    #   # SELECT a.title FROM (SELECT * FROM topics WHERE approved = 't') a
    #
    def from(value, subquery_name = nil)
      spawn.from!(value, subquery_name)
    end

    def from!(value, subquery_name = nil) # :nodoc:
      self.from_clause = Relation::FromClause.new(value, subquery_name)
      self
    end

    # Specifies whether the records should be unique or not. For example:
    #
    #   User.select(:name)
    #   # Might return two records with the same name
    #
    #   User.select(:name).distinct
    #   # Returns 1 record per distinct name
    #
    #   User.select(:name).distinct.distinct(false)
    #   # You can also remove the uniqueness
    def distinct(value = true)
      spawn.distinct!(value)
    end

    # Like #distinct, but modifies relation in place.
    def distinct!(value = true) # :nodoc:
      self.distinct_value = value
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
      modules << Module.new(&block) if block
      modules.flatten!

      self.extending_values += modules
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
      orders = order_values.uniq
      orders.reject!(&:blank?)
      self.order_values = reverse_sql_order(orders)
      self
    end

    def skip_query_cache! # :nodoc:
      self.skip_query_cache_value = true
      self
    end

    # Returns the Arel object associated with the relation.
    def arel(aliases = nil) # :nodoc:
      @arel ||= build_arel(aliases)
    end

    protected
      # Returns a relation value with a given name
      def get_value(name) # :nodoc:
        @values.fetch(name, DEFAULT_VALUES[name])
      end

      # Sets the relation value with the given name
      def set_value(name, value) # :nodoc:
        assert_mutability!
        @values[name] = value
      end

    private

      def assert_mutability!
        raise ImmutableRelation if @loaded
        raise ImmutableRelation if defined?(@arel) && @arel
      end

      def build_arel(aliases)
        arel = Arel::SelectManager.new(table)

        aliases = build_joins(arel, joins_values.flatten, aliases) unless joins_values.empty?
        build_left_outer_joins(arel, left_outer_joins_values.flatten, aliases) unless left_outer_joins_values.empty?

        arel.where(where_clause.ast) unless where_clause.empty?
        arel.having(having_clause.ast) unless having_clause.empty?
        if limit_value
          limit_attribute = ActiveModel::Attribute.with_cast_value(
            "LIMIT",
            connection.sanitize_limit(limit_value),
            Type.default_value,
          )
          arel.take(Arel::Nodes::BindParam.new(limit_attribute))
        end
        if offset_value
          offset_attribute = ActiveModel::Attribute.with_cast_value(
            "OFFSET",
            offset_value.to_i,
            Type.default_value,
          )
          arel.skip(Arel::Nodes::BindParam.new(offset_attribute))
        end
        arel.group(*arel_columns(group_values.uniq.reject(&:blank?))) unless group_values.empty?

        build_order(arel)

        build_select(arel)

        arel.distinct(distinct_value)
        arel.from(build_from) unless from_clause.empty?
        arel.lock(lock_value) if lock_value

        arel
      end

      def build_from
        opts = from_clause.value
        name = from_clause.name
        case opts
        when Relation
          if opts.eager_loading?
            opts = opts.send(:apply_join_dependency)
          end
          name ||= "subquery"
          opts.arel.as(name.to_s)
        else
          opts
        end
      end

      def build_left_outer_joins(manager, outer_joins, aliases)
        buckets = outer_joins.group_by do |join|
          case join
          when Hash, Symbol, Array
            :association_join
          else
            raise ArgumentError, "only Hash, Symbol and Array are allowed"
          end
        end

        build_join_query(manager, buckets, Arel::Nodes::OuterJoin, aliases)
      end

      def build_joins(manager, joins, aliases)
        buckets = joins.group_by do |join|
          case join
          when String
            :string_join
          when Hash, Symbol, Array
            :association_join
          when ActiveRecord::Associations::JoinDependency
            :stashed_join
          when Arel::Nodes::Join
            :join_node
          else
            raise "unknown class: %s" % join.class.name
          end
        end

        build_join_query(manager, buckets, Arel::Nodes::InnerJoin, aliases)
      end

      def build_join_query(manager, buckets, join_type, aliases)
        buckets.default = []

        association_joins         = buckets[:association_join]
        stashed_association_joins = buckets[:stashed_join]
        join_nodes                = buckets[:join_node].uniq
        string_joins              = buckets[:string_join].map(&:strip).uniq

        join_list = join_nodes + convert_join_strings_to_ast(manager, string_joins)
        alias_tracker = alias_tracker(join_list, aliases)

        join_dependency = ActiveRecord::Associations::JoinDependency.new(
          klass, table, association_joins, alias_tracker
        )

        joins = join_dependency.join_constraints(stashed_association_joins, join_type)
        joins.each { |join| manager.from(join) }

        manager.join_sources.concat(join_list)

        alias_tracker.aliases
      end

      def convert_join_strings_to_ast(table, joins)
        joins
          .flatten
          .reject(&:blank?)
          .map { |join| table.create_string_join(Arel.sql(join)) }
      end

      def build_select(arel)
        if select_values.any?
          arel.project(*arel_columns(select_values.uniq))
        elsif klass.ignored_columns.any?
          arel.project(*klass.column_names.map { |field| arel_attribute(field) })
        else
          arel.project(table[Arel.star])
        end
      end

      def arel_columns(columns)
        columns.map do |field|
          if (Symbol === field || String === field) && (klass.has_attribute?(field) || klass.attribute_alias?(field)) && !from_clause.value
            arel_attribute(field)
          elsif Symbol === field
            connection.quote_table_name(field.to_s)
          else
            field
          end
        end
      end

      def reverse_sql_order(order_query)
        if order_query.empty?
          return [arel_attribute(primary_key).desc] if primary_key
          raise IrreversibleOrderError,
            "Relation has no current order and table has no primary key to be used as default order"
        end

        order_query.flat_map do |o|
          case o
          when Arel::Attribute
            o.desc
          when Arel::Nodes::Ordering
            o.reverse
          when String
            if does_not_support_reverse?(o)
              raise IrreversibleOrderError, "Order #{o.inspect} can not be reversed automatically"
            end
            o.split(",").map! do |s|
              s.strip!
              s.gsub!(/\sasc\Z/i, " DESC") || s.gsub!(/\sdesc\Z/i, " ASC") || (s << " DESC")
            end
          else
            o
          end
        end
      end

      def does_not_support_reverse?(order)
        # Account for String subclasses like Arel::Nodes::SqlLiteral that
        # override methods like #count.
        order = String.new(order) unless order.instance_of?(String)

        # Uses SQL function with multiple arguments.
        (order.include?(",") && order.split(",").find { |section| section.count("(") != section.count(")") }) ||
          # Uses "nulls first" like construction.
          /nulls (first|last)\Z/i.match?(order)
      end

      def build_order(arel)
        orders = order_values.uniq
        orders.reject!(&:blank?)

        arel.order(*orders) unless orders.empty?
      end

      VALID_DIRECTIONS = [:asc, :desc, :ASC, :DESC,
                          "asc", "desc", "ASC", "DESC"].to_set # :nodoc:

      def validate_order_args(args)
        args.each do |arg|
          next unless arg.is_a?(Hash)
          arg.each do |_key, value|
            unless VALID_DIRECTIONS.include?(value)
              raise ArgumentError,
                "Direction \"#{value}\" is invalid. Valid directions are: #{VALID_DIRECTIONS.to_a.inspect}"
            end
          end
        end
      end

      def preprocess_order_args(order_args)
        order_args.map! do |arg|
          klass.sanitize_sql_for_order(arg)
        end
        order_args.flatten!

        @klass.enforce_raw_sql_whitelist(
          order_args.flat_map { |a| a.is_a?(Hash) ? a.keys : a },
          whitelist: AttributeMethods::ClassMethods::COLUMN_NAME_ORDER_WHITELIST
        )

        validate_order_args(order_args)

        references = order_args.grep(String)
        references.map! { |arg| arg =~ /^\W?(\w+)\W?\./ && $1 }.compact!
        references!(references) if references.any?

        # if a symbol is given we prepend the quoted table name
        order_args.map! do |arg|
          case arg
          when Symbol
            arel_attribute(arg).asc
          when Hash
            arg.map { |field, dir|
              case field
              when Arel::Nodes::SqlLiteral
                field.send(dir.downcase)
              else
                arel_attribute(field).send(dir.downcase)
              end
            }
          else
            arg
          end
        end.flatten!
      end

      # Checks to make sure that the arguments are not blank. Note that if some
      # blank-like object were initially passed into the query method, then this
      # method will not raise an error.
      #
      # Example:
      #
      #    Post.references()   # raises an error
      #    Post.references([]) # does not raise an error
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

      STRUCTURAL_OR_METHODS = Relation::VALUE_METHODS - [:extending, :where, :having, :unscope, :references]
      def structurally_incompatible_values_for_or(other)
        STRUCTURAL_OR_METHODS.reject do |method|
          get_value(method) == other.get_value(method)
        end
      end

      def where_clause_factory
        @where_clause_factory ||= Relation::WhereClauseFactory.new(klass, predicate_builder)
      end
      alias having_clause_factory where_clause_factory

      DEFAULT_VALUES = {
        create_with: FROZEN_EMPTY_HASH,
        where: Relation::WhereClause.empty,
        having: Relation::WhereClause.empty,
        from: Relation::FromClause.empty
      }

      Relation::MULTI_VALUE_METHODS.each do |value|
        DEFAULT_VALUES[value] ||= FROZEN_EMPTY_ARRAY
      end
  end
end
