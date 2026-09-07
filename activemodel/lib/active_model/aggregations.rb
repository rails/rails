# frozen_string_literal: true

# :markup: markdown

require "active_support/core_ext/hash/keys"
require "active_support/core_ext/string/inflections"

module ActiveModel
  # See ActiveModel::Aggregations::ClassMethods for documentation.
  module Aggregations
    extend ActiveSupport::Concern

    def initialize_dup(*) # :nodoc:
      @aggregation_cache = @aggregation_cache.dup
      super
    end

    private
      def _aggregation_read_attribute(key)
        self.class._composed_of_reader(key).bind_call(self)
      end

      def _aggregation_write_attribute(key, value)
        self.class._composed_of_writer(key).bind_call(self, value)
      end

      # A frozen object cannot be given a cache, so its value objects are rebuilt on each read.
      def _aggregation_cache
        return @aggregation_cache if @aggregation_cache

        if frozen?
          {}
        else
          @aggregation_cache = {}
        end
      end

      # # Active Model Aggregations
      #
      # Active Model implements aggregation through a macro-like class method called #composed_of
      # for representing attributes as value objects. It expresses relationships like "Account [is]
      # composed of Money [among other things]" or "Person [is] composed of [an] address". Each call
      # to the macro adds a description of how the value objects are created from the attributes of
      # the entity object (when the entity is initialized either as a new object or from finding an
      # existing object) and how it can be turned back into attributes (when the entity is saved to
      # the database, for classes that support persistence).
      #
      # The mapped attributes are read and written through their own accessors, so any
      # kind of accessor will do, whether declared with ActiveModel::Attributes,
      # `attr_accessor`, or by hand. An aggregation named after one of its mapped
      # attributes replaces that attribute's accessor, so accessors defined directly on
      # the class, such as `attr_accessor` ones, have to be declared before #composed_of
      # or they will replace it right back.
      #
      #     class Customer
      #       include ActiveModel::Aggregations
      #       include ActiveModel::Attributes
      #
      #       attribute :balance
      #       attribute :address_street
      #       attribute :address_city
      #
      #       composed_of :balance, class_name: "Money", mapping: { balance: :amount }
      #       composed_of :address, mapping: { address_street: :street, address_city: :city }
      #     end
      #
      # The customer class now has the following methods to manipulate the value objects:
      #
      # *   `Customer#balance, Customer#balance=(money)`
      # *   `Customer#address, Customer#address=(address)`
      #
      # These methods will operate with value objects like the ones described below:
      #
      #     class Money
      #       include Comparable
      #       attr_reader :amount, :currency
      #       EXCHANGE_RATES = { "USD_TO_DKK" => 6 }
      #
      #       def initialize(amount, currency = "USD")
      #         @amount, @currency = amount, currency
      #       end
      #
      #       def exchange_to(other_currency)
      #         exchanged_amount = (amount * EXCHANGE_RATES["#{currency}_TO_#{other_currency}"]).floor
      #         Money.new(exchanged_amount, other_currency)
      #       end
      #
      #       def ==(other_money)
      #         amount == other_money.amount && currency == other_money.currency
      #       end
      #
      #       def <=>(other_money)
      #         if currency == other_money.currency
      #           amount <=> other_money.amount
      #         else
      #           amount <=> other_money.exchange_to(currency).amount
      #         end
      #       end
      #     end
      #
      #     class Address
      #       attr_reader :street, :city
      #       def initialize(street, city)
      #         @street, @city = street, city
      #       end
      #
      #       def close_to?(other_address)
      #         city == other_address.city
      #       end
      #
      #       def ==(other_address)
      #         city == other_address.city && street == other_address.street
      #       end
      #     end
      #
      # Now it's possible to access attributes from the entity through the value objects instead. If
      # you choose to name the composition the same as the attribute's name, it will be the only way to
      # access that attribute. That's the case with our `balance` attribute. You interact with the value
      # objects just like you would with any other attribute:
      #
      #     customer.balance = Money.new(20)     # sets the Money value object and the attribute
      #     customer.balance                     # => Money value object
      #     customer.balance.exchange_to("DKK")  # => Money.new(120, "DKK")
      #     customer.balance > Money.new(10)     # => true
      #     customer.balance == Money.new(20)    # => true
      #     customer.balance < Money.new(5)      # => false
      #
      # Value objects can also be composed of multiple attributes, such as the case of Address. The order
      # of the mappings will determine the order of the parameters.
      #
      #     customer.address_street = "Hyancintvej"
      #     customer.address_city   = "Copenhagen"
      #     customer.address        # => Address.new("Hyancintvej", "Copenhagen")
      #
      #     customer.address = Address.new("May Street", "Chicago")
      #     customer.address_street # => "May Street"
      #     customer.address_city   # => "Chicago"
      #
      # ## Writing value objects
      #
      # Value objects are immutable and interchangeable objects that represent a given value, such as
      # a Money object representing $5. Two Money objects both representing $5 should be equal (through
      # methods such as `==` and `<=>` from Comparable if ranking makes sense). This is
      # unlike entity objects where equality is determined by identity. An entity class such as Customer can
      # easily have two different objects that both have an address on Hyancintvej. Entity identity is
      # determined by object or relational unique identifiers (such as primary keys).
      #
      # It's also important to treat the value objects as immutable. Don't allow the Money object to have
      # its amount changed after creation. Create a new Money object with the new value instead. The
      # `Money#exchange_to` method is an example of this. It returns a new value object instead of changing
      # its own values. Aggregations won't persist value objects that have been changed through means
      # other than the writer method.
      #
      # The immutable requirement is enforced by freezing any object assigned as a value object.
      # Attempting to change it afterwards will result in a `RuntimeError`.
      #
      # Read more about value objects on http://c2.com/cgi/wiki?ValueObject and on the dangers of not
      # keeping value objects immutable on http://c2.com/cgi/wiki?ValueObjectsShouldBeImmutable
      #
      # ## Custom constructors and converters
      #
      # By default value objects are initialized by calling the `new` constructor of the value
      # class passing each of the mapped attributes, in the order specified by the `:mapping`
      # option, as arguments. If the value class doesn't support this convention then #composed_of allows
      # a custom constructor to be specified.
      #
      # When a new value is assigned to the value object, the default assumption is that the new value
      # is an instance of the value class. Specifying a custom converter allows the new value to be automatically
      # converted to an instance of value class if necessary.
      #
      # For example, the `NetworkResource` model has `network_address` and `cidr_range` attributes that should be
      # aggregated using the `NetAddr::CIDR` value class (https://www.rubydoc.info/gems/netaddr/1.5.0/NetAddr/CIDR).
      # The constructor for the value class is called `create` and it expects a CIDR address string as a parameter.
      # New values can be assigned to the value object using either another `NetAddr::CIDR` object, a string
      # or an array. The `:constructor` and `:converter` options can be used to meet
      # these requirements:
      #
      #     class NetworkResource
      #       include ActiveModel::API
      #       include ActiveModel::Aggregations
      #       include ActiveModel::Attributes
      #
      #       attribute :network_address
      #       attribute :cidr_range
      #
      #       composed_of :cidr,
      #                   class_name: 'NetAddr::CIDR',
      #                   mapping: { network_address: :network, cidr_range: :bits },
      #                   allow_nil: true,
      #                   constructor: Proc.new { |network_address, cidr_range| NetAddr::CIDR.create("#{network_address}/#{cidr_range}") },
      #                   converter: Proc.new { |value| NetAddr::CIDR.create(value.is_a?(Array) ? value.join('/') : value) }
      #     end
      #
      #     # This calls the :constructor
      #     network_resource = NetworkResource.new(network_address: '192.168.0.1', cidr_range: 24)
      #
      #     # These assignments will both use the :converter
      #     network_resource.cidr = [ '192.168.2.1', 8 ]
      #     network_resource.cidr = '192.168.0.1/24'
      #
      #     # This assignment won't use the :converter as the value is already an instance of the value class
      #     network_resource.cidr = NetAddr::CIDR.create('192.168.2.1/8')
      module ClassMethods
        # Adds reader and writer methods for manipulating a value object:
        # `composed_of :address` adds `address` and `address=(new_address)` methods.
        #
        # Options are:
        #
        # *   `:class_name` - Specifies the class name of the association. Use it only if that name
        #     can't be inferred from the part id. So `composed_of :address` will by default be linked
        #     to the Address class, but if the real class name is `CompanyAddress`, you'll have to specify it
        #     with this option.
        # *   `:mapping` - Specifies the mapping of entity attributes to attributes of the value
        #     object. Each mapping is represented as a key-value pair where the key is the name of the
        #     entity attribute and the value is the name of the attribute in the value object. The
        #     order in which mappings are defined determines the order in which attributes are sent to the
        #     value class constructor. The mapping can be written as a hash or as an array of pairs.
        # *   `:allow_nil` - Specifies that the value object will not be instantiated when all mapped
        #     attributes are `nil`. Setting the value object to `nil` has the effect of writing `nil` to all
        #     mapped attributes.
        #     This defaults to `false`.
        # *   `:constructor` - A symbol specifying the name of the constructor method or a Proc that
        #     is called to initialize the value object. The constructor is passed all of the mapped attributes,
        #     in the order that they are defined in the `:mapping` option, as arguments and uses them
        #     to instantiate a `:class_name` object.
        #     The default is `:new`.
        # *   `:converter` - A symbol specifying the name of a class method of `:class_name`
        #     or a Proc that is called when a new value is assigned to the value object. The converter is
        #     passed the single value that is used in the assignment and is only called if the new value is
        #     not an instance of `:class_name`. If `:allow_nil` is set to true, the converter
        #     can return `nil` to skip the assignment.
        #
        # Option examples:
        #
        #     composed_of :temperature, mapping: { reading: :celsius }
        #     composed_of :balance, class_name: "Money", mapping: { balance: :amount }
        #     composed_of :address, mapping: { address_street: :street, address_city: :city }
        #     composed_of :address, mapping: [ %w(address_street street), %w(address_city city) ]
        #     composed_of :gps_location
        #     composed_of :gps_location, allow_nil: true
        #     composed_of :ip_address,
        #                 class_name: 'IPAddr',
        #                 mapping: { ip: :to_i },
        #                 constructor: Proc.new { |ip| IPAddr.new(ip, Socket::AF_INET) },
        #                 converter: Proc.new { |ip| ip.is_a?(Integer) ? IPAddr.new(ip, Socket::AF_INET) : IPAddr.new(ip.to_s) }
        def composed_of(part_id, options = {})
          options.assert_valid_keys(:class_name, :mapping, :allow_nil, :constructor, :converter)

          name        = part_id.id2name
          class_name  = options[:class_name]  || name.camelize
          mapping     = options[:mapping]     || [ name, name ]
          mapping     = [ mapping ] unless mapping.first.is_a?(Array)
          mapping     = mapping.map { |key, value| [ key.to_s, value ] }
          allow_nil   = options[:allow_nil]   || false
          constructor = options[:constructor] || :new
          converter   = options[:converter]

          [ name, "#{name}=" ].each do |method_name|
            # Redeclaring an aggregation must not capture the accessor it generated before.
            next if _composed_of_shadowed_methods.key?(method_name)

            if method_defined?(method_name, false) || private_method_defined?(method_name, false)
              _composed_of_shadowed_methods[method_name] = instance_method(method_name)
              remove_method(method_name)
            else
              _composed_of_shadowed_methods[method_name] = nil
            end
          end

          reader_method(name, class_name, mapping, allow_nil, constructor)
          writer_method(name, class_name, mapping, allow_nil, converter)
        end

        # The accessors #composed_of has generated on this class, keyed by name, mapped to
        # the accessor each one replaced (or `nil` when it replaced none).
        def _composed_of_shadowed_methods # :nodoc:
          @_composed_of_shadowed_methods ||= {}
        end

        # Returns the method instances read the mapped attribute `key` with: the accessor
        # #composed_of shadowed, or the attribute's own accessor.
        def _composed_of_reader(key) # :nodoc:
          _composed_of_readers.fetch(key) do
            _composed_of_readers[key] = _composed_of_shadowed_method(key) || instance_method(key)
          end
        end

        # Returns the method instances write the mapped attribute `key` with: the accessor
        # #composed_of shadowed, or the attribute's own accessor.
        def _composed_of_writer(key) # :nodoc:
          _composed_of_writers.fetch(key) do
            writer = "#{key}="
            _composed_of_writers[key] = _composed_of_shadowed_method(writer) || instance_method(writer)
          end
        end

        private
          def _composed_of_readers
            @_composed_of_readers ||= {}
          end

          def _composed_of_writers
            @_composed_of_writers ||= {}
          end

          # Returns the accessor that #composed_of shadowed with `method_name`, or `nil`
          # when #composed_of generated no accessor by that name and the attribute can be
          # reached through its own accessor.
          def _composed_of_shadowed_method(method_name)
            shadowing = false
            shadowed = nil

            ancestors.each do |mod|
              # Nothing beyond Object can be an attribute accessor, but Kernel has
              # private methods named like plausible attributes (`format`, `test`).
              break if mod == Object

              if mod.respond_to?(:_composed_of_shadowed_methods) && mod._composed_of_shadowed_methods.key?(method_name)
                shadowing = true
                # The ancestor may have captured the accessor it replaced.
                if (captured = mod._composed_of_shadowed_methods[method_name])
                  shadowed = captured
                  break
                end
                next
              end

              # Definitions ahead of the generated accessor (subclass overrides, prepended
              # modules) call it through `super`
              next unless shadowing
              next unless mod.method_defined?(method_name, false) || mod.private_method_defined?(method_name, false)

              shadowed = mod.instance_method(method_name)
              break
            end

            if shadowing && shadowed.nil?
              raise NoMethodError, "#{self} has no accessor for '#{method_name.delete_suffix("=")}', " \
                "which composed_of maps to a value object"
            end

            shadowed
          end

          def reader_method(name, class_name, mapping, allow_nil, constructor)
            define_method(name) do
              cache = _aggregation_cache

              if cache[name].nil? && (!allow_nil || mapping.any? { |key, _| !_aggregation_read_attribute(key).nil? })
                attrs = mapping.collect { |key, _| _aggregation_read_attribute(key) }
                object = constructor.respond_to?(:call) ?
                  constructor.call(*attrs) :
                  class_name.constantize.send(constructor, *attrs)
                cache[name] = object.freeze
              end
              cache[name]
            end
          end

          def writer_method(name, class_name, mapping, allow_nil, converter)
            define_method(:"#{name}=") do |part|
              cache = _aggregation_cache
              klass = class_name.constantize

              unless part.is_a?(klass) || converter.nil? || part.nil?
                part = converter.respond_to?(:call) ? converter.call(part) : klass.send(converter, part)
              end

              hash_from_multiparameter_assignment = part.is_a?(Hash) &&
                part.keys.all?(Integer)
              if hash_from_multiparameter_assignment
                raise ArgumentError unless part.size == part.each_key.max
                part = klass.new(*part.sort.map(&:last))
              end

              if part.nil? && allow_nil
                mapping.each { |key, _| _aggregation_write_attribute(key, nil) }
                cache[name] = nil
              else
                mapping.each { |key, value| _aggregation_write_attribute(key, part.send(value)) }
                cache[name] = part.dup.freeze
              end
            end
          end
      end
  end
end
