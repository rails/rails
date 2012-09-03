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
      # +create+ respects mass-assignment security and accepts either +:as+ or +:without_protection+ options
      # in the +options+ parameter.
      #
      # ==== Examples
      #   # Create a single new object
      #   User.create(:first_name => 'Jamie')
      #
      #   # Create a single new object using the :admin mass-assignment security role
      #   User.create({ :first_name => 'Jamie', :is_admin => true }, :as => :admin)
      #
      #   # Create a single new object bypassing mass-assignment security
      #   User.create({ :first_name => 'Jamie', :is_admin => true }, :without_protection => true)
      #
      #   # Create an Array of new objects
      #   User.create([{ :first_name => 'Jamie' }, { :first_name => 'Jeremy' }])
      #
      #   # Create a single object and pass it into a block to set other attributes.
      #   User.create(:first_name => 'Jamie') do |u|
      #     u.is_admin = false
      #   end
      #
      #   # Creating an Array of new objects using a block, where the block is executed for each object:
      #   User.create([{ :first_name => 'Jamie' }, { :first_name => 'Jeremy' }]) do |u|
      #     u.is_admin = false
      #   end
      def create(attributes = nil, options = {}, &block)
        if attributes.is_a?(Array)
          attributes.collect { |attr| create(attr, options, &block) }
        else
          object = new(attributes, options, &block)
          object.save
          object
        end
      end
    end

    # Returns true if this object hasn't been saved yet -- that is, a record
    # for the object doesn't exist in the data store yet; otherwise, returns false.
    def new_record?
      @new_record
    end

    # Returns true if this object has been destroyed, otherwise returns false.
    def destroyed?
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
    # :validate => false, validations are bypassed altogether. See
    # ActiveRecord::Validations for more information.
    #
    # There's a series of callbacks associated with +save+. If any of the
    # <tt>before_*</tt> callbacks return +false+ the action is cancelled and
    # +save+ returns +false+. See ActiveRecord::Callbacks for further
    # details.
    def save(*)
      begin
        create_or_update
      rescue ActiveRecord::RecordInvalid
        false
      end
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
    #
    # There's a series of callbacks associated with <tt>destroy</tt>. If
    # the <tt>before_destroy</tt> callback return +false+ the action is cancelled
    # and <tt>destroy</tt> returns +false+. See
    # ActiveRecord::Callbacks for further details.
    def destroy
      raise ReadOnlyRecord if readonly?
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
      destroy || raise(ActiveRecord::RecordNotDestroyed)
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
      became.instance_variable_set("@errors", errors)
      became.public_send("#{klass.inheritance_column}=", klass.name) unless self.class.descends_from_active_record?
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
      verify_readonly_attribute(name)
      send("#{name}=", value)
      save(:validate => false)
    end

    # Updates the attributes of the model from the passed-in hash and saves the
    # record, all wrapped in a transaction. If the object is invalid, the saving
    # will fail and false will be returned.
    #
    # When updating model attributes, mass-assignment security protection is respected.
    # If no +:as+ option is supplied then the +:default+ role will be used.
    # If you want to bypass the protection given by +attr_protected+ and
    # +attr_accessible+ then you can do so using the +:without_protection+ option.
    def update_attributes(attributes, options = {})
      # The following transaction covers any possible database side-effects of the
      # attributes assignment. For example, setting the IDs of a child collection.
      with_transaction_returning_status do
        assign_attributes(attributes, options)
        save
      end
    end

    # Updates its receiver just like +update_attributes+ but calls <tt>save!</tt> instead
    # of +save+, so an exception is raised if the record is invalid.
    def update_attributes!(attributes, options = {})
      # The following transaction covers any possible database side-effects of the
      # attributes assignment. For example, setting the IDs of a child collection.
      with_transaction_returning_status do
        assign_attributes(attributes, options)
        save!
      end
    end

    # Updates a single attribute of an object, without calling save.
    #
    # * Validation is skipped.
    # * Callbacks are skipped.
    # * updated_at/updated_on column is not updated if that column is available.
    #
    # Raises an +ActiveRecordError+ when called on new objects, or when the +name+
    # attribute is marked as readonly.
    def update_column(name, value)
      update_columns(name => value)
    end

    # Updates the attributes from the passed-in hash, without calling save.
    #
    # * Validation is skipped.
    # * Callbacks are skipped.
    # * updated_at/updated_on column is not updated if that column is available.
    #
    # Raises an +ActiveRecordError+ when called on new objects, or when at least
    # one of the attributes is marked as readonly.
    def update_columns(attributes)
      raise ActiveRecordError, "can not update on a new record object" unless persisted?

      attributes.each_key do |key|
        verify_readonly_attribute(key.to_s)
      end

      attributes.each do |k,v|
        raw_write_attribute(k,v)
      end

      self.class.where(self.class.primary_key => id).update_all(attributes) == 1
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

      fresh_object =
        if options && options[:lock]
          self.class.unscoped { self.class.lock.find(id) }
        else
          self.class.unscoped { self.class.find(id) }
        end

      @attributes.update(fresh_object.instance_variable_get('@attributes'))
      @columns_hash = fresh_object.instance_variable_get('@columns_hash')

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
          column = column.to_s
          changes[column] = write_attribute(column, current_time)
        end

        changes[self.class.locking_column] = increment_lock if locking_enabled?

        @changed_attributes.except!(*changes.keys)
        primary_key = self.class.primary_key
        self.class.unscoped.where(primary_key => self[primary_key]).update_all(changes) == 1
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
      substitute = connection.substitute_at(column, 0)

      relation = self.class.unscoped.where(
        self.class.arel_table[pk].eq(substitute))

      relation.bind_values = [[column, id]]
      relation
    end

    def create_or_update
      raise ReadOnlyRecord if readonly?
      result = new_record? ? create : update
      result != false
    end

    # Updates the associated record with values matching those of the instance attributes.
    # Returns the number of affected rows.
    def update(attribute_names = @attributes.keys)
      attributes_with_values = arel_attributes_with_values_for_update(attribute_names)
      return 0 if attributes_with_values.empty?
      klass = self.class
      stmt = klass.unscoped.where(klass.arel_table[klass.primary_key].eq(id)).arel.compile_update(attributes_with_values)
      klass.connection.update stmt
    end

    # Creates a record with values matching those of the instance attributes
    # and returns its id.
    def create
      attributes_values = arel_attributes_with_values_for_create(!id.nil?)

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
