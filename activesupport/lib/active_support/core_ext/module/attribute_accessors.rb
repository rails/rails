require "active_support/core_ext/array/extract_options"
require "active_support/core_ext/regexp"

# Extends the module object with class/module and instance accessors for
# class/module attributes, just like the native attr* accessors for instance
# attributes.
class Module
  # Defines a class attribute and creates a class and instance reader methods.
  # The underlying class variable is set to +nil+, if it is not previously
  # defined.
  # Note: Both methods will be public even if this method is called from
  # inside a private or protected block.
  #
  #   module HairColors
  #     mattr_reader :hair_colors
  #   end
  #
  #   HairColors.hair_colors # => nil
  #   HairColors.class_variable_set("@@hair_colors", [:brown, :black])
  #   HairColors.hair_colors # => [:brown, :black]
  #
  # The attribute name must be a valid method name in Ruby.
  #
  #   module Foo
  #     mattr_reader :"1_Badname"
  #   end
  #   # => NameError: invalid attribute name: 1_Badname
  #
  # If you want to opt out the creation on the instance reader method, pass
  # <tt>instance_reader: false</tt> or <tt>instance_accessor: false</tt>.
  #
  #   module HairColors
  #     mattr_reader :hair_colors, instance_reader: false
  #   end
  #
  #   class Person
  #     include HairColors
  #   end
  #
  #   Person.new.hair_colors # => NoMethodError
  #
  #
  # Also, you can pass a block to set up the attribute with a default value.
  #
  #   module HairColors
  #     mattr_reader :hair_colors do
  #       [:brown, :black, :blonde, :red]
  #     end
  #   end
  #
  #   class Person
  #     include HairColors
  #   end
  #
  #   Person.new.hair_colors # => [:brown, :black, :blonde, :red]
  def mattr_reader(*syms)
    options = syms.extract_options!
    syms.each do |sym|
      raise NameError.new("invalid attribute name: #{sym}") unless /\A[_A-Za-z]\w*\z/.match?(sym)
      class_eval(<<-EOS, __FILE__, __LINE__ + 1)
        @@#{sym} = nil unless defined? @@#{sym}

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
      class_variable_set("@@#{sym}", yield) if block_given?
    end
  end
  alias :cattr_reader :mattr_reader

  # Defines a class attribute and creates a class and instance writer methods to
  # allow assignment to the attribute.
  # Note: Both methods will be public even if this method is called from
  # inside a private or protected block.
  #
  #   module HairColors
  #     mattr_writer :hair_colors
  #   end
  #
  #   class Person
  #     include HairColors
  #   end
  #
  #   HairColors.hair_colors = [:brown, :black]
  #   Person.class_variable_get("@@hair_colors") # => [:brown, :black]
  #   Person.new.hair_colors = [:blonde, :red]
  #   HairColors.class_variable_get("@@hair_colors") # => [:blonde, :red]
  #
  # If you want to opt out the instance writer method, pass
  # <tt>instance_writer: false</tt> or <tt>instance_accessor: false</tt>.
  #
  #   module HairColors
  #     mattr_writer :hair_colors, instance_writer: false
  #   end
  #
  #   class Person
  #     include HairColors
  #   end
  #
  #   Person.new.hair_colors = [:blonde, :red] # => NoMethodError
  #
  # Also, you can pass a block to set up the attribute with a default value.
  #
  #   module HairColors
  #     mattr_writer :hair_colors do
  #       [:brown, :black, :blonde, :red]
  #     end
  #   end
  #
  #   class Person
  #     include HairColors
  #   end
  #
  #   Person.class_variable_get("@@hair_colors") # => [:brown, :black, :blonde, :red]
  def mattr_writer(*syms)
    options = syms.extract_options!
    syms.each do |sym|
      raise NameError.new("invalid attribute name: #{sym}") unless /\A[_A-Za-z]\w*\z/.match?(sym)
      class_eval(<<-EOS, __FILE__, __LINE__ + 1)
        @@#{sym} = nil unless defined? @@#{sym}

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
  alias :cattr_writer :mattr_writer

  # Defines both class and instance accessors for class attributes.
  # Note: All methods will be public even if this method is called from
  # inside a private or protected block.
  #
  #   module HairColors
  #     mattr_accessor :hair_colors
  #   end
  #
  #   class Person
  #     include HairColors
  #   end
  #
  #   HairColors.hair_colors = [:brown, :black, :blonde, :red]
  #   HairColors.hair_colors # => [:brown, :black, :blonde, :red]
  #   Person.new.hair_colors # => [:brown, :black, :blonde, :red]
  #
  # If a subclass changes the value then that would also change the value for
  # parent class. Similarly if parent class changes the value then that would
  # change the value of subclasses too.
  #
  #   class Male < Person
  #   end
  #
  #   Male.new.hair_colors << :blue
  #   Person.new.hair_colors # => [:brown, :black, :blonde, :red, :blue]
  #
  # To opt out of the instance writer method, pass <tt>instance_writer: false</tt>.
  # To opt out of the instance reader method, pass <tt>instance_reader: false</tt>.
  #
  #   module HairColors
  #     mattr_accessor :hair_colors, instance_writer: false, instance_reader: false
  #   end
  #
  #   class Person
  #     include HairColors
  #   end
  #
  #   Person.new.hair_colors = [:brown]  # => NoMethodError
  #   Person.new.hair_colors             # => NoMethodError
  #
  # Or pass <tt>instance_accessor: false</tt>, to opt out both instance methods.
  #
  #   module HairColors
  #     mattr_accessor :hair_colors, instance_accessor: false
  #   end
  #
  #   class Person
  #     include HairColors
  #   end
  #
  #   Person.new.hair_colors = [:brown]  # => NoMethodError
  #   Person.new.hair_colors             # => NoMethodError
  #
  # Also you can pass a block to set up the attribute with a default value.
  #
  #   module HairColors
  #     mattr_accessor :hair_colors do
  #       [:brown, :black, :blonde, :red]
  #     end
  #   end
  #
  #   class Person
  #     include HairColors
  #   end
  #
  #   Person.class_variable_get("@@hair_colors") # => [:brown, :black, :blonde, :red]
  def mattr_accessor(*syms, &blk)
    mattr_reader(*syms, &blk)
    mattr_writer(*syms)
  end
  alias :cattr_accessor :mattr_accessor
end
