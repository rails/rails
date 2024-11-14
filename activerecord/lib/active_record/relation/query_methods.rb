# frozen_string_literal: true

require "active_record/relation/from_clause"
require "active_record/relation/query_attribute"
require "active_record/relation/where_clause"
require "active_support/core_ext/array/wrap"

module ActiveRecord
  module QueryMethods
    include ActiveModel::ForbiddenAttributesProtection

    # +WhereChain+ objects act as placeholder for queries in which +where+ does not have any parameter.
    # In this case, +where+ can be chained to return a new relation.
    class WhereChain
      def initialize(scope) # :nodoc:
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
      #    # SELECT * FROM users WHERE NOT (name = 'Jon' AND role = 'admin')
      #
      # If there is a non-nil condition on a nullable column in the hash condition, the records that have
      # nil values on the nullable column won't be returned.
      #    User.create!(nullable_country: nil)
      #    User.where.not(nullable_country: "UK")
      #    # SELECT * FROM users WHERE NOT (nullable_country = 'UK')
      #    # => []
      def not(opts, *rest)
        where_clause = @scope.send(:build_where_clause, opts, rest)

        @scope.where_clause += where_clause.invert

        @scope
      end

      # Returns a new relation with joins and where clause to identify
      # associated relations.
      #
      # For example, posts that are associated to a related author:
      #
      #    Post.where.associated(:author)
      #    # SELECT "posts".* FROM "posts"
      #    # INNER JOIN "authors" ON "authors"."id" = "posts"."author_id"
      #    # WHERE "authors"."id" IS NOT NULL
      #
      # Additionally, multiple relations can be combined. This will return posts
      # associated to both an author and any comments:
      #
      #    Post.where.associated(:author, :comments)
      #    # SELECT "posts".* FROM "posts"
      #    # INNER JOIN "authors" ON "authors"."id" = "posts"."author_id"
      #    # INNER JOIN "comments" ON "comments"."post_id" = "posts"."id"
      #    # WHERE "authors"."id" IS NOT NULL AND "comments"."id" IS NOT NULL
      #
      # You can define join type in the scope and +associated+ will not use `JOIN` by default.
      #
      #    Post.left_joins(:author).where.associated(:author)
      #    # SELECT "posts".* FROM "posts"
      #    # LEFT OUTER JOIN "authors" "authors"."id" = "posts"."author_id"
      #    # WHERE "authors"."id" IS NOT NULL
      #
      #    Post.left_joins(:comments).where.associated(:author)
      #    # SELECT "posts".* FROM "posts"
      #    # INNER JOIN "authors" ON "authors"."id" = "posts"."author_id"
      #    # LEFT OUTER JOIN "comments" ON "comments"."post_id" = "posts"."id"
      #   #  WHERE "author"."id" IS NOT NULL
      def associated(*associations)
        associations.each do |association|
          reflection = scope_association_reflection(association)
          unless @scope.joins_values.include?(reflection.name) || @scope.left_outer_joins_values.include?(reflection.name)
            @scope.joins!(association)
          end

          association_conditions = Array(reflection.association_primary_key).index_with(nil)
          if reflection.options[:class_name]
            self.not(association => association_conditions)
          else
            self.not(reflection.table_name => association_conditions)
          end
        end

        @scope
      end

      # Returns a new relation with left outer joins and where clause to identify
      # missing relations.
      #
      # For example, posts that are missing a related author:
      #
      #    Post.where.missing(:author)
      #    # SELECT "posts".* FROM "posts"
      #    # LEFT OUTER JOIN "authors" ON "authors"."id" = "posts"."author_id"
      #    # WHERE "authors"."id" IS NULL
      #
      # Additionally, multiple relations can be combined. This will return posts
      # that are missing both an author and any comments:
      #
      #    Post.where.missing(:author, :comments)
      #    # SELECT "posts".* FROM "posts"
      #    # LEFT OUTER JOIN "authors" ON "authors"."id" = "posts"."author_id"
      #    # LEFT OUTER JOIN "comments" ON "comments"."post_id" = "posts"."id"
      #    # WHERE "authors"."id" IS NULL AND "comments"."id" IS NULL
      def missing(*associations)
        associations.each do |association|
          reflection = scope_association_reflection(association)
          @scope.left_outer_joins!(association)
          association_conditions = Array(reflection.association_primary_key).index_with(nil)
          if reflection.options[:class_name]
            @scope.where!(association => association_conditions)
          else
            @scope.where!(reflection.table_name => association_conditions)
          end
        end

        @scope
      end

      private
        def scope_association_reflection(association)
          model = @scope.model
          reflection = model._reflect_on_association(association)
          unless reflection
            raise ArgumentError.new("An association named `:#{association}` does not exist on the model `#{model.name}`.")
          end
          reflection
        end
    end

    # A wrapper to distinguish CTE joins from other nodes.
    class CTEJoin # :nodoc:
      attr_reader :name

      def initialize(name)
        @name = name
      end
    end

    FROZEN_EMPTY_ARRAY = [].freeze
    FROZEN_EMPTY_HASH = {}.freeze

    Relation::VALUE_METHODS.each do |name|
      method_name, default =
        case name
        when *Relation::MULTI_VALUE_METHODS
          ["#{name}_values", "FROZEN_EMPTY_ARRAY"]
        when *Relation::SINGLE_VALUE_METHODS
          ["#{name}_value", name == :create_with ? "FROZEN_EMPTY_HASH" : "nil"]
        when *Relation::CLAUSE_METHODS
          ["#{name}_clause", name == :from ? "Relation::FromClause.empty" : "Relation::WhereClause.empty"]
        end

      class_eval <<-CODE, __FILE__, __LINE__ + 1
        def #{method_name}                     # def includes_values
          @values.fetch(:#{name}, #{default})  #   @values.fetch(:includes, FROZEN_EMPTY_ARRAY)
        end                                    # end

        def #{method_name}=(value)             # def includes_values=(value)
          assert_modifiable!                   #   assert_modifiable!
          @values[:#{name}] = value            #   @values[:includes] = value
        end                                    # end
      CODE
    end

    alias extensions extending_values

    # Specify associations +args+ to be eager loaded to prevent N + 1 queries.
    # A separate query is performed for each association, unless a join is
    # required by conditions.
    #
    # For example:
    #
    #   users = User.includes(:address).limit(5)
    #   users.each do |user|
    #     user.address.city
    #   end
    #
    #   # SELECT "users".* FROM "users" LIMIT 5
    #   # SELECT "addresses".* FROM "addresses" WHERE "addresses"."id" IN (1,2,3,4,5)
    #
    # Instead of loading the 5 addresses with 5 separate queries, all addresses
    # are loaded with a single query.
    #
    # Loading the associations in a separate query will often result in a
    # performance improvement over a simple join, as a join can result in many
    # rows that contain redundant data and it performs poorly at scale.
    #
    # You can also specify multiple associations. Each association will result
    # in an additional query:
    #
    #   User.includes(:address, :friends).to_a
    #   # SELECT "users".* FROM "users"
    #   # SELECT "addresses".* FROM "addresses" WHERE "addresses"."id" IN (1,2,3,4,5)
    #   # SELECT "friends".* FROM "friends" WHERE "friends"."user_id" IN (1,2,3,4,5)
    #
    # Loading nested associations is possible using a Hash:
    #
    #   User.includes(:address, friends: [:address, :followers])
    #
    # === Conditions
    #
    # If you want to add string conditions to your included models, you'll have
    # to explicitly reference them. For example:
    #
    #   User.includes(:posts).where('posts.name = ?', 'example').to_a
    #
    # Will throw an error, but this will work:
    #
    #   User.includes(:posts).where('posts.name = ?', 'example').references(:posts).to_a
    #   # SELECT "users"."id" AS t0_r0, ... FROM "users"
    #   #   LEFT OUTER JOIN "posts" ON "posts"."user_id" = "users"."id"
    #   #   WHERE "posts"."name" = ?  [["name", "example"]]
    #
    # As the <tt>LEFT OUTER JOIN</tt> already contains the posts, the second query for
    # the posts is no longer performed.
    #
    # Note that #includes works with association names while #references needs
    # the actual table name.
    #
    # If you pass the conditions via a Hash, you don't need to call #references
    # explicitly, as #where references the tables for you. For example, this
    # will work correctly:
    #
    #   User.includes(:posts).where(posts: { name: 'example' })
    #
    # NOTE: Conditions affect both sides of an association. For example, the
    # above code will return only users that have a post named "example",
    # <em>and will only include posts named "example"</em>, even when a
    # matching user has other additional posts.
    def includes(*args)
      check_if_method_has_arguments!(__callee__, args)
      spawn.includes!(*args)
    end

    def includes!(*args) # :nodoc:
      self.includes_values |= args
      self
    end

    def all # :nodoc:
      spawn
    end

    # Specify associations +args+ to be eager loaded using a <tt>LEFT OUTER JOIN</tt>.
    # Performs a single query joining all specified associations. For example:
    #
    #   users = User.eager_load(:address).limit(5)
    #   users.each do |user|
    #     user.address.city
    #   end
    #
    #   # SELECT "users"."id" AS t0_r0, "users"."name" AS t0_r1, ... FROM "users"
    #   #   LEFT OUTER JOIN "addresses" ON "addresses"."id" = "users"."address_id"
    #   #   LIMIT 5
    #
    # Instead of loading the 5 addresses with 5 separate queries, all addresses
    # are loaded with a single joined query.
    #
    # Loading multiple and nested associations is possible using Hashes and Arrays,
    # similar to #includes:
    #
    #   User.eager_load(:address, friends: [:address, :followers])
    #   # SELECT "users"."id" AS t0_r0, "users"."name" AS t0_r1, ... FROM "users"
    #   #   LEFT OUTER JOIN "addresses" ON "addresses"."id" = "users"."address_id"
    #   #   LEFT OUTER JOIN "friends" ON "friends"."user_id" = "users"."id"
    #   #   ...
    #
    # NOTE: Loading the associations in a join can result in many rows that
    # contain redundant data and it performs poorly at scale.
    def eager_load(*args)
      check_if_method_has_arguments!(__callee__, args)
      spawn.eager_load!(*args)
    end

    def eager_load!(*args) # :nodoc:
      self.eager_load_values |= args
      self
    end

    # Specify associations +args+ to be eager loaded using separate queries.
    # A separate query is performed for each association.
    #
    #   users = User.preload(:address).limit(5)
    #   users.each do |user|
    #     user.address.city
    #   end
    #
    #   # SELECT "users".* FROM "users" LIMIT 5
    #   # SELECT "addresses".* FROM "addresses" WHERE "addresses"."id" IN (1,2,3,4,5)
    #
    # Instead of loading the 5 addresses with 5 separate queries, all addresses
    # are loaded with a separate query.
    #
    # Loading multiple and nested associations is possible using Hashes and Arrays,
    # similar to #includes:
    #
    #   User.preload(:address, friends: [:address, :followers])
    #   # SELECT "users".* FROM "users"
    #   # SELECT "addresses".* FROM "addresses" WHERE "addresses"."id" IN (1,2,3,4,5)
    #   # SELECT "friends".* FROM "friends" WHERE "friends"."user_id" IN (1,2,3,4,5)
    #   # SELECT ...
    def preload(*args)
      check_if_method_has_arguments!(__callee__, args)
      spawn.preload!(*args)
    end

    def preload!(*args) # :nodoc:
      self.preload_values |= args
      self
    end

    # Extracts a named +association+ from the relation. The named association is first preloaded,
    # then the individual association records are collected from the relation. Like so:
    #
    #   account.memberships.extract_associated(:user)
    #   # => Returns collection of User records
    #
    # This is short-hand for:
    #
    #   account.memberships.preload(:user).collect(&:user)
    def extract_associated(association)
      preload(association).collect(&association)
    end

    # Use to indicate that the given +table_names+ are referenced by an SQL string,
    # and should therefore be +JOIN+ed in any query rather than loaded separately.
    # This method only works in conjunction with #includes.
    # See #includes for more details.
    #
    #   User.includes(:posts).where("posts.name = 'foo'")
    #   # Doesn't JOIN the posts table, resulting in an error.
    #
    #   User.includes(:posts).where("posts.name = 'foo'").references(:posts)
    #   # Query now knows the string references posts, so adds a JOIN
    def references(*table_names)
      check_if_method_has_arguments!(__callee__, table_names)
      spawn.references!(*table_names)
    end

    def references!(*table_names) # :nodoc:
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
    # The argument also can be a hash of fields and aliases.
    #
    #   Model.select(models: { field: :alias, other_field: :other_alias })
    #   # => [#<Model id: nil, alias: "value", other_alias: "value">]
    #
    #   Model.select(models: [:field, :other_field])
    #   # => [#<Model id: nil, field: "value", other_field: "value">]
    #
    # You can also use one or more strings, which will be used unchanged as SELECT fields.
    #
    #   Model.select('field AS field_one', 'other_field AS field_two')
    #   # => [#<Model id: nil, field_one: "value", field_two: "value">]
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
    #   # => ActiveModel::MissingAttributeError: missing attribute 'other_field' for Model
    def select(*fields)
      if block_given?
        if fields.any?
          raise ArgumentError, "`select' with block doesn't take arguments."
        end

        return super()
      end

      check_if_method_has_arguments!(__callee__, fields, "Call `select' with at least one field.")

      fields = process_select_args(fields)
      spawn._select!(*fields)
    end

    def _select!(*fields) # :nodoc:
      self.select_values |= fields
      self
    end

    # Add a Common Table Expression (CTE) that you can then reference within another SELECT statement.
    #
    # Note: CTE's are only supported in MySQL for versions 8.0 and above. You will not be able to
    # use CTE's with MySQL 5.7.
    #
    #   Post.with(posts_with_tags: Post.where("tags_count > ?", 0))
    #   # => ActiveRecord::Relation
    #   # WITH posts_with_tags AS (
    #   #   SELECT * FROM posts WHERE (tags_count > 0)
    #   # )
    #   # SELECT * FROM posts
    #
    # You can also pass an array of sub-queries to be joined in a +UNION ALL+.
    #
    #   Post.with(posts_with_tags_or_comments: [Post.where("tags_count > ?", 0), Post.where("comments_count > ?", 0)])
    #   # => ActiveRecord::Relation
    #   # WITH posts_with_tags_or_comments AS (
    #   #  (SELECT * FROM posts WHERE (tags_count > 0))
    #   #  UNION ALL
    #   #  (SELECT * FROM posts WHERE (comments_count > 0))
    #   # )
    #   # SELECT * FROM posts
    #
    # Once you define Common Table Expression you can use custom +FROM+ value or +JOIN+ to reference it.
    #
    #   Post.with(posts_with_tags: Post.where("tags_count > ?", 0)).from("posts_with_tags AS posts")
    #   # => ActiveRecord::Relation
    #   # WITH posts_with_tags AS (
    #   #  SELECT * FROM posts WHERE (tags_count > 0)
    #   # )
    #   # SELECT * FROM posts_with_tags AS posts
    #
    #   Post.with(posts_with_tags: Post.where("tags_count > ?", 0)).joins("JOIN posts_with_tags ON posts_with_tags.id = posts.id")
    #   # => ActiveRecord::Relation
    #   # WITH posts_with_tags AS (
    #   #   SELECT * FROM posts WHERE (tags_count > 0)
    #   # )
    #   # SELECT * FROM posts JOIN posts_with_tags ON posts_with_tags.id = posts.id
    #
    # It is recommended to pass a query as ActiveRecord::Relation. If that is not possible
    # and you have verified it is safe for the database, you can pass it as SQL literal
    # using +Arel+.
    #
    #   Post.with(popular_posts: Arel.sql("... complex sql to calculate posts popularity ..."))
    #
    # Great caution should be taken to avoid SQL injection vulnerabilities. This method should not
    # be used with unsafe values that include unsanitized input.
    #
    # To add multiple CTEs just pass multiple key-value pairs
    #
    #   Post.with(
    #     posts_with_comments: Post.where("comments_count > ?", 0),
    #     posts_with_tags: Post.where("tags_count > ?", 0)
    #   )
    #
    # or chain multiple +.with+ calls
    #
    #   Post
    #     .with(posts_with_comments: Post.where("comments_count > ?", 0))
    #     .with(posts_with_tags: Post.where("tags_count > ?", 0))
    def with(*args)
      raise ArgumentError, "ActiveRecord::Relation#with does not accept a block" if block_given?
      check_if_method_has_arguments!(__callee__, args)
      spawn.with!(*args)
    end

    # Like #with, but modifies relation in place.
    def with!(*args) # :nodoc:
      args = process_with_args(args)
      self.with_values |= args
      self
    end

    # Add a recursive Common Table Expression (CTE) that you can then reference within another SELECT statement.
    #
    #   Post.with_recursive(post_and_replies: [Post.where(id: 42), Post.joins('JOIN post_and_replies ON posts.in_reply_to_id = post_and_replies.id')])
    #   # => ActiveRecord::Relation
    #   # WITH RECURSIVE post_and_replies AS (
    #   #   (SELECT * FROM posts WHERE id = 42)
    #   #   UNION ALL
    #   #   (SELECT * FROM posts JOIN posts_and_replies ON posts.in_reply_to_id = posts_and_replies.id)
    #   # )
    #   # SELECT * FROM posts
    #
    # See `#with` for more information.
    def with_recursive(*args)
      check_if_method_has_arguments!(__callee__, args)
      spawn.with_recursive!(*args)
    end

    # Like #with_recursive but modifies the relation in place.
    def with_recursive!(*args) # :nodoc:
      args = process_with_args(args)
      self.with_values |= args
      @with_is_recursive = true
      self
    end

    # Allows you to change a previously set select statement.
    #
    #   Post.select(:title, :body)
    #   # SELECT `posts`.`title`, `posts`.`body` FROM `posts`
    #
    #   Post.select(:title, :body).reselect(:created_at)
    #   # SELECT `posts`.`created_at` FROM `posts`
    #
    # This is short-hand for <tt>unscope(:select).select(fields)</tt>.
    # Note that we're unscoping the entire select statement.
    def reselect(*args)
      check_if_method_has_arguments!(__callee__, args)
      args = process_select_args(args)
      spawn.reselect!(*args)
    end

    # Same as #reselect but operates on relation in-place instead of copying.
    def reselect!(*args) # :nodoc:
      self.select_values = args
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
      check_if_method_has_arguments!(__callee__, args)
      spawn.group!(*args)
    end

    def group!(*args) # :nodoc:
      self.group_values += args
      self
    end

    # Allows you to change a previously set group statement.
    #
    #   Post.group(:title, :body)
    #   # SELECT `posts`.`*` FROM `posts` GROUP BY `posts`.`title`, `posts`.`body`
    #
    #   Post.group(:title, :body).regroup(:title)
    #   # SELECT `posts`.`*` FROM `posts` GROUP BY `posts`.`title`
    #
    # This is short-hand for <tt>unscope(:group).group(fields)</tt>.
    # Note that we're unscoping the entire group statement.
    def regroup(*args)
      check_if_method_has_arguments!(__callee__, args)
      spawn.regroup!(*args)
    end

    # Same as #regroup but operates on relation in-place instead of copying.
    def regroup!(*args) # :nodoc:
      self.group_values = args
      self
    end

    # Applies an <code>ORDER BY</code> clause to a query.
    #
    # #order accepts arguments in one of several formats.
    #
    # === symbols
    #
    # The symbol represents the name of the column you want to order the results by.
    #
    #   User.order(:name)
    #   # SELECT "users".* FROM "users" ORDER BY "users"."name" ASC
    #
    # By default, the order is ascending. If you want descending order, you can
    # map the column name symbol to +:desc+.
    #
    #   User.order(email: :desc)
    #   # SELECT "users".* FROM "users" ORDER BY "users"."email" DESC
    #
    # Multiple columns can be passed this way, and they will be applied in the order specified.
    #
    #   User.order(:name, email: :desc)
    #   # SELECT "users".* FROM "users" ORDER BY "users"."name" ASC, "users"."email" DESC
    #
    # === strings
    #
    # Strings are passed directly to the database, allowing you to specify
    # simple SQL expressions.
    #
    # This could be a source of SQL injection, so only strings composed of plain
    # column names and simple <code>function(column_name)</code> expressions
    # with optional +ASC+/+DESC+ modifiers are allowed.
    #
    #   User.order('name')
    #   # SELECT "users".* FROM "users" ORDER BY name
    #
    #   User.order('name DESC')
    #   # SELECT "users".* FROM "users" ORDER BY name DESC
    #
    #   User.order('name DESC, email')
    #   # SELECT "users".* FROM "users" ORDER BY name DESC, email
    #
    # === Arel
    #
    # If you need to pass in complicated expressions that you have verified
    # are safe for the database, you can use Arel.
    #
    #   User.order(Arel.sql('end_date - start_date'))
    #   # SELECT "users".* FROM "users" ORDER BY end_date - start_date
    #
    # Custom query syntax, like JSON columns for PostgreSQL, is supported in this way.
    #
    #   User.order(Arel.sql("payload->>'kind'"))
    #   # SELECT "users".* FROM "users" ORDER BY payload->>'kind'
    def order(*args)
      check_if_method_has_arguments!(__callee__, args) do
        sanitize_order_arguments(args)
      end
      spawn.order!(*args)
    end

    # Same as #order but operates on relation in-place instead of copying.
    def order!(*args) # :nodoc:
      preprocess_order_args(args) unless args.empty?
      self.order_values |= args
      self
    end

    # Applies an <tt>ORDER BY</tt> clause based on a given +column+,
    # ordered and filtered by a specific set of +values+.
    #
    #   User.in_order_of(:id, [1, 5, 3])
    #   # SELECT "users".* FROM "users"
    #   #   WHERE "users"."id" IN (1, 5, 3)
    #   #   ORDER BY CASE
    #   #     WHEN "users"."id" = 1 THEN 1
    #   #     WHEN "users"."id" = 5 THEN 2
    #   #     WHEN "users"."id" = 3 THEN 3
    #   #   END ASC
    #
    # +column+ can point to an enum column; the actual query generated may be different depending
    # on the database adapter and the column definition.
    #
    #   class Conversation < ActiveRecord::Base
    #     enum :status, [ :active, :archived ]
    #   end
    #
    #   Conversation.in_order_of(:status, [:archived, :active])
    #   # SELECT "conversations".* FROM "conversations"
    #   #   WHERE "conversations"."status" IN (1, 0)
    #   #   ORDER BY CASE
    #   #     WHEN "conversations"."status" = 1 THEN 1
    #   #     WHEN "conversations"."status" = 0 THEN 2
    #   #   END ASC
    #
    # +values+ can also include +nil+.
    #
    #   Conversation.in_order_of(:status, [nil, :archived, :active])
    #   # SELECT "conversations".* FROM "conversations"
    #   #   WHERE ("conversations"."status" IN (1, 0) OR "conversations"."status" IS NULL)
    #   #   ORDER BY CASE
    #   #     WHEN "conversations"."status" IS NULL THEN 1
    #   #     WHEN "conversations"."status" = 1 THEN 2
    #   #     WHEN "conversations"."status" = 0 THEN 3
    #   #   END ASC
    #
    # +filter+ can be set to +false+ to include all results instead of only the ones specified in +values+.
    #
    #   Conversation.in_order_of(:status, [:archived, :active], filter: false)
    #   # SELECT "conversations".* FROM "conversations"
    #   #   ORDER BY CASE
    #   #     WHEN "conversations"."status" = 1 THEN 1
    #   #     WHEN "conversations"."status" = 0 THEN 2
    #   #     ELSE 3
    #   #   END ASC
    def in_order_of(column, values, filter: true)
      model.disallow_raw_sql!([column], permit: model.adapter_class.column_name_with_order_matcher)
      return spawn.none! if values.empty?

      references = column_references([column])
      self.references_values |= references unless references.empty?

      values = values.map { |value| model.type_caster.type_cast_for_database(column, value) }
      arel_column = column.is_a?(Arel::Nodes::SqlLiteral) ? column : order_column(column.to_s)

      scope = spawn.order!(build_case_for_value_position(arel_column, values, filter: filter))

      if filter
        where_clause =
          if values.include?(nil)
            arel_column.in(values.compact).or(arel_column.eq(nil))
          else
            arel_column.in(values)
          end

        scope = scope.where!(where_clause)
      end

      scope
    end

    # Replaces any existing order defined on the relation with the specified order.
    #
    #   User.order('email DESC').reorder('id ASC') # generated SQL has 'ORDER BY id ASC'
    #
    # Subsequent calls to order on the same relation will be appended. For example:
    #
    #   User.order('email DESC').reorder('id ASC').order('name ASC')
    #
    # generates a query with <tt>ORDER BY id ASC, name ASC</tt>.
    def reorder(*args)
      check_if_method_has_arguments!(__callee__, args) do
        sanitize_order_arguments(args)
      end
      spawn.reorder!(*args)
    end

    # Same as #reorder but operates on relation in-place instead of copying.
    def reorder!(*args) # :nodoc:
      preprocess_order_args(args)
      args.uniq!
      self.reordering_value = true
      self.order_values = args
      self
    end

    VALID_UNSCOPING_VALUES = Set.new([:where, :select, :group, :order, :lock,
                                     :limit, :offset, :joins, :left_outer_joins, :annotate,
                                     :includes, :eager_load, :preload, :from, :readonly,
                                     :having, :optimizer_hints, :with])

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
      check_if_method_has_arguments!(__callee__, args)
      spawn.unscope!(*args)
    end

    def unscope!(*args) # :nodoc:
      self.unscope_values += args

      args.each do |scope|
        case scope
        when Symbol
          scope = :left_outer_joins if scope == :left_joins
          if !VALID_UNSCOPING_VALUES.include?(scope)
            raise ArgumentError, "Called unscope() with invalid unscoping argument ':#{scope}'. Valid arguments are :#{VALID_UNSCOPING_VALUES.to_a.join(", :")}."
          end
          assert_modifiable!
          @values.delete(scope)
        when Hash
          scope.each do |key, target_value|
            if key != :where
              raise ArgumentError, "Hash arguments in .unscope(*args) must have :where as the key."
            end

            target_values = resolve_arel_attributes(Array.wrap(target_value))
            self.where_clause = where_clause.except(*target_values)
          end
        else
          raise ArgumentError, "Unrecognized scoping: #{args.inspect}. Use .unscope(where: :attribute_name) or .unscope(:order), for example."
        end
      end

      self
    end

    # Performs JOINs on +args+. The given symbol(s) should match the name of
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
    #   # INNER JOIN "comments" ON "comments"."post_id" = "posts"."id"
    #
    # You can use strings in order to customize your joins:
    #
    #   User.joins("LEFT JOIN bookmarks ON bookmarks.bookmarkable_type = 'Post' AND bookmarks.user_id = users.id")
    #   # SELECT "users".* FROM "users" LEFT JOIN bookmarks ON bookmarks.bookmarkable_type = 'Post' AND bookmarks.user_id = users.id
    def joins(*args)
      check_if_method_has_arguments!(__callee__, args)
      spawn.joins!(*args)
    end

    def joins!(*args) # :nodoc:
      self.joins_values |= args
      self
    end

    # Performs LEFT OUTER JOINs on +args+:
    #
    #   User.left_outer_joins(:posts)
    #   # SELECT "users".* FROM "users" LEFT OUTER JOIN "posts" ON "posts"."user_id" = "users"."id"
    #
    def left_outer_joins(*args)
      check_if_method_has_arguments!(__callee__, args)
      spawn.left_outer_joins!(*args)
    end
    alias :left_joins :left_outer_joins

    def left_outer_joins!(*args) # :nodoc:
      self.left_outer_joins_values |= args
      self
    end

    # Returns a new relation, which is the result of filtering the current relation
    # according to the conditions in the arguments.
    #
    # #where accepts conditions in one of several formats. In the examples below, the resulting
    # SQL is given as an illustration; the actual query generated may be different depending
    # on the database adapter.
    #
    # === \String
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
    # === \Array
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
    # === \Hash
    #
    # #where will also accept a hash condition, in which the keys are fields and the values
    # are values to be searched for.
    #
    # Fields can be symbols or strings. Values can be single values, arrays, or ranges.
    #
    #    User.where(name: "Joe", email: "joe@example.com")
    #    # SELECT * FROM users WHERE name = 'Joe' AND email = 'joe@example.com'
    #
    #    User.where(name: ["Alice", "Bob"])
    #    # SELECT * FROM users WHERE name IN ('Alice', 'Bob')
    #
    #    User.where(created_at: (Time.now.midnight - 1.day)..Time.now.midnight)
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
    # Hash conditions may also be specified in a tuple-like syntax. Hash keys may be
    # an array of columns with an array of tuples as values.
    #
    #   Article.where([:author_id, :id] => [[15, 1], [15, 2]])
    #   # SELECT * FROM articles WHERE author_id = 15 AND id = 1 OR author_id = 15 AND id = 2
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
    #    User.joins(:posts).where("posts.published" => true)
    #    User.joins(:posts).where(posts: { published: true })
    #
    # === No Argument
    #
    # If no argument is passed, #where returns a new instance of WhereChain, that
    # can be chained with WhereChain#not, WhereChain#missing, or WhereChain#associated.
    #
    # Chaining with WhereChain#not:
    #
    #    User.where.not(name: "Jon")
    #    # SELECT * FROM users WHERE name != 'Jon'
    #
    # Chaining with WhereChain#associated:
    #
    #    Post.where.associated(:author)
    #    # SELECT "posts".* FROM "posts"
    #    # INNER JOIN "authors" ON "authors"."id" = "posts"."author_id"
    #    # WHERE "authors"."id" IS NOT NULL
    #
    # Chaining with WhereChain#missing:
    #
    #    Post.where.missing(:author)
    #    # SELECT "posts".* FROM "posts"
    #    # LEFT OUTER JOIN "authors" ON "authors"."id" = "posts"."author_id"
    #    # WHERE "authors"."id" IS NULL
    #
    # === Blank Condition
    #
    # If the condition is any blank-ish object, then #where is a no-op and returns
    # the current relation.
    def where(*args)
      if args.empty?
        WhereChain.new(spawn)
      elsif args.length == 1 && args.first.blank?
        self
      else
        spawn.where!(*args)
      end
    end

    def where!(opts, *rest) # :nodoc:
      self.where_clause += build_where_clause(opts, rest)
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
      return unscope(:where) if conditions.nil?

      scope = spawn
      where_clause = scope.build_where_clause(conditions)

      scope.unscope!(where: where_clause.extract_attributes)
      scope.where_clause += where_clause
      scope
    end

    # Allows you to invert an entire where clause instead of manually applying conditions.
    #
    #   class User
    #     scope :active, -> { where(accepted: true, locked: false) }
    #   end
    #
    #   User.where(accepted: true)
    #   # WHERE `accepted` = 1
    #
    #   User.where(accepted: true).invert_where
    #   # WHERE `accepted` != 1
    #
    #   User.active
    #   # WHERE `accepted` = 1 AND `locked` = 0
    #
    #   User.active.invert_where
    #   # WHERE NOT (`accepted` = 1 AND `locked` = 0)
    #
    # Be careful because this inverts all conditions before +invert_where+ call.
    #
    #   class User
    #     scope :active, -> { where(accepted: true, locked: false) }
    #     scope :inactive, -> { active.invert_where } # Do not attempt it
    #   end
    #
    #   # It also inverts `where(role: 'admin')` unexpectedly.
    #   User.where(role: 'admin').inactive
    #   # WHERE NOT (`role` = 'admin' AND `accepted` = 1 AND `locked` = 0)
    #
    def invert_where
      spawn.invert_where!
    end

    def invert_where! # :nodoc:
      self.where_clause = where_clause.invert
      self
    end

    # Checks whether the given relation is structurally compatible with this relation, to determine
    # if it's possible to use the #and and #or methods without raising an error. Structurally
    # compatible is defined as: they must be scoping the same model, and they must differ only by
    # #where (if no #group has been defined) or #having (if a #group is present).
    #
    #    Post.where("id = 1").structurally_compatible?(Post.where("author_id = 3"))
    #    # => true
    #
    #    Post.joins(:comments).structurally_compatible?(Post.where("id = 1"))
    #    # => false
    #
    def structurally_compatible?(other)
      structurally_incompatible_values_for(other).empty?
    end

    # Returns a new relation, which is the logical intersection of this relation and the one passed
    # as an argument.
    #
    # The two relations must be structurally compatible: they must be scoping the same model, and
    # they must differ only by #where (if no #group has been defined) or #having (if a #group is
    # present).
    #
    #    Post.where(id: [1, 2]).and(Post.where(id: [2, 3]))
    #    # SELECT `posts`.* FROM `posts` WHERE `posts`.`id` IN (1, 2) AND `posts`.`id` IN (2, 3)
    #
    def and(other)
      if other.is_a?(Relation)
        spawn.and!(other)
      else
        raise ArgumentError, "You have passed #{other.class.name} object to #and. Pass an ActiveRecord::Relation object instead."
      end
    end

    def and!(other) # :nodoc:
      incompatible_values = structurally_incompatible_values_for(other)

      unless incompatible_values.empty?
        raise ArgumentError, "Relation passed to #and must be structurally compatible. Incompatible values: #{incompatible_values}"
      end

      self.where_clause |= other.where_clause
      self.having_clause |= other.having_clause
      self.references_values |= other.references_values

      self
    end

    # Returns a new relation, which is the logical union of this relation and the one passed as an
    # argument.
    #
    # The two relations must be structurally compatible: they must be scoping the same model, and
    # they must differ only by #where (if no #group has been defined) or #having (if a #group is
    # present).
    #
    #    Post.where("id = 1").or(Post.where("author_id = 3"))
    #    # SELECT `posts`.* FROM `posts` WHERE ((id = 1) OR (author_id = 3))
    #
    def or(other)
      if other.is_a?(Relation)
        if @none
          other.spawn
        else
          spawn.or!(other)
        end
      else
        raise ArgumentError, "You have passed #{other.class.name} object to #or. Pass an ActiveRecord::Relation object instead."
      end
    end

    def or!(other) # :nodoc:
      incompatible_values = structurally_incompatible_values_for(other)

      unless incompatible_values.empty?
        raise ArgumentError, "Relation passed to #or must be structurally compatible. Incompatible values: #{incompatible_values}"
      end

      self.where_clause = where_clause.or(other.where_clause)
      self.having_clause = having_clause.or(other.having_clause)
      self.references_values |= other.references_values

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
      self.having_clause += build_having_clause(opts, rest)
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
      unless @none
        where!("1=0")
        @none = true
      end
      self
    end

    def null_relation? # :nodoc:
      @none
    end

    # Mark a relation as readonly. Attempting to update a record will result in
    # an error.
    #
    #   users = User.readonly
    #   users.first.save
    #   => ActiveRecord::ReadOnlyRecord: User is marked as readonly
    #
    # To make a readonly relation writable, pass +false+.
    #
    #   users.readonly(false)
    #   users.first.save
    #   => true
    def readonly(value = true)
      spawn.readonly!(value)
    end

    def readonly!(value = true) # :nodoc:
      self.readonly_value = value
      self
    end

    # Sets the returned relation to strict_loading mode. This will raise an error
    # if the record tries to lazily load an association.
    #
    #   user = User.strict_loading.first
    #   user.comments.to_a
    #   => ActiveRecord::StrictLoadingViolationError
    def strict_loading(value = true)
      spawn.strict_loading!(value)
    end

    def strict_loading!(value = true) # :nodoc:
      self.strict_loading_value = value
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

    # Specifies the table from which the records will be fetched. For example:
    #
    #   Topic.select('title').from('posts')
    #   # SELECT title FROM posts
    #
    # Can accept other relation objects. For example:
    #
    #   Topic.select('title').from(Topic.approved)
    #   # SELECT title FROM (SELECT * FROM topics WHERE approved = 't') subquery
    #
    # Passing a second argument (string or symbol), creates the alias for the SQL from clause. Otherwise the alias "subquery" is used:
    #
    #   Topic.select('a.title').from(Topic.approved, :a)
    #   # SELECT a.title FROM (SELECT * FROM topics WHERE approved = 't') a
    #
    # It does not add multiple arguments to the SQL from clause. The last +from+ chained is the one used:
    #
    #   Topic.select('title').from(Topic.approved).from(Topic.inactive)
    #   # SELECT title FROM (SELECT topics.* FROM topics WHERE topics.active = 'f') subquery
    #
    # For multiple arguments for the SQL from clause, you can pass a string with the exact elements in the SQL from list:
    #
    #   color = "red"
    #   Color
    #     .from("colors c, JSONB_ARRAY_ELEMENTS(colored_things) AS colorvalues(colorvalue)")
    #     .where("colorvalue->>'color' = ?", color)
    #     .select("c.*").to_a
    #   # SELECT c.*
    #   # FROM colors c, JSONB_ARRAY_ELEMENTS(colored_things) AS colorvalues(colorvalue)
    #   # WHERE (colorvalue->>'color' = 'red')
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
    # === Using a \Module
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
    # === Using a Block
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

    # Specify optimizer hints to be used in the SELECT statement.
    #
    # Example (for MySQL):
    #
    #   Topic.optimizer_hints("MAX_EXECUTION_TIME(50000)", "NO_INDEX_MERGE(topics)")
    #   # SELECT /*+ MAX_EXECUTION_TIME(50000) NO_INDEX_MERGE(topics) */ `topics`.* FROM `topics`
    #
    # Example (for PostgreSQL with pg_hint_plan):
    #
    #   Topic.optimizer_hints("SeqScan(topics)", "Parallel(topics 8)")
    #   # SELECT /*+ SeqScan(topics) Parallel(topics 8) */ "topics".* FROM "topics"
    def optimizer_hints(*args)
      check_if_method_has_arguments!(__callee__, args)
      spawn.optimizer_hints!(*args)
    end

    def optimizer_hints!(*args) # :nodoc:
      self.optimizer_hints_values |= args
      self
    end

    # Reverse the existing order clause on the relation.
    #
    #   User.order('name ASC').reverse_order # generated SQL has 'ORDER BY name DESC'
    def reverse_order
      spawn.reverse_order!
    end

    def reverse_order! # :nodoc:
      orders = order_values.compact_blank
      self.order_values = reverse_sql_order(orders)
      self
    end

    def skip_query_cache!(value = true) # :nodoc:
      self.skip_query_cache_value = value
      self
    end

    def skip_preloading! # :nodoc:
      self.skip_preloading_value = true
      self
    end

    # Adds an SQL comment to queries generated from this relation. For example:
    #
    #   User.annotate("selecting user names").select(:name)
    #   # SELECT "users"."name" FROM "users" /* selecting user names */
    #
    #   User.annotate("selecting", "user", "names").select(:name)
    #   # SELECT "users"."name" FROM "users" /* selecting */ /* user */ /* names */
    #
    # The SQL block comment delimiters, "/*" and "*/", will be added automatically.
    #
    # Some escaping is performed, however untrusted user input should not be used.
    def annotate(*args)
      check_if_method_has_arguments!(__callee__, args)
      spawn.annotate!(*args)
    end

    # Like #annotate, but modifies relation in place.
    def annotate!(*args) # :nodoc:
      self.annotate_values += args
      self
    end

    # Deduplicate multiple values.
    def uniq!(name)
      if values = @values[name]
        values.uniq! if values.is_a?(Array) && !values.empty?
      end
      self
    end

    # Excludes the specified record (or collection of records) from the resulting
    # relation. For example:
    #
    #   Post.excluding(post)
    #   # SELECT "posts".* FROM "posts" WHERE "posts"."id" != 1
    #
    #   Post.excluding(post_one, post_two)
    #   # SELECT "posts".* FROM "posts" WHERE "posts"."id" NOT IN (1, 2)
    #
    #   Post.excluding(Post.drafts)
    #   # SELECT "posts".* FROM "posts" WHERE "posts"."id" NOT IN (3, 4, 5)
    #
    # This can also be called on associations. As with the above example, either
    # a single record of collection thereof may be specified:
    #
    #   post = Post.find(1)
    #   comment = Comment.find(2)
    #   post.comments.excluding(comment)
    #   # SELECT "comments".* FROM "comments" WHERE "comments"."post_id" = 1 AND "comments"."id" != 2
    #
    # This is short-hand for <tt>.where.not(id: post.id)</tt> and <tt>.where.not(id: [post_one.id, post_two.id])</tt>.
    #
    # An <tt>ArgumentError</tt> will be raised if either no records are
    # specified, or if any of the records in the collection (if a collection
    # is passed in) are not instances of the same model that the relation is
    # scoping.
    def excluding(*records)
      relations = records.extract! { |element| element.is_a?(Relation) }
      records.flatten!(1)
      records.compact!

      unless records.all?(model) && relations.all? { |relation| relation.model == model }
        raise ArgumentError, "You must only pass a single or collection of #{model.name} objects to ##{__callee__}."
      end

      spawn.excluding!(records + relations.flat_map(&:ids))
    end
    alias :without :excluding

    def excluding!(records) # :nodoc:
      predicates = [ predicate_builder[primary_key, records].invert ]
      self.where_clause += Relation::WhereClause.new(predicates)
      self
    end

    # Returns the Arel object associated with the relation.
    def arel(aliases = nil) # :nodoc:
      @arel ||= with_connection { |c| build_arel(c, aliases) }
    end

    def construct_join_dependency(associations, join_type) # :nodoc:
      ActiveRecord::Associations::JoinDependency.new(
        model, table, associations, join_type
      )
    end

    protected
      def build_subquery(subquery_alias, select_value) # :nodoc:
        subquery = except(:optimizer_hints).arel.as(subquery_alias)

        Arel::SelectManager.new(subquery).project(select_value).tap do |arel|
          arel.optimizer_hints(*optimizer_hints_values) unless optimizer_hints_values.empty?
        end
      end

      def build_where_clause(opts, rest = []) # :nodoc:
        opts = sanitize_forbidden_attributes(opts)

        if opts.is_a?(Array)
          opts, *rest = opts
        end

        case opts
        when String
          if rest.empty?
            parts = [Arel.sql(opts)]
          elsif rest.first.is_a?(Hash) && /:\w+/.match?(opts)
            parts = [build_named_bound_sql_literal(opts, rest.first)]
          elsif opts.include?("?")
            parts = [build_bound_sql_literal(opts, rest)]
          else
            parts = [model.sanitize_sql(rest.empty? ? opts : [opts, *rest])]
          end
        when Hash
          opts = opts.transform_keys do |key|
            if key.is_a?(Array)
              key.map { |k| model.attribute_aliases[k.to_s] || k.to_s }
            else
              key = key.to_s
              model.attribute_aliases[key] || key
            end
          end
          references = PredicateBuilder.references(opts)
          self.references_values |= references unless references.empty?

          parts = predicate_builder.build_from_hash(opts) do |table_name|
            lookup_table_klass_from_join_dependencies(table_name)
          end
        when Arel::Nodes::Node
          parts = [opts]
        else
          raise ArgumentError, "Unsupported argument type: #{opts} (#{opts.class})"
        end

        Relation::WhereClause.new(parts)
      end
      alias :build_having_clause :build_where_clause

      def async!
        @async = true
        self
      end

    protected
      def arel_columns(columns)
        columns.flat_map do |field|
          case field
          when Symbol, String
            arel_column(field)
          when Proc
            field.call
          when Hash
            arel_columns_from_hash(field)
          else
            field
          end
        end
      end

    private
      def async
        spawn.async!
      end

      def build_named_bound_sql_literal(statement, values)
        bound_values = values.transform_values do |value|
          if ActiveRecord::Relation === value
            Arel.sql(value.to_sql)
          elsif value.respond_to?(:map) && !value.acts_like?(:string)
            values = value.map { |v| v.respond_to?(:id_for_database) ? v.id_for_database : v }
            values.empty? ? nil : values
          else
            value = value.id_for_database if value.respond_to?(:id_for_database)
            value
          end
        end

        begin
          Arel::Nodes::BoundSqlLiteral.new("(#{statement})", nil, bound_values)
        rescue Arel::BindError => error
          raise ActiveRecord::PreparedStatementInvalid, error.message
        end
      end

      def build_bound_sql_literal(statement, values)
        bound_values = values.map do |value|
          if ActiveRecord::Relation === value
            Arel.sql(value.to_sql)
          elsif value.respond_to?(:map) && !value.acts_like?(:string)
            values = value.map { |v| v.respond_to?(:id_for_database) ? v.id_for_database : v }
            values.empty? ? nil : values
          else
            value = value.id_for_database if value.respond_to?(:id_for_database)
            value
          end
        end

        begin
          Arel::Nodes::BoundSqlLiteral.new("(#{statement})", bound_values, nil)
        rescue Arel::BindError => error
          raise ActiveRecord::PreparedStatementInvalid, error.message
        end
      end

      def lookup_table_klass_from_join_dependencies(table_name)
        each_join_dependencies do |join|
          return join.base_klass if table_name == join.table_name
        end
        nil
      end

      def each_join_dependencies(join_dependencies = build_join_dependencies, &block)
        join_dependencies.each do |join_dependency|
          join_dependency.each(&block)
        end
      end

      def build_join_dependencies
        joins = joins_values | left_outer_joins_values
        joins |= eager_load_values unless eager_load_values.empty?
        joins |= includes_values unless includes_values.empty?

        join_dependencies = []
        join_dependencies.unshift construct_join_dependency(
          select_named_joins(joins, join_dependencies), nil
        )
      end

      def assert_modifiable!
        raise UnmodifiableRelation if @loaded || @arel
      end

      def build_arel(connection, aliases = nil)
        arel = Arel::SelectManager.new(table)

        build_joins(arel.join_sources, aliases)

        arel.where(where_clause.ast) unless where_clause.empty?
        arel.having(having_clause.ast) unless having_clause.empty?
        arel.take(build_cast_value("LIMIT", connection.sanitize_limit(limit_value))) if limit_value
        arel.skip(build_cast_value("OFFSET", offset_value.to_i)) if offset_value
        arel.group(*arel_columns(group_values.uniq)) unless group_values.empty?

        build_order(arel)
        build_with(arel)
        build_select(arel)

        arel.optimizer_hints(*optimizer_hints_values) unless optimizer_hints_values.empty?
        arel.distinct(distinct_value)
        arel.from(build_from) unless from_clause.empty?
        arel.lock(lock_value) if lock_value

        unless annotate_values.empty?
          annotates = annotate_values
          annotates = annotates.uniq if annotates.size > 1
          arel.comment(*annotates)
        end

        arel
      end

      def build_cast_value(name, value)
        ActiveModel::Attribute.with_cast_value(name, value, Type.default_value)
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

      def select_named_joins(join_names, stashed_joins = nil, &block)
        cte_joins, associations = join_names.partition do |join_name|
          Symbol === join_name && with_values.any? { _1.key?(join_name) }
        end

        cte_joins.each do |cte_name|
          block&.call(CTEJoin.new(cte_name))
        end

        select_association_list(associations, stashed_joins, &block)
      end

      def select_association_list(associations, stashed_joins = nil)
        result = []
        associations.each do |association|
          case association
          when Hash, Symbol, Array
            result << association
          when ActiveRecord::Associations::JoinDependency
            stashed_joins&.<< association
          else
            yield association if block_given?
          end
        end
        result
      end

      def build_join_buckets
        buckets = Hash.new { |h, k| h[k] = [] }

        unless left_outer_joins_values.empty?
          stashed_left_joins = []
          left_joins = select_named_joins(left_outer_joins_values, stashed_left_joins) do |left_join|
            if left_join.is_a?(CTEJoin)
              buckets[:join_node] << build_with_join_node(left_join.name, Arel::Nodes::OuterJoin)
            else
              raise ArgumentError, "only Hash, Symbol and Array are allowed"
            end
          end

          if joins_values.empty?
            buckets[:named_join] = left_joins
            buckets[:stashed_join] = stashed_left_joins
            return buckets, Arel::Nodes::OuterJoin
          else
            stashed_left_joins.unshift construct_join_dependency(left_joins, Arel::Nodes::OuterJoin)
          end
        end

        joins = joins_values.dup
        if joins.last.is_a?(ActiveRecord::Associations::JoinDependency)
          stashed_eager_load = joins.pop if joins.last.base_klass == model
        end

        joins.each_with_index do |join, i|
          joins[i] = Arel::Nodes::StringJoin.new(Arel.sql(join.strip)) if join.is_a?(String)
        end

        while joins.first.is_a?(Arel::Nodes::Join)
          join_node = joins.shift
          if !join_node.is_a?(Arel::Nodes::LeadingJoin) && (stashed_eager_load || stashed_left_joins)
            buckets[:join_node] << join_node
          else
            buckets[:leading_join] << join_node
          end
        end

        buckets[:named_join] = select_named_joins(joins, buckets[:stashed_join]) do |join|
          if join.is_a?(Arel::Nodes::Join)
            buckets[:join_node] << join
          elsif join.is_a?(CTEJoin)
            buckets[:join_node] << build_with_join_node(join.name)
          else
            raise "unknown class: %s" % join.class.name
          end
        end

        buckets[:stashed_join].concat stashed_left_joins if stashed_left_joins
        buckets[:stashed_join] << stashed_eager_load if stashed_eager_load

        return buckets, Arel::Nodes::InnerJoin
      end

      def build_joins(join_sources, aliases = nil)
        return join_sources if joins_values.empty? && left_outer_joins_values.empty?

        buckets, join_type = build_join_buckets

        named_joins   = buckets[:named_join]
        stashed_joins = buckets[:stashed_join]
        leading_joins = buckets[:leading_join]
        join_nodes    = buckets[:join_node]

        join_sources.concat(leading_joins) unless leading_joins.empty?

        unless named_joins.empty? && stashed_joins.empty?
          alias_tracker = alias_tracker(leading_joins + join_nodes, aliases)
          join_dependency = construct_join_dependency(named_joins, join_type)
          join_sources.concat(join_dependency.join_constraints(stashed_joins, alias_tracker, references_values))
        end

        join_sources.concat(join_nodes) unless join_nodes.empty?
        join_sources
      end

      def build_select(arel)
        if select_values.any?
          arel.project(*arel_columns(select_values))
        elsif model.ignored_columns.any? || model.enumerate_columns_in_select_statements
          arel.project(*model.column_names.map { |field| table[field] })
        else
          arel.project(table[Arel.star])
        end
      end

      def build_with(arel)
        return if with_values.empty?

        with_statements = with_values.map do |with_value|
          build_with_value_from_hash(with_value)
        end

        @with_is_recursive ? arel.with(:recursive, with_statements) : arel.with(with_statements)
      end

      def build_with_value_from_hash(hash)
        hash.map do |name, value|
          Arel::Nodes::TableAlias.new(build_with_expression_from_value(value), name)
        end
      end

      def build_with_expression_from_value(value, nested = false)
        case value
        when Arel::Nodes::SqlLiteral then Arel::Nodes::Grouping.new(value)
        when ActiveRecord::Relation
          if nested
            value.arel.ast
          else
            value.arel
          end
        when Arel::SelectManager then value
        when Array
          return build_with_expression_from_value(value.first, false) if value.size == 1

          parts = value.map do |query|
            build_with_expression_from_value(query, true)
          end

          parts.reduce do |result, value|
            Arel::Nodes::UnionAll.new(result, value)
          end
        else
          raise ArgumentError, "Unsupported argument type: `#{value}` #{value.class}"
        end
      end

      def build_with_join_node(name, kind = Arel::Nodes::InnerJoin)
        with_table = Arel::Table.new(name)

        table.join(with_table, kind).on(
          with_table[model.model_name.to_s.foreign_key].eq(table[model.primary_key])
        ).join_sources.first
      end

      def arel_columns_from_hash(fields)
        fields.flat_map do |table_name, columns|
          table_name = table_name.name if table_name.is_a?(Symbol)
          case columns
          when Symbol, String
            arel_column_with_table(table_name, columns)
          when Array
            columns.map do |column|
              arel_column_with_table(table_name, column)
            end
          else
            raise TypeError, "Expected Symbol, String or Array, got: #{columns.class}"
          end
        end
      end

      def arel_column_with_table(table_name, column_name)
        self.references_values |= [Arel.sql(table_name, retryable: true)]

        if column_name.is_a?(Symbol) || !column_name.match?(/\W/)
          predicate_builder.resolve_arel_attribute(table_name, column_name) do
            lookup_table_klass_from_join_dependencies(table_name)
          end
        else
          Arel.sql("#{model.adapter_class.quote_table_name(table_name)}.#{column_name}")
        end
      end

      def arel_column(field)
        field = field.name if is_symbol = field.is_a?(Symbol)

        field = model.attribute_aliases[field] || field.to_s
        from = from_clause.name || from_clause.value

        if model.columns_hash.key?(field) && (!from || table_name_matches?(from))
          table[field]
        elsif /\A(?<table>(?:\w+\.)?\w+)\.(?<column>\w+)\z/ =~ field
          arel_column_with_table(table, column)
        elsif block_given?
          yield field
        elsif Arel.arel_node?(field)
          field
        else
          Arel.sql(is_symbol ? model.adapter_class.quote_table_name(field) : field)
        end
      end

      def table_name_matches?(from)
        table_name = Regexp.escape(table.name)
        quoted_table_name = Regexp.escape(model.adapter_class.quote_table_name(table.name))
        /(?:\A|(?<!FROM)\s)(?:\b#{table_name}\b|#{quoted_table_name})(?!\.)/i.match?(from.to_s)
      end

      def reverse_sql_order(order_query)
        if order_query.empty?
          return [table[primary_key].desc] if primary_key
          raise IrreversibleOrderError,
            "Relation has no current order and table has no primary key to be used as default order"
        end

        order_query.flat_map do |o|
          case o
          when Arel::Attribute
            o.desc
          when Arel::Nodes::Ordering
            o.reverse
          when Arel::Nodes::NodeExpression
            o.desc
          when String
            if does_not_support_reverse?(o)
              raise IrreversibleOrderError, "Order #{o.inspect} cannot be reversed automatically"
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
          /\bnulls\s+(?:first|last)\b/i.match?(order)
      end

      def build_order(arel)
        orders = order_values.compact_blank
        arel.order(*orders) unless orders.empty?
      end

      VALID_DIRECTIONS = [:asc, :desc, :ASC, :DESC,
                          "asc", "desc", "ASC", "DESC"].to_set # :nodoc:

      def validate_order_args(args)
        args.each do |arg|
          next unless arg.is_a?(Hash)
          arg.each do |_key, value|
            if value.is_a?(Hash)
              validate_order_args([value])
            elsif VALID_DIRECTIONS.exclude?(value)
              raise ArgumentError,
                "Direction \"#{value}\" is invalid. Valid directions are: #{VALID_DIRECTIONS.to_a.inspect}"
            end
          end
        end
      end

      def flattened_args(args)
        args.flat_map { |e| (e.is_a?(Hash) || e.is_a?(Array)) ? flattened_args(e.to_a) : e }
      end

      def preprocess_order_args(order_args)
        model.disallow_raw_sql!(
          flattened_args(order_args),
          permit: model.adapter_class.column_name_with_order_matcher
        )

        validate_order_args(order_args)

        references = column_references(order_args)
        self.references_values |= references unless references.empty?

        # if a symbol is given we prepend the quoted table name
        order_args.map! do |arg|
          case arg
          when Symbol
            order_column(arg.to_s).asc
          when Hash
            arg.map do |key, value|
              if value.is_a?(Hash)
                value.map do |field, dir|
                  order_column([key.to_s, field.to_s].join(".")).public_send(dir.downcase)
                end
              else
                case key
                when Arel::Nodes::SqlLiteral, Arel::Nodes::Node, Arel::Attribute
                  key.public_send(value.downcase)
                else
                  order_column(key.to_s).public_send(value.downcase)
                end
              end
            end
          else
            arg
          end
        end.flatten!
      end

      def sanitize_order_arguments(order_args)
        order_args.map! do |arg|
          model.sanitize_sql_for_order(arg)
        end
      end

      def column_references(order_args)
        order_args.flat_map do |arg|
          case arg
          when String, Symbol
            extract_table_name_from(arg)
          when Hash
            arg
              .map do |key, value|
                case value
                when Hash
                  key.to_s
                else
                  extract_table_name_from(key) if key.is_a?(String) || key.is_a?(Symbol)
                end
              end
          when Arel::Attribute
            arg.relation.name
          when Arel::Nodes::Ordering
            if arg.expr.is_a?(Arel::Attribute)
              arg.expr.relation.name
            end
          end
        end.filter_map { |ref| Arel.sql(ref, retryable: true) if ref }
      end

      def extract_table_name_from(string)
        string.match(/^\W?(\w+)\W?\./) && $1
      end

      def order_column(field)
        arel_column(field) do |attr_name|
          if attr_name == "count" && !group_values.empty?
            table[attr_name]
          else
            Arel.sql(model.adapter_class.quote_table_name(attr_name), retryable: true)
          end
        end
      end

      def build_case_for_value_position(column, values, filter: true)
        node = Arel::Nodes::Case.new
        values.each.with_index(1) do |value, order|
          node.when(column.eq(value)).then(order)
        end

        node = node.else(values.length + 1) unless filter
        Arel::Nodes::Ascending.new(node)
      end

      def resolve_arel_attributes(attrs)
        attrs.flat_map do |attr|
          case attr
          when Arel::Predications
            attr
          when Hash
            attr.flat_map do |table, columns|
              table = table.to_s
              Array(columns).map do |column|
                predicate_builder.resolve_arel_attribute(table, column)
              end
            end
          else
            attr = attr.to_s
            if attr.include?(".")
              table, column = attr.split(".", 2)
              predicate_builder.resolve_arel_attribute(table, column)
            else
              attr
            end
          end
        end
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
      # This particular method should be called with a method_name (__callee__) and the args
      # passed into that method as an input. For example:
      #
      # def references(*args)
      #   check_if_method_has_arguments!(__callee__, args)
      #   ...
      # end
      def check_if_method_has_arguments!(method_name, args, message = nil)
        if args.blank?
          raise ArgumentError, message || "The method .#{method_name}() must contain arguments."
        else
          yield args if block_given?

          args.flatten!
          args.compact_blank!
        end
      end

      def process_select_args(fields)
        fields.flat_map do |field|
          if field.is_a?(Hash)
            arel_column_aliases_from_hash(field)
          else
            field
          end
        end
      end

      def arel_column_aliases_from_hash(fields)
        fields.flat_map do |key, columns_aliases|
          table_name = key.is_a?(Symbol) ? key.name : key
          case columns_aliases
          when Hash
            columns_aliases.map do |column, column_alias|
              arel_column_with_table(table_name, column)
                .as(model.adapter_class.quote_column_name(column_alias.to_s))
            end
          when Array
            columns_aliases.map do |column|
              arel_column_with_table(table_name, column)
            end
          when String, Symbol
            arel_column(key)
              .as(model.adapter_class.quote_column_name(columns_aliases.to_s))
          end
        end
      end

      def process_with_args(args)
        args.flat_map do |arg|
          raise ArgumentError, "Unsupported argument type: #{arg} #{arg.class}" unless arg.is_a?(Hash)
          arg.map { |k, v| { k => v } }
        end
      end

      STRUCTURAL_VALUE_METHODS = (
        Relation::VALUE_METHODS -
        [:extending, :where, :having, :unscope, :references, :annotate, :optimizer_hints]
      ).freeze # :nodoc:

      def structurally_incompatible_values_for(other)
        values = other.values
        STRUCTURAL_VALUE_METHODS.reject do |method|
          v1, v2 = @values[method], values[method]
          if v1.is_a?(Array)
            next true unless v2.is_a?(Array)
            v1 = v1.uniq
            v2 = v2.uniq
          end
          v1 == v2
        end
      end
  end
end
