require 'active_support/core_ext/enumerable'

module ActiveRecord
  module AttributeMethods #:nodoc:
    extend ActiveSupport::Concern
    include ActiveModel::AttributeMethods

    module ClassMethods
      # Generates all the attribute related methods for columns in the database
      # accessors, mutators and query methods.
      def define_attribute_methods
        super(columns_hash.keys)
      end

      # Checks whether the method is defined in the model or any of its subclasses
      # that also derive from Active Record. Raises DangerousAttributeError if the
      # method is defined by Active Record though.
      def instance_method_already_implemented?(method_name)
        method_name = method_name.to_s
        @_defined_class_methods         ||= ancestors.first(ancestors.index(ActiveRecord::Base)).sum([]) { |m| m.public_instance_methods(false) | m.private_instance_methods(false) | m.protected_instance_methods(false) }.map {|m| m.to_s }.to_set
        @@_defined_activerecord_methods ||= (ActiveRecord::Base.public_instance_methods(false) | ActiveRecord::Base.private_instance_methods(false) | ActiveRecord::Base.protected_instance_methods(false)).map{|m| m.to_s }.to_set
        raise DangerousAttributeError, "#{method_name} is defined by ActiveRecord" if @@_defined_activerecord_methods.include?(method_name)
        @_defined_class_methods.include?(method_name)
      end
    end

    def method_missing(method_id, *args, &block)
      # If we haven't generated any methods yet, generate them, then
      # see if we've created the method we're looking for.
      if !self.class.attribute_methods_generated?
        self.class.define_attribute_methods
        method_name = method_id.to_s
        guard_private_attribute_method!(method_name, args)
        if self.class.generated_attribute_methods.instance_methods.include?(method_name)
          return self.send(method_id, *args, &block)
        end
      end
      super
    end

    def respond_to?(*args)
      self.class.define_attribute_methods
      super
    end

    protected
      def attribute_method?(attr_name)
        attr_name == 'id' || attributes.include?(attr_name)
      end
  end
end
