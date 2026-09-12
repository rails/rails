# frozen_string_literal: true

require "cases/helper"

class AggregationsTest < ActiveModel::TestCase
  class Money
    include Comparable
    attr_reader :amount, :currency

    def initialize(amount, currency = "USD")
      @amount, @currency = amount, currency
    end

    def ==(other)
      other.is_a?(Money) && amount == other.amount && currency == other.currency
    end

    def <=>(other)
      amount <=> other.amount
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
      other.is_a?(GpsLocation) && gps_location == other.gps_location
    end
  end

  class Customer
    include ActiveModel::API
    include ActiveModel::Aggregations
    include ActiveModel::Attributes

    attribute :balance
    attribute :balance_currency

    composed_of :balance, class_name: "AggregationsTest::Money", mapping: { balance: :amount, balance_currency: :currency }
  end

  class Vehicle
    include ActiveModel::API
    include ActiveModel::Aggregations
    include ActiveModel::Attributes

    attribute :gps_location

    composed_of :gps_location, class_name: "AggregationsTest::GpsLocation", allow_nil: true
  end

  class Truck
    include ActiveModel::API
    include ActiveModel::Aggregations
    include ActiveModel::Attributes

    attribute :gps_location, default: "39x110"

    composed_of :gps_location, class_name: "AggregationsTest::GpsLocation", allow_nil: true
  end

  class MonsterTruck < Truck
    composed_of :gps_location, class_name: "AggregationsTest::GpsLocation", allow_nil: true
  end

  class OverridingTruck < Truck
    def gps_location
      super
    end

    def gps_location=(value)
      super
    end
  end

  module GpsLocationWrapper
    def gps_location
      super
    end

    def gps_location=(value)
      super
    end
  end

  class WrappedTruck < Truck
    prepend GpsLocationWrapper
  end

  class PrivateCustomer
    include ActiveModel::Aggregations

    attr_accessor :balance_amount, :balance_currency
    private :balance_amount, :balance_amount=, :balance_currency, :balance_currency=

    composed_of :balance, class_name: "AggregationsTest::Money", mapping: { balance_amount: :amount, balance_currency: :currency }
  end

  class Event
    include ActiveModel::Aggregations

    composed_of :format, class_name: "AggregationsTest::GpsLocation", allow_nil: true
  end

  class ReversedTruck
    include ActiveModel::API
    include ActiveModel::Aggregations
    include ActiveModel::Attributes

    composed_of :gps_location, class_name: "AggregationsTest::GpsLocation", allow_nil: true

    attribute :gps_location, default: "39x110"
  end

  class PlainCustomer
    include ActiveModel::Aggregations

    attr_accessor :balance, :balance_currency

    composed_of :balance, class_name: "AggregationsTest::Money", mapping: { balance: :amount, balance_currency: :currency }
  end

  class PlainVehicle
    include ActiveModel::Aggregations

    attr_accessor :gps_location

    composed_of :gps_location, class_name: "AggregationsTest::GpsLocation", allow_nil: true
  end

  class PlainMonsterVehicle < PlainVehicle
    composed_of :gps_location, class_name: "AggregationsTest::GpsLocation", allow_nil: true
  end

  class UnmappedVehicle
    include ActiveModel::Aggregations

    composed_of :gps_location, class_name: "AggregationsTest::GpsLocation", allow_nil: true
  end

  def test_writer_assigns_mapped_attributes_and_reader_rebuilds_value_object
    customer = Customer.new
    customer.balance = Money.new(100, "DKK")

    assert_equal 100, customer.attributes["balance"]
    assert_equal "DKK", customer.attributes["balance_currency"]
    assert_equal Money.new(100, "DKK"), customer.balance
  end

  def test_value_object_is_frozen
    customer = Customer.new
    customer.balance = Money.new(50, "USD")
    assert_predicate customer.balance, :frozen?
  end

  def test_self_named_composed_of_does_not_recurse
    vehicle = Vehicle.new
    vehicle.gps_location = GpsLocation.new("39x110")
    assert_equal GpsLocation.new("39x110"), vehicle.gps_location
  end

  def test_allow_nil_skips_construction_when_all_mapped_attributes_nil
    assert_nil Vehicle.new.gps_location
  end

  def test_setting_nil_with_allow_nil_clears_mapped_attribute
    vehicle = Vehicle.new
    vehicle.gps_location = GpsLocation.new("39x110")
    vehicle.gps_location = nil
    assert_nil vehicle.gps_location
    assert_nil vehicle.attributes["gps_location"]
  end

  def test_subclass_redeclaring_self_named_composed_of_reads_the_underlying_attribute
    assert_equal GpsLocation.new("39x110"), MonsterTruck.new.gps_location
  end

  def test_subclass_redeclaring_self_named_composed_of_writes_the_underlying_attribute
    truck = MonsterTruck.new
    truck.gps_location = GpsLocation.new("24x113")

    assert_equal "24x113", truck.attributes["gps_location"]
  end

  def test_subclass_overriding_self_named_aggregation_accessors_with_super
    truck = OverridingTruck.new
    assert_equal GpsLocation.new("39x110"), truck.gps_location

    truck.gps_location = GpsLocation.new("24x113")
    assert_equal "24x113", truck.attributes["gps_location"]
    assert_equal GpsLocation.new("24x113"), truck.gps_location
  end

  def test_prepended_module_wrapping_self_named_aggregation_accessors_with_super
    truck = WrappedTruck.new
    assert_equal GpsLocation.new("39x110"), truck.gps_location

    truck.gps_location = GpsLocation.new("24x113")
    assert_equal "24x113", truck.attributes["gps_location"]
    assert_equal GpsLocation.new("24x113"), truck.gps_location
  end

  def test_attr_accessor_backed_aggregation
    customer = PlainCustomer.new
    customer.balance = Money.new(100, "DKK")

    assert_equal 100, customer.instance_variable_get(:@balance)
    assert_equal "DKK", customer.instance_variable_get(:@balance_currency)
    assert_equal Money.new(100, "DKK"), customer.balance
  end

  def test_attr_accessor_backed_self_named_aggregation
    vehicle = PlainVehicle.new
    vehicle.gps_location = GpsLocation.new("39x110")

    assert_equal "39x110", vehicle.instance_variable_get(:@gps_location)
    assert_equal GpsLocation.new("39x110"), vehicle.gps_location
  end

  def test_subclass_redeclaring_attr_accessor_backed_self_named_aggregation
    vehicle = PlainMonsterVehicle.new
    vehicle.gps_location = GpsLocation.new("39x110")
    assert_equal "39x110", vehicle.instance_variable_get(:@gps_location)

    vehicle = PlainMonsterVehicle.new
    vehicle.instance_variable_set(:@gps_location, "24x113")
    assert_equal GpsLocation.new("24x113"), vehicle.gps_location
  end

  def test_aggregation_without_an_accessor_for_its_mapped_attribute
    error = assert_raises(NoMethodError) { UnmappedVehicle.new.gps_location }
    assert_match "has no accessor for 'gps_location'", error.message
  end

  def test_aggregation_named_like_a_kernel_method_without_an_accessor
    error = assert_raises(NoMethodError) { Event.new.format }
    assert_match "has no accessor for 'format'", error.message
  end

  def test_private_accessor_backed_aggregation
    customer = PrivateCustomer.new
    customer.balance = Money.new(100, "DKK")

    assert_equal 100, customer.instance_variable_get(:@balance_amount)
    assert_equal Money.new(100, "DKK"), customer.balance
  end

  def test_reading_an_aggregation_from_a_frozen_object
    vehicle = PlainVehicle.new
    vehicle.instance_variable_set(:@gps_location, "39x110")
    vehicle.freeze

    assert_equal GpsLocation.new("39x110"), vehicle.gps_location
  end

  def test_declaring_a_shadowing_composed_of_after_first_use
    parent = Class.new do
      include ActiveModel::Aggregations
      include ActiveModel::Attributes

      attribute :gps_location, default: "39x110"
      composed_of :position, class_name: "AggregationsTest::GpsLocation", mapping: %w(gps_location gps_location)
    end
    child = Class.new(parent)
    assert_equal GpsLocation.new("39x110"), child.new.position

    parent.composed_of :gps_location, class_name: "AggregationsTest::GpsLocation"

    assert_equal GpsLocation.new("39x110"), child.new.position
    assert_equal GpsLocation.new("39x110"), child.new.gps_location
  end

  def test_composed_of_declared_before_the_attribute_it_maps
    truck = ReversedTruck.new
    assert_equal GpsLocation.new("39x110"), truck.gps_location

    truck = ReversedTruck.new
    truck.gps_location = GpsLocation.new("24x113")

    assert_equal "24x113", truck.attributes["gps_location"]
    assert_equal GpsLocation.new("24x113"), truck.gps_location
  end
end
