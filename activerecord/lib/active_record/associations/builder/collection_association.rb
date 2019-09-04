# frozen_string_literal: true

require "active_record/associations"

module ActiveRecord::Associations::Builder # :nodoc:
  class CollectionAssociation < Association #:nodoc:
    CALLBACKS = [:before_add, :after_add, :before_remove, :after_remove]

    def self.valid_options(options)
      super + [:table_name, :before_add,
               :after_add, :before_remove, :after_remove, :extend]
    end

    def self.define_callbacks(model, reflection)
      super
      name    = reflection.name
      options = reflection.options
      CALLBACKS.each { |callback_name|
        define_callback(model, callback_name, name, options)
      }
    end

    def self.define_extensions(model, name, &block)
      if block_given?
        extension_module_name = "#{model.name.demodulize}#{name.to_s.camelize}AssociationExtension"
        extension = Module.new(&block)
        model.parent.const_set(extension_module_name, extension)
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

    def self.wrap_scope(scope, mod)
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
