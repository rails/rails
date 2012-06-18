class Customer < ActiveRecord::Base
  cattr_accessor :gps_conversion_was_run
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
    self.latitude == other.latitude && self.longitude == other.longitude
  end
end

class Fullname
  attr_reader :first, :last

  def self.parse(str)
    return nil unless str
    new(*str.to_s.split)
  end

  def initialize(first, last = nil)
    @first, @last = first, last
  end

  def to_s
    "#{first} #{last.upcase}"
  end
end
