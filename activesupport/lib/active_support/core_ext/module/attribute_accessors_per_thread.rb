require 'active_support/core_ext/array/extract_options'

# Extends the module object with class/module and instance accessors for
# class/module attributes, just like the native attr* accessors for instance
# attributes, but does so on a per-thread basis.
# 
# So the values are scoped within the Thread.current space under the class name
# of the module.
class Module
  # Defines a per-thread class attribute and creates class and instance reader methods.
  # The underlying per-thread class variable is set to +nil+, if it is not previously defined.
  #
  #   module Current
  #     thread_mattr_reader :user
  #   end
  #
  #   Current.user # => nil
  #   Thread.current[:attr_Current_user] = "DHH"
  #   Current.user # => "DHH"
  #
  # The attribute name must be a valid method name in Ruby.
  #
  #   module Foo
  #     thread_mattr_reader :"1_Badname"
  #   end
  #   # => NameError: invalid attribute name: 1_Badname
  #
  # If you want to opt out the creation on the instance reader method, pass
  # <tt>instance_reader: false</tt> or <tt>instance_accessor: false</tt>.
  #
  #   class Current
  #     thread_mattr_reader :user, instance_reader: false
  #   end
  #
  #   Current.new.user # => NoMethodError
  def thread_mattr_reader(*syms)
    options = syms.extract_options!

    syms.each do |sym|
      raise NameError.new("invalid attribute name: #{sym}") unless sym =~ /^[_A-Za-z]\w*$/
      class_eval(<<-EOS, __FILE__, __LINE__ + 1)
        def self.#{sym}
          Thread.current[:"attr_#{name}_#{sym}"]
        end
      EOS

      unless options[:instance_reader] == false || options[:instance_accessor] == false
        class_eval(<<-EOS, __FILE__, __LINE__ + 1)
          def #{sym}
            Thread.current[:"attr_#{name}_#{sym}"]
          end
        EOS
      end
    end
  end
  alias :thread_cattr_reader :thread_mattr_reader

  # Defines a per-thread class attribute and creates a class and instance writer methods to
  # allow assignment to the attribute.
  #
  #   module Current
  #     thread_mattr_writer :user
  #   end
  #
  #   Current.user = "DHH"
  #   Thread.current[:attr_Current_user] # => "DHH"
  #
  # If you want to opt out the instance writer method, pass
  # <tt>instance_writer: false</tt> or <tt>instance_accessor: false</tt>.
  #
  #   class Current
  #     thread_mattr_writer :user, instance_writer: false
  #   end
  #
  #   Current.new.user = "DHH" # => NoMethodError
  def thread_mattr_writer(*syms)
    options = syms.extract_options!
    syms.each do |sym|
      raise NameError.new("invalid attribute name: #{sym}") unless sym =~ /^[_A-Za-z]\w*$/
      class_eval(<<-EOS, __FILE__, __LINE__ + 1)
        def self.#{sym}=(obj)
          Thread.current[:"attr_#{name}_#{sym}"] = obj
        end
      EOS

      unless options[:instance_writer] == false || options[:instance_accessor] == false
        class_eval(<<-EOS, __FILE__, __LINE__ + 1)
          def #{sym}=(obj)
            Thread.current[:"attr_#{name}_#{sym}"] = obj
          end
        EOS
      end
    end
  end
  alias :thread_cattr_writer :thread_mattr_writer

  # Defines both class and instance accessors for class attributes.
  #
  #   class Account
  #     thread_mattr_accessor :user
  #   end
  #
  #   Account.user = "DHH"
  #   Account.user     # => "DHH"
  #   Account.new.user # => "DHH"
  #
  # If a subclass changes the value, the parent class' value is not changed.
  # Similarly, if the parent class changes the value, the value of subclasses
  # is not changed.
  #
  #   class Customer < Account
  #   end
  #
  #   Customer.user = "Rafael"
  #   Customer.user # => "Rafael"
  #   Account.user  # => "DHH"
  #
  # To opt out of the instance writer method, pass <tt>instance_writer: false</tt>.
  # To opt out of the instance reader method, pass <tt>instance_reader: false</tt>.
  #
  #   class Current
  #     thread_mattr_accessor :user, instance_writer: false, instance_reader: false
  #   end
  #
  #   Current.new.user = "DHH"  # => NoMethodError
  #   Current.new.user          # => NoMethodError
  #
  # Or pass <tt>instance_accessor: false</tt>, to opt out both instance methods.
  #
  #   class Current
  #     mattr_accessor :user, instance_accessor: false
  #   end
  #
  #   Current.new.user = "DHH"  # => NoMethodError
  #   Current.new.user          # => NoMethodError
  def thread_mattr_accessor(*syms, &blk)
    thread_mattr_reader(*syms, &blk)
    thread_mattr_writer(*syms, &blk)
  end
  alias :thread_cattr_accessor :thread_mattr_accessor
end
