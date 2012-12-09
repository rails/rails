module ActiveRecord

  # = Active Record Errors
  #
  # Generic Active Record exception class.
  class ActiveRecordError < StandardError
  end

  # Raised when the single-table inheritance mechanism fails to locate the subclass
  # (for example due to improper usage of column that +inheritance_column+ points to).
  class SubclassNotFound < ActiveRecordError #:nodoc:
  end

  # Raised when an object assigned to an association has an incorrect type.
  #
  #   class Ticket < ActiveRecord::Base
  #     has_many :patches
  #   end
  #
  #   class Patch < ActiveRecord::Base
  #     belongs_to :ticket
  #   end
  #
  #   # Comments are not patches, this assignment raises AssociationTypeMismatch.
  #   @ticket.patches << Comment.new(content: "Please attach tests to your patch.")
  class AssociationTypeMismatch < ActiveRecordError
  end

  # Raised when unserialized object's type mismatches one specified for serializable field.
  class SerializationTypeMismatch < ActiveRecordError
  end

  # Raised when adapter not specified on connection (or configuration file <tt>config/database.yml</tt>
  # misses adapter field).
  class AdapterNotSpecified < ActiveRecordError
  end

  # Raised when Active Record cannot find database adapter specified in <tt>config/database.yml</tt> or programmatically.
  class AdapterNotFound < ActiveRecordError
  end

  # Raised when connection to the database could not been established (for example when <tt>connection=</tt>
  # is given a nil object).
  class ConnectionNotEstablished < ActiveRecordError
  end

  # Raised when Active Record cannot find record by given id or set of ids.
  class RecordNotFound < ActiveRecordError
  end

  # Raised by ActiveRecord::Base.save! and ActiveRecord::Base.create! methods when record cannot be
  # saved because record is invalid.
  class RecordNotSaved < ActiveRecordError
  end

  # Raised by ActiveRecord::Base.destroy! when a call to destroy would return false.
  class RecordNotDestroyed < ActiveRecordError
  end

  # Raised when SQL statement cannot be executed by the database (for example, it's often the case for
  # MySQL when Ruby driver used is too old).
  class StatementInvalid < ActiveRecordError
  end

  # Raised when SQL statement is invalid and the application gets a blank result.
  class ThrowResult < ActiveRecordError
  end

  # Parent class for all specific exceptions which wrap database driver exceptions
  # provides access to the original exception also.
  class WrappedDatabaseException < StatementInvalid
    attr_reader :original_exception

    def initialize(message, original_exception)
      super(message)
      @original_exception = original_exception
    end
  end

  # Raised when a record cannot be inserted because it would violate a uniqueness constraint.
  class RecordNotUnique < WrappedDatabaseException
  end

  # Raised when a record cannot be inserted or updated because it references a non-existent record.
  class InvalidForeignKey < WrappedDatabaseException
  end

  # Raised when number of bind variables in statement given to <tt>:condition</tt> key (for example,
  # when using +find+ method)
  # does not match number of expected variables.
  #
  # For example, in
  #
  #   Location.where("lat = ? AND lng = ?", 53.7362)
  #
  # two placeholders are given but only one variable to fill them.
  class PreparedStatementInvalid < ActiveRecordError
  end

  # Raised on attempt to save stale record. Record is stale when it's being saved in another query after
  # instantiation, for example, when two users edit the same wiki page and one starts editing and saves
  # the page before the other.
  #
  # Read more about optimistic locking in ActiveRecord::Locking module RDoc.
  class StaleObjectError < ActiveRecordError
    attr_reader :record, :attempted_action

    def initialize(record, attempted_action)
      super("Attempted to #{attempted_action} a stale object: #{record.class.name}")
      @record = record
      @attempted_action = attempted_action
    end

  end

  # Raised when association is being configured improperly or
  # user tries to use offset and limit together with has_many or has_and_belongs_to_many associations.
  class ConfigurationError < ActiveRecordError
  end

  # Raised on attempt to update record that is instantiated as read only.
  class ReadOnlyRecord < ActiveRecordError
  end

  # ActiveRecord::Transactions::ClassMethods.transaction uses this exception
  # to distinguish a deliberate rollback from other exceptional situations.
  # Normally, raising an exception will cause the +transaction+ method to rollback
  # the database transaction *and* pass on the exception. But if you raise an
  # ActiveRecord::Rollback exception, then the database transaction will be rolled back,
  # without passing on the exception.
  #
  # For example, you could do this in your controller to rollback a transaction:
  #
  #   class BooksController < ActionController::Base
  #     def create
  #       Book.transaction do
  #         book = Book.new(params[:book])
  #         book.save!
  #         if today_is_friday?
  #           # The system must fail on Friday so that our support department
  #           # won't be out of job. We silently rollback this transaction
  #           # without telling the user.
  #           raise ActiveRecord::Rollback, "Call tech support!"
  #         end
  #       end
  #       # ActiveRecord::Rollback is the only exception that won't be passed on
  #       # by ActiveRecord::Base.transaction, so this line will still be reached
  #       # even on Friday.
  #       redirect_to root_url
  #     end
  #   end
  class Rollback < ActiveRecordError
  end

  # Raised when attribute has a name reserved by Active Record (when attribute has name of one of Active Record instance methods).
  class DangerousAttributeError < ActiveRecordError
  end

  # Raised when unknown attributes are supplied via mass assignment.
  class UnknownAttributeError < NoMethodError
  end

  # Raised when an error occurred while doing a mass assignment to an attribute through the
  # <tt>attributes=</tt> method. The exception has an +attribute+ property that is the name of the
  # offending attribute.
  class AttributeAssignmentError < ActiveRecordError
    attr_reader :exception, :attribute
    def initialize(message, exception, attribute)
      super(message)
      @exception = exception
      @attribute = attribute
    end
  end

  # Raised when there are multiple errors while doing a mass assignment through the +attributes+
  # method. The exception has an +errors+ property that contains an array of AttributeAssignmentError
  # objects, each corresponding to the error while assigning to an attribute.
  class MultiparameterAssignmentErrors < ActiveRecordError
    attr_reader :errors
    def initialize(errors)
      @errors = errors
    end
  end

  # Raised when a primary key is needed, but there is not one specified in the schema or model.
  class UnknownPrimaryKey < ActiveRecordError
    attr_reader :model

    def initialize(model)
      super("Unknown primary key for table #{model.table_name} in model #{model}.")
      @model = model
    end

  end

  # Raised when a relation cannot be mutated because it's already loaded.
  #
  #   class Task < ActiveRecord::Base
  #   end
  #
  #   relation = Task.all
  #   relation.loaded? # => true
  #
  #   # Methods which try to mutate a loaded relation fail.
  #   relation.where!(title: 'TODO')  # => ActiveRecord::ImmutableRelation
  #   relation.limit!(5)              # => ActiveRecord::ImmutableRelation
  class ImmutableRelation < ActiveRecordError
  end

  class TransactionIsolationError < ActiveRecordError
  end
end
