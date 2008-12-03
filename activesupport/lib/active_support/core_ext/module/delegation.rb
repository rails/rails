class Module
  # Provides a delegate class method to easily expose contained objects' methods
  # as your own. Pass one or more methods (specified as symbols or strings)
  # and the name of the target object as the final <tt>:to</tt> option (also a symbol
  # or string).  At least one method and the <tt>:to</tt> option are required.
  #
  # Delegation is particularly useful with Active Record associations:
  #
  #   class Greeter < ActiveRecord::Base
  #     def hello()   "hello"   end
  #     def goodbye() "goodbye" end
  #   end
  #
  #   class Foo < ActiveRecord::Base
  #     belongs_to :greeter
  #     delegate :hello, :to => :greeter
  #   end
  #
  #   Foo.new.hello   # => "hello"
  #   Foo.new.goodbye # => NoMethodError: undefined method `goodbye' for #<Foo:0x1af30c>
  #
  # Multiple delegates to the same target are allowed:
  #
  #   class Foo < ActiveRecord::Base
  #     belongs_to :greeter
  #     delegate :hello, :goodbye, :to => :greeter
  #   end
  #
  #   Foo.new.goodbye # => "goodbye"
  #
  # Methods can be delegated to instance variables, class variables, or constants
  # by providing them as a symbols:
  #
  #   class Foo
  #     CONSTANT_ARRAY = [0,1,2,3]
  #     @@class_array  = [4,5,6,7]
  #     
  #     def initialize
  #       @instance_array = [8,9,10,11]
  #     end
  #     delegate :sum, :to => :CONSTANT_ARRAY
  #     delegate :min, :to => :@@class_array
  #     delegate :max, :to => :@instance_array
  #   end
  #
  #   Foo.new.sum # => 6
  #   Foo.new.min # => 4
  #   Foo.new.max # => 11
  #
  # Delegates can optionally be prefixed using the <tt>:prefix</tt> option. If the value
  # is <tt>true</tt>, the delegate methods are prefixed with the name of the object being
  # delegated to.
  #
  #   Person = Struct.new(:name, :address)
  #
  #   class Invoice < Struct.new(:client)
  #     delegate :name, :address, :to => :client, :prefix => true
  #   end
  #
  #   john_doe = Person.new("John Doe", "Vimmersvej 13")
  #   invoice = Invoice.new(john_doe)
  #   invoice.client_name    # => "John Doe"
  #   invoice.client_address # => "Vimmersvej 13"
  #
  # It is also possible to supply a custom prefix.
  #
  #   class Invoice < Struct.new(:client)
  #     delegate :name, :address, :to => :client, :prefix => :customer
  #   end
  #
  #   invoice = Invoice.new(john_doe)
  #   invoice.customer_name    # => "John Doe"
  #   invoice.customer_address # => "Vimmersvej 13"
  #
  def delegate(*methods)
    options = methods.pop
    unless options.is_a?(Hash) && to = options[:to]
      raise ArgumentError, "Delegation needs a target. Supply an options hash with a :to key as the last argument (e.g. delegate :hello, :to => :greeter)."
    end

    if options[:prefix] == true && options[:to].to_s =~ /^[^a-z_]/
      raise ArgumentError, "Can only automatically set the delegation prefix when delegating to a method."
    end

    prefix = options[:prefix] && "#{options[:prefix] == true ? to : options[:prefix]}_"

    methods.each do |method|
      module_eval(<<-EOS, "(__DELEGATION__)", 1)
        def #{prefix}#{method}(*args, &block)
          #{to}.__send__(#{method.inspect}, *args, &block)
        end
      EOS
    end
  end
end
