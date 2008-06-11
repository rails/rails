module ActiveRecord
  module Aggregations # :nodoc:
    def self.included(base)
      base.extend(ClassMethods)
    end

    def clear_aggregation_cache #:nodoc:
      self.class.reflect_on_all_aggregations.to_a.each do |assoc|
        instance_variable_set "@#{assoc.name}", nil
      end unless self.new_record?
    end

    # Active Record implements aggregation through a macro-like class method called +composed_of+ for representing attributes 
    # as value objects. It expresses relationships like "Account [is] composed of Money [among other things]" or "Person [is]
    # composed of [an] address". Each call to the macro adds a description of how the value objects are created from the 
    # attributes of the entity object (when the entity is initialized either as a new object or from finding an existing object) 
    # and how it can be turned back into attributes (when the entity is saved to the database). Example:
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
    #        amount <=> amount
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
    # Now it's possible to access attributes from the database through the value objects instead. If you choose to name the
    # composition the same as the attribute's name, it will be the only way to access that attribute. That's the case with our
    # +balance+ attribute. You interact with the value objects just like you would any other attribute, though:
    #
    #   customer.balance = Money.new(20)     # sets the Money value object and the attribute
    #   customer.balance                     # => Money value object
    #   customer.balance.exchanged_to("DKK") # => Money.new(120, "DKK")
    #   customer.balance > Money.new(10)     # => true
    #   customer.balance == Money.new(20)    # => true
    #   customer.balance < Money.new(5)      # => false
    #
    # Value objects can also be composed of multiple attributes, such as the case of Address. The order of the mappings will
    # determine the order of the parameters. Example:
    #
    #   customer.address_street = "Hyancintvej"
    #   customer.address_city   = "Copenhagen"
    #   customer.address        # => Address.new("Hyancintvej", "Copenhagen")
    #   customer.address = Address.new("May Street", "Chicago")
    #   customer.address_street # => "May Street" 
    #   customer.address_city   # => "Chicago" 
    #
    # == Writing value objects
    #
    # Value objects are immutable and interchangeable objects that represent a given value, such as a Money object representing
    # $5. Two Money objects both representing $5 should be equal (through methods such as <tt>==</tt> and <tt><=></tt> from Comparable if ranking
    # makes sense). This is unlike entity objects where equality is determined by identity. An entity class such as Customer can
    # easily have two different objects that both have an address on Hyancintvej. Entity identity is determined by object or
    # relational unique identifiers (such as primary keys). Normal ActiveRecord::Base classes are entity objects.
    #
    # It's also important to treat the value objects as immutable. Don't allow the Money object to have its amount changed after
    # creation. Create a new Money object with the new value instead. This is exemplified by the Money#exchanged_to method that
    # returns a new value object instead of changing its own values. Active Record won't persist value objects that have been
    # changed through means other than the writer method.
    #
    # The immutable requirement is enforced by Active Record by freezing any object assigned as a value object. Attempting to 
    # change it afterwards will result in a ActiveSupport::FrozenObjectError.
    # 
    # Read more about value objects on http://c2.com/cgi/wiki?ValueObject and on the dangers of not keeping value objects
    # immutable on http://c2.com/cgi/wiki?ValueObjectsShouldBeImmutable
    #
    # == Finding records by a value object
    #
    # Once a +composed_of+ relationship is specified for a model, records can be loaded from the database by specifying an instance
    # of the value object in the conditions hash. The following example finds all customers with +balance_amount+ equal to 20 and
    # +balance_currency+ equal to "USD":
    #
    #   Customer.find(:all, :conditions => {:balance => Money.new(20, "USD")})
    #
    module ClassMethods
      # Adds reader and writer methods for manipulating a value object:
      # <tt>composed_of :address</tt> adds <tt>address</tt> and <tt>address=(new_address)</tt> methods.
      #
      # Options are:
      # * <tt>:class_name</tt>  - specify the class name of the association. Use it only if that name can't be inferred
      #   from the part id. So <tt>composed_of :address</tt> will by default be linked to the Address class, but
      #   if the real class name is CompanyAddress, you'll have to specify it with this option.
      # * <tt>:mapping</tt> - specifies a number of mapping arrays (attribute, parameter) that bind an attribute name
      #   to a constructor parameter on the value class.
      # * <tt>:allow_nil</tt> - specifies that the aggregate object will not be instantiated when all mapped
      #   attributes are +nil+.  Setting the aggregate class to +nil+ has the effect of writing +nil+ to all mapped attributes.
      #   This defaults to +false+.
      #
      # An optional block can be passed to convert the argument that is passed to the writer method into an instance of
      # <tt>:class_name</tt>. The block will only be called if the argument is not already an instance of <tt>:class_name</tt>.
      #
      # Option examples:
      #   composed_of :temperature, :mapping => %w(reading celsius)
      #   composed_of(:balance, :class_name => "Money", :mapping => %w(balance amount)) {|balance| balance.to_money }
      #   composed_of :address, :mapping => [ %w(address_street street), %w(address_city city) ]
      #   composed_of :gps_location
      #   composed_of :gps_location, :allow_nil => true
      #
      def composed_of(part_id, options = {}, &block)
        options.assert_valid_keys(:class_name, :mapping, :allow_nil)

        name        = part_id.id2name
        class_name  = options[:class_name] || name.camelize
        mapping     = options[:mapping]    || [ name, name ]
        mapping     = [ mapping ] unless mapping.first.is_a?(Array)
        allow_nil   = options[:allow_nil]  || false

        reader_method(name, class_name, mapping, allow_nil)
        writer_method(name, class_name, mapping, allow_nil, block)
        
        create_reflection(:composed_of, part_id, options, self)
      end

      private
        def reader_method(name, class_name, mapping, allow_nil)
          module_eval do
            define_method(name) do |*args|
              force_reload = args.first || false
              if (instance_variable_get("@#{name}").nil? || force_reload) && (!allow_nil || mapping.any? {|pair| !read_attribute(pair.first).nil? })
                instance_variable_set("@#{name}", class_name.constantize.new(*mapping.collect {|pair| read_attribute(pair.first)}))
              end
              instance_variable_get("@#{name}")
            end
          end

        end

        def writer_method(name, class_name, mapping, allow_nil, conversion)
          module_eval do
            define_method("#{name}=") do |part|
              if part.nil? && allow_nil
                mapping.each { |pair| self[pair.first] = nil }
                instance_variable_set("@#{name}", nil)
              else
                part = conversion.call(part) unless part.is_a?(class_name.constantize) || conversion.nil?
                mapping.each { |pair| self[pair.first] = part.send(pair.last) }
                instance_variable_set("@#{name}", part.freeze)
              end
            end
          end
        end
    end
  end
end
