# frozen_string_literal: true

module ActiveModel
  # = Active \Model \API
  #
  # Includes the required interface for an object to interact with
  # Action Pack and Action View, using different Active \Model modules.
  # It includes model name introspections, conversions, translations, and
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
  # Note that, by default, +ActiveModel::API+ implements #persisted?
  # to return +false+, which is the most common case. You may want to override
  # it in your class to simulate a different scenario:
  #
  #   class Person
  #     include ActiveModel::API
  #     attr_accessor :id, :name
  #
  #     def persisted?
  #       self.id.present?
  #     end
  #   end
  #
  #   person = Person.new(id: 1, name: 'bob')
  #   person.persisted? # => true
  #
  # Also, if for some reason you need to run code on initialize ( ::new ), make
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
  # refer to the specific modules included in +ActiveModel::API+
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

    module ClassMethods
      def filter_attributes
        if defined?(@filter_attributes)
          @filter_attributes
        elsif superclass.respond_to?(:filter_attributes)
          superclass.filter_attributes
        else
          []
        end
      end

      def filter_attributes=(filter_attributes)
        @filter_attributes = filter_attributes
      end
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

    def inspect
      "<#{self.class.name} #{inspect_attributes.map { |k, v| "#{k}=#{v.inspect}" }.join(", ")}>"
    end

    def inspect_attributes
      attributes.merge(self.class.filter_attributes.index_with do |filter_attribute|
        "[FILTERED]"
      end)
    end

    def method_missing(method_name, *args, &block)
      case method_name
      when "attributes", :attributes
        self.class.define_method(method_name) do
          if instance_variable_defined?(:@attributes)
            instance_variable_get(:@attributes)
          else
            instance_variable_set(:@attributes, {})
          end
        end
        public_send(method_name)
      else
        super
      end
    end

    def respond_to_missing?(method_name, include_private = false)
      case method_name
      when "attributes", :attributes
        true
      else
        super
      end
    end
  end
end
