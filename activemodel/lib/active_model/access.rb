# frozen_string_literal: true

require "active_support/core_ext/enumerable"
require "active_support/core_ext/hash/indifferent_access"

module ActiveModel
  # = Active \Model \Access
  #
  # Provides methods to access object attributes by name.
  #
  #   class Person
  #     include ActiveModel::Access
  #     attr_accessor :id, :name
  #   end
  #
  #   person = Person.new(id: 1, name: "bob")
  #   person.slice(:id, :name)  # => { "id" => 1, "name" => "bob" }
  #   person.values_at(:id, :name)  # => [1, "bob"]
  module Access
    # Returns a hash of the given methods with their names as keys and returned
    # values as values. The hash has indifferent access.
    #
    #   person.slice(:id, :name)  # => { "id" => 1, "name" => "bob" }
    #   person.slice([:id, :name])  # => same as above
    #   person.slice { |method| [:id, :name].include?(method) }  # => same as above
    #
    # Raises +NoMethodError+ if any of the given methods don't exist.
    def slice(*methods, &block)
      method_list = if block_given?
        self.class.public_instance_methods(false).select(&block)
      else
        methods.flatten
      end

      method_list.index_with { |method| public_send(method) }.with_indifferent_access
    end

    # Returns an array of the values returned by the given methods.
    #
    #   person.values_at(:id, :name)  # => [1, "bob"]
    #   person.values_at([:id, :name])  # => same as above
    #
    # Raises +NoMethodError+ if any of the given methods don't exist.
    def values_at(*methods)
      methods.flatten.map! { |method| public_send(method) }
    end
  end
end
