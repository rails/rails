# This class is inherited by the has_many and has_many_and_belongs_to_many association classes

require 'active_record/associations'

module ActiveRecord::Associations::Builder
  class CollectionAssociation < Association #:nodoc:

    CALLBACKS = [:before_add, :after_add, :before_remove, :after_remove]

    def valid_options
      super + [:table_name, :before_add,
               :after_add, :before_remove, :after_remove, :extend]
    end

    attr_reader :block_extension

    def initialize(model, name, scope, options)
      super
      @mod = nil
      if block_given?
        @mod = Module.new(&Proc.new)
        @scope = wrap_scope @scope, @mod
      end
    end

    def self.define_callbacks(model, reflection)
      super
      name    = reflection.name
      options = reflection.options
      CALLBACKS.each { |callback_name|
        define_callback(model, callback_name, name, options)
      }
    end

    def define_extensions(model)
      if @mod
        extension_module_name = "#{model.name.demodulize}#{name.to_s.camelize}AssociationExtension"
        model.parent.const_set(extension_module_name, @mod)
      end
    end

    def self.define_callback(model, callback_name, name, options)
      full_callback_name = "#{callback_name}_for_#{name}"

      # TODO : why do i need method_defined? I think its because of the inheritance chain
      model.class_attribute full_callback_name unless model.method_defined?(full_callback_name)
      callbacks = Array(options[callback_name.to_sym]).map do |callback|
        case callback
        when Symbol
          ->(method, owner, record) { owner.send(callback, record) }
        when Proc
          ->(method, owner, record) { callback.call(owner, record) }
        else
          ->(method, owner, record) { callback.send(method, owner, record) }
        end
      end
      model.send "#{full_callback_name}=", callbacks
    end

    # Defines the setter and getter methods for the collection_singular_ids.
    def self.define_readers(mixin, name)
      super

      mixin.class_eval <<-CODE, __FILE__, __LINE__ + 1
        def #{name.to_s.singularize}_ids
          association(:#{name}).ids_reader
        end
      CODE
    end

    def self.define_writers(mixin, name)
      super

      mixin.class_eval <<-CODE, __FILE__, __LINE__ + 1
        def #{name.to_s.singularize}_ids=(ids)
          association(:#{name}).ids_writer(ids)
        end
      CODE
    end

    private

    def wrap_scope(scope, mod)
      if scope
        if scope.arity > 0
          proc { |owner| instance_exec(owner, &scope).extending(mod) }
        else
          proc { instance_exec(&scope).extending(mod) }
        end
      else
        proc { extending(mod) }
      end
    end
  end
end
