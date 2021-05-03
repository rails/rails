# frozen_string_literal: true

module ActiveModel
  # == Active \Model \API
  #
  # Includes the required interface for an object to interact with
  # Action Pack and Action View, using different Active Model modules.
  # It includes model name introspections, conversions, translations and
  # validations. Besides that, it allows you to initialize the object with a
  # hash of attributes, pretty much like Active Record does.
  #
  # A minimal implementation could be:
  #
  #   class Person
  #     include ActiveModel::API
  #     attr_accessor :name, :age
  #   end
  #
  #   person = Person.new(name: 'bob', age: '18')
  #   person.name # => "bob"
  #   person.age  # => "18"
  #
  # Note that, by default, <tt>ActiveModel::API</tt> implements <tt>persisted?</tt>
  # to return +false+, which is the most common case. You may want to override
  # it in your class to simulate a different scenario:
  #
  #   class Person
  #     include ActiveModel::API
  #     attr_accessor :id, :name
  #
  #     def persisted?
  #       self.id == 1
  #     end
  #   end
  #
  #   person = Person.new(id: 1, name: 'bob')
  #   person.persisted? # => true
  #
  # Also, if for some reason you need to run code on <tt>initialize</tt>, make
  # sure you call +super+ if you want the attributes hash initialization to
  # happen.
  #
  #   class Person
  #     include ActiveModel::API
  #     attr_accessor :id, :name, :omg
  #
  #     def initialize(attributes={})
  #       super
  #       @omg ||= true
  #     end
  #   end
  #
  #   person = Person.new(id: 1, name: 'bob')
  #   person.omg # => true
  #
  # For more detailed information on other functionalities available, please
  # refer to the specific modules included in <tt>ActiveModel::API</tt>
  # (see below).
  module API
    extend ActiveSupport::Concern
    include ActiveModel::AttributeAssignment
    include ActiveModel::Validations
    include ActiveModel::Conversion

    included do
      extend ActiveModel::Naming
      extend ActiveModel::Translation
    end

    # Initializes a new model with the given +params+.
    #
    #   class Person
    #     include ActiveModel::API
    #     attr_accessor :name, :age
    #   end
    #
    #   person = Person.new(name: 'bob', age: '18')
    #   person.name # => "bob"
    #   person.age  # => "18"
    def initialize(attributes = {})
      assign_attributes(attributes) if attributes

      super()
    end

    # Indicates if the model is persisted. Default is +false+.
    #
    #  class Person
    #    include ActiveModel::API
    #    attr_accessor :id, :name
    #  end
    #
    #  person = Person.new(id: 1, name: 'bob')
    #  person.persisted? # => false
    def persisted?
      false
    end
  end
end
