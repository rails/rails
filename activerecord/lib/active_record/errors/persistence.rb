module ActiveRecord
  # Superclass for all ActiveRecord persistence-related errors.
  class PersistenceError < ActiveRecordError
  end

  # = Active Record \RecordInvalid
  #
  # Raised by {ActiveRecord::Base#save!}[rdoc-ref:Persistence#save!] and
  # {ActiveRecord::Base#create!}[rdoc-ref:Persistence::ClassMethods#create!] when the record is invalid.
  # Use the #record method to retrieve the record which did not validate.
  #
  #   begin
  #     complex_operation_that_internally_calls_save!
  #   rescue ActiveRecord::RecordInvalid => invalid
  #     puts invalid.record.errors
  #   end
  class RecordInvalid < PersistenceError
    attr_reader :record

    def initialize(record = nil)
      if record
        @record = record
        errors = @record.errors.full_messages.join(", ")
        message = I18n.t(:"#{@record.class.i18n_scope}.errors.messages.record_invalid", errors: errors, default: :"errors.messages.record_invalid")
      else
        message = "Record invalid"
      end

      super(message)
    end
  end

  # Raised by {ActiveRecord::Base#save!}[rdoc-ref:Persistence#save!] and
  # {ActiveRecord::Base.create!}[rdoc-ref:Persistence::ClassMethods#create!]
  # methods when a record is invalid and can not be saved.
  class RecordNotSaved < PersistenceError
    attr_reader :record

    def initialize(message = nil, record = nil)
      @record = record
      super(message)
    end
  end

  # Raised by {ActiveRecord::Base#destroy!}[rdoc-ref:Persistence#destroy!]
  # when a call to {#destroy}[rdoc-ref:Persistence#destroy!]
  # would return false.
  #
  #   begin
  #     complex_operation_that_internally_calls_destroy!
  #   rescue ActiveRecord::RecordNotDestroyed => invalid
  #     puts invalid.record.errors
  #   end
  #
  class RecordNotDestroyed < PersistenceError
    attr_reader :record

    def initialize(message = nil, record = nil)
      @record = record
      super(message)
    end
  end

  # Raised on attempt to save stale record. Record is stale when it's being saved in another query after
  # instantiation, for example, when two users edit the same wiki page and one starts editing and saves
  # the page before the other.
  #
  # Read more about optimistic locking in ActiveRecord::Locking module
  # documentation.
  class StaleObjectError < PersistenceError
    attr_reader :record, :attempted_action

    def initialize(record = nil, attempted_action = nil)
      if record && attempted_action
        @record = record
        @attempted_action = attempted_action
        super("Attempted to #{attempted_action} a stale object: #{record.class.name}.")
      else
        super("Stale object error.")
      end
    end
  end

  # Raised on attempt to update record that is instantiated as read only.
  class ReadOnlyRecord < PersistenceError
  end

  # Raised by {ActiveRecord::Base#touch}[rdoc-ref:Persistence#touch] and
  # {ActiveRecord::Base#update_columns}[rdoc-ref:Persistence#update_columns]
  # trying to update a record that hasn't been persisted yet.
  class CannotUpdateNewRecord < PersistenceError
    attr_reader :record

    def initialize(message = nil, record = nil)
      @record = record
      super(message)
    end
  end

  # Raised by {ActiveRecord::Base#update_columns}[rdoc-ref:Persistence#update_columns]
  # trying to update a record instance +AFTER+ it's been destroyed.
  #
  # Please, note that if the record id is not found in the database,
  # this error will +NOT+ be raised.
  #
  # Read more about optimistic locking in ActiveRecord::Locking module
  # documentation.
  class CannotUpdateDestroyedRecord < PersistenceError
    attr_reader :record

    def initialize(message = nil, record = nil)
      @record = record
      super(message)
    end
  end
end
