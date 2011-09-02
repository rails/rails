require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/module/delegation'

module ActiveRecord
  # = Active Record Relation
  class Relation
    JoinOperation = Struct.new(:relation, :join_class, :on)
    ASSOCIATION_METHODS = [:includes, :eager_load, :preload]
    MULTI_VALUE_METHODS = [:select, :group, :order, :joins, :where, :having, :bind]
    SINGLE_VALUE_METHODS = [:limit, :offset, :lock, :readonly, :from, :reorder, :reverse_order]

    include FinderMethods, Calculations, SpawnMethods, QueryMethods, Batches

    # These are explicitly delegated to improve performance (avoids method_missing)
    delegate :to_xml, :to_yaml, :length, :collect, :map, :each, :all?, :include?, :to => :to_a
    delegate :table_name, :quoted_table_name, :primary_key, :quoted_primary_key, :to => :klass

    attr_reader :table, :klass, :loaded
    attr_accessor :extensions, :default_scoped
    alias :loaded? :loaded
    alias :default_scoped? :default_scoped

    def initialize(klass, table)
      @klass, @table = klass, table

      @implicit_readonly = nil
      @loaded            = false
      @default_scoped    = false

      SINGLE_VALUE_METHODS.each {|v| instance_variable_set(:"@#{v}_value", nil)}
      (ASSOCIATION_METHODS + MULTI_VALUE_METHODS).each {|v| instance_variable_set(:"@#{v}_values", [])}
      @extensions = []
      @create_with_value = {}
    end

    def insert(values)
      primary_key_value = nil

      if primary_key && Hash === values
        primary_key_value = values[values.keys.find { |k|
          k.name == primary_key
        }]

        if !primary_key_value && connection.prefetch_primary_key?(klass.table_name)
          primary_key_value = connection.next_sequence_value(klass.sequence_name)
          values[klass.arel_table[klass.primary_key]] = primary_key_value
        end
      end

      im = arel.create_insert
      im.into @table

      conn = @klass.connection

      substitutes = values.sort_by { |arel_attr,_| arel_attr.name }
      binds       = substitutes.map do |arel_attr, value|
        [@klass.columns_hash[arel_attr.name], value]
      end

      substitutes.each_with_index do |tuple, i|
        tuple[1] = conn.substitute_at(binds[i][0], i)
      end

      if values.empty? # empty insert
        im.values = Arel.sql(connection.empty_insert_statement_value)
      else
        im.insert substitutes
      end

      conn.insert(
        im,
        'SQL',
        primary_key,
        primary_key_value,
        nil,
        binds)
    end

    def new(*args, &block)
      scoping { @klass.new(*args, &block) }
    end

    def initialize_copy(other)
      reset
    end

    alias build new

    def create(*args, &block)
      scoping { @klass.create(*args, &block) }
    end

    def create!(*args, &block)
      scoping { @klass.create!(*args, &block) }
    end

    def respond_to?(method, include_private = false)
      arel.respond_to?(method, include_private)     ||
        Array.method_defined?(method)               ||
        @klass.respond_to?(method, include_private) ||
        super
    end

    def to_a
      return @records if loaded?

      default_scoped = with_default_scope

      if default_scoped.equal?(self)
        @records = if @readonly_value.nil? && !@klass.locking_enabled?
          eager_loading? ? find_with_associations : @klass.find_by_sql(arel, @bind_values)
        else
          IdentityMap.without do
            eager_loading? ? find_with_associations : @klass.find_by_sql(arel, @bind_values)
          end
        end

        preload = @preload_values
        preload +=  @includes_values unless eager_loading?
        preload.each do |associations|
          ActiveRecord::Associations::Preloader.new(@records, associations).run
        end

        # @readonly_value is true only if set explicitly. @implicit_readonly is true if there
        # are JOINS and no explicit SELECT.
        readonly = @readonly_value.nil? ? @implicit_readonly : @readonly_value
        @records.each { |record| record.readonly! } if readonly
      else
        @records = default_scoped.to_a
      end

      @loaded = true
      @records
    end

    def as_json(options = nil) #:nodoc:
      to_a.as_json(options)
    end

    # Returns size of the records.
    def size
      loaded? ? @records.length : count
    end

    # Returns true if there are no records.
    def empty?
      return @records.empty? if loaded?

      c = count
      c.respond_to?(:zero?) ? c.zero? : c.empty?
    end

    def any?
      if block_given?
        to_a.any? { |*block_args| yield(*block_args) }
      else
        !empty?
      end
    end

    def many?
      if block_given?
        to_a.many? { |*block_args| yield(*block_args) }
      else
        @limit_value ? to_a.many? : size > 1
      end
    end

    # Scope all queries to the current scope.
    #
    # ==== Example
    #
    #   Comment.where(:post_id => 1).scoping do
    #     Comment.first # SELECT * FROM comments WHERE post_id = 1
    #   end
    #
    # Please check unscoped if you want to remove all previous scopes (including
    # the default_scope) during the execution of a block.
    def scoping
      @klass.send(:with_scope, self, :overwrite) { yield }
    end

    # Updates all records with details given if they match a set of conditions supplied, limits and order can
    # also be supplied. This method constructs a single SQL UPDATE statement and sends it straight to the
    # database. It does not instantiate the involved models and it does not trigger Active Record callbacks
    # or validations.
    #
    # ==== Parameters
    #
    # * +updates+ - A string, array, or hash representing the SET part of an SQL statement.
    # * +conditions+ - A string, array, or hash representing the WHERE part of an SQL statement.
    #   See conditions in the intro.
    # * +options+ - Additional options are <tt>:limit</tt> and <tt>:order</tt>, see the examples for usage.
    #
    # ==== Examples
    #
    #   # Update all customers with the given attributes
    #   Customer.update_all :wants_email => true
    #
    #   # Update all books with 'Rails' in their title
    #   Book.update_all "author = 'David'", "title LIKE '%Rails%'"
    #
    #   # Update all avatars migrated more than a week ago
    #   Avatar.update_all ['migrated_at = ?', Time.now.utc], ['migrated_at > ?', 1.week.ago]
    #
    #   # Update all books that match conditions, but limit it to 5 ordered by date
    #   Book.update_all "author = 'David'", "title LIKE '%Rails%'", :order => 'created_at', :limit => 5
    #
    #   # Conditions from the current relation also works
    #   Book.where('title LIKE ?', '%Rails%').update_all(:author => 'David')
    #
    #   # The same idea applies to limit and order
    #   Book.where('title LIKE ?', '%Rails%').order(:created_at).limit(5).update_all(:author => 'David')
    def update_all(updates, conditions = nil, options = {})
      IdentityMap.repository[symbolized_base_class].clear if IdentityMap.enabled?
      if conditions || options.present?
        where(conditions).apply_finder_options(options.slice(:limit, :order)).update_all(updates)
      else
        stmt = Arel::UpdateManager.new(arel.engine)

        stmt.set Arel.sql(@klass.send(:sanitize_sql_for_assignment, updates))
        stmt.table(table)
        stmt.key = table[primary_key]

        if joins_values.any?
          @klass.connection.join_to_update(stmt, arel)
        else
          stmt.take(arel.limit)
          stmt.order(*arel.orders)
          stmt.wheres = arel.constraints
        end

        @klass.connection.update stmt, 'SQL', bind_values
      end
    end

    # Updates an object (or multiple objects) and saves it to the database, if validations pass.
    # The resulting object is returned whether the object was saved successfully to the database or not.
    #
    # ==== Parameters
    #
    # * +id+ - This should be the id or an array of ids to be updated.
    # * +attributes+ - This should be a hash of attributes or an array of hashes.
    #
    # ==== Examples
    #
    #   # Updates one record
    #   Person.update(15, :user_name => 'Samuel', :group => 'expert')
    #
    #   # Updates multiple records
    #   people = { 1 => { "first_name" => "David" }, 2 => { "first_name" => "Jeremy" } }
    #   Person.update(people.keys, people.values)
    def update(id, attributes)
      if id.is_a?(Array)
        idx = -1
        id.collect { |one_id| idx += 1; update(one_id, attributes[idx]) }
      else
        object = find(id)
        object.update_attributes(attributes)
        object
      end
    end

    # Destroys the records matching +conditions+ by instantiating each
    # record and calling its +destroy+ method. Each object's callbacks are
    # executed (including <tt>:dependent</tt> association options and
    # +before_destroy+/+after_destroy+ Observer methods). Returns the
    # collection of objects that were destroyed; each will be frozen, to
    # reflect that no changes should be made (since they can't be
    # persisted).
    #
    # Note: Instantiation, callback execution, and deletion of each
    # record can be time consuming when you're removing many records at
    # once. It generates at least one SQL +DELETE+ query per record (or
    # possibly more, to enforce your callbacks). If you want to delete many
    # rows quickly, without concern for their associations or callbacks, use
    # +delete_all+ instead.
    #
    # ==== Parameters
    #
    # * +conditions+ - A string, array, or hash that specifies which records
    #   to destroy. If omitted, all records are destroyed. See the
    #   Conditions section in the introduction to ActiveRecord::Base for
    #   more information.
    #
    # ==== Examples
    #
    #   Person.destroy_all("last_login < '2004-04-04'")
    #   Person.destroy_all(:status => "inactive")
    #   Person.where(:age => 0..18).destroy_all
    def destroy_all(conditions = nil)
      if conditions
        where(conditions).destroy_all
      else
        to_a.each {|object| object.destroy }.tap { reset }
      end
    end

    # Destroy an object (or multiple objects) that has the given id, the object is instantiated first,
    # therefore all callbacks and filters are fired off before the object is deleted.  This method is
    # less efficient than ActiveRecord#delete but allows cleanup methods and other actions to be run.
    #
    # This essentially finds the object (or multiple objects) with the given id, creates a new object
    # from the attributes, and then calls destroy on it.
    #
    # ==== Parameters
    #
    # * +id+ - Can be either an Integer or an Array of Integers.
    #
    # ==== Examples
    #
    #   # Destroy a single object
    #   Todo.destroy(1)
    #
    #   # Destroy multiple objects
    #   todos = [1,2,3]
    #   Todo.destroy(todos)
    def destroy(id)
      if id.is_a?(Array)
        id.map { |one_id| destroy(one_id) }
      else
        find(id).destroy
      end
    end

    # Deletes the records matching +conditions+ without instantiating the records first, and hence not
    # calling the +destroy+ method nor invoking callbacks. This is a single SQL DELETE statement that
    # goes straight to the database, much more efficient than +destroy_all+. Be careful with relations
    # though, in particular <tt>:dependent</tt> rules defined on associations are not honored.  Returns
    # the number of rows affected.
    #
    # ==== Parameters
    #
    # * +conditions+ - Conditions are specified the same way as with +find+ method.
    #
    # ==== Example
    #
    #   Post.delete_all("person_id = 5 AND (category = 'Something' OR category = 'Else')")
    #   Post.delete_all(["person_id = ? AND (category = ? OR category = ?)", 5, 'Something', 'Else'])
    #   Post.where(:person_id => 5).where(:category => ['Something', 'Else']).delete_all
    #
    # Both calls delete the affected posts all at once with a single DELETE statement.
    # If you need to destroy dependent associations or call your <tt>before_*</tt> or
    # +after_destroy+ callbacks, use the +destroy_all+ method instead.
    def delete_all(conditions = nil)
      IdentityMap.repository[symbolized_base_class] = {} if IdentityMap.enabled?
      if conditions
        where(conditions).delete_all
      else
        statement = arel.compile_delete
        affected = @klass.connection.delete(statement, 'SQL', bind_values)

        reset
        affected
      end
    end

    # Deletes the row with a primary key matching the +id+ argument, using a
    # SQL +DELETE+ statement, and returns the number of rows deleted. Active
    # Record objects are not instantiated, so the object's callbacks are not
    # executed, including any <tt>:dependent</tt> association options or
    # Observer methods.
    #
    # You can delete multiple rows at once by passing an Array of <tt>id</tt>s.
    #
    # Note: Although it is often much faster than the alternative,
    # <tt>#destroy</tt>, skipping callbacks might bypass business logic in
    # your application that ensures referential integrity or performs other
    # essential jobs.
    #
    # ==== Examples
    #
    #   # Delete a single row
    #   Todo.delete(1)
    #
    #   # Delete multiple rows
    #   Todo.delete([2,3,4])
    def delete(id_or_array)
      IdentityMap.remove_by_id(self.symbolized_base_class, id_or_array) if IdentityMap.enabled?
      where(primary_key => id_or_array).delete_all
    end

    def reload
      reset
      to_a # force reload
      self
    end

    def reset
      @first = @last = @to_sql = @order_clause = @scope_for_create = @arel = @loaded = nil
      @should_eager_load = @join_dependency = nil
      @records = []
      self
    end

    def to_sql
      @to_sql ||= klass.connection.to_sql(arel)
    end

    def where_values_hash
      equalities = with_default_scope.where_values.grep(Arel::Nodes::Equality).find_all { |node|
        node.left.relation.name == table_name
      }

      Hash[equalities.map { |where| [where.left.name, where.right] }]
    end

    def scope_for_create
      @scope_for_create ||= where_values_hash.merge(create_with_value)
    end

    def eager_loading?
      @should_eager_load ||=
        @eager_load_values.any? ||
        @includes_values.any? && (joined_includes_values.any? || references_eager_loaded_tables?)
    end

    # Joins that are also marked for preloading. In which case we should just eager load them.
    # Note that this is a naive implementation because we could have strings and symbols which
    # represent the same association, but that aren't matched by this. Also, we could have
    # nested hashes which partially match, e.g. { :a => :b } & { :a => [:b, :c] }
    def joined_includes_values
      @includes_values & @joins_values
    end

    def ==(other)
      case other
      when Relation
        other.to_sql == to_sql
      when Array
        to_a == other
      end
    end

    def inspect
      to_a.inspect
    end

    def with_default_scope #:nodoc:
      if default_scoped? && default_scope = klass.send(:build_default_scope)
        default_scope = default_scope.merge(self)
        default_scope.default_scoped = false
        default_scope
      else
        self
      end
    end

    protected

    def method_missing(method, *args, &block)
      if Array.method_defined?(method)
        to_a.send(method, *args, &block)
      elsif @klass.respond_to?(method)
        scoping { @klass.send(method, *args, &block) }
      elsif arel.respond_to?(method)
        arel.send(method, *args, &block)
      else
        super
      end
    end

    private

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
      joined_tables = joined_tables.flatten.compact.map { |t| t.downcase }.uniq

      (tables_in_string(to_sql) - joined_tables).any?
    end

    def tables_in_string(string)
      return [] if string.blank?
      # always convert table names to downcase as in Oracle quoted table names are in uppercase
      # ignore raw_sql_ that is used by Oracle adapter as alias for limit/offset subqueries
      string.scan(/([a-zA-Z_][.\w]+).?\./).flatten.map{ |s| s.downcase }.uniq - ['raw_sql_']
    end

  end
end
