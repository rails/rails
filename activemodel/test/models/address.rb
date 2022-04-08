# frozen_string_literal: true

class Address
  include ActiveModel::Serializers::JSON

  attr_accessor :address_line, :city, :state, :country

  def initialize(options = {})
    options.each { |name, value| public_send("#{name}=", value) }
  end

  def attributes
    instance_values
  end
end
