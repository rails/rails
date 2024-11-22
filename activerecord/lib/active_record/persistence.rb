# frozen_string_literal: true

require "active_record/insert_all"

module ActiveRecord
  # = Active Record \Persistence
  module Persistence
    extend ActiveSupport::Concern

    module ClassMethods
      # Creates an object (or multiple objects) and saves it to the database, if validations pass.
      # The resulting object is returned whether the object was saved successfully to the database or not.
      #
      # The +attributes+ parameter can be either a Hash or an Array of Hashes. These Hashes describe the
      # attributes on the objects that are to be created.
      #
      # ==== Examples
      #   # Create a single new object
      #   User.create(first_name: 'Jamie')
      #
      #   # Create an Array of new objects
      #   User.create([{ first_name: 'Jamie' }, { first_name: 'Jeremy' }])
      #
      #   # Create a single object and pass it into a block to set other attributes.
      #   User.create(first_name: 'Jamie') do |u|
      #     u.is_admin = false
      #   end
      #
      #   # Creating an Array of new objects using a block, where the block is executed for each object:
      #   User.create([{ first_name: 'Jamie' }, { first_name: 'Jeremy' }]) do |u|
      #     u.is_admin = false
      #   end
      def create(attributes = nil, &block)
        if attributes.is_a?(Array)
          attributes.collect { |attr| create(attr, &block) }
        else
          object = new(attributes, &block)
          object.save
          object
        end
      end

      # Creates an object (or multiple objects) and saves it to the database,
      # if validations pass. Raises a RecordInvalid error if validations fail,
      # unlike Base#create.
      #
      # The +attributes+ parameter can be either a Hash or an Array of Hashes.
      # These describe which attributes to be created on the object, or
      # multiple objects when given an Array of Hashes.
      def create!(attributes = nil, &block)
        if attributes.is_a?(Array)
          attributes.collect { |attr| create!(attr, &block) }
        else
          object = new(attributes, &block)
          object.save!
          object
        end
      end

      # Builds an object (or multiple objects) and returns either the built object or a list of built
      # objects.
      #
      # The +attributes+ parameter can be either a Hash or an Array of Hashes. These Hashes describe the
      # attributes on the objects that are to be built.
      #
      # ==== Examples
      #   # Build a single new object
      #   User.build(first_name: 'Jamie')
      #
      #   # Build an Array of new objects
      #   User.build([{ first_name: 'Jamie' }, { first_name: 'Jeremy' }])
      #
      #   # Build a single object and pass it into a block to set other attributes.
      #   User.build(first_name: 'Jamie') do |u|
      #     u.is_admin = false
      #   end
      #
      #   # Building an Array of new objects using a block, where the block is executed for each object:
      #   User.build([{ first_name: 'Jamie' }, { first_name: 'Jeremy' }]) do |u|
      #     u.is_admin = false
      #   end
      def build(attributes = nil, &block)
        if attributes.is_a?(Array)
          attributes.collect { |attr| build(attr, &block) }
        else
          new(attributes, &block)
        end
      end

      # Given an attributes hash, +instantiate+ returns a new instance of
      # the appropriate class. Accepts only keys as strings.
      #
      # For example, +Post.all+ may return Comments, Messages, and Emails
      # by storing the record's subclass in a +type+ attribute. By calling
      # +instantiate+ instead of +new+, finder methods ensure they get new
      # instances of the appropriate class for each record.
      #
      # See <tt>ActiveRecord::Inheritance#discriminate_class_for_record</tt> to see
      # how this "single-table" inheritance mapping is implemented.
      def instantiate(attributes, column_types = {}, &block)
        klass = discriminate_class_for_record(attributes)
        instantiate_instance_of(klass, attributes, column_types, &block)
      end

      # Updates an object (or multiple objects) and saves it to the database, if validations pass.
      # The resulting object is returned whether the object was saved successfully to the database or not.
      #
      # ==== Parameters
      #
      # * +id+ - This should be the id or an array of ids to be updated.
      #   Optional argument, defaults to all records in the relation.
      # * +attributes+ - This should be a hash of attributes or an array of hashes.
      #
      # ==== Examples
      #
      #   # Updates one record
      #   Person.update(15, user_name: "Samuel", group: "expert")
      #
      #   # Updates multiple records
      #   people = { 1 => { "first_name" => "David" }, 2 => { "first_name" => "Jeremy" } }
      #   Person.update(people.keys, people.values)
      #
      #   # Updates multiple records from the result of a relation
      #   people = Person.where(group: "expert")
      #   people.update(group: "masters")
      #
      # Note: Updating a large number of records will run an UPDATE
      # query for each record, which may cause a performance issue.
      # When running callbacks is not needed for each record update,
      # it is preferred to use {update_all}[rdoc-ref:Relation#update_all]
      # for updating all records in a single query.
      def update(id = :all, attributes)
        if id.is_a?(Array)
          if id.any?(ActiveRecord::Base)
            raise ArgumentError,
              "You are passing an array of ActiveRecord::Base instances to `update`. " \
              "Please pass the ids of the objects by calling `pluck(:id)` or `map(&:id)`."
          end
          id.map { |one_id| find(one_id) }.each_with_index { |object, idx|
            object.update(attributes[idx])
          }
        elsif id == :all
          all.each { |record| record.update(attributes) }
        else
          if ActiveRecord::Base === id
            raise ArgumentError,
              "You are passing an instance of ActiveRecord::Base to `update`. " \
              "Please pass the id of the object by calling `.id`."
          end
          object = find(id)
          object.update(attributes)
          object
        end
      end

      # Updates the object (or multiple objects) just like #update but calls #update! instead
      # of +update+, so an exception is raised if the record is invalid and saving will fail.
      def update!(id = :all, attributes)
        if id.is_a?(Array)
          if id.any?(ActiveRecord::Base)
            raise ArgumentError,
              "You are passing an array of ActiveRecord::Base instances to `update!`. " \
              "Please pass the ids of the objects by calling `pluck(:id)` or `map(&:id)`."
          end
          id.map { |one_id| find(one_id) }.each_with_index { |object, idx|
            object.update!(attributes[idx])
          }
        elsif id == :all
          all.each { |record| record.update!(attributes) }
        else
          if ActiveRecord::Base === id
            raise ArgumentError,
              "You are passing an instance of ActiveRecord::Base to `update!`. " \
              "Please pass the id of the object by calling `.id`."
          end
          object = find(id)
          object.update!(attributes)
          object
        end
      end

      # Accepts a list of attribute names to be used in the WHERE clause
      # of SELECT / UPDATE / DELETE queries and in the ORDER BY clause for +#first+ and +#last+ finder methods.
      #
      #   class Developer < ActiveRecord::Base
      #     query_constraints :company_id, :id
      #   end
      #
      #   developer = Developer.first
      #   # SELECT "developers".* FROM "developers" ORDER BY "developers"."company_id" ASC, "developers"."id" ASC LIMIT 1
      #   developer.inspect # => #<Developer id: 1, company_id: 1, ...>
      #
      #   developer.update!(name: "Nikita")
      #   # UPDATE "developers" SET "name" = 'Nikita' WHERE "developers"."company_id" = 1 AND "developers"."id" = 1
      #
      #   # It is possible to update an attribute used in the query_constraints clause:
      #   developer.update!(company_id: 2)
      #   # UPDATE "developers" SET "company_id" = 2 WHERE "developers"."company_id" = 1 AND "developers"."id" = 1
      #
      #   developer.name = "Bob"
      #   developer.save!
      #   # UPDATE "developers" SET "name" = 'Bob' WHERE "developers"."company_id" = 1 AND "developers"."id" = 1
      #
      #   developer.destroy!
      #   # DELETE FROM "developers" WHERE "developers"."company_id" = 1 AND "developers"."id" = 1
      #
      #   developer.delete
      #   # DELETE FROM "developers" WHERE "developers"."company_id" = 1 AND "developers"."id" = 1
      #
      #   developer.reload
      #   # SELECT "developers".* FROM "developers" WHERE "developers"."company_id" = 1 AND "developers"."id" = 1 LIMIT 1
      def query_constraints(*columns_list)
        raise ArgumentError, "You must specify at least one column to be used in querying" if columns_list.empty?

        @query_constraints_list = columns_list.map(&:to_s)
        @has_query_constraints = @query_constraints_list
      end

      def has_query_constraints? # :nodoc:
        @has_query_constraints
      end

      def query_constraints_list # :nodoc:
        @query_constraints_list ||= if base_class? || primary_key != base_class.primary_key
          primary_key if primary_key.is_a?(Array)
        else
          base_class.query_constraints_list
        end
      end

      # Returns an array of column names to be used in queries. The source of column
      # names is derived from +query_constraints_list+ or +primary_key+. This method
      # is for internal use when the primary key is to be treated as an array.
      def composite_query_constraints_list # :nodoc:
        @composite_query_constraints_list ||= query_constraints_list || Array(primary_key)
      end

      def _insert_record(connection, values, returning) # :nodoc:
        primary_key = self.primary_key
        primary_key_value = nil

        if prefetch_primary_key? && primary_key
          values[primary_key] ||= begin
            primary_key_value = next_sequence_value
            _default_attributes[primary_key].with_cast_value(primary_key_value)
          end
        end

        im = Arel::InsertManager.new(arel_table)

        if values.empty?
          im.insert(connection.empty_insert_statement_value(primary_key))
        else
          im.insert(values.transform_keys { |name| arel_table[name] })
        end

        connection.insert(
          im, "#{self} Create", primary_key || false, primary_key_value,
          returning: returning
        )
      end

      def _update_record(values, constraints) # :nodoc:
        constraints = constraints.map { |name, value| predicate_builder[name, value] }

        default_constraint = build_default_constraint
        constraints << default_constraint if default_constraint

        if current_scope = self.global_current_scope
          constraints << current_scope.where_clause.ast
        end

        um = Arel::UpdateManager.new(arel_table)
        um.set(values.transform_keys { |name| arel_table[name] })
        um.wheres = constraints

        with_connection do |c|
          c.update(um, "#{self} Update")
        end
      end

      def _delete_record(constraints) # :nodoc:
        constraints = constraints.map { |name, value| predicate_builder[name, value] }

        default_constraint = build_default_constraint
        constraints << default_constraint if default_constraint

        if current_scope = self.global_current_scope
          constraints << current_scope.where_clause.ast
        end

        dm = Arel::DeleteManager.new(arel_table)
        dm.wheres = constraints

        with_connection do |c|
          c.delete(dm, "#{self} Destroy")
        end
      end

      private
        def inherited(subclass)
          super
          subclass.class_eval do
            @_query_constraints_list = nil
            @has_query_constraints = false
          end
        end

        # Given a class, an attributes hash, +instantiate_instance_of+ returns a
        # new instance of the class. Accepts only keys as strings.
        def instantiate_instance_of(klass, attributes, column_types = {}, &block)
          attributes = klass.attributes_builder.build_from_database(attributes, column_types)
          klass.allocate.init_with_attributes(attributes, &block)
        end

        # Called by +instantiate+ to decide which class to use for a new
        # record instance.
        #
        # See +ActiveRecord::Inheritance#discriminate_class_for_record+ for
        # the single-table inheritance discriminator.
        def discriminate_class_for_record(record)
          self
        end

        # Called by +_update_record+ and +_delete_record+
        # to build `where` clause from default scopes.
        # Skips empty scopes.
        def build_default_constraint
          return unless default_scopes?(all_queries: true)

          default_where_clause = default_scoped(all_queries: true).where_clause
          default_where_clause.ast unless default_where_clause.empty?
        end
    end

    # Returns true if this object hasn't been saved yet -- that is, a record
    # for the object doesn't exist in the database yet; otherwise, returns false.
    def new_record?
      @new_record
    end

    # Returns true if this object was just created -- that is, prior to the last
    # update or delete, the object didn't exist in the database and new_record? would have
    # returned true.
    def previously_new_record?
      @previously_new_record
    end

    # Returns true if this object was previously persisted but now it has been deleted.
    def previously_persisted?
      !new_record? && destroyed?
    end

    # Returns true if this object has been destroyed, otherwise returns false.
    def destroyed?
      @destroyed
    end

    # Returns true if the record is persisted, i.e. it's not a new record and it was
    # not destroyed, otherwise returns false.
    def persisted?
      !(@new_record || @destroyed)
    end

    ##
    # :call-seq:
    #   save(**options)
    #
    # Saves the model.
    #
    # If the model is new, a record gets created in the database, otherwise
    # the existing record gets updated.
    #
    # By default, save always runs validations. If any of them fail the action
    # is cancelled and #save returns +false+, and the record won't be saved. However, if you supply
    # <tt>validate: false</tt>, validations are bypassed altogether. See
    # ActiveRecord::Validations for more information.
    #
    # By default, #save also sets the +updated_at+/+updated_on+ attributes to
    # the current time. However, if you supply <tt>touch: false</tt>, these
    # timestamps will not be updated.
    #
    # There's a series of callbacks associated with #save. If any of the
    # <tt>before_*</tt> callbacks throws +:abort+ the action is cancelled and
    # #save returns +false+. See ActiveRecord::Callbacks for further
    # details.
    #
    # Attributes marked as readonly are silently ignored if the record is
    # being updated.
    def save(**options, &block)
      create_or_update(**options, &block)
    rescue ActiveRecord::RecordInvalid
      false
    end

    ##
    # :call-seq:
    #   save!(**options)
    #
    # Saves the model.
    #
    # If the model is new, a record gets created in the database, otherwise
    # the existing record gets updated.
    #
    # By default, #save! always runs validations. If any of them fail
    # ActiveRecord::RecordInvalid gets raised, and the record won't be saved. However, if you supply
    # <tt>validate: false</tt>, validations are bypassed altogether. See
    # ActiveRecord::Validations for more information.
    #
    # By default, #save! also sets the +updated_at+/+updated_on+ attributes to
    # the current time. However, if you supply <tt>touch: false</tt>, these
    # timestamps will not be updated.
    #
    # There's a series of callbacks associated with #save!. If any of
    # the <tt>before_*</tt> callbacks throws +:abort+ the action is cancelled
    # and #save! raises ActiveRecord::RecordNotSaved. See
    # ActiveRecord::Callbacks for further details.
    #
    # Attributes marked as readonly are silently ignored if the record is
    # being updated.
    #
    # Unless an error is raised, returns true.
    def save!(**options, &block)
      create_or_update(**options, &block) || raise(RecordNotSaved.new("Failed to save the record", self))
    end

    # Deletes the record in the database and freezes this instance to
    # reflect that no changes should be made (since they can't be
    # persisted). Returns the frozen instance.
    #
    # The row is simply removed with an SQL +DELETE+ statement on the
    # record's primary key, and no callbacks are executed.
    #
    # Note that this will also delete records marked as {#readonly?}[rdoc-ref:Core#readonly?].
    #
    # To enforce the object's +before_destroy+ and +after_destroy+
    # callbacks or any <tt>:dependent</tt> association
    # options, use #destroy.
    def delete
      _delete_row if persisted?
      @destroyed = true
      @previously_new_record = false
      freeze
    end

    # Deletes the record in the database and freezes this instance to reflect
    # that no changes should be made (since they can't be persisted).
    #
    # There's a series of callbacks associated with #destroy. If the
    # <tt>before_destroy</tt> callback throws +:abort+ the action is cancelled
    # and #destroy returns +false+.
    # See ActiveRecord::Callbacks for further details.
    def destroy
      _raise_readonly_record_error if readonly?
      destroy_associations
      @_trigger_destroy_callback ||= persisted? && destroy_row > 0
      @destroyed = true
      @previously_new_record = false
      freeze
    end

    # Deletes the record in the database and freezes this instance to reflect
    # that no changes should be made (since they can't be persisted).
    #
    # There's a series of callbacks associated with #destroy!. If the
    # <tt>before_destroy</tt> callback throws +:abort+ the action is cancelled
    # and #destroy! raises ActiveRecord::RecordNotDestroyed.
    # See ActiveRecord::Callbacks for further details.
    def destroy!
      destroy || _raise_record_not_destroyed
    end

    # Returns an instance of the specified +klass+ with the attributes of the
    # current record. This is mostly useful in relation to single table
    # inheritance (STI) structures where you want a subclass to appear as the
    # superclass. This can be used along with record identification in
    # Action Pack to allow, say, <tt>Client < Company</tt> to do something
    # like render <tt>partial: @client.becomes(Company)</tt> to render that
    # instance using the companies/company partial instead of clients/client.
    #
    # Note: The new instance will share a link to the same attributes as the original class.
    # Therefore the STI column value will still be the same.
    # Any change to the attributes on either instance will affect both instances.
    # This includes any attribute initialization done by the new instance.
    #
    # If you want to change the STI column as well, use #becomes! instead.
    def becomes(klass)
      became = klass.allocate

      became.send(:initialize) do |becoming|
        @attributes.reverse_merge!(becoming.instance_variable_get(:@attributes))
        becoming.instance_variable_set(:@attributes, @attributes)
        becoming.instance_variable_set(:@mutations_from_database, @mutations_from_database ||= nil)
        becoming.instance_variable_set(:@new_record, new_record?)
        becoming.instance_variable_set(:@previously_new_record, previously_new_record?)
        becoming.instance_variable_set(:@destroyed, destroyed?)
        becoming.errors.copy!(errors)
      end

      became
    end

    # Wrapper around #becomes that also changes the instance's STI column value.
    # This is especially useful if you want to persist the changed class in your
    # database.
    #
    # Note: The old instance's STI column value will be changed too, as both objects
    # share the same set of attributes.
    def becomes!(klass)
      became = becomes(klass)
      sti_type = nil
      if !klass.descends_from_active_record?
        sti_type = klass.sti_name
      end
      became.public_send("#{klass.inheritance_column}=", sti_type)
      became
    end

    # Updates a single attribute and saves the record.
    # This is especially useful for boolean flags on existing records. Also note that
    #
    # * Validation is skipped.
    # * \Callbacks are invoked.
    # * updated_at/updated_on column is updated if that column is available.
    # * Updates all the attributes that are dirty in this object.
    #
    # This method raises an ActiveRecord::ActiveRecordError if the
    # attribute is marked as readonly.
    #
    # Also see #update_column.
    def update_attribute(name, value)
      name = name.to_s
      verify_readonly_attribute(name)
      public_send("#{name}=", value)

      save(validate: false)
    end

    # Updates a single attribute and saves the record.
    # This is especially useful for boolean flags on existing records. Also note that
    #
    # * Validation is skipped.
    # * \Callbacks are invoked.
    # * updated_at/updated_on column is updated if that column is available.
    # * Updates all the attributes that are dirty in this object.
    #
    # This method raises an ActiveRecord::ActiveRecordError if the
    # attribute is marked as readonly.
    #
    # If any of the <tt>before_*</tt> callbacks throws +:abort+ the action is cancelled
    # and #update_attribute! raises ActiveRecord::RecordNotSaved. See
    # ActiveRecord::Callbacks for further details.
    def update_attribute!(name, value)
      name = name.to_s
      verify_readonly_attribute(name)
      public_send("#{name}=", value)

      save!(validate: false)
    end

    # Updates the attributes of the model from the passed-in hash and saves the
    # record, all wrapped in a transaction. If the object is invalid, the saving
    # will fail and false will be returned.
    def update(attributes)
      # The following transaction covers any possible database side-effects of the
      # attributes assignment. For example, setting the IDs of a child collection.
      with_transaction_returning_status do
        assign_attributes(attributes)
        save
      end
    end

    # Updates its receiver just like #update but calls #save! instead
    # of +save+, so an exception is raised if the record is invalid and saving will fail.
    def update!(attributes)
      # The following transaction covers any possible database side-effects of the
      # attributes assignment. For example, setting the IDs of a child collection.
      with_transaction_returning_status do
        assign_attributes(attributes)
        save!
      end
    end

    # Equivalent to <code>update_columns(name => value)</code>.
    def update_column(name, value)
      update_columns(name => value)
    end

    # Updates the attributes directly in the database issuing an UPDATE SQL
    # statement and sets them in the receiver:
    #
    #   user.update_columns(last_request_at: Time.current)
    #
    # This is the fastest way to update attributes because it goes straight to
    # the database, but take into account that in consequence the regular update
    # procedures are totally bypassed. In particular:
    #
    # * \Validations are skipped.
    # * \Callbacks are skipped.
    # * +updated_at+/+updated_on+ are not updated.
    # * However, attributes are serialized with the same rules as ActiveRecord::Relation#update_all
    #
    # This method raises an ActiveRecord::ActiveRecordError when called on new
    # objects, or when at least one of the attributes is marked as readonly.
    def update_columns(attributes)
      raise ActiveRecordError, "cannot update a new record" if new_record?
      raise ActiveRecordError, "cannot update a destroyed record" if destroyed?
      _raise_readonly_record_error if readonly?

      attributes = attributes.transform_keys do |key|
        name = key.to_s
        name = self.class.attribute_aliases[name] || name
        verify_readonly_attribute(name) || name
      end

      update_constraints = _query_constraints_hash
      attributes = attributes.each_with_object({}) do |(k, v), h|
        h[k] = @attributes.write_cast_value(k, v)
        clear_attribute_change(k)
      end

      affected_rows = self.class._update_record(
        attributes,
        update_constraints
      )

      affected_rows == 1
    end

    # Initializes +attribute+ to zero if +nil+ and adds the value passed as +by+ (default is 1).
    # The increment is performed directly on the underlying attribute, no setter is invoked.
    # Only makes sense for number-based attributes. Returns +self+.
    def increment(attribute, by = 1)
      self[attribute] ||= 0
      self[attribute] += by
      self
    end

    # Wrapper around #increment that writes the update to the database.
    # Only +attribute+ is updated; the record itself is not saved.
    # This means that any other modified attributes will still be dirty.
    # Validations and callbacks are skipped. Supports the +touch+ option from
    # +update_counters+, see that for more.
    # Returns +self+.
    def increment!(attribute, by = 1, touch: nil)
      increment(attribute, by)
      change = public_send(attribute) - (public_send(:"#{attribute}_in_database") || 0)
      self.class.update_counters(id, attribute => change, touch: touch)
      public_send(:"clear_#{attribute}_change")
      self
    end

    # Initializes +attribute+ to zero if +nil+ and subtracts the value passed as +by+ (default is 1).
    # The decrement is performed directly on the underlying attribute, no setter is invoked.
    # Only makes sense for number-based attributes. Returns +self+.
    def decrement(attribute, by = 1)
      increment(attribute, -by)
    end

    # Wrapper around #decrement that writes the update to the database.
    # Only +attribute+ is updated; the record itself is not saved.
    # This means that any other modified attributes will still be dirty.
    # Validations and callbacks are skipped. Supports the +touch+ option from
    # +update_counters+, see that for more.
    # Returns +self+.
    def decrement!(attribute, by = 1, touch: nil)
      increment!(attribute, -by, touch: touch)
    end

    # Assigns to +attribute+ the boolean opposite of <tt>attribute?</tt>. So
    # if the predicate returns +true+ the attribute will become +false+. This
    # method toggles directly the underlying value without calling any setter.
    # Returns +self+.
    #
    # Example:
    #
    #   user = User.first
    #   user.banned? # => false
    #   user.toggle(:banned)
    #   user.banned? # => true
    #
    def toggle(attribute)
      self[attribute] = !public_send("#{attribute}?")
      self
    end

    # Wrapper around #toggle that saves the record. This method differs from
    # its non-bang version in the sense that it passes through the attribute setter.
    # Saving is not subjected to validation checks. Returns +true+ if the
    # record could be saved.
    def toggle!(attribute)
      toggle(attribute).update_attribute(attribute, self[attribute])
    end

    # Reloads the record from the database.
    #
    # This method finds the record by its primary key (which could be assigned
    # manually) and modifies the receiver in-place:
    #
    #   account = Account.new
    #   # => #<Account id: nil, email: nil>
    #   account.id = 1
    #   account.reload
    #   # Account Load (1.2ms)  SELECT "accounts".* FROM "accounts" WHERE "accounts"."id" = $1 LIMIT 1  [["id", 1]]
    #   # => #<Account id: 1, email: 'account@example.com'>
    #
    # Attributes are reloaded from the database, and caches busted, in
    # particular the associations cache and the QueryCache.
    #
    # If the record no longer exists in the database ActiveRecord::RecordNotFound
    # is raised. Otherwise, in addition to the in-place modification the method
    # returns +self+ for convenience.
    #
    # The optional <tt>:lock</tt> flag option allows you to lock the reloaded record:
    #
    #   reload(lock: true) # reload with pessimistic locking
    #
    # Reloading is commonly used in test suites to test something is actually
    # written to the database, or when some action modifies the corresponding
    # row in the database but not the object in memory:
    #
    #   assert account.deposit!(25)
    #   assert_equal 25, account.credit        # check it is updated in memory
    #   assert_equal 25, account.reload.credit # check it is also persisted
    #
    # Another common use case is optimistic locking handling:
    #
    #   def with_optimistic_retry
    #     begin
    #       yield
    #     rescue ActiveRecord::StaleObjectError
    #       begin
    #         # Reload lock_version in particular.
    #         reload
    #       rescue ActiveRecord::RecordNotFound
    #         # If the record is gone there is nothing to do.
    #       else
    #         retry
    #       end
    #     end
    #   end
    #
    def reload(options = nil)
      self.class.connection_pool.clear_query_cache

      fresh_object = if apply_scoping?(options)
        _find_record((options || {}).merge(all_queries: true))
      else
        self.class.unscoped { _find_record(options) }
      end

      @association_cache = fresh_object.instance_variable_get(:@association_cache)
      @association_cache.each_value { |association| association.owner = self }
      @attributes = fresh_object.instance_variable_get(:@attributes)
      @new_record = false
      @previously_new_record = false
      self
    end

    # Saves the record with the updated_at/on attributes set to the current time
    # or the time specified.
    # Please note that no validation is performed and only the +after_touch+,
    # +after_commit+ and +after_rollback+ callbacks are executed.
    #
    # This method can be passed attribute names and an optional time argument.
    # If attribute names are passed, they are updated along with updated_at/on
    # attributes. If no time argument is passed, the current time is used as default.
    #
    #   product.touch                         # updates updated_at/on with current time
    #   product.touch(time: Time.new(2015, 2, 16, 0, 0, 0)) # updates updated_at/on with specified time
    #   product.touch(:designed_at)           # updates the designed_at attribute and updated_at/on
    #   product.touch(:started_at, :ended_at) # updates started_at, ended_at and updated_at/on attributes
    #
    # If used along with {belongs_to}[rdoc-ref:Associations::ClassMethods#belongs_to]
    # then +touch+ will invoke +touch+ method on associated object.
    #
    #   class Brake < ActiveRecord::Base
    #     belongs_to :car, touch: true
    #   end
    #
    #   class Car < ActiveRecord::Base
    #     belongs_to :corporation, touch: true
    #   end
    #
    #   # triggers @brake.car.touch and @brake.car.corporation.touch
    #   @brake.touch
    #
    # Note that +touch+ must be used on a persisted object, or else an
    # ActiveRecordError will be thrown. For example:
    #
    #   ball = Ball.new
    #   ball.touch(:updated_at)   # => raises ActiveRecordError
    #
    def touch(*names, time: nil)
      _raise_record_not_touched_error unless persisted?
      _raise_readonly_record_error if readonly?

      attribute_names = timestamp_attributes_for_update_in_model
      attribute_names = (attribute_names | names).map! do |name|
        name = name.to_s
        name = self.class.attribute_aliases[name] || name
        verify_readonly_attribute(name)
        name
      end

      unless attribute_names.empty?
        affected_rows = _touch_row(attribute_names, time)
        @_trigger_update_callback = affected_rows == 1
      else
        true
      end
    end

    private
      def init_internals
        super
        @_trigger_destroy_callback = @_trigger_update_callback = nil
        @previously_new_record = false
      end

      def strict_loaded_associations
        @association_cache.find_all do |_, assoc|
          assoc.owner.strict_loading? && !assoc.owner.strict_loading_n_plus_one_only?
        end.map(&:first)
      end

      def _find_record(options)
        all_queries = options ? options[:all_queries] : nil
        base = self.class.all(all_queries: all_queries).preload(strict_loaded_associations)

        if options && options[:lock]
          base.lock(options[:lock]).find_by!(_in_memory_query_constraints_hash)
        else
          base.find_by!(_in_memory_query_constraints_hash)
        end
      end

      def _in_memory_query_constraints_hash
        if self.class.query_constraints_list.nil?
          { @primary_key => id }
        else
          self.class.query_constraints_list.index_with do |column_name|
            attribute(column_name)
          end
        end
      end

      def apply_scoping?(options)
        !(options && options[:unscoped]) &&
          (self.class.default_scopes?(all_queries: true) || self.class.global_current_scope)
      end

      def _query_constraints_hash
        if self.class.query_constraints_list.nil?
          { @primary_key => id_in_database }
        else
          self.class.query_constraints_list.index_with do |column_name|
            attribute_in_database(column_name)
          end
        end
      end

      # A hook to be overridden by association modules.
      def destroy_associations
      end

      def destroy_row
        _delete_row
      end

      def _delete_row
        self.class._delete_record(_query_constraints_hash)
      end

      def _touch_row(attribute_names, time)
        time ||= current_time_from_proper_timezone

        attribute_names.each do |attr_name|
          _write_attribute(attr_name, time)
        end

        _update_row(attribute_names, "touch")
      end

      def _update_row(attribute_names, attempted_action = "update")
        self.class._update_record(
          attributes_with_values(attribute_names),
          _query_constraints_hash
        )
      end

      def create_or_update(**, &block)
        _raise_readonly_record_error if readonly?
        return false if destroyed?
        result = new_record? ? _create_record(&block) : _update_record(&block)
        result != false
      end

      # Updates the associated record with values matching those of the instance attributes.
      # Returns the number of affected rows.
      def _update_record(attribute_names = self.attribute_names)
        attribute_names = attributes_for_update(attribute_names)

        if attribute_names.empty?
          affected_rows = 0
          @_trigger_update_callback = true
        else
          affected_rows = _update_row(attribute_names)
          @_trigger_update_callback = affected_rows == 1
        end

        @previously_new_record = false

        yield(self) if block_given?

        affected_rows
      end

      # Creates a record with values matching those of the instance attributes
      # and returns its id.
      def _create_record(attribute_names = self.attribute_names)
        attribute_names = attributes_for_create(attribute_names)

        self.class.with_connection do |connection|
          returning_columns = self.class._returning_columns_for_insert(connection)

          returning_values = self.class._insert_record(
            connection,
            attributes_with_values(attribute_names),
            returning_columns
          )

          returning_columns.zip(returning_values).each do |column, value|
            _write_attribute(column, type_for_attribute(column).deserialize(value)) if !_read_attribute(column)
          end if returning_values
        end

        @new_record = false
        @previously_new_record = true

        yield(self) if block_given?

        id
      end

      def verify_readonly_attribute(name)
        raise ActiveRecordError, "#{name} is marked as readonly" if self.class.readonly_attribute?(name)
      end

      def _raise_record_not_destroyed
        @_association_destroy_exception ||= nil
        key = self.class.primary_key
        raise @_association_destroy_exception || RecordNotDestroyed.new("Failed to destroy #{self.class} with #{key}=#{id}", self)
      ensure
        @_association_destroy_exception = nil
      end

      def _raise_readonly_record_error
        raise ReadOnlyRecord, "#{self.class} is marked as readonly"
      end

      def _raise_record_not_touched_error
        raise ActiveRecordError, <<~MSG.squish
          Cannot touch on a new or destroyed record object. Consider using
          persisted?, new_record?, or destroyed? before touching.
        MSG
      end
  end
end
