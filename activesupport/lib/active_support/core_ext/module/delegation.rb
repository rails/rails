# :markup: markdown
# frozen_string_literal: true

class Module
  require "active_support/delegation"
  DelegationError = ActiveSupport::DelegationError # :nodoc:

  # Provides a `delegate` class method to easily expose contained objects'
  # public methods as your own.
  #
  # #### Options
  # * `:to` - Specifies the target object name as a symbol or string
  # * `:prefix` - Prefixes the new method with the target name or a custom prefix
  # * `:allow_nil` - If set to true, prevents a `ActiveSupport::DelegationError`
  #   from being raised
  # * `:private` - If set to true, changes method visibility to private
  #
  # The macro receives one or more method names (specified as symbols or
  # strings) and the name of the target object via the `:to` option
  # (also a symbol or string).
  #
  # Delegation is particularly useful with Active Record associations:
  #
  # ```
  # class Greeter < ActiveRecord::Base
  #   def hello
  #     'hello'
  #   end
  #
  #   def goodbye
  #     'goodbye'
  #   end
  # end
  #
  # class Foo < ActiveRecord::Base
  #   belongs_to :greeter
  #   delegate :hello, to: :greeter
  # end
  #
  # Foo.new.hello   # => "hello"
  # Foo.new.goodbye # => NoMethodError: undefined method `goodbye' for #<Foo:0x1af30c>
  # ```
  #
  # Multiple delegates to the same target are allowed:
  #
  #
  # ```
  # class Foo < ActiveRecord::Base
  #   belongs_to :greeter
  #   delegate :hello, :goodbye, to: :greeter
  # end
  #
  # Foo.new.goodbye # => "goodbye"
  # ```
  #
  # Methods can be delegated to instance variables, class variables, or constants
  #
  # by providing them as a symbols:
  #
  # ```
  # class Foo
  #   CONSTANT_ARRAY = [0,1,2,3]
  #   @@class_array  = [4,5,6,7]
  #
  #   def initialize
  #     @instance_array = [8,9,10,11]
  #   end
  #   delegate :sum, to: :CONSTANT_ARRAY
  #   delegate :min, to: :@@class_array
  #   delegate :max, to: :@instance_array
  # end
  #
  # Foo.new.sum # => 6
  # Foo.new.min # => 4
  # Foo.new.max # => 11
  # ```
  #
  # It's also possible to delegate a method to the class by using `:class`:
  #
  #
  # ```
  # class Foo
  #   def self.hello
  #     "world"
  #   end
  #
  #   delegate :hello, to: :class
  # end
  #
  # Foo.new.hello # => "world"
  # ```
  #
  # Delegates can optionally be prefixed using the `:prefix` option. If the value
  #
  # is `true`, the delegate methods are prefixed with the name of the object being
  # delegated to.
  #
  # ```
  # Person = Struct.new(:name, :address)
  #
  # class Invoice < Struct.new(:client)
  #   delegate :name, :address, to: :client, prefix: true
  # end
  #
  # john_doe = Person.new('John Doe', 'Vimmersvej 13')
  # invoice = Invoice.new(john_doe)
  # invoice.client_name    # => "John Doe"
  # invoice.client_address # => "Vimmersvej 13"
  # ```
  #
  # It is also possible to supply a custom prefix.
  #
  #
  # ```
  # class Invoice < Struct.new(:client)
  #   delegate :name, :address, to: :client, prefix: :customer
  # end
  #
  # invoice = Invoice.new(john_doe)
  # invoice.customer_name    # => 'John Doe'
  # invoice.customer_address # => 'Vimmersvej 13'
  # ```
  #
  # The delegated methods are public by default.
  #
  # Pass `private: true` to change that.
  #
  # ```
  # class User < ActiveRecord::Base
  #   has_one :profile
  #   delegate :first_name, to: :profile
  #   delegate :date_of_birth, to: :profile, private: true
  #
  #   def age
  #     Date.today.year - date_of_birth.year
  #   end
  # end
  #
  # User.new.first_name # => "Tomas"
  # User.new.date_of_birth # => NoMethodError: private method `date_of_birth' called for #<User:0x00000008221340>
  # User.new.age # => 2
  # ```
  #
  # If the target is `nil` and does not respond to the delegated method a
  #
  # `ActiveSupport::DelegationError` is raised. If you wish to instead return `nil`,
  # use the `:allow_nil` option.
  #
  # ```
  # class User < ActiveRecord::Base
  #   has_one :profile
  #   delegate :age, to: :profile
  # end
  #
  # User.new.age
  # # => ActiveSupport::DelegationError: User#age delegated to profile.age, but profile is nil
  # ```
  #
  # But if not having a profile yet is fine and should not be an error
  #
  # condition:
  #
  # ```
  # class User < ActiveRecord::Base
  #   has_one :profile
  #   delegate :age, to: :profile, allow_nil: true
  # end
  #
  # User.new.age # nil
  # ```
  #
  # Note that if the target is not `nil` then the call is attempted regardless of the
  #
  # `:allow_nil` option, and thus an exception is still raised if said object
  # does not respond to the method:
  #
  # ```
  # class Foo
  #   def initialize(bar)
  #     @bar = bar
  #   end
  #
  #   delegate :name, to: :@bar, allow_nil: true
  # end
  #
  # Foo.new("Bar").name # raises NoMethodError: undefined method `name'
  # ```
  #
  # The target method must be public, otherwise it will raise `NoMethodError`.
  #
  def delegate(*methods, to: nil, prefix: nil, allow_nil: nil, private: nil)
    ::ActiveSupport::Delegation.generate(
      self,
      methods,
      location: caller_locations(1, 1).first,
      to: to,
      prefix: prefix,
      allow_nil: allow_nil,
      private: private,
    )
  end

  # When building decorators, a common pattern may emerge:
  #
  # ```
  # class Partition
  #   def initialize(event)
  #     @event = event
  #   end
  #
  #   def person
  #     detail.person || creator
  #   end
  #
  #   private
  #     def respond_to_missing?(name, include_private = false)
  #       @event.respond_to?(name, include_private)
  #     end
  #
  #     def method_missing(method, *args, &block)
  #       @event.send(method, *args, &block)
  #     end
  # end
  # ```
  #
  # With `Module#delegate_missing_to`, the above is condensed to:
  #
  #
  # ```
  # class Partition
  #   delegate_missing_to :@event
  #
  #   def initialize(event)
  #     @event = event
  #   end
  #
  #   def person
  #     detail.person || creator
  #   end
  # end
  # ```
  #
  # The target can be anything callable within the object, e.g. instance
  #
  # variables, methods, constants, etc.
  #
  # The delegated method must be public on the target, otherwise it will
  # raise `ActiveSupport::DelegationError`. If you wish to instead return `nil`,
  # use the `:allow_nil` option.
  #
  # The `marshal_dump` and `_dump` methods are exempt from
  # delegation due to possible interference when calling
  # `Marshal.dump(object)`, should the delegation target method
  # of `object` add or remove instance variables.
  def delegate_missing_to(target, allow_nil: nil)
    ::ActiveSupport::Delegation.generate_method_missing(
      self,
      target,
      allow_nil: allow_nil,
    )
  end
end
