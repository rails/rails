require 'active_support/deprecation'
require 'active_support/concern'
require 'active_support/core_ext/module/delegation'
require 'active_support/core_ext/module/attribute_accessors'

module ActiveRecord
  module Configuration # :nodoc:
    # This just abstracts out how we define configuration options in AR. Essentially we
    # have mattr_accessors on the ActiveRecord:Model constant that define global defaults.
    # Classes that then use AR get class_attributes defined, which means that when they
    # are assigned the default will be overridden for that class and subclasses. (Except
    # when options[:global] == true, in which case there is one global value always.)
    def config_attribute(name, options = {})
      if options[:global]
        class_eval <<-CODE, __FILE__, __LINE__ + 1
          def self.#{name};       ActiveRecord::Model.#{name};       end
          def #{name};            ActiveRecord::Model.#{name};       end
          def self.#{name}=(val); ActiveRecord::Model.#{name} = val; end
        CODE
      else
        options[:instance_writer] ||= false
        class_attribute name, options

        singleton_class.class_eval <<-CODE, __FILE__, __LINE__ + 1
          remove_method :#{name}
          def #{name}; ActiveRecord::Model.#{name}; end
        CODE
      end
    end
  end

  # <tt>ActiveRecord::Model</tt> can be included into a class to add Active Record persistence.
  # This is an alternative to inheriting from <tt>ActiveRecord::Base</tt>. Example:
  #
  #     class Post
  #       include ActiveRecord::Model
  #     end
  #
  module Model
    extend ActiveSupport::Concern
    extend ConnectionHandling
    extend ActiveModel::Observing::ClassMethods

    # This allows us to detect an ActiveRecord::Model while it's in the process of being included.
    module Tag; end

    def self.append_features(base)
      base.class_eval do
        include Tag
        extend Configuration
      end

      super
    end

    included do
      extend ActiveModel::Naming
      extend ActiveSupport::Benchmarkable
      extend ActiveSupport::DescendantsTracker

      extend QueryCache::ClassMethods
      extend Querying
      extend Translation
      extend DynamicMatchers
      extend Explain
      extend ConnectionHandling

      initialize_generated_modules unless self == Base
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
    include CounterCache
    include Locking::Optimistic
    include Locking::Pessimistic
    include AttributeMethods
    include Callbacks
    include ActiveModel::Observing
    include Timestamp
    include Associations
    include ActiveModel::SecurePassword
    include AutosaveAssociation
    include NestedAttributes
    include Transactions
    include Reflection
    include Serialization
    include Store
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

  # This hook is where config accessors on Model get defined.
  #
  # We don't want to just open the Model module and add stuff to it in other files, because
  # that would cause Model to load, which causes all sorts of loading order issues.
  #
  # We need this hook rather than just using the :active_record one, because users of the
  # :active_record hook may need to use config options.
  ActiveSupport.run_load_hooks(:active_record_config, Model)

  # Load Base at this point, because the active_record load hook is run in that file.
  Base
end
