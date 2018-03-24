# frozen_string_literal: true

require "active_support/core_ext/kernel/singleton_class"
require "active_support/core_ext/module/redefine_method"
require "active_support/core_ext/array/extract_options"

class Class
  # Declare a class-level attribute whose value is inheritable by subclasses.
  # Subclasses can change their own value and it will not impact parent class.
  #
  # ==== Options
  #
  # * <tt>:instance_reader</tt> - Sets the instance reader method (defaults to true).
  # * <tt>:instance_writer</tt> - Sets the instance writer method (defaults to true).
  # * <tt>:instance_accessor</tt> - Sets both instance methods (defaults to true).
  # * <tt>:instance_predicate</tt> - Sets a predicate method (defaults to true).
  # * <tt>:default</tt> - Sets a default value for the attribute (defaults to nil).
  #
  # ==== Examples
  #
  #   class Base
  #     class_attribute :setting
  #   end
  #
  #   class Subclass < Base
  #   end
  #
  #   Base.setting = true
  #   Subclass.setting            # => true
  #   Subclass.setting = false
  #   Subclass.setting            # => false
  #   Base.setting                # => true
  #
  # In the above case as long as Subclass does not assign a value to setting
  # by performing <tt>Subclass.setting = _something_</tt>, <tt>Subclass.setting</tt>
  # would read value assigned to parent class. Once Subclass assigns a value then
  # the value assigned by Subclass would be returned.
  #
  # This matches normal Ruby method inheritance: think of writing an attribute
  # on a subclass as overriding the reader method. However, you need to be aware
  # when using +class_attribute+ with mutable structures as +Array+ or +Hash+.
  # In such cases, you don't want to do changes in place. Instead use setters:
  #
  #   Base.setting = []
  #   Base.setting                # => []
  #   Subclass.setting            # => []
  #
  #   # Appending in child changes both parent and child because it is the same object:
  #   Subclass.setting << :foo
  #   Base.setting               # => [:foo]
  #   Subclass.setting           # => [:foo]
  #
  #   # Use setters to not propagate changes:
  #   Base.setting = []
  #   Subclass.setting += [:foo]
  #   Base.setting               # => []
  #   Subclass.setting           # => [:foo]
  #
  # For convenience, an instance predicate method is defined as well.
  # To skip it, pass <tt>instance_predicate: false</tt>.
  #
  #   Subclass.setting?       # => false
  #
  # Instances may overwrite the class value in the same way:
  #
  #   Base.setting = true
  #   object = Base.new
  #   object.setting          # => true
  #   object.setting = false
  #   object.setting          # => false
  #   Base.setting            # => true
  #
  # To opt out of the instance reader method, pass <tt>instance_reader: false</tt>.
  #
  #   object.setting          # => NoMethodError
  #   object.setting?         # => NoMethodError
  #
  # To opt out of the instance writer method, pass <tt>instance_writer: false</tt>.
  #
  #   object.setting = false  # => NoMethodError
  #
  # To opt out of both instance methods, pass <tt>instance_accessor: false</tt>.
  #
  # To set a default value for the attribute, pass <tt>default:</tt>, like so:
  #
  #   class_attribute :settings, default: {}
  def class_attribute(*attrs)
    options = attrs.extract_options!
    instance_reader    = options.fetch(:instance_accessor, true) && options.fetch(:instance_reader, true)
    instance_writer    = options.fetch(:instance_accessor, true) && options.fetch(:instance_writer, true)
    instance_predicate = options.fetch(:instance_predicate, true)
    default_value      = options.dig(:default)

    attrs.each do |name|
      singleton_class.silence_redefinition_of_method(name)
      define_singleton_method(name) { nil }

      singleton_class.silence_redefinition_of_method("#{name}?")
      define_singleton_method("#{name}?") { !!public_send(name) } if instance_predicate

      ivar = "@#{name}".to_sym

      singleton_class.silence_redefinition_of_method("#{name}=")
      define_singleton_method("#{name}=") do |val|
        singleton_class.class_eval do
          redefine_method(name) { val }
        end

        if singleton_class?
          class_eval do
            redefine_method(name) do
              if instance_variable_defined? ivar
                instance_variable_get ivar
              else
                singleton_class.send name
              end
            end
          end
        end
        val
      end

      if instance_reader
        redefine_method(name) do
          if instance_variable_defined?(ivar)
            instance_variable_get ivar
          else
            self.class.public_send name
          end
        end

        redefine_method("#{name}?") { !!public_send(name) } if instance_predicate
      end

      if instance_writer
        redefine_method("#{name}=") do |val|
          instance_variable_set ivar, val
        end
      end

      unless default_value.nil?
        self.send("#{name}=", default_value)
      end
    end
  end
end
