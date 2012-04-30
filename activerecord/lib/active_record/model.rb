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
    module ClassMethods #:nodoc:
      include ActiveSupport::Callbacks::ClassMethods
      include ActiveModel::Naming
      include QueryCache::ClassMethods
      include ActiveSupport::Benchmarkable
      include ActiveSupport::DescendantsTracker

      include Querying
      include Translation
      include DynamicMatchers
      include CounterCache
      include Explain
      include ConnectionHandling
    end

    def self.included(base)
      return if base.singleton_class < ClassMethods

      base.class_eval do
        extend ClassMethods
        Callbacks::Register.setup(self)
        initialize_generated_modules unless self == Base
      end
    end

    extend ActiveModel::Configuration
    extend ActiveModel::Callbacks
    extend ActiveModel::MassAssignmentSecurity::ClassMethods
    extend ActiveModel::AttributeMethods::ClassMethods
    extend Callbacks::Register
    extend Explain
    extend ConnectionHandling

    def self.extend(*modules)
      ClassMethods.send(:include, *modules)
    end

    include Persistence
    include ReadonlyAttributes
    include ModelSchema
    include Inheritance
    include Scoping
    include Sanitization
    include Integration
    include AttributeAssignment
    include ActiveModel::Conversion
    include Validations
    include Locking::Optimistic, Locking::Pessimistic
    include AttributeMethods
    include Callbacks, ActiveModel::Observing, Timestamp
    include Associations
    include ActiveModel::SecurePassword
    include AutosaveAssociation, NestedAttributes
    include Aggregations, Transactions, Reflection, Serialization, Store
    include Core

    class << self
      def arel_engine
        self
      end

      def abstract_class?
        false
      end

      def inheritance_column
        'type'
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
