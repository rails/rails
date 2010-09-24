module ActiveRecord
  # = Active Record Persistence
  module Persistence
    # Returns true if this object hasn't been saved yet -- that is, a record
    # for the object doesn't exist in the data store yet; otherwise, returns false.
    def new_record?
      @new_record
    end

    # Returns true if this object has been destroyed, otherwise returns false.
    def destroyed?
      @destroyed
    end

    # Returns if the record is persisted, i.e. it's not a new record and it was
    # not destroyed.
    def persisted?
      !(new_record? || destroyed?)
    end

    # :call-seq:
    #   save(options)
    #
    # Saves the model.
    #
    # If the model is new a record gets created in the database, otherwise
    # the existing record gets updated.
    #
    # By default, save always run validations. If any of them fail the action
    # is cancelled and +save+ returns +false+. However, if you supply
    # :validate => false, validations are bypassed altogether. See
    # ActiveRecord::Validations for more information.
    #
    # There's a series of callbacks associated with +save+. If any of the
    # <tt>before_*</tt> callbacks return +false+ the action is cancelled and
    # +save+ returns +false+. See ActiveRecord::Callbacks for further
    # details.
    def save(*)
      create_or_update
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
    def save!(*)
      create_or_update || raise(RecordNotSaved)
    end

    # Deletes the record in the database and freezes this instance to
    # reflect that no changes should be made (since they can't be
    # persisted). Returns the frozen instance.
    #
    # The row is simply removed with an SQL +DELETE+ statement on the
    # record's primary key, and no callbacks are executed.
    #
    # To enforce the object's +before_destroy+ and +after_destroy+
    # callbacks, Observer methods, or any <tt>:dependent</tt> association
    # options, use <tt>#destroy</tt>.
    def delete
      self.class.delete(id) if persisted?
      @destroyed = true
      freeze
    end

    # Deletes the record in the database and freezes this instance to reflect
    # that no changes should be made (since they can't be persisted).
    def destroy
      if persisted?
        self.class.unscoped.where(self.class.arel_table[self.class.primary_key].eq(id)).delete_all
      end

      @destroyed = true
      freeze
    end

    # Returns an instance of the specified +klass+ with the attributes of the
    # current record. This is mostly useful in relation to single-table
    # inheritance structures where you want a subclass to appear as the
    # superclass. This can be used along with record identification in
    # Action Pack to allow, say, <tt>Client < Company</tt> to do something
    # like render <tt>:partial => @client.becomes(Company)</tt> to render that
    # instance using the companies/company partial instead of clients/client.
    #
    # Note: The new instance will share a link to the same attributes as the original class.
    # So any change to the attributes in either instance will affect the other.
    def becomes(klass)
      became = klass.new
      became.instance_variable_set("@attributes", @attributes)
      became.instance_variable_set("@attributes_cache", @attributes_cache)
      became.instance_variable_set("@new_record", new_record?)
      became.instance_variable_set("@destroyed", destroyed?)
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
    def update_attribute(name, value)
      name = name.to_s
      raise ActiveRecordError, "#{name} is marked as readonly" if self.class.readonly_attributes.include?(name)
      send("#{name}=", value)
      save(:validate => false)
    end

    # Updates the attributes of the model from the passed-in hash and saves the
    # record, all wrapped in a transaction. If the object is invalid, the saving
    # will fail and false will be returned.
    def update_attributes(attributes)
      # The following transaction covers any possible database side-effects of the
      # attributes assignment. For example, setting the IDs of a child collection.
      with_transaction_returning_status do
        self.attributes = attributes
        save
      end
    end

    # Updates its receiver just like +update_attributes+ but calls <tt>save!</tt> instead
    # of +save+, so an exception is raised if the record is invalid.
    def update_attributes!(attributes)
      # The following transaction covers any possible database side-effects of the
      # attributes assignment. For example, setting the IDs of a child collection.
      with_transaction_returning_status do
        self.attributes = attributes
        save!
      end
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

    # Reloads the attributes of this object from the database.
    # The optional options argument is passed to find when reloading so you
    # may do e.g. record.reload(:lock => true) to reload the same record with
    # an exclusive row lock.
    def reload(options = nil)
      clear_aggregation_cache
      clear_association_cache
      @attributes.update(self.class.unscoped { self.class.find(self.id, options) }.instance_variable_get('@attributes'))
      @attributes_cache = {}
      self
    end

    # Saves the record with the updated_at/on attributes set to the current time.
    # Please note that no validation is performed and no callbacks are executed.
    # If an attribute name is passed, that attribute is updated along with
    # updated_at/on attributes.
    #
    #   product.touch               # updates updated_at/on
    #   product.touch(:designed_at) # updates the designed_at attribute and updated_at/on
    #
    # If used along with +belongs_to+ then +touch+ will invoke +touch+ method on associated object.
    #
    #   class Brake < ActiveRecord::Base
    #     belongs_to :car, :touch => true
    #   end
    #
    #   class Car < ActiveRecord::Base
    #     belongs_to :corporation, :touch => true
    #   end
    #
    #   # triggers @brake.car.touch and @brake.car.corporation.touch
    #   @brake.touch
    def touch(name = nil)
      attributes = timestamp_attributes_for_update_in_model
      attributes << name if name
      unless attributes.empty?
        current_time = current_time_from_proper_timezone
        changes = {}

        attributes.each do |column|
          changes[column.to_s] = write_attribute(column.to_s, current_time)
        end

        @changed_attributes.except!(*changes.keys)
        primary_key = self.class.primary_key
        self.class.update_all(changes, { primary_key => self[primary_key] }) == 1
      end
    end

  private
    def create_or_update
      raise ReadOnlyRecord if readonly?
      result = new_record? ? create : update
      result != false
    end

    # Updates the associated record with values matching those of the instance attributes.
    # Returns the number of affected rows.
    def update(attribute_names = @attributes.keys)
      attributes_with_values = arel_attributes_values(false, false, attribute_names)
      return 0 if attributes_with_values.empty?
      self.class.unscoped.where(self.class.arel_table[self.class.primary_key].eq(id)).arel.update(attributes_with_values)
    end

    # Creates a record with values matching those of the instance attributes
    # and returns its id.
    def create
      if self.id.nil? && connection.prefetch_primary_key?(self.class.table_name)
        self.id = connection.next_sequence_value(self.class.sequence_name)
      end

      attributes_values = arel_attributes_values

      new_id = if attributes_values.empty?
        self.class.unscoped.insert connection.empty_insert_statement_value
      else
        self.class.unscoped.insert attributes_values
      end

      self.id ||= new_id

      @new_record = false
      id
    end

    # Initializes the attributes array with keys matching the columns from the linked table and
    # the values matching the corresponding default value of that column, so
    # that a new instance, or one populated from a passed-in Hash, still has all the attributes
    # that instances loaded from the database would.
    def attributes_from_column_definition
      self.class.columns.inject({}) do |attributes, column|
        attributes[column.name] = column.default unless column.name == self.class.primary_key
        attributes
      end
    end
  end
end
