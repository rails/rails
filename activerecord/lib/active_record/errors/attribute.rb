module ActiveRecord
  #
  # Superclass for all ActiveRecord attribute-related errors.
  #
  class AttributeError < ActiveRecordError
  end

  # Raised when attribute has a name reserved by Active Record (when attribute
  # has name of one of Active Record instance methods).
  class DangerousAttributeError < AttributeError
  end

  # Raised when unknown attributes are supplied via mass assignment.
  UnknownAttributeError = ActiveModel::UnknownAttributeError

  # MissingAttributeError = ActiveModel::MissingAttributeError

  # Raised when an error occurred while doing a mass assignment to an attribute through the
  # {ActiveRecord::Base#attributes=}[rdoc-ref:AttributeAssignment#attributes=] method.
  # The exception has an +attribute+ property that is the name of the offending attribute.
  class AttributeAssignmentError < AttributeError
    attr_reader :exception, :attribute

    def initialize(message = nil, exception = nil, attribute = nil)
      super(message)
      @exception = exception
      @attribute = attribute
    end
  end

  # Raised when there are multiple errors while doing a mass assignment through the
  # {ActiveRecord::Base#attributes=}[rdoc-ref:AttributeAssignment#attributes=]
  # method. The exception has an +errors+ property that contains an array of AttributeAssignmentError
  # objects, each corresponding to the error while assigning to an attribute.
  class MultiparameterAssignmentErrors < AttributeError
    attr_reader :errors

    def initialize(errors = nil)
      @errors = errors
    end
  end

  # Raised when a primary key is needed, but not specified in the schema or model.
  class UnknownPrimaryKey < AttributeError
    attr_reader :model

    def initialize(model = nil, description = nil)
      if model
        message = "Unknown primary key for table #{model.table_name} in model #{model}."
        message += "\n#{description}" if description
        @model = model
        super(message)
      else
        super("Unknown primary key.")
      end
    end
  end

  class DirtyAttributeError < AttributeError # :nodoc:
  end

  # TooManyNestedRecords is raised when calling limit()
  # but the size of the nested attributes array exceeds the specified limit
  class TooManyNestedRecords < AttributeError
  end

  # Raised by methods update_attribute and update_column
  # when trying update an attribute marked as readonly
  class ReadOnlyAttribute < AttributeError
  end
end
