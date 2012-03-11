module ActiveModel

  # == Active Model Basic Model
  #
  # Includes the required interface for an object to interact with +ActionPack+,
  # using different +ActiveModel+ modules. It includes model name introspections,
  # conversions, translations and validations. Besides that, it allows you to
  # initialize the object with a hash of attributes, pretty much like
  # +ActiveRecord+ does.
  #
  # A minimal implementation could be:
  #
  #   class Person
  #     include ActiveModel::Model
  #     attr_accessor :name, :age
  #   end
  #
  #   person = Person.new(:name => 'bob', :age => '18')
  #   person.name # => 'bob'
  #   person.age # => 18
  #
  # Note that, by default, +ActiveModel::Model+ implements +persisted?+ to
  # return +false+, which is the most common case. You may want to override it
  # in your class to simulate a different scenario:
  #
  #   class Person
  #     include ActiveModel::Model
  #     attr_accessor :id, :name
  #
  #     def persisted?
  #       self.id == 1
  #     end
  #   end
  #
  #   person = Person.new(:id => 1, :name => 'bob')
  #   person.persisted? # => true
  #
  # Also, if for some reason you need to run code on +initialize+, make sure you
  # call super if you want the attributes hash initialization to happen.
  #
  #   class Person
  #     include ActiveModel::Model
  #     attr_accessor :id, :name, :omg
  #
  #     def initialize(attributes)
  #       super
  #       @omg ||= true
  #     end
  #   end
  #
  #   person = Person.new(:id => 1, :name => 'bob')
  #   person.omg # => true
  #
  # For more detailed information on other functionalities available, please refer
  # to the specific modules included in +ActiveModel::Model+ (see below).
  module Model
    def self.included(base)
      base.class_eval do
        extend  ActiveModel::Naming
        extend  ActiveModel::Translation
        include ActiveModel::Validations
        include ActiveModel::Conversion
      end
    end

    def initialize(params={})
      params.each do |attr, value|
        self.public_send("#{attr}=", value)
      end if params
    end

    def persisted?
      false
    end
  end
end
