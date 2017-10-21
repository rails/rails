# frozen_string_literal: true

require "active_support/core_ext/array/extract_options"
require "active_support/core_ext/regexp"

# Extends the module object with class/module and instance accessors for
# class/module attributes, just like the native attr* accessors for instance
# attributes.
class Module
  # Defines a class attribute and creates a class and instance reader methods.
  # The underlying class variable is set to +nil+, if it is not previously
  # defined. All class and instance methods created will be public, even if
  # this method is called with a private or protected access modifier.
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
  # You can set a default value for the attribute.
  #
  #   module HairColors
  #     mattr_reader :hair_colors, default: [:brown, :black, :blonde, :red]
  #   end
  #
  #   class Person
  #     include HairColors
  #   end
  #
  #   Person.new.hair_colors # => [:brown, :black, :blonde, :red]
  def mattr_reader(*syms, instance_reader: true, instance_accessor: true, default: nil)
    syms.each do |sym|
      raise NameError.new("invalid attribute name: #{sym}") unless /\A[_A-Za-z]\w*\z/.match?(sym)
      class_eval(<<-EOS, __FILE__, __LINE__ + 1)
        @@#{sym} = nil unless defined? @@#{sym}

        def self.#{sym}
          @@#{sym}
        end
      EOS

      if instance_reader && instance_accessor
        class_eval(<<-EOS, __FILE__, __LINE__ + 1)
          def #{sym}
            @@#{sym}
          end
        EOS
      end

      sym_default_value = (block_given? && default.nil?) ? yield : default
      class_variable_set("@@#{sym}", sym_default_value) unless sym_default_value.nil?
    end
  end
  alias :cattr_reader :mattr_reader

  # Defines a class attribute and creates a class and instance writer methods to
  # allow assignment to the attribute. All class and instance methods created
  # will be public, even if this method is called with a private or protected
  # access modifier.
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
  # You can set a default value for the attribute.
  #
  #   module HairColors
  #     mattr_writer :hair_colors, default: [:brown, :black, :blonde, :red]
  #   end
  #
  #   class Person
  #     include HairColors
  #   end
  #
  #   Person.class_variable_get("@@hair_colors") # => [:brown, :black, :blonde, :red]
  def mattr_writer(*syms, instance_writer: true, instance_accessor: true, default: nil)
    syms.each do |sym|
      raise NameError.new("invalid attribute name: #{sym}") unless /\A[_A-Za-z]\w*\z/.match?(sym)
      class_eval(<<-EOS, __FILE__, __LINE__ + 1)
        @@#{sym} = nil unless defined? @@#{sym}

        def self.#{sym}=(obj)
          @@#{sym} = obj
        end
      EOS

      if instance_writer && instance_accessor
        class_eval(<<-EOS, __FILE__, __LINE__ + 1)
          def #{sym}=(obj)
            @@#{sym} = obj
          end
        EOS
      end

      sym_default_value = (block_given? && default.nil?) ? yield : default
      send("#{sym}=", sym_default_value) unless sym_default_value.nil?
    end
  end
  alias :cattr_writer :mattr_writer

  # Defines both class and instance accessors for class attributes.
  # All class and instance methods created will be public, even if
  # this method is called with a private or protected access modifier.
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
  # You can set a default value for the attribute.
  #
  #   module HairColors
  #     mattr_accessor :hair_colors, default: [:brown, :black, :blonde, :red]
  #   end
  #
  #   class Person
  #     include HairColors
  #   end
  #
  #   Person.class_variable_get("@@hair_colors") # => [:brown, :black, :blonde, :red]
  def mattr_accessor(*syms, instance_reader: true, instance_writer: true, instance_accessor: true, default: nil, &blk)
    mattr_reader(*syms, instance_reader: instance_reader, instance_accessor: instance_accessor, default: default, &blk)
    mattr_writer(*syms, instance_writer: instance_writer, instance_accessor: instance_accessor, default: default)
  end
  alias :cattr_accessor :mattr_accessor
end
