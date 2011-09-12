require 'active_support/core_ext/enumerable'

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

      # Checks whether the method is defined in the model or any of its subclasses
      # that also derive from Active Record. Raises DangerousAttributeError if the
      # method is defined by Active Record though.
      def instance_method_already_implemented?(method_name)
        method_name = method_name.to_s
        index = ancestors.index(ActiveRecord::Base) || ancestors.length
        @_defined_class_methods         ||= ancestors.first(index).map { |m|
          m.instance_methods(false) | m.private_instance_methods(false)
        }.flatten.map {|m| m.to_s }.to_set

        @@_defined_activerecord_methods ||= defined_activerecord_methods
        raise DangerousAttributeError, "#{method_name} is defined by ActiveRecord" if @@_defined_activerecord_methods.include?(method_name)
        @_defined_class_methods.include?(method_name) || generated_attribute_methods.method_defined?(method_name)
      end

      def defined_activerecord_methods
        active_record = ActiveRecord::Base
        super_klass   = ActiveRecord::Base.superclass
        methods = (active_record.instance_methods - super_klass.instance_methods) +
                  (active_record.private_instance_methods - super_klass.private_instance_methods)
        methods.map {|m| m.to_s }.to_set
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
