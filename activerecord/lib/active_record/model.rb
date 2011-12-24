require 'active_support/deprecation'

module ActiveRecord
  # <tt>ActiveRecord::Model</tt> can be included into a class to add Active Record persistence.
  # This is an alternative to inheriting from <tt>ActiveRecord::Base</tt>. Example:
  #
  #     class Post
  #       include ActiveRecord::Model
  #     end
  #
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

    module DeprecationProxy #:nodoc:
      class << self
        instance_methods.each { |m| undef_method m unless m =~ /^__|^object_id$|^instance_eval$/ }

        def method_missing(name, *args, &block)
          if Model.respond_to?(name)
            Model.send(name, *args, &block)
          else
            ActiveSupport::Deprecation.warn(
              "The object passed to the active_record load hook was previously ActiveRecord::Base " \
              "(a Class). Now it is ActiveRecord::Model (a Module). You have called `#{name}' which " \
              "is only defined on ActiveRecord::Base. Please change your code so that it works with " \
              "a module rather than a class. (Model is included in Base, so anything added to Model " \
              "will be available on Base as well.)"
            )
            Base.send(name, *args, &block)
          end
        end

        alias send method_missing
      end
    end
  end

  # Load Base at this point, because the active_record load hook is run in that file.
  Base
end
