module ActiveRecord
  # = Active Record Persistence
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

      # Given an attributes hash, +instantiate+ returns a new instance of
      # the appropriate class. Accepts only keys as strings.
      #
      # For example, +Post.all+ may return Comments, Messages, and Emails
      # by storing the record's subclass in a +type+ attribute. By calling
      # +instantiate+ instead of +new+, finder methods ensure they get new
      # instances of the appropriate class for each record.
      #
      # See +ActiveRecord::Inheritance#discriminate_class_for_record+ to see
      # how this "single-table" inheritance mapping is implemented.
      def instantiate(attributes, column_types = {})
        klass = discriminate_class_for_record(attributes)
        attributes = klass.attributes_builder.build_from_database(attributes, column_types)
        klass.allocate.init_with('attributes' => attributes, 'new_record' => false)
      end

      private
        # Called by +instantiate+ to decide which class to use for a new
        # record instance.
        #
        # See +ActiveRecord::Inheritance#discriminate_class_for_record+ for
        # the single-table inheritance discriminator.
        def discriminate_class_for_record(record)
          self
        end
    end

    # Returns true if this object hasn't been saved yet -- that is, a record
    # for the object doesn't exist in the database yet; otherwise, returns false.
    def new_record?
      sync_with_transaction_state
      @new_record
    end

    # Returns true if this object has been destroyed, otherwise returns false.
    def destroyed?
      sync_with_transaction_state
      @destroyed
    end

    # Returns true if the record is persisted, i.e. it's not a new record and it was
    # not destroyed, otherwise returns false.
    def persisted?
      !(new_record? || destroyed?)
    end

    # Saves the model.
    #
    # If the model is new a record gets created in the database, otherwise
    # the existing record gets updated.
    #
    # By default, save always run validations. If any of them fail the action
    # is cancelled and +save+ returns +false+. However, if you supply
    # validate: false, validations are bypassed altogether. See
    # ActiveRecord::Validations for more information.
    #
    # There's a series of callbacks associated with +save+. If any of the
    # <tt>before_*</tt> callbacks return +false+ the action is cancelled and
    # +save+ returns +false+. See ActiveRecord::Callbacks for further
    # details.
    #
    # Attributes marked as readonly are silently ignored if the record is
    # being updated.
    def save(*)
      create_or_update
    rescue ActiveRecord::RecordInvalid
      false
    end

    # Saves the model.
    #
    # If the model is new a record gets created in the database, otherwise
    # the existing record gets updated.
    #
    # With <tt>save!</tt> validations always run. If any of them fail
    # ActiveRecord::RecordInvalid gets raised. See ActiveRecord::Validations
    # for more information.
    #
    # There's a series of callbacks associated with <tt>save!</tt>. If any of
    # the <tt>before_*</tt> callbacks return +false+ the action is cancelled
    # and <tt>save!</tt> raises ActiveRecord::RecordNotSaved. See
    # ActiveRecord::Callbacks for further details.
    #
    # Attributes marked as readonly are silently ignored if the record is
    # being updated.
    def save!(*)
      create_or_update || raise(RecordNotSaved.new(nil, self))
    end

    # Deletes the record in the database and freezes this instance to
    # reflect that no changes should be made (since they can't be
    # persisted). Returns the frozen instance.
    #
    # The row is simply removed with an SQL +DELETE+ statement on the
    # record's primary key, and no callbacks are executed.
    #
    # To enforce the object's +before_destroy+ and +after_destroy+
    # callbacks or any <tt>:dependent</tt> association
    # options, use <tt>#destroy</tt>.
    def delete
      self.class.delete(id) if persisted?
      @destroyed = true
      freeze
    end

    # Deletes the record in the database and freezes this instance to reflect
    # that no changes should be made (since they can't be persisted).
    #
    # There's a series of callbacks associated with <tt>destroy</tt>. If
    # the <tt>before_destroy</tt> callback return +false+ the action is cancelled
    # and <tt>destroy</tt> returns +false+. See
    # ActiveRecord::Callbacks for further details.
    def destroy
      raise ReadOnlyRecord, "#{self.class} is marked as readonly" if readonly?
      destroy_associations
      destroy_row if persisted?
      @destroyed = true
      freeze
    end

    # Deletes the record in the database and freezes this instance to reflect
    # that no changes should be made (since they can't be persisted).
    #
    # There's a series of callbacks associated with <tt>destroy!</tt>. If
    # the <tt>before_destroy</tt> callback return +false+ the action is cancelled
    # and <tt>destroy!</tt> raises ActiveRecord::RecordNotDestroyed. See
    # ActiveRecord::Callbacks for further details.
    def destroy!
      destroy || raise(ActiveRecord::RecordNotDestroyed, self)
    end

    # Returns an instance of the specified +klass+ with the attributes of the
    # current record. This is mostly useful in relation to single-table
    # inheritance structures where you want a subclass to appear as the
    # superclass. This can be used along with record identification in
    # Action Pack to allow, say, <tt>Client < Company</tt> to do something
    # like render <tt>partial: @client.becomes(Company)</tt> to render that
    # instance using the companies/company partial instead of clients/client.
    #
    # Note: The new instance will share a link to the same attributes as the original class.
    # So any change to the attributes in either instance will affect the other.
    def becomes(klass)
      became = klass.new
      became.instance_variable_set("@attributes", @attributes)
      changed_attributes = @changed_attributes if defined?(@changed_attributes)
      became.instance_variable_set("@changed_attributes", changed_attributes || {})
      became.instance_variable_set("@new_record", new_record?)
      became.instance_variable_set("@destroyed", destroyed?)
      became.instance_variable_set("@errors", errors)
      became
    end

    # Wrapper around +becomes+ that also changes the instance's sti column value.
    # This is especially useful if you want to persist the changed class in your
    # database.
    #
    # Note: The old instance's sti column value will be changed too, as both objects
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
    # * Callbacks are invoked.
    # * updated_at/updated_on column is updated if that column is available.
    # * Updates all the attributes that are dirty in this object.
    #
    # This method raises an +ActiveRecord::ActiveRecordError+  if the
    # attribute is marked as readonly.
    #
    # See also +update_column+.
    def update_attribute(name, value)
      name = name.to_s
      verify_readonly_attribute(name)
      send("#{name}=", value)
      save(validate: false)
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

    alias update_attributes update

    # Updates its receiver just like +update+ but calls <tt>save!</tt> instead
    # of +save+, so an exception is raised if the record is invalid.
    def update!(attributes)
      # The following transaction covers any possible database side-effects of the
      # attributes assignment. For example, setting the IDs of a child collection.
      with_transaction_returning_status do
        assign_attributes(attributes)
        save!
      end
    end

    alias update_attributes! update!

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
    # * Validations are skipped.
    # * Callbacks are skipped.
    # * +updated_at+/+updated_on+ are not updated.
    #
    # This method raises an +ActiveRecord::ActiveRecordError+ when called on new
    # objects, or when at least one of the attributes is marked as readonly.
    def update_columns(attributes)
      raise ActiveRecordError, "cannot update a new record" if new_record?
      raise ActiveRecordError, "cannot update a destroyed record" if destroyed?

      attributes.each_key do |key|
        verify_readonly_attribute(key.to_s)
      end

      updated_count = self.class.unscoped.where(self.class.primary_key => id).update_all(attributes)

      attributes.each do |k, v|
        raw_write_attribute(k, v)
      end

      updated_count == 1
    end

    # Initializes +attribute+ to zero if +nil+ and adds the value passed as +by+ (default is 1).
    # The increment is performed directly on the underlying attribute, no setter is invoked.
    # Only makes sense for number-based attributes. Returns +self+.
    def increment(attribute, by = 1)
      self[attribute] ||= 0
      self[attribute] += by
      self
    end

    # Wrapper around +increment+ that saves the record. This method differs from
    # its non-bang version in that it passes through the attribute setter.
    # Saving is not subjected to validation checks. Returns +true+ if the
    # record could be saved.
    def increment!(attribute, by = 1)
      increment(attribute, by).update_attribute(attribute, self[attribute])
    end

    # Initializes +attribute+ to zero if +nil+ and subtracts the value passed as +by+ (default is 1).
    # The decrement is performed directly on the underlying attribute, no setter is invoked.
    # Only makes sense for number-based attributes. Returns +self+.
    def decrement(attribute, by = 1)
      self[attribute] ||= 0
      self[attribute] -= by
      self
    end

    # Wrapper around +decrement+ that saves the record. This method differs from
    # its non-bang version in that it passes through the attribute setter.
    # Saving is not subjected to validation checks. Returns +true+ if the
    # record could be saved.
    def decrement!(attribute, by = 1)
      decrement(attribute, by).update_attribute(attribute, self[attribute])
    end

    # Assigns to +attribute+ the boolean opposite of <tt>attribute?</tt>. So
    # if the predicate returns +true+ the attribute will become +false+. This
    # method toggles directly the underlying value without calling any setter.
    # Returns +self+.
    def toggle(attribute)
      self[attribute] = !send("#{attribute}?")
      self
    end

    # Wrapper around +toggle+ that saves the record. This method differs from
    # its non-bang version in that it passes through the attribute setter.
    # Saving is not subjected to validation checks. Returns +true+ if the
    # record could be saved.
    def toggle!(attribute)
      toggle(attribute).update_attribute(attribute, self[attribute])
    end

    # Reloads the record from the database.
    #
    # This method finds record by its primary key (which could be assigned manually) and
    # modifies the receiver in-place:
    #
    #   account = Account.new
    #   # => #<Account id: nil, email: nil>
    #   account.id = 1
    #   account.reload
    #   # Account Load (1.2ms)  SELECT "accounts".* FROM "accounts" WHERE "accounts"."id" = $1 LIMIT 1  [["id", 1]]
    #   # => #<Account id: 1, email: 'account@example.com'>
    #
    # Attributes are reloaded from the database, and caches busted, in
    # particular the associations cache.
    #
    # If the record no longer exists in the database <tt>ActiveRecord::RecordNotFound</tt>
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
      clear_aggregation_cache
      clear_association_cache

      fresh_object =
        if options && options[:lock]
          self.class.unscoped { self.class.lock(options[:lock]).find(id) }
        else
          self.class.unscoped { self.class.find(id) }
        end

      @attributes = fresh_object.instance_variable_get('@attributes')
      @new_record = false
      self
    end

    # Saves the record with the updated_at/on attributes set to the current time.
    # Please note that no validation is performed and only the +after_touch+,
    # +after_commit+ and +after_rollback+ callbacks are executed.
    #
    # If attribute names are passed, they are updated along with updated_at/on
    # attributes.
    #
    #   product.touch                         # updates updated_at/on
    #   product.touch(:designed_at)           # updates the designed_at attribute and updated_at/on
    #   product.touch(:started_at, :ended_at) # updates started_at, ended_at and updated_at/on attributes
    #
    # If used along with +belongs_to+ then +touch+ will invoke +touch+ method on
    # associated object.
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
    def touch(*names)
      raise ActiveRecordError, "cannot touch on a new record object" unless persisted?

      attributes = timestamp_attributes_for_update_in_model
      attributes.concat(names)

      unless attributes.empty?
        current_time = current_time_from_proper_timezone
        changes = {}

        attributes.each do |column|
          column = column.to_s
          changes[column] = write_attribute(column, current_time)
        end

        changes[self.class.locking_column] = increment_lock if locking_enabled?

        clear_attribute_changes(changes.keys)
        primary_key = self.class.primary_key
        self.class.unscoped.where(primary_key => self[primary_key]).update_all(changes) == 1
      else
        true
      end
    end

  private

    # A hook to be overridden by association modules.
    def destroy_associations
    end

    def destroy_row
      relation_for_destroy.delete_all
    end

    def relation_for_destroy
      pk         = self.class.primary_key
      column     = self.class.columns_hash[pk]
      substitute = self.class.connection.substitute_at(column)

      relation = self.class.unscoped.where(
        self.class.arel_table[pk].eq(substitute))

      relation.bind_values = [[column, id]]
      relation
    end

    def create_or_update
      raise ReadOnlyRecord, "#{self.class} is marked as readonly" if readonly?
      result = new_record? ? _create_record : _update_record
      result != false
    end

    # Updates the associated record with values matching those of the instance attributes.
    # Returns the number of affected rows.
    def _update_record(attribute_names = self.attribute_names)
      attributes_values = arel_attributes_with_values_for_update(attribute_names)
      if attributes_values.empty?
        0
      else
        self.class.unscoped._update_record attributes_values, id, id_was
      end
    end

    # Creates a record with values matching those of the instance attributes
    # and returns its id.
    def _create_record(attribute_names = self.attribute_names)
      attributes_values = arel_attributes_with_values_for_create(attribute_names)

      new_id = self.class.unscoped.insert attributes_values
      self.id ||= new_id if self.class.primary_key

      @new_record = false
      id
    end

    def verify_readonly_attribute(name)
      raise ActiveRecordError, "#{name} is marked as readonly" if self.class.readonly_attributes.include?(name)
    end
  end
end
