require 'active_support/core_ext/kernel/singleton_class'
require 'active_support/core_ext/module/remove_method'
require 'active_support/core_ext/array/extract_options'
require 'active_support/core_ext/hash/keys'

class Class
  # Declare a class-level attribute whose value is inheritable by subclasses.
  # Subclasses can change their own value and it will not impact parent class.
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
  # by performing <tt>Subclass.setting = _something_ </tt>, <tt>Subclass.setting</tt>
  # would read value assigned to parent class. Once Subclass assigns a value then
  # the value assigned by Subclass would be returned.
  #
  # This matches normal Ruby method inheritance: think of writing an attribute
  # on a subclass as overriding the reader method. However, you need to be aware
  # when using +class_attribute+ with mutable structures as +Array+ or +Hash+.
  # In such cases, you don't want to do changes in places but use setters:
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
  # For convenience, a query method is defined as well:
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

  def class_attribute(*attrs)
    options = attrs.extract_options!
    attrs.each { |attr| define_class_attribute(attr, options) }
  end

  def define_class_attribute(attr, options={})
    options.assert_valid_keys :instance_accessor, :instance_writer, :instance_reader, :persist_when_inherited
    instance_reader   = options.fetch(:instance_accessor, true) && options.fetch(:instance_reader, true)
    instance_writer   = options.fetch(:instance_accessor, true) && options.fetch(:instance_writer, true)
    persist_when_inherited = options.fetch(:persist_when_inherited, true)

    define_singleton_method "#{attr}" do
      if instance_variable_defined?(:"@#{attr}")
        instance_variable_get(:"@#{attr}")
      elsif persist_when_inherited && superclass.respond_to?("#{attr}")
        superclass.send "#{attr}"
      else
        nil
      end
    end

    define_singleton_method "#{attr}?" do
      !!send(attr)
    end

    define_singleton_method "#{attr}=" do |value|
      instance_variable_set(:"@#{attr}", value)
    end

    if instance_reader
      define_method "#{attr}" do
        if instance_variable_defined?(:"@#{attr}")
          instance_variable_get(:"@#{attr}")
        else
          self.singleton_class.send attr
        end
      end

      define_method "#{attr}?" do
        !!send(attr)
      end
    end

    attr_writer attr if instance_writer

  end

end
