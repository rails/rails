# frozen_string_literal: true

require "mutex_m"

module ActiveRecord
  class AttributeMethodsBuilder < ActiveModel::AttributeMethodsBuilder # :nodoc
    include Mutex_m

    attr_accessor :model_class

    def initialize(*)
      super
      @attribute_methods_generated = false
    end

    def included(model_class)
      super
      @model_class = model_class
    end

    # Generates all the attribute related methods for columns in the database
    # accessors, mutators and query methods.
    def define_attribute_methods(*attr_names)
      return false if @attribute_methods_generated
      # Use a mutex; we don't want two threads simultaneously trying to define
      # attribute methods.
      synchronize do
        return false if @attribute_methods_generated
        super(*attr_names)
        @attribute_methods_generated = true
      end
    end

    def undefine_attribute_methods
      synchronize do
        super if defined?(@attribute_methods_defined) && @attribute_methods_defined
        @attribute_methods_generated = false
      end
    end

    def apply(klass)
      super unless klass == Base || klass.abstract_class?
    end

    private

      # We want to generate the methods via module_eval rather than
      # define_method, because define_method is slower on dispatch.
      # Evaluating many similar methods may use more memory as the instruction
      # sequences are duplicated and cached (in MRI).  define_method may
      # be slower on dispatch, but if you're careful about the closure
      # created, then define_method will consume much less memory.
      #
      # But sometimes the database might return columns with
      # characters that are not allowed in normal method names (like
      # 'my_column(omg)'. So to work around this we first define with
      # the __temp__ identifier, and then use alias method to rename
      # it to what we want.
      #
      # We are also defining a constant to hold the frozen string of
      # the attribute name. Using a constant means that we do not have
      # to allocate an object on each call to the attribute method.
      # Making it frozen means that it doesn't get duped when used to
      # key the @attributes in read_attribute.
      def define_method_attribute(name)
        safe_name = name.unpack("h*".freeze).first
        temp_method = "__temp__#{safe_name}"

        ActiveRecord::AttributeMethods::AttrNames.set_name_cache safe_name, name

        module_eval <<-STR, __FILE__, __LINE__ + 1
          def #{temp_method}
            name = ::ActiveRecord::AttributeMethods::AttrNames::ATTR_#{safe_name}
            sync_with_transaction_state if name == self.class.primary_key
            _read_attribute(name) { |n| missing_attribute(n, caller) }
          end
        STR

        alias_method name, temp_method
        undef_method temp_method
      end

      def define_method_attribute=(name)
        safe_name = name.unpack("h*".freeze).first
        ActiveRecord::AttributeMethods::AttrNames.set_name_cache safe_name, name

        module_eval <<-STR, __FILE__, __LINE__ + 1
          def __temp__#{safe_name}=(value)
            name = ::ActiveRecord::AttributeMethods::AttrNames::ATTR_#{safe_name}
            sync_with_transaction_state if name == self.class.primary_key
            _write_attribute(name, value)
          end
          alias_method #{(name + '=').inspect}, :__temp__#{safe_name}=
          undef_method :__temp__#{safe_name}=
        STR
      end

      def instance_method_already_implemented?(method_name)
        @model_class && @model_class.instance_method_already_implemented?(method_name)
      end
  end
end
