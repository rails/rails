# frozen_string_literal: true

module ActiveModel
  # = Active \Model \Basic \Model
  #
  # Allows implementing models similar to ActiveRecord::Base.
  # Includes ActiveModel::API for the required interface for an
  # object to interact with Action Pack and Action View, but can be
  # extended with other functionalities.
  #
  # A minimal implementation could be:
  #
  #   class Person
  #     include ActiveModel::Model
  #     attr_accessor :name, :age
  #   end
  #
  #   person = Person.new(name: 'bob', age: '18')
  #   person.name # => "bob"
  #   person.age  # => "18"
  #
  # If for some reason you need to run code on <tt>initialize</tt>, make
  # sure you call +super+ if you want the attributes hash initialization to
  # happen.
  #
  #   class Person
  #     include ActiveModel::Model
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
  # refer to the specific modules included in +ActiveModel::Model+
  # (see below).
  module Model
    extend ActiveSupport::Concern
    include ActiveModel::API
    include ActiveModel::Access

    ##
    # :method: slice
    #
    # :call-seq: slice(*methods)
    #
    # Returns a hash of the given methods with their names as keys and returned
    # values as values.
    #
    #   person = Person.new(id: 1, name: "bob")
    #   person.slice(:id, :name)
    #   # => { "id" => 1, "name" => "bob" }
    #
    #--
    # Implemented by ActiveModel::Access#slice.

    ##
    # :method: values_at
    #
    # :call-seq: values_at(*methods)
    #
    # Returns an array of the values returned by the given methods.
    #
    #   person = Person.new(id: 1, name: "bob")
    #   person.values_at(:id, :name)
    #   # => [1, "bob"]
    #
    #--
    # Implemented by ActiveModel::Access#values_at.
  end

  ActiveSupport.run_load_hooks(:active_model, Model)
end
