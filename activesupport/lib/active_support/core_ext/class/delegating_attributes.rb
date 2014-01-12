require 'active_support/core_ext/kernel/singleton_class'
require 'active_support/core_ext/module/remove_method'

class Class
  def superclass_delegating_accessor(name, options = {})
    # Create private _name and _name= methods that can still be used if the public
    # methods are overridden.
    _superclass_delegating_accessor("_#{name}", options)

    # Generate the public methods name, name=, and name?.
    # These methods dispatch to the private _name, and _name= methods, making them
    # overridable.
    singleton_class.send(:define_method, name) { send("_#{name}") }
    singleton_class.send(:define_method, "#{name}?") { !!send("_#{name}") }
    singleton_class.send(:define_method, "#{name}=") { |value| send("_#{name}=", value) }

    # If an instance_reader is needed, generate public instance methods name and name?.
    if options[:instance_reader] != false
      define_method(name) { send("_#{name}") }
      define_method("#{name}?") { !!send("#{name}") }
    end
  end

  private
    # Take the object being set and store it in a method. This gives us automatic
    # inheritance behavior, without having to store the object in an instance
    # variable and look up the superclass chain manually.
    def _stash_object_in_method(object, method, instance_reader = true)
      singleton_class.remove_possible_method(method)
      singleton_class.send(:define_method, method) { object }
      remove_possible_method(method)
      define_method(method) { object } if instance_reader
    end

    def _superclass_delegating_accessor(name, options = {})
      singleton_class.send(:define_method, "#{name}=") do |value|
        _stash_object_in_method(value, name, options[:instance_reader] != false)
      end
      send("#{name}=", nil)
    end
end
