require 'active_support/core_ext/enumerable'
require 'active_support/deprecation'

module ActiveRecord
  # = Active Record Attribute Methods
  module AttributeMethods #:nodoc:
    extend ActiveSupport::Concern
    include ActiveModel::AttributeMethods

    module ClassMethods
      # Generates all the attribute related methods for columns in the database
      # accessors, mutators and query methods.
      def define_attribute_methods
        return if attribute_methods_generated?

        if base_class == self
          super(column_names)
          @attribute_methods_generated = true
        else
          base_class.define_attribute_methods
        end
      end

      def attribute_methods_generated?
        if base_class == self
          @attribute_methods_generated ||= false
        else
          base_class.attribute_methods_generated?
        end
      end

      def undefine_attribute_methods(*args)
        if base_class == self
          super
          @attribute_methods_generated = false
        else
          base_class.undefine_attribute_methods(*args)
        end
      end

      def instance_method_already_implemented?(method_name)
        if dangerous_attribute_method?(method_name)
          raise DangerousAttributeError, "#{method_name} is defined by ActiveRecord"
        end

        super
      end

      # A method name is 'dangerous' if it is already defined by Active Record, but
      # not by any ancestors. (So 'puts' is not dangerous but 'save' is.)
      def dangerous_attribute_method?(method_name)
        active_record = ActiveRecord::Base
        superclass    = ActiveRecord::Base.superclass

        (active_record.method_defined?(method_name) ||
         active_record.private_method_defined?(method_name)) &&
        !superclass.method_defined?(method_name) &&
        !superclass.private_method_defined?(method_name)
      end
    end

    # If we haven't generated any methods yet, generate them, then
    # see if we've created the method we're looking for.
    def method_missing(method, *args, &block)
      unless self.class.attribute_methods_generated?
        self.class.define_attribute_methods

        if respond_to_without_attributes?(method)
          send(method, *args, &block)
        else
          super
        end
      else
        super
      end
    end

    def attribute_missing(match, *args, &block)
      if self.class.columns_hash[match.attr_name]
        ActiveSupport::Deprecation.warn(
          "The method `#{match.method_name}', matching the attribute `#{match.attr_name}' has " \
          "dispatched through method_missing. This shouldn't happen, because `#{match.attr_name}' " \
          "is a column of the table. If this error has happened through normal usage of Active " \
          "Record (rather than through your own code or external libraries), please report it as " \
          "a bug."
        )
      end

      super
    end

    def respond_to?(name, include_private = false)
      self.class.define_attribute_methods unless self.class.attribute_methods_generated?
      super
    end

    protected
      def attribute_method?(attr_name)
        attr_name == 'id' || (defined?(@attributes) && @attributes.include?(attr_name))
      end
  end
end
