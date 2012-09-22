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

  # This allows us to detect an ActiveRecord::Model while it's in the process of
  # being included.
  module Tag; end

  # <tt>ActiveRecord::Model</tt> can be included into a class to add Active Record
  # persistence. This is an alternative to inheriting from <tt>ActiveRecord::Base</tt>.
  #
  #     class Post
  #       include ActiveRecord::Model
  #     end
  module Model
    extend ActiveSupport::Concern
    extend ConnectionHandling
    extend ActiveModel::Observing::ClassMethods

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
    include AttributeAssignment
    include ActiveModel::Conversion
    include Integration
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
    include Aggregations
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

      # Defines the name of the table column which will store the class name on single-table
      # inheritance situations.
      #
      # The default inheritance column name is +type+, which means it's a
      # reserved word inside Active Record. To be able to use single-table
      # inheritance with another column name, or to use the column +type+ in
      # your own model for something else, you can set +inheritance_column+:
      #
      #     self.inheritance_column = 'zoink'
      def inheritance_column
        'type'
      end
    end

    class DeprecationProxy < BasicObject #:nodoc:
      def initialize(model = Model, base = Base)
        @model = model
        @base  = base
      end

      def method_missing(name, *args, &block)
        if @model.respond_to?(name, true)
          @model.send(name, *args, &block)
        else
          ::ActiveSupport::Deprecation.warn(
            "The object passed to the active_record load hook was previously ActiveRecord::Base " \
            "(a Class). Now it is ActiveRecord::Model (a Module). You have called `#{name}' which " \
            "is only defined on ActiveRecord::Base. Please change your code so that it works with " \
            "a module rather than a class. (Model is included in Base, so anything added to Model " \
            "will be available on Base as well.)"
          )
          @base.send(name, *args, &block)
        end
      end

      alias send method_missing

      def extend(*mods)
        ::ActiveSupport::Deprecation.warn(
          "The object passed to the active_record load hook was previously ActiveRecord::Base " \
          "(a Class). Now it is ActiveRecord::Model (a Module). You have called `extend' which " \
          "would add singleton methods to Model. This is presumably not what you want, since the " \
          "methods would not be inherited down to Base. Rather than using extend, please use " \
          "ActiveSupport::Concern + include, which will ensure that your class methods are " \
          "inherited."
        )
        @base.extend(*mods)
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
