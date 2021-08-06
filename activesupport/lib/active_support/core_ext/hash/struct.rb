# frozen_string_literal: true

class Hash
  # Returns a new struct with the same key/value pairs
  #
  #   user = { first_name: "Dorian", last_name: "Marié" }.to_struct
  #   user.first_name # => "Dorian"
  #   user.birthdate # => NoMethodError: undefined method `birthdate' for <struct...>
  #
  def to_struct
    Struct.new(*keys).new(*values)
  end
end
