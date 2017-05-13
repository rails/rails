module ActiveRecord
  # Superclass for common ActiveRecord errors.
  class CommonActiveRecordError < ActiveRecordError
  end

  # Raised when unserialized object's type mismatches one specified for serializable field.
  class SerializationTypeMismatch < CommonActiveRecordError
  end

  # Raised when Active Record cannot find a record by given id or set of ids.
  class RecordNotFound < CommonActiveRecordError
    attr_reader :model, :primary_key, :id

    def initialize(message = nil, model = nil, primary_key = nil, id = nil)
      @primary_key = primary_key
      @model = model
      @id = id

      super(message)
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
  class ImmutableRelation < CommonActiveRecordError
  end

  # IrreversibleOrderError is raised when a relation's order is too complex for
  # +reverse_order+ to automatically reverse.
  class IrreversibleOrderError < CommonActiveRecordError
  end

  class FixtureClassNotFound < CommonActiveRecordError #:nodoc:
  end

  # Raised when +delete_all+ is invoked with invalid methods.
  class DeleteAllError < CommonActiveRecordError
  end
end
