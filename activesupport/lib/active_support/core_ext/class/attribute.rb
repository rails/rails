# :markup: markdown
# frozen_string_literal: true

require "active_support/core_ext/module/redefine_method"
require "active_support/class_attribute"

class Class
  # Declare a class-level attribute whose value is inheritable by subclasses.
  # Subclasses can change their own value and it will not impact parent class.
  #
  # #### Options
  #
  # * `:instance_reader` - Sets the instance reader method (defaults to true).
  # * `:instance_writer` - Sets the instance writer method (defaults to true).
  # * `:instance_accessor` - Sets both instance methods (defaults to true).
  # * `:instance_predicate` - Sets a predicate method (defaults to true).
  # * `:default` - Sets a default value for the attribute (defaults to nil).
  #
  # #### Examples
  #
  # ```ruby
  # class Base
  #   class_attribute :setting
  # end
  #
  # class Subclass < Base
  # end
  #
  # Base.setting = true
  # Subclass.setting            # => true
  # Subclass.setting = false
  # Subclass.setting            # => false
  # Base.setting                # => true
  # ```
  #
  # In the above case as long as Subclass does not assign a value to setting
  # by performing `Subclass.setting = _something_`, `Subclass.setting`
  # would read value assigned to parent class. Once Subclass assigns a value then
  # the value assigned by Subclass would be returned.
  #
  # This matches normal Ruby method inheritance: think of writing an attribute
  # on a subclass as overriding the reader method. However, you need to be aware
  # when using `class_attribute` with mutable structures as `Array` or `Hash`.
  # In such cases, you don't want to do changes in place. Instead use setters:
  #
  # ```ruby
  # Base.setting = []
  # Base.setting                # => []
  # Subclass.setting            # => []
  #
  # # Appending in child changes both parent and child because it is the same object:
  # Subclass.setting << :foo
  # Base.setting               # => [:foo]
  # Subclass.setting           # => [:foo]
  #
  # # Use setters to not propagate changes:
  # Base.setting = []
  # Subclass.setting += [:foo]
  # Base.setting               # => []
  # Subclass.setting           # => [:foo]
  # ```
  #
  # For convenience, an instance predicate method is defined as well.
  # To skip it, pass `instance_predicate: false`.
  #
  # ```ruby
  # Subclass.setting?       # => false
  # ```
  #
  # Instances may overwrite the class value in the same way:
  #
  # ```ruby
  # Base.setting = true
  # object = Base.new
  # object.setting          # => true
  # object.setting = false
  # object.setting          # => false
  # Base.setting            # => true
  # ```
  #
  # To opt out of the instance reader method, pass `instance_reader: false`.
  #
  # ```ruby
  # object.setting          # => NoMethodError
  # object.setting?         # => NoMethodError
  # ```
  #
  # To opt out of the instance writer method, pass `instance_writer: false`.
  #
  # ```ruby
  # object.setting = false  # => NoMethodError
  # ```
  #
  # To opt out of both instance methods, pass `instance_accessor: false`.
  #
  # To set a default value for the attribute, pass `default:`, like so:
  #
  # ```ruby
  # class_attribute :settings, default: {}
  # ```
  def class_attribute(*attrs, instance_accessor: true,
    instance_reader: instance_accessor, instance_writer: instance_accessor, instance_predicate: true, default: nil
  )
    class_methods, methods = [], []
    attrs.each do |name|
      unless name.is_a?(Symbol) || name.is_a?(String)
        raise TypeError, "#{name.inspect} is not a symbol nor a string"
      end

      name = name.to_sym
      reader_method = :"__class_attr_#{name}"
      owner_method = :"__class_attr_#{name}_owner"
      ::ActiveSupport::ClassAttribute.redefine(self, name, owner_method, reader_method, default, instance_reader)

      singleton_class.attr_reader(reader_method)

      class_methods << "def #{name}; #{owner_method}.#{reader_method}; end"
      class_methods << <<~RUBY
        def #{name}=(value)
          if #{owner_method}.equal?(self)
            @#{reader_method} = value
          else
            ::ActiveSupport::ClassAttribute.redefine(self, :#{name}, :#{owner_method}, :#{reader_method}, value, #{!!instance_reader})
          end
        end
      RUBY

      if singleton_class?
        methods << <<~RUBY if instance_reader
          silence_redefinition_of_method(:#{name})
          def #{name}
            self.singleton_class.#{name}
          end
        RUBY
      else
        methods << <<~RUBY if instance_reader
          silence_redefinition_of_method def #{name}
            if defined?(@#{name})
              @#{name}
            else
              self.class.#{name}
            end
          end
        RUBY
      end

      methods << <<~RUBY if instance_writer
        silence_redefinition_of_method(:#{name}=)
        attr_writer :#{name}
      RUBY

      if instance_predicate
        class_methods << "silence_redefinition_of_method def #{name}?; !!self.#{name}; end"
        if instance_reader
          methods << "silence_redefinition_of_method def #{name}?; !!self.#{name}; end"
        end
      end
    end

    location = caller_locations(1, 1).first
    class_eval(["class << self", *class_methods, "end", *methods].join(";").tr("\n", ";"), location.path, location.lineno)
  end
end
