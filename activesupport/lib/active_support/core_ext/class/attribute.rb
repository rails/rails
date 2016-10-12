require "active_support/core_ext/kernel/singleton_class"
require "active_support/core_ext/module/remove_method"
require "active_support/core_ext/array/extract_options"

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
  # Methods generated by <tt>class_attribute</tt> are fully thread-safe, but
  # calling the method itself isn't. This means you need to keep calls to
  # <tt>class_attribute</tt> single threaded (e.g. in the boot phase), but the
  # attribute accessors generated can then be safely used in a multi-threaded
  # context.
  def class_attribute(*attrs)
    options = attrs.extract_options!
    instance_reader = options.fetch(:instance_accessor, true) && options.fetch(:instance_reader, true)
    instance_writer = options.fetch(:instance_accessor, true) && options.fetch(:instance_writer, true)
    instance_predicate = options.fetch(:instance_predicate, true)

    attrs.each do |name|
      reader_name = name
      writer_name = "#{name}="
      predicate_name = "#{name}?"
      instance_variable_name = "@#{name}"

      class_eval <<-RUBY, __FILE__, __LINE__ + 1
        def self.#{reader_name}
          if defined?(#{instance_variable_name})
            return #{instance_variable_name}
          elsif superclass.respond_to?(:#{reader_name})
            return superclass.#{reader_name}
          else
            return nil
          end
        end
      RUBY

      class_eval <<-RUBY, __FILE__, __LINE__ + 1
        def self.#{writer_name}(value)
          #{instance_variable_name} = value
        end
      RUBY

      # Define predicate method
      class_eval <<-RUBY, __FILE__, __LINE__ + 1
        def self.#{predicate_name}
          !!#{reader_name}
        end
      RUBY

      # Define instance reader method
      if instance_reader
        class_eval <<-RUBY, __FILE__, __LINE__ + 1
          def #{reader_name}
            return #{instance_variable_name} if defined?(#{instance_variable_name})

            # Here we can't just call singleton_class every time, as this would
            # automatically create a singleton class unless it already exists.
            # Therefore, we have to search manually whether there is a singleton
            # class for our object.
            has_singleton_class = ObjectSpace.each_object(Class).any? do |klass|
              klass < self.class && klass.singleton_class? && self.is_a?(klass)
            end

            if has_singleton_class
              return singleton_class.#{reader_name}
            else
              return self.class.#{reader_name}
            end
          end
        RUBY
      end

      # Define instance writer method
      if instance_writer
        class_eval <<-RUBY, __FILE__, __LINE__ + 1
          def #{writer_name}(value)
            #{instance_variable_name} = value
          end
        RUBY
      end

      # Define predicate method
      if instance_reader && instance_predicate
        class_eval <<-RUBY, __FILE__, __LINE__ + 1
          def #{predicate_name}
            !!#{reader_name}
          end
        RUBY
      end
    end
  end
end
