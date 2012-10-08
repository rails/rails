module ActiveRecord
  # = Active Record Aggregations
  module Aggregations # :nodoc:
    extend ActiveSupport::Concern

    def clear_aggregation_cache #:nodoc:
      @aggregation_cache.clear if persisted?
    end

    # Active Record implements aggregation through a macro-like class method called +composed_of+
    # for representing attributes  as value objects. It expresses relationships like "Account [is]
    # composed of Money [among other things]" or "Person [is] composed of [an] address". Each call
    # to the macro adds a description of how the value objects are created from the attributes of
    # the entity object (when the entity is initialized either as a new object or from finding an
    # existing object) and how it can be turned back into attributes (when the entity is saved to
    # the database).
    #
    #   class Customer < ActiveRecord::Base
    #     composed_of :balance, :class_name => "Money", :mapping => %w(balance amount)
    #     composed_of :address, :mapping => [ %w(address_street street), %w(address_city city) ]
    #   end
    #
    # The customer class now has the following methods to manipulate the value objects:
    # * <tt>Customer#balance, Customer#balance=(money)</tt>
    # * <tt>Customer#address, Customer#address=(address)</tt>
    #
    # These methods will operate with value objects like the ones described below:
    #
    #  class Money
    #    include Comparable
    #    attr_reader :amount, :currency
    #    EXCHANGE_RATES = { "USD_TO_DKK" => 6 }
    #
    #    def initialize(amount, currency = "USD")
    #      @amount, @currency = amount, currency
    #    end
    #
    #    def exchange_to(other_currency)
    #      exchanged_amount = (amount * EXCHANGE_RATES["#{currency}_TO_#{other_currency}"]).floor
    #      Money.new(exchanged_amount, other_currency)
    #    end
    #
    #    def ==(other_money)
    #      amount == other_money.amount && currency == other_money.currency
    #    end
    #
    #    def <=>(other_money)
    #      if currency == other_money.currency
    #        amount <=> other_money.amount
    #      else
    #        amount <=> other_money.exchange_to(currency).amount
    #      end
    #    end
    #  end
    #
    #  class Address
    #    attr_reader :street, :city
    #    def initialize(street, city)
    #      @street, @city = street, city
    #    end
    #
    #    def close_to?(other_address)
    #      city == other_address.city
    #    end
    #
    #    def ==(other_address)
    #      city == other_address.city && street == other_address.street
    #    end
    #  end
    #
    # Now it's possible to access attributes from the database through the value objects instead. If
    # you choose to name the composition the same as the attribute's name, it will be the only way to
    # access that attribute. That's the case with our +balance+ attribute. You interact with the value
    # objects just like you would with any other attribute:
    #
    #   customer.balance = Money.new(20)     # sets the Money value object and the attribute
    #   customer.balance                     # => Money value object
    #   customer.balance.exchange_to("DKK")  # => Money.new(120, "DKK")
    #   customer.balance > Money.new(10)     # => true
    #   customer.balance == Money.new(20)    # => true
    #   customer.balance < Money.new(5)      # => false
    #
    # Value objects can also be composed of multiple attributes, such as the case of Address. The order
    # of the mappings will determine the order of the parameters.
    #
    #   customer.address_street = "Hyancintvej"
    #   customer.address_city   = "Copenhagen"
    #   customer.address        # => Address.new("Hyancintvej", "Copenhagen")
    #
    #   customer.address_street = "Vesterbrogade"
    #   customer.address        # => Address.new("Hyancintvej", "Copenhagen")
    #   customer.clear_aggregation_cache
    #   customer.address        # => Address.new("Vesterbrogade", "Copenhagen")
    #
    #   customer.address = Address.new("May Street", "Chicago")
    #   customer.address_street # => "May Street"
    #   customer.address_city   # => "Chicago"
    #
    # == Writing value objects
    #
    # Value objects are immutable and interchangeable objects that represent a given value, such as
    # a Money object representing $5. Two Money objects both representing $5 should be equal (through
    # methods such as <tt>==</tt> and <tt><=></tt> from Comparable if ranking makes sense). This is
    # unlike entity objects where equality is determined by identity. An entity class such as Customer can
    # easily have two different objects that both have an address on Hyancintvej. Entity identity is
    # determined by object or relational unique identifiers (such as primary keys). Normal
    # ActiveRecord::Base classes are entity objects.
    #
    # It's also important to treat the value objects as immutable. Don't allow the Money object to have
    # its amount changed after creation. Create a new Money object with the new value instead. The
    # Money#exchange_to method is an example of this. It returns a new value object instead of changing
    # its own values. Active Record won't persist value objects that have been changed through means
    # other than the writer method.
    #
    # The immutable requirement is enforced by Active Record by freezing any object assigned as a value
    # object. Attempting to change it afterwards will result in a ActiveSupport::FrozenObjectError.
    #
    # Read more about value objects on http://c2.com/cgi/wiki?ValueObject and on the dangers of not
    # keeping value objects immutable on http://c2.com/cgi/wiki?ValueObjectsShouldBeImmutable
    #
    # == Custom constructors and converters
    #
    # By default value objects are initialized by calling the <tt>new</tt> constructor of the value
    # class passing each of the mapped attributes, in the order specified by the <tt>:mapping</tt>
    # option, as arguments. If the value class doesn't support this convention then +composed_of+ allows
    # a custom constructor to be specified.
    #
    # When a new value is assigned to the value object, the default assumption is that the new value
    # is an instance of the value class. Specifying a custom converter allows the new value to be automatically
    # converted to an instance of value class if necessary.
    #
    # For example, the NetworkResource model has +network_address+ and +cidr_range+ attributes that
    # should be aggregated using the NetAddr::CIDR value class (http://netaddr.rubyforge.org). The constructor
    # for the value class is called +create+ and it expects a CIDR address string as a parameter. New
    # values can be assigned to the value object using either another NetAddr::CIDR object, a string
    # or an array. The <tt>:constructor</tt> and <tt>:converter</tt> options can be used to meet
    # these requirements:
    #
    #   class NetworkResource < ActiveRecord::Base
    #     composed_of :cidr,
    #                 :class_name => 'NetAddr::CIDR',
    #                 :mapping => [ %w(network_address network), %w(cidr_range bits) ],
    #                 :allow_nil => true,
    #                 :constructor => Proc.new { |network_address, cidr_range| NetAddr::CIDR.create("#{network_address}/#{cidr_range}") },
    #                 :converter => Proc.new { |value| NetAddr::CIDR.create(value.is_a?(Array) ? value.join('/') : value) }
    #   end
    #
    #   # This calls the :constructor
    #   network_resource = NetworkResource.new(:network_address => '192.168.0.1', :cidr_range => 24)
    #
    #   # These assignments will both use the :converter
    #   network_resource.cidr = [ '192.168.2.1', 8 ]
    #   network_resource.cidr = '192.168.0.1/24'
    #
    #   # This assignment won't use the :converter as the value is already an instance of the value class
    #   network_resource.cidr = NetAddr::CIDR.create('192.168.2.1/8')
    #
    #   # Saving and then reloading will use the :constructor on reload
    #   network_resource.save
    #   network_resource.reload
    #
    # == Finding records by a value object
    #
    # Once a +composed_of+ relationship is specified for a model, records can be loaded from the database
    # by specifying an instance of the value object in the conditions hash. The following example
    # finds all customers with +balance_amount+ equal to 20 and +balance_currency+ equal to "USD":
    #
    #   Customer.where(:balance => Money.new(20, "USD")).all
    #
    module ClassMethods
      # Adds reader and writer methods for manipulating a value object:
      # <tt>composed_of :address</tt> adds <tt>address</tt> and <tt>address=(new_address)</tt> methods.
      #
      # Options are:
      # * <tt>:class_name</tt> - Specifies the class name of the association. Use it only if that name
      #   can't be inferred from the part id. So <tt>composed_of :address</tt> will by default be linked
      #   to the Address class, but if the real class name is CompanyAddress, you'll have to specify it
      #   with this option.
      # * <tt>:mapping</tt> - Specifies the mapping of entity attributes to attributes of the value
      #   object. Each mapping is represented as an array where the first item is the name of the
      #   entity attribute and the second item is the name of the attribute in the value object. The
      #   order in which mappings are defined determines the order in which attributes are sent to the
      #   value class constructor.
      # * <tt>:allow_nil</tt> - Specifies that the value object will not be instantiated when all mapped
      #   attributes are +nil+. Setting the value object to +nil+ has the effect of writing +nil+ to all
      #   mapped attributes.
      #   This defaults to +false+.
      # * <tt>:constructor</tt> - A symbol specifying the name of the constructor method or a Proc that
      #   is called to initialize the value object. The constructor is passed all of the mapped attributes,
      #   in the order that they are defined in the <tt>:mapping option</tt>, as arguments and uses them
      #   to instantiate a <tt>:class_name</tt> object.
      #   The default is <tt>:new</tt>.
      # * <tt>:converter</tt> - A symbol specifying the name of a class method of <tt>:class_name</tt>
      #   or a Proc that is called when a new value is assigned to the value object. The converter is
      #   passed the single value that is used in the assignment and is only called if the new value is
      #   not an instance of <tt>:class_name</tt>. If <tt>:allow_nil</tt> is set to true, the converter
      #   can return nil to skip the assignment.
      #
      # Option examples:
      #   composed_of :temperature, :mapping => %w(reading celsius)
      #   composed_of :balance, :class_name => "Money", :mapping => %w(balance amount),
      #                         :converter => Proc.new { |balance| balance.to_money }
      #   composed_of :address, :mapping => [ %w(address_street street), %w(address_city city) ]
      #   composed_of :gps_location
      #   composed_of :gps_location, :allow_nil => true
      #   composed_of :ip_address,
      #               :class_name => 'IPAddr',
      #               :mapping => %w(ip to_i),
      #               :constructor => Proc.new { |ip| IPAddr.new(ip, Socket::AF_INET) },
      #               :converter => Proc.new { |ip| ip.is_a?(Integer) ? IPAddr.new(ip, Socket::AF_INET) : IPAddr.new(ip.to_s) }
      #
      def composed_of(part_id, options = {})
        options.assert_valid_keys(:class_name, :mapping, :allow_nil, :constructor, :converter)

        name        = part_id.id2name
        class_name  = options[:class_name]  || name.camelize
        mapping     = options[:mapping]     || [ name, name ]
        mapping     = [ mapping ] unless mapping.first.is_a?(Array)
        allow_nil   = options[:allow_nil]   || false
        constructor = options[:constructor] || :new
        converter   = options[:converter]

        reader_method(name, class_name, mapping, allow_nil, constructor)
        writer_method(name, class_name, mapping, allow_nil, converter)

        create_reflection(:composed_of, part_id, nil, options, self)
      end

      private
        def reader_method(name, class_name, mapping, allow_nil, constructor)
          define_method(name) do
            if @aggregation_cache[name].nil? && (!allow_nil || mapping.any? {|pair| !read_attribute(pair.first).nil? })
              attrs = mapping.collect {|pair| read_attribute(pair.first)}
              object = constructor.respond_to?(:call) ?
                constructor.call(*attrs) :
                class_name.constantize.send(constructor, *attrs)
              @aggregation_cache[name] = object
            end
            @aggregation_cache[name]
          end
        end

        def writer_method(name, class_name, mapping, allow_nil, converter)
          define_method("#{name}=") do |part|
            klass = class_name.constantize
            unless part.is_a?(klass) || converter.nil? || part.nil?
              part = converter.respond_to?(:call) ? converter.call(part) : klass.send(converter, part)
            end

            if part.nil? && allow_nil
              mapping.each { |pair| self[pair.first] = nil }
              @aggregation_cache[name] = nil
            else
              mapping.each { |pair| self[pair.first] = part.send(pair.last) }
              @aggregation_cache[name] = part.freeze
            end
          end
        end
    end
  end
end
