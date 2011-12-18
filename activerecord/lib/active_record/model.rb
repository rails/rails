module ActiveRecord
  module Model
    def self.included(base)
      base.class_eval do
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
      end
    end
  end
end

require 'active_record/connection_adapters/abstract/connection_specification'
ActiveSupport.run_load_hooks(:active_record, ActiveRecord::Base)
