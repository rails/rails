# frozen_string_literal: true

class Customer < ActiveRecord::Base
  cattr_accessor :gps_conversion_was_run

  composed_of :address, mapping: [ %w(address_street street), %w(address_city city), %w(address_country country) ], allow_nil: true
  composed_of :balance, class_name: "Money", mapping: %w(balance amount)
  composed_of :gps_location, allow_nil: true
  composed_of :non_blank_gps_location, class_name: "GpsLocation", allow_nil: true, mapping: %w(gps_location gps_location),
              converter: lambda { |gps| self.gps_conversion_was_run = true; gps.blank? ? nil : GpsLocation.new(gps) }
  composed_of :fullname, mapping: %w(name to_s), constructor: Proc.new { |name| Fullname.parse(name) }, converter: :parse
  composed_of :fullname_no_converter, mapping: %w(name to_s), class_name: "Fullname"
end

class Address
  attr_reader :street, :city, :country

  def initialize(street, city, country)
    @street, @city, @country = street, city, country
  end

  def close_to?(other_address)
    city == other_address.city && country == other_address.country
  end

  def ==(other)
    other.is_a?(self.class) && other.street == street && other.city == city && other.country == country
  end
end

class Money
  attr_reader :amount, :currency

  EXCHANGE_RATES = { "USD_TO_DKK" => 6, "DKK_TO_USD" => 0.6 }

  def initialize(amount, currency = "USD")
    @amount, @currency = amount, currency
  end

  def exchange_to(other_currency)
    Money.new((amount * EXCHANGE_RATES["#{currency}_TO_#{other_currency}"]).floor, other_currency)
  end
end

class GpsLocation
  attr_reader :gps_location

  def initialize(gps_location)
    @gps_location = gps_location
  end

  def latitude
    gps_location.split("x").first
  end

  def longitude
    gps_location.split("x").last
  end

  def ==(other)
    latitude == other.latitude && longitude == other.longitude
  end
end

class Fullname
  attr_reader :first, :last

  def self.parse(str)
    return nil unless str

    if str.is_a?(Hash)
      new(str[:first], str[:last])
    else
      new(*str.to_s.split)
    end
  end

  def initialize(first, last = nil)
    @first, @last = first, last
  end

  def to_s
    "#{first} #{last.upcase}"
  end
end
