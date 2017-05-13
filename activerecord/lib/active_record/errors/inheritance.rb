module ActiveRecord
  # Superclass for all ActiveRecord inheritance-related errors.
  class InheritanceError < ActiveRecordError
  end

  # Raised when the single-table inheritance mechanism fails to locate the subclass
  # (for example due to improper usage of column that
  # {ActiveRecord::Base.inheritance_column}[rdoc-ref:ModelSchema::ClassMethods#inheritance_column]
  # points to).
  class SubclassNotFound < InheritanceError
  end

  class NotAnActiveRecord < InheritanceError #:nodoc:
  end
end
