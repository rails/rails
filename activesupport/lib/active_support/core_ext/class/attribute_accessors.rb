require 'active_support/core_ext/array/extract_options'

# Extends the class object with class and instance accessors for class attributes,
# just like the native attr* accessors for instance attributes.
class Class
  # Defines a class attribute if it's not defined and creates a reader method that
  # returns the attribute value.
  #
  #   class Person
  #     cattr_reader :hair_colors
  #   end
  #
  #   Person.class_variable_set("@@hair_colors", [:brown, :black])
  #   Person.hair_colors     # => [:brown, :black]
  #   Person.new.hair_colors # => [:brown, :black]
  #
  # The attribute name must be a valid method name in Ruby.
  #
  #   class Person
  #     cattr_reader :"1_Badname "
  #   end
  #   # => NameError: invalid attribute name
  #
  # If you want to opt out the instance reader method, you can pass <tt>instance_reader: false</tt>
  # or <tt>instance_accessor: false</tt>.
  #
  #   class Person
  #     cattr_reader :hair_colors, instance_reader: false
  #   end
  #
  #   Person.new.hair_colors # => NoMethodError
  def cattr_reader(*syms)
    options = syms.extract_options!
    syms.each do |sym|
      raise NameError.new("invalid class attribute name: #{sym}") unless sym =~ /^[_A-Za-z]\w*$/
      class_eval(<<-EOS, __FILE__, __LINE__ + 1)
        unless defined? @@#{sym}
          @@#{sym} = nil
        end

        def self.#{sym}
          @@#{sym}
        end
      EOS

      unless options[:instance_reader] == false || options[:instance_accessor] == false
        class_eval(<<-EOS, __FILE__, __LINE__ + 1)
          def #{sym}
            @@#{sym}
          end
        EOS
      end
    end
  end

  # Defines a class attribute if it's not defined and creates a writer method to allow
  # assignment to the attribute.
  #
  #   class Person
  #     cattr_writer :hair_colors
  #   end
  #
  #   Person.hair_colors = [:brown, :black]
  #   Person.class_variable_get("@@hair_colors") # => [:brown, :black]
  #   Person.new.hair_colors = [:blonde, :red]
  #   Person.class_variable_get("@@hair_colors") # => [:blonde, :red]
  #
  # The attribute name must be a valid method name in Ruby.
  #
  #   class Person
  #     cattr_writer :"1_Badname "
  #   end
  #   # => NameError: invalid attribute name
  #
  # If you want to opt out the instance writer method, pass <tt>instance_writer: false</tt>
  # or <tt>instance_accessor: false</tt>.
  #
  #   class Person
  #     cattr_writer :hair_colors, instance_writer: false
  #   end
  #
  #   Person.new.hair_colors = [:blonde, :red] # => NoMethodError
  #
  # Also, you can pass a block to set up the attribute with a default value.
  #
  #   class Person
  #     cattr_writer :hair_colors do
  #       [:brown, :black, :blonde, :red]
  #     end
  #   end
  #
  #   Person.class_variable_get("@@hair_colors") # => [:brown, :black, :blonde, :red]
  def cattr_writer(*syms)
    options = syms.extract_options!
    syms.each do |sym|
      raise NameError.new("invalid class attribute name: #{sym}") unless sym =~ /^[_A-Za-z]\w*$/
      class_eval(<<-EOS, __FILE__, __LINE__ + 1)
        unless defined? @@#{sym}
          @@#{sym} = nil
        end

        def self.#{sym}=(obj)
          @@#{sym} = obj
        end
      EOS

      unless options[:instance_writer] == false || options[:instance_accessor] == false
        class_eval(<<-EOS, __FILE__, __LINE__ + 1)
          def #{sym}=(obj)
            @@#{sym} = obj
          end
        EOS
      end
      send("#{sym}=", yield) if block_given?
    end
  end

  # Defines both class and instance accessors for class attributes.
  #
  #   class Person
  #     cattr_accessor :hair_colors
  #   end
  #
  #   Person.hair_colors = [:brown, :black, :blonde, :red]
  #   Person.hair_colors     # => [:brown, :black, :blonde, :red]
  #   Person.new.hair_colors # => [:brown, :black, :blonde, :red]
  #
  # If a subclass changes the value then that would also change the value for
  # parent class. Similarly if parent class changes the value then that would
  # change the value of subclasses too.
  #
  #   class Male < Person
  #   end
  #
  #   Male.hair_colors << :blue
  #   Person.hair_colors # => [:brown, :black, :blonde, :red, :blue]
  #
  # To opt out of the instance writer method, pass <tt>instance_writer: false</tt>.
  # To opt out of the instance reader method, pass <tt>instance_reader: false</tt>.
  #
  #   class Person
  #     cattr_accessor :hair_colors, instance_writer: false, instance_reader: false
  #   end
  #
  #   Person.new.hair_colors = [:brown]  # => NoMethodError
  #   Person.new.hair_colors             # => NoMethodError
  #
  # Or pass <tt>instance_accessor: false</tt>, to opt out both instance methods.
  #
  #   class Person
  #     cattr_accessor :hair_colors, instance_accessor: false
  #   end
  #
  #   Person.new.hair_colors = [:brown]  # => NoMethodError
  #   Person.new.hair_colors             # => NoMethodError
  #
  # Also you can pass a block to set up the attribute with a default value.
  #
  #   class Person
  #     cattr_accessor :hair_colors do
  #       [:brown, :black, :blonde, :red]
  #     end
  #   end
  #
  #   Person.class_variable_get("@@hair_colors") #=> [:brown, :black, :blonde, :red]
  def cattr_accessor(*syms, &blk)
    cattr_reader(*syms)
    cattr_writer(*syms, &blk)
  end
end
