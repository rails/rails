module ActiveRecord
  module Model
    # So we can recognise an AR class even while self.included is being
    # executed. (At that time, klass < Model == false.)
    module Tag #:nodoc:
    end

    def self.included(base)
      return if base < Tag

      base.class_eval do
        include Tag

        include Configuration

        include ActiveRecord::Persistence
        extend ActiveModel::Naming
        extend QueryCache::ClassMethods
        extend ActiveSupport::Benchmarkable
        extend ActiveSupport::DescendantsTracker

        extend Querying
        include ReadonlyAttributes
        include ModelSchema
        extend Translation
        include Inheritance
        include Scoping
        extend DynamicMatchers
        include Sanitization
        include Integration
        include AttributeAssignment
        include ActiveModel::Conversion
        include Validations
        extend CounterCache
        include Locking::Optimistic, Locking::Pessimistic
        include AttributeMethods
        include Callbacks, ActiveModel::Observing, Timestamp
        include Associations
        include IdentityMap
        include ActiveModel::SecurePassword
        extend Explain

        # AutosaveAssociation needs to be included before Transactions, because we want
        # #save_with_autosave_associations to be wrapped inside a transaction.
        include AutosaveAssociation, NestedAttributes
        include Aggregations, Transactions, Reflection, Serialization, Store

        include Core

        self.connection_handler = Base.connection_handler
      end
    end
  end
end

require 'active_record/connection_adapters/abstract/connection_specification'
ActiveSupport.run_load_hooks(:active_record, ActiveRecord::Model)
