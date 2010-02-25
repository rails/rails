require 'active_support/core_ext/object/singleton_class'
require 'active_support/core_ext/module/delegation'

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
  def class_attribute(*attrs)
    s = singleton_class
    attrs.each do |attr|
      s.send(:define_method, attr) { }
      s.send(:define_method, "#{attr}?") { !!send(attr) }
      s.send(:define_method, "#{attr}=") do |value|
        singleton_class.send(:define_method, attr) { value }
      end
    end
  end
end
