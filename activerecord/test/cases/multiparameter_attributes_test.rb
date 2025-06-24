# frozen_string_literal: true

require "cases/helper"
require "models/topic"
require "models/customer"

class MultiParameterAttributeTest < ActiveRecord::TestCase
  fixtures :topics

  def test_multiparameter_attributes_on_date
    attributes = { "last_read(1i)" => "2004", "last_read(2i)" => "6", "last_read(3i)" => "24" }
    topic = Topic.find(1)
    topic.attributes = attributes
    # note that extra #to_date call allows test to pass for Oracle, which
    # treats dates/times the same
    assert_equal Date.new(2004, 6, 24), topic.last_read.to_date
  end

  def test_multiparameter_attributes_on_date_with_empty_year
    attributes = { "last_read(1i)" => "", "last_read(2i)" => "6", "last_read(3i)" => "24" }
    topic = Topic.find(1)
    topic.attributes = attributes
    assert_nil topic.last_read
  end

  def test_multiparameter_attributes_on_date_with_empty_month
    attributes = { "last_read(1i)" => "2004", "last_read(2i)" => "", "last_read(3i)" => "24" }
    topic = Topic.find(1)
    topic.attributes = attributes
    assert_nil topic.last_read
  end

  def test_multiparameter_attributes_on_date_with_empty_day
    attributes = { "last_read(1i)" => "2004", "last_read(2i)" => "6", "last_read(3i)" => "" }
    topic = Topic.find(1)
    topic.attributes = attributes
    assert_nil topic.last_read
  end

  def test_multiparameter_attributes_on_date_with_empty_day_and_year
    attributes = { "last_read(1i)" => "", "last_read(2i)" => "6", "last_read(3i)" => "" }
    topic = Topic.find(1)
    topic.attributes = attributes
    assert_nil topic.last_read
  end

  def test_multiparameter_attributes_on_date_with_empty_day_and_month
    attributes = { "last_read(1i)" => "2004", "last_read(2i)" => "", "last_read(3i)" => "" }
    topic = Topic.find(1)
    topic.attributes = attributes
    assert_nil topic.last_read
  end

  def test_multiparameter_attributes_on_date_with_empty_year_and_month
    attributes = { "last_read(1i)" => "", "last_read(2i)" => "", "last_read(3i)" => "24" }
    topic = Topic.find(1)
    topic.attributes = attributes
    assert_nil topic.last_read
  end

  def test_multiparameter_attributes_on_date_with_all_empty
    attributes = { "last_read(1i)" => "", "last_read(2i)" => "", "last_read(3i)" => "" }
    topic = Topic.find(1)
    topic.attributes = attributes
    assert_nil topic.last_read
  end

  def test_multiparameter_attributes_on_time
    with_timezone_config default: :local do
      attributes = {
        "written_on(1i)" => "2004", "written_on(2i)" => "6", "written_on(3i)" => "24",
        "written_on(4i)" => "16", "written_on(5i)" => "24", "written_on(6i)" => "00"
      }
      topic = Topic.find(1)
      topic.attributes = attributes
      assert_equal Time.local(2004, 6, 24, 16, 24, 0), topic.written_on
    end
  end

  def test_multiparameter_attributes_on_time_with_no_date
    ex = assert_raise(ActiveRecord::MultiparameterAssignmentErrors) do
      attributes = {
        "written_on(4i)" => "16", "written_on(5i)" => "24", "written_on(6i)" => "00"
      }
      topic = Topic.find(1)
      topic.attributes = attributes
    end
    assert_equal("written_on", ex.errors[0].attribute)
  end

  def test_multiparameter_attributes_on_time_with_invalid_time_params
    ex = assert_raise(ActiveRecord::MultiparameterAssignmentErrors) do
      attributes = {
        "written_on(1i)" => "2004", "written_on(2i)" => "6", "written_on(3i)" => "24",
        "written_on(4i)" => "2004", "written_on(5i)" => "36", "written_on(6i)" => "64",
      }
      topic = Topic.find(1)
      topic.attributes = attributes
    end
    assert_equal("written_on", ex.errors[0].attribute)
  end

  def test_multiparameter_attributes_on_time_with_old_date
    attributes = {
      "written_on(1i)" => "1850", "written_on(2i)" => "6", "written_on(3i)" => "24",
      "written_on(4i)" => "16", "written_on(5i)" => "24", "written_on(6i)" => "00"
    }
    topic = Topic.find(1)
    topic.attributes = attributes
    # testing against to_fs(:db) representation because either a Time or a DateTime might be returned, depending on platform
    assert_equal "1850-06-24 16:24:00", topic.written_on.to_fs(:db)
  end

  def test_multiparameter_attributes_on_time_will_raise_on_big_time_if_missing_date_parts
    ex = assert_raise(ActiveRecord::MultiparameterAssignmentErrors) do
      attributes = {
        "written_on(4i)" => "16", "written_on(5i)" => "24"
      }
      topic = Topic.find(1)
      topic.attributes = attributes
    end
    assert_equal("written_on", ex.errors[0].attribute)
  end

  def test_multiparameter_attributes_on_time_with_raise_on_small_time_if_missing_date_parts
    ex = assert_raise(ActiveRecord::MultiparameterAssignmentErrors) do
      attributes = {
        "written_on(4i)" => "16", "written_on(5i)" => "12", "written_on(6i)" => "02"
      }
      topic = Topic.find(1)
      topic.attributes = attributes
    end
    assert_equal("written_on", ex.errors[0].attribute)
  end

  def test_multiparameter_attributes_on_time_will_ignore_hour_if_missing
    with_timezone_config default: :local do
      attributes = {
        "written_on(1i)" => "2004", "written_on(2i)" => "12", "written_on(3i)" => "12",
        "written_on(5i)" => "12", "written_on(6i)" => "02"
      }
      topic = Topic.find(1)
      topic.attributes = attributes
      assert_equal Time.local(2004, 12, 12, 0, 12, 2), topic.written_on
    end
  end

  def test_multiparameter_attributes_on_time_will_ignore_hour_if_blank
    attributes = {
      "written_on(1i)" => "", "written_on(2i)" => "", "written_on(3i)" => "",
      "written_on(4i)" => "", "written_on(5i)" => "12", "written_on(6i)" => "02"
    }
    topic = Topic.find(1)
    topic.attributes = attributes
    assert_nil topic.written_on
  end

  def test_multiparameter_attributes_on_time_will_ignore_date_if_empty
    attributes = {
      "written_on(1i)" => "", "written_on(2i)" => "", "written_on(3i)" => "",
      "written_on(4i)" => "16", "written_on(5i)" => "24"
    }
    topic = Topic.find(1)
    topic.attributes = attributes
    assert_nil topic.written_on
  end

  def test_multiparameter_attributes_on_time_with_seconds_will_ignore_date_if_empty
    attributes = {
      "written_on(1i)" => "", "written_on(2i)" => "", "written_on(3i)" => "",
      "written_on(4i)" => "16", "written_on(5i)" => "12", "written_on(6i)" => "02"
    }
    topic = Topic.find(1)
    topic.attributes = attributes
    assert_nil topic.written_on
  end

  def test_multiparameter_attributes_on_time_with_utc
    with_timezone_config default: :utc do
      attributes = {
        "written_on(1i)" => "2004", "written_on(2i)" => "6", "written_on(3i)" => "24",
        "written_on(4i)" => "16", "written_on(5i)" => "24", "written_on(6i)" => "00"
      }
      topic = Topic.find(1)
      topic.attributes = attributes
      assert_equal Time.utc(2004, 6, 24, 16, 24, 0), topic.written_on
    end
  end

  def test_multiparameter_attributes_on_time_with_time_zone_aware_attributes
    with_timezone_config default: :utc, aware_attributes: true, zone: -28800 do
      Topic.reset_column_information
      attributes = {
        "written_on(1i)" => "2004", "written_on(2i)" => "6", "written_on(3i)" => "24",
        "written_on(4i)" => "16", "written_on(5i)" => "24", "written_on(6i)" => "00"
      }
      topic = Topic.find(1)
      topic.attributes = attributes
      assert_equal Time.utc(2004, 6, 24, 23, 24, 0), topic.written_on
      assert_equal Time.utc(2004, 6, 24, 16, 24, 0), topic.written_on.time
      assert_equal Time.zone, topic.written_on.time_zone
    end
  ensure
    Topic.reset_column_information
  end

  def test_multiparameter_attributes_on_time_with_time_zone_aware_attributes_and_invalid_time_params
    with_timezone_config aware_attributes: true do
      Topic.reset_column_information
      attributes = {
        "written_on(1i)" => "2004", "written_on(2i)" => "", "written_on(3i)" => ""
      }
      topic = Topic.find(1)
      topic.attributes = attributes
      assert_nil topic.written_on
    end
  ensure
    Topic.reset_column_information
  end

  def test_multiparameter_attributes_on_time_with_time_zone_aware_attributes_false
    with_timezone_config default: :local, aware_attributes: false, zone: -28800 do
      attributes = {
        "written_on(1i)" => "2004", "written_on(2i)" => "6", "written_on(3i)" => "24",
        "written_on(4i)" => "16", "written_on(5i)" => "24", "written_on(6i)" => "00"
      }
      topic = Topic.find(1)
      topic.attributes = attributes
      assert_equal Time.local(2004, 6, 24, 16, 24, 0), topic.written_on
      assert_not_respond_to topic.written_on, :time_zone
    end
  end

  def test_multiparameter_attributes_on_time_with_skip_time_zone_conversion_for_attributes
    with_timezone_config default: :utc, aware_attributes: true, zone: -28800 do
      Topic.skip_time_zone_conversion_for_attributes = [:written_on]
      Topic.reset_column_information
      attributes = {
        "written_on(1i)" => "2004", "written_on(2i)" => "6", "written_on(3i)" => "24",
        "written_on(4i)" => "16", "written_on(5i)" => "24", "written_on(6i)" => "00"
      }
      topic = Topic.find(1)
      topic.attributes = attributes
      assert_equal Time.utc(2004, 6, 24, 16, 24, 0), topic.written_on
      assert_not_respond_to topic.written_on, :time_zone
    end
  ensure
    Topic.skip_time_zone_conversion_for_attributes = []
    Topic.reset_column_information
  end

  def test_multiparameter_attributes_on_time_only_column_with_time_zone_aware_attributes_does_not_do_time_zone_conversion
    with_timezone_config default: :utc, aware_attributes: true, zone: -28800 do
      Topic.reset_column_information
      attributes = {
        "bonus_time(1i)" => "2000", "bonus_time(2i)" => "1", "bonus_time(3i)" => "1",
        "bonus_time(4i)" => "16", "bonus_time(5i)" => "24"
      }
      topic = Topic.find(1)
      topic.attributes = attributes
      assert_equal Time.zone.local(2000, 1, 1, 16, 24, 0), topic.bonus_time
      assert_not_predicate topic.bonus_time, :utc?

      attributes = {
        "written_on(1i)" => "2000", "written_on(2i)" => "", "written_on(3i)" => "",
        "written_on(4i)" => "", "written_on(5i)" => ""
      }
      topic.attributes = attributes
      assert_nil topic.written_on
    end
  ensure
    Topic.reset_column_information
  end

  def test_multiparameter_attributes_setting_time_attribute
    topic = Topic.new("bonus_time(4i)" => "01", "bonus_time(5i)" => "05")
    assert_equal 1, topic.bonus_time.hour
    assert_equal 5, topic.bonus_time.min
  end

  def test_multiparameter_attributes_on_time_with_empty_seconds
    with_timezone_config default: :local do
      attributes = {
        "written_on(1i)" => "2004", "written_on(2i)" => "6", "written_on(3i)" => "24",
        "written_on(4i)" => "16", "written_on(5i)" => "24", "written_on(6i)" => ""
      }
      topic = Topic.find(1)
      topic.attributes = attributes
      assert_equal Time.local(2004, 6, 24, 16, 24, 0), topic.written_on
    end
  end

  def test_multiparameter_attributes_setting_date_attribute
    topic = Topic.new("written_on(1i)" => "1952", "written_on(2i)" => "3", "written_on(3i)" => "11")
    assert_equal 1952, topic.written_on.year
    assert_equal 3, topic.written_on.month
    assert_equal 11, topic.written_on.day
  end

  def test_create_with_multiparameter_attributes_setting_date_attribute
    topic = Topic.create_with("written_on(1i)" => "1952", "written_on(2i)" => "3", "written_on(3i)" => "11").new
    assert_equal 1952, topic.written_on.year
    assert_equal 3, topic.written_on.month
    assert_equal 11, topic.written_on.day
  end

  def test_multiparameter_attributes_setting_date_and_time_attribute
    topic = Topic.new(
      "written_on(1i)" => "1952",
      "written_on(2i)" => "3",
      "written_on(3i)" => "11",
      "written_on(4i)" => "13",
      "written_on(5i)" => "55")
    assert_equal 1952, topic.written_on.year
    assert_equal 3, topic.written_on.month
    assert_equal 11, topic.written_on.day
    assert_equal 13, topic.written_on.hour
    assert_equal 55, topic.written_on.min
  end

  def test_create_with_multiparameter_attributes_setting_date_and_time_attribute
    topic = Topic.create_with(
      "written_on(1i)" => "1952",
      "written_on(2i)" => "3",
      "written_on(3i)" => "11",
      "written_on(4i)" => "13",
      "written_on(5i)" => "55").new
    assert_equal 1952, topic.written_on.year
    assert_equal 3, topic.written_on.month
    assert_equal 11, topic.written_on.day
    assert_equal 13, topic.written_on.hour
    assert_equal 55, topic.written_on.min
  end

  def test_multiparameter_attributes_setting_time_but_not_date_on_date_field
    assert_raise(ActiveRecord::MultiparameterAssignmentErrors) do
      Topic.new("written_on(4i)" => "13", "written_on(5i)" => "55")
    end
  end

  def test_multiparameter_assignment_of_aggregation
    customer = Customer.new
    address = Address.new("The Street", "The City", "The Country")
    attributes = { "address(1)" => address.street, "address(2)" => address.city, "address(3)" => address.country }
    customer.attributes = attributes
    assert_equal address, customer.address
  end

  def test_multiparameter_assignment_of_aggregation_out_of_order
    customer = Customer.new
    address = Address.new("The Street", "The City", "The Country")
    attributes = { "address(3)" => address.country, "address(2)" => address.city, "address(1)" => address.street }
    customer.attributes = attributes
    assert_equal address, customer.address
  end

  def test_multiparameter_assignment_of_aggregation_with_missing_values
    ex = assert_raise(ActiveRecord::MultiparameterAssignmentErrors) do
      customer = Customer.new
      address = Address.new("The Street", "The City", "The Country")
      attributes = { "address(2)" => address.city, "address(3)" => address.country }
      customer.attributes = attributes
    end
    assert_equal("address", ex.errors[0].attribute)
  end

  def test_multiparameter_assignment_of_aggregation_with_blank_values
    customer = Customer.new
    address = Address.new("The Street", "The City", "The Country")
    attributes = { "address(1)" => "", "address(2)" => address.city, "address(3)" => address.country }
    customer.attributes = attributes
    assert_equal Address.new(nil, "The City", "The Country"), customer.address
  end

  def test_multiparameter_assignment_of_aggregation_with_large_index
    ex = assert_raise(ActiveRecord::MultiparameterAssignmentErrors) do
      customer = Customer.new
      address = Address.new("The Street", "The City", "The Country")
      attributes = { "address(1)" => "The Street", "address(2)" => address.city, "address(3000)" => address.country }
      customer.attributes = attributes
    end

    assert_equal("address", ex.errors[0].attribute)
  end

  def test_multiparameter_assigned_attributes_did_not_come_from_user
    topic = Topic.new(
      "written_on(1i)" => "1952",
      "written_on(2i)" => "3",
      "written_on(3i)" => "11",
      "written_on(4i)" => "13",
      "written_on(5i)" => "55",
    )
    assert_not_predicate topic, :written_on_came_from_user?
  end
end
