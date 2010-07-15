require 'active_support/core_ext/kernel/singleton_class'
require 'active_support/core_ext/module/remove_method'

class Class
  # Declare a class-level attribute whose value is inheritable and
  # overwritable by subclasses:
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
  # This matches normal Ruby method inheritance: think of writing an attribute
  # on a subclass as overriding the reader method.
  #
  # For convenience, a query method is defined as well:
  #
  #   Subclass.setting?           # => false
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
  # To opt out of the instance writer method, pass :instance_writer => false.
  #
  #   object.setting = false  # => NoMethodError
  def class_attribute(*attrs)
    instance_writer = !attrs.last.is_a?(Hash) || attrs.pop[:instance_writer]

    attrs.each do |name|
      class_eval <<-RUBY, __FILE__, __LINE__ + 1
        def self.#{name}() nil end
        def self.#{name}?() !!#{name} end

        def self.#{name}=(val)
          singleton_class.class_eval do
            remove_possible_method(:#{name})
            define_method(:#{name}) { val }
          end
        end

        def #{name}
          defined?(@#{name}) ? @#{name} : singleton_class.#{name}
        end

        def #{name}?
          !!#{name}
        end
      RUBY

      attr_writer name if instance_writer
    end
  end
end
