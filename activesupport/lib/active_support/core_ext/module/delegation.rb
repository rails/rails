require "active_support/core_ext/module/remove_method"

class Module
  # Provides a delegate class method to easily expose contained objects' methods
  # as your own. Pass one or more methods (specified as symbols or strings)
  # and the name of the target object via the <tt>:to</tt> option (also a symbol
  # or string). At least one method and the <tt>:to</tt> option are required.
  #
  # Delegation is particularly useful with Active Record associations:
  #
  #   class Greeter < ActiveRecord::Base
  #     def hello
  #       "hello"
  #     end
  #
  #     def goodbye
  #       "goodbye"
  #     end
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
  # If the delegate object is +nil+ an exception is raised, and that happens
  # no matter whether +nil+ responds to the delegated method. You can get a
  # +nil+ instead with the +:allow_nil+ option.
  #
  #  class Foo
  #    attr_accessor :bar
  #    def initialize(bar = nil)
  #      @bar = bar
  #    end
  #    delegate :zoo, :to => :bar
  #  end
  #
  #  Foo.new.zoo   # raises NoMethodError exception (you called nil.zoo)
  #
  #  class Foo
  #    attr_accessor :bar
  #    def initialize(bar = nil)
  #      @bar = bar
  #    end
  #    delegate :zoo, :to => :bar, :allow_nil => true
  #  end
  #
  #  Foo.new.zoo   # returns nil
  #
  def delegate(*methods)
    options = methods.pop
    unless options.is_a?(Hash) && to = options[:to]
      raise ArgumentError, "Delegation needs a target. Supply an options hash with a :to key as the last argument (e.g. delegate :hello, :to => :greeter)."
    end

    if options[:prefix] == true && options[:to].to_s =~ /^[^a-z_]/
      raise ArgumentError, "Can only automatically set the delegation prefix when delegating to a method."
    end

    prefix = options[:prefix] && "#{options[:prefix] == true ? to : options[:prefix]}_" || ''

    file, line = caller.first.split(':', 2)
    line = line.to_i

    methods.each do |method|
      method_name = ":#{method}"

      on_nil =
        if options[:allow_nil]
          'return'
        else
          %(raise "#{self}##{prefix}#{method} delegated to #{to}.#{method}, but #{to} is nil: \#{self.inspect}")
        end

      rescue_clause = <<-EOS
        rescue NoMethodError => e                                                # rescue NoMethodError => e
          raise unless e.name == #{method_name}                                  #   raise unless e.name == :name
          begin                                                                  #   begin
            result = #{to}.__send__(#{method_name}, *args, &block)               #     result = client.__send__(:name, *args, &block)
          rescue NoMethodError => e2                                             #   rescue NoMethodError => e2
            raise unless e2.name == #{method_name}                               #     raise unless e2.name == :name
            if #{to}.nil?                                                        #     if client.nil?
              #{on_nil}                                                          #       return # depends on :allow_nil
            else                                                                 #     else
              raise(e)                                                           #       raise(e)
            end                                                                  #     end
          else                                                                   #   else
            ActiveSupport::Deprecation.warn(                                     #     ActiveSupport::Deprecation.warn(
              'Delegating to non-public methods is deprecated.', caller)         #       'Delegating to non-public methods is deprecated.', caller)
            result                                                               #     result
          end                                                                    #   end
      EOS

      method_body =
        if method.to_s =~ /[^\]]=/
          <<-EOS
            if args.length > 1 || block_given?                                     #   if args.length > 1 || block_given?
              ActiveSupport::Deprecation.warn(                                     #     ActiveSupport::Deprecation.warn(
                "Support for using Module#delegate with writer methods and " +     #       "Support for using Module#delegate with writer methods and " +
                "multiple arguments, or block arguments, is going to be " +        #       "multiple arguments, or block arguments, is going to be " +
                "removed. If you need this functionality, please define your " +   #       "removed. If you need this functionality, please define your " +
                "own delegation manually.", caller)                                #       "own delegation manually.", caller)
              #{to}.__send__(#{method_name}, *args, &block)                        #     client.__send__(:invoices=, *args, &block)
            else                                                                   #   else
              #{to}.#{method}(args.first)                                          #     client.invoices=(args.first)
            end                                                                    #   end
          EOS
        else
          <<-EOS
            #{to}.#{method}(*args, &block)                                         #   client.name(*args, &block)
          EOS
        end

      module_eval(<<-EOS, file, line - 1)
        def #{prefix}#{method}(*args, &block)                                    # def customer_name(*args, &block)
          #{method_body}
          #{rescue_clause}
        end                                                                      # end
      EOS
    end
  end
end
