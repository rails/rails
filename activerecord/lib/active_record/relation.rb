# -*- coding: utf-8 -*-
require "arel/collectors/bind"

module ActiveRecord
  # = Active Record Relation
  class Relation
    MULTI_VALUE_METHODS  = [:includes, :eager_load, :preload, :select, :group,
                            :order, :joins, :references,
                            :extending, :unscope]

    SINGLE_VALUE_METHODS = [:limit, :offset, :lock, :readonly, :reordering,
                            :reverse_order, :distinct, :create_with, :uniq]
    CLAUSE_METHODS = [:where, :having, :from]
    INVALID_METHODS_FOR_DELETE_ALL = [:limit, :distinct, :offset, :group, :having]

    VALUE_METHODS = MULTI_VALUE_METHODS + SINGLE_VALUE_METHODS + CLAUSE_METHODS

    include FinderMethods, Calculations, SpawnMethods, QueryMethods, Batches,
      Explain, Delegation, Mutation, Collection, SerializationMethods


    attr_reader :table, :klass, :loaded, :predicate_builder
    alias :model :klass
    alias :loaded? :loaded

    def initialize(klass, table, predicate_builder, values = {})
      @klass  = klass
      @table  = table
      @values = values
      @offsets = {}
      @loaded = false
      @predicate_builder = predicate_builder
    end

    def initialize_copy(other)
      # This method is a hot spot, so for now, use Hash[] to dup the hash.
      #   https://bugs.ruby-lang.org/issues/7166
      @values = Hash[@values]
      reset
    end

    # Initializes new record from relation while maintaining the current
    # scope.
    #
    # Expects arguments in the same format as +Base.new+.
    #
    #   users = User.where(name: 'DHH')
    #   user = users.new # => #<User id: nil, name: "DHH", created_at: nil, updated_at: nil>
    #
    # You can also pass a block to new with the new record as argument:
    #
    #   user = users.new { |user| user.name = 'Oscar' }
    #   user.name # => Oscar
    def new(*args, &block)
      scoping { @klass.new(*args, &block) }
    end

    alias build new

    # Tries to create a new record with the same scoped attributes
    # defined in the relation. Returns the initialized object if validation fails.
    #
    # Expects arguments in the same format as +Base.create+.
    #
    # ==== Examples
    #   users = User.where(name: 'Oscar')
    #   users.create # #<User id: 3, name: "oscar", ...>
    #
    #   users.create(name: 'fxn')
    #   users.create # #<User id: 4, name: "fxn", ...>
    #
    #   users.create { |user| user.name = 'tenderlove' }
    #   # #<User id: 5, name: "tenderlove", ...>
    #
    #   users.create(name: nil) # validation on name
    #   # #<User id: nil, name: nil, ...>
    def create(*args, &block)
      scoping { @klass.create(*args, &block) }
    end

    # Similar to #create, but calls +create!+ on the base class. Raises
    # an exception if a validation error occurs.
    #
    # Expects arguments in the same format as <tt>Base.create!</tt>.
    def create!(*args, &block)
      scoping { @klass.create!(*args, &block) }
    end

    def first_or_create(attributes = nil, &block) # :nodoc:
      first || create(attributes, &block)
    end

    def first_or_create!(attributes = nil, &block) # :nodoc:
      first || create!(attributes, &block)
    end

    def first_or_initialize(attributes = nil, &block) # :nodoc:
      first || new(attributes, &block)
    end

    # Finds the first record with the given attributes, or creates a record
    # with the attributes if one is not found:
    #
    #   # Find the first user named "Penélope" or create a new one.
    #   User.find_or_create_by(first_name: 'Penélope')
    #   # => #<User id: 1, first_name: "Penélope", last_name: nil>
    #
    #   # Find the first user named "Penélope" or create a new one.
    #   # We already have one so the existing record will be returned.
    #   User.find_or_create_by(first_name: 'Penélope')
    #   # => #<User id: 1, first_name: "Penélope", last_name: nil>
    #
    #   # Find the first user named "Scarlett" or create a new one with
    #   # a particular last name.
    #   User.create_with(last_name: 'Johansson').find_or_create_by(first_name: 'Scarlett')
    #   # => #<User id: 2, first_name: "Scarlett", last_name: "Johansson">
    #
    # This method accepts a block, which is passed down to +create+. The last example
    # above can be alternatively written this way:
    #
    #   # Find the first user named "Scarlett" or create a new one with a
    #   # different last name.
    #   User.find_or_create_by(first_name: 'Scarlett') do |user|
    #     user.last_name = 'Johansson'
    #   end
    #   # => #<User id: 2, first_name: "Scarlett", last_name: "Johansson">
    #
    # This method always returns a record, but if creation was attempted and
    # failed due to validation errors it won't be persisted, you get what
    # +create+ returns in such situation.
    #
    # Please note *this method is not atomic*, it runs first a SELECT, and if
    # there are no results an INSERT is attempted. If there are other threads
    # or processes there is a race condition between both calls and it could
    # be the case that you end up with two similar records.
    #
    # Whether that is a problem or not depends on the logic of the
    # application, but in the particular case in which rows have a UNIQUE
    # constraint an exception may be raised, just retry:
    #
    #  begin
    #    CreditAccount.find_or_create_by(user_id: user.id)
    #  rescue ActiveRecord::RecordNotUnique
    #    retry
    #  end
    #
    def find_or_create_by(attributes, &block)
      find_by(attributes) || create(attributes, &block)
    end

    # Like <tt>find_or_create_by</tt>, but calls <tt>create!</tt> so an exception
    # is raised if the created record is invalid.
    def find_or_create_by!(attributes, &block)
      find_by(attributes) || create!(attributes, &block)
    end

    # Like <tt>find_or_create_by</tt>, but calls <tt>new</tt> instead of <tt>create</tt>.
    def find_or_initialize_by(attributes, &block)
      find_by(attributes) || new(attributes, &block)
    end

    # Scope all queries to the current scope.
    #
    #   Comment.where(post_id: 1).scoping do
    #     Comment.first
    #   end
    #   # => SELECT "comments".* FROM "comments" WHERE "comments"."post_id" = 1 ORDER BY "comments"."id" ASC LIMIT 1
    #
    # Please check unscoped if you want to remove all previous scopes (including
    # the default_scope) during the execution of a block.
    def scoping
      previous, klass.current_scope = klass.current_scope, self
      yield
    ensure
      klass.current_scope = previous
    end

    # Forces reloading of relation.
    def reload
      reset
      load
    end

    def reset
      @last = @to_sql = @order_clause = @scope_for_create = @arel = @loaded = nil
      @should_eager_load = @join_dependency = nil
      @records = []
      @offsets = {}
      self
    end

    # Compares two relations for equality.
    def ==(other)
      case other
      when Associations::CollectionProxy, AssociationRelation
        self == other.to_a
      when Relation
        other.to_sql == to_sql
      when Array
        to_a == other
      end
    end

    def pretty_print(q)
      q.pp(self.to_a)
    end

    def values
      Hash[@values]
    end

    def inspect
      entries = to_a.take([limit_value, 11].compact.min).map!(&:inspect)
      entries[10] = '...' if entries.size == 11

      "#<#{self.class.name} [#{entries.join(', ')}]>"
    end

    private

    def build_preloader
      ActiveRecord::Associations::Preloader.new
    end

    def references_eager_loaded_tables?
      joined_tables = arel.join_sources.map do |join|
        if join.is_a?(Arel::Nodes::StringJoin)
          tables_in_string(join.left)
        else
          [join.left.table_name, join.left.table_alias]
        end
      end

      joined_tables += [table.name, table.table_alias]

      # always convert table names to downcase as in Oracle quoted table names are in uppercase
      joined_tables = joined_tables.flatten.compact.map(&:downcase).uniq

      (references_values - joined_tables).any?
    end

    def tables_in_string(string)
      return [] if string.blank?
      # always convert table names to downcase as in Oracle quoted table names are in uppercase
      # ignore raw_sql_ that is used by Oracle adapter as alias for limit/offset subqueries
      string.scan(/([a-zA-Z_][.\w]+).?\./).flatten.map(&:downcase).uniq - ['raw_sql_']
    end
  end
end
