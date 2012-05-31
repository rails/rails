module ActiveModel

  # == Active Model Mass Assignment
  #
  # Allows you to initialize the object with a hash of attributes, pretty much
  # like <tt>ActiveRecord</tt> does.
  #
  # A minimal implementation could be:
  #
  #   class Person
  #     include ActiveModel::MassAssignment
  #     attr_accessor :name, :age
  #   end
  #
  #   person = Person.new(:name => 'bob', :age => '18')
  #   person.name # => 'bob'
  #   person.age # => 18
  #
  # Also, if for some reason you need to run code on <tt>initialize</tt>, make sure
  # you call super if you want the attributes hash initialization to happen.
  #
  #   class Person
  #     include ActiveModel::MassAssignment
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
  module MassAssignment
    def initialize(params={})
      params.each do |attr, value|
        self.public_send("#{attr}=", value)
      end if params
    end
  end
end
