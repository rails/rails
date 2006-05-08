class Module
  # Provides a delegate class method to easily expose contained objects' methods
  # as your own. Pass one or more methods (specified as symbols or strings)
  # and the name of the target object as the final :to option (also a symbol
  # or string).  At least one method and the :to option are required.
  #
  # Delegation is particularly useful with Active Record associations:
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
  #   class Foo < ActiveRecord::Base
  #     delegate :hello, :goodbye, :to => :greeter
  #   end
  #
  #   Foo.new.goodbye # => "goodbye"
  def delegate(*methods)
    options = methods.pop
    unless options.is_a?(Hash) && to = options[:to]
      raise ArgumentError, "Delegation needs a target. Supply an options hash with a :to key as the last argument (e.g. delegate :hello, :to => :greeter)."
    end

    methods.each do |method|
      module_eval(<<-EOS, "(__DELEGATION__)", 1)
        def #{method}(*args, &block)
          #{to}.__send__(#{method.inspect}, *args, &block)
        end
      EOS
    end
  end
end
