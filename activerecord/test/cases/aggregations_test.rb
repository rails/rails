require "cases/helper"
require 'models/customer'

class AggregationsTest < ActiveRecord::TestCase
  fixtures :customers

  def test_find_single_value_object
    assert_equal 50, customers(:david).balance.amount
    assert_kind_of Money, customers(:david).balance
    assert_equal 300, customers(:david).balance.exchange_to("DKK").amount
  end

  def test_find_multiple_value_object
    assert_equal customers(:david).address_street, customers(:david).address.street
    assert(
      customers(:david).address.close_to?(Address.new("Different Street", customers(:david).address_city, customers(:david).address_country))
    )
  end

  def test_change_single_value_object
    customers(:david).balance = Money.new(100)
    customers(:david).save
    assert_equal 100, customers(:david).reload.balance.amount
  end

  def test_immutable_value_objects
    customers(:david).balance = Money.new(100)
    assert_raise(ActiveSupport::FrozenObjectError) { customers(:david).balance.instance_eval { @amount = 20 } }
  end

  def test_inferred_mapping
    assert_equal "35.544623640962634", customers(:david).gps_location.latitude
    assert_equal "-105.9309951055148", customers(:david).gps_location.longitude

    customers(:david).gps_location = GpsLocation.new("39x-110")

    assert_equal "39", customers(:david).gps_location.latitude
    assert_equal "-110", customers(:david).gps_location.longitude

    customers(:david).save

    customers(:david).reload

    assert_equal "39", customers(:david).gps_location.latitude
    assert_equal "-110", customers(:david).gps_location.longitude
  end

  def test_reloaded_instance_refreshes_aggregations
    assert_equal "35.544623640962634", customers(:david).gps_location.latitude
    assert_equal "-105.9309951055148", customers(:david).gps_location.longitude

    Customer.update_all("gps_location = '24x113'")
    customers(:david).reload
    assert_equal '24x113', customers(:david)['gps_location']

    assert_equal GpsLocation.new('24x113'), customers(:david).gps_location
  end

  def test_gps_equality
    assert GpsLocation.new('39x110') == GpsLocation.new('39x110')
  end

  def test_gps_inequality
    assert GpsLocation.new('39x110') != GpsLocation.new('39x111')
  end

  def test_allow_nil_gps_is_nil
    assert_equal nil, customers(:zaphod).gps_location
  end

  def test_allow_nil_gps_set_to_nil
    customers(:david).gps_location = nil
    customers(:david).save
    customers(:david).reload
    assert_equal nil, customers(:david).gps_location
  end

  def test_allow_nil_set_address_attributes_to_nil
    customers(:zaphod).address = nil
    assert_equal nil, customers(:zaphod).attributes[:address_street]
    assert_equal nil, customers(:zaphod).attributes[:address_city]
    assert_equal nil, customers(:zaphod).attributes[:address_country]
  end

  def test_allow_nil_address_set_to_nil
    customers(:zaphod).address = nil
    customers(:zaphod).save
    customers(:zaphod).reload
    assert_equal nil, customers(:zaphod).address
  end

  def test_nil_raises_error_when_allow_nil_is_false
    assert_raise(NoMethodError) { customers(:david).balance = nil }
  end

  def test_allow_nil_address_loaded_when_only_some_attributes_are_nil
    customers(:zaphod).address_street = nil
    customers(:zaphod).save
    customers(:zaphod).reload
    assert_kind_of Address, customers(:zaphod).address
    assert customers(:zaphod).address.street.nil?
  end

  def test_nil_assignment_results_in_nil
    customers(:david).gps_location = GpsLocation.new('39x111')
    assert_not_equal nil, customers(:david).gps_location
    customers(:david).gps_location = nil
    assert_equal nil, customers(:david).gps_location
  end

  def test_custom_constructor
    assert_equal 'Barney GUMBLE', customers(:barney).fullname.to_s
    assert_kind_of Fullname, customers(:barney).fullname
  end

  def test_custom_converter
    customers(:barney).fullname = 'Barnoit Gumbleau'
    assert_equal 'Barnoit GUMBLEAU', customers(:barney).fullname.to_s
    assert_kind_of Fullname, customers(:barney).fullname
  end
end

class DeprecatedAggregationsTest < ActiveRecord::TestCase
  class Person < ActiveRecord::Base; end

  def test_conversion_block_is_deprecated
    assert_deprecated 'conversion block has been deprecated' do
      Person.composed_of(:balance, :class_name => "Money", :mapping => %w(balance amount)) { |balance| balance.to_money }
    end
  end

  def test_conversion_block_used_when_converter_option_is_nil
    assert_deprecated 'conversion block has been deprecated' do
      Person.composed_of(:balance, :class_name => "Money", :mapping => %w(balance amount)) { |balance| balance.to_money }
    end
    assert_raise(NoMethodError) { Person.new.balance = 5 }
  end

  def test_converter_option_overrides_conversion_block
    assert_deprecated 'conversion block has been deprecated' do
      Person.composed_of(:balance, :class_name => "Money", :mapping => %w(balance amount), :converter => Proc.new { |balance| Money.new(balance) }) { |balance| balance.to_money }
    end

    person = Person.new
    assert_nothing_raised { person.balance = 5 }
    assert_equal 5, person.balance.amount
    assert_kind_of Money, person.balance
  end
end

class OverridingAggregationsTest < ActiveRecord::TestCase
  class Name; end
  class DifferentName; end

  class Person   < ActiveRecord::Base
    composed_of :composed_of, :mapping => %w(person_first_name first_name)
  end

  class DifferentPerson < Person
    composed_of :composed_of, :class_name => 'DifferentName', :mapping => %w(different_person_first_name first_name)
  end

  def test_composed_of_aggregation_redefinition_reflections_should_differ_and_not_inherited
    assert_not_equal Person.reflect_on_aggregation(:composed_of),
                     DifferentPerson.reflect_on_aggregation(:composed_of)
  end
end
