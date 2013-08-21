require 'cases/helper'
require 'models/company'
require 'models/developer'
require 'models/car'
require 'models/bulb'

class IntegrationTest < ActiveRecord::TestCase
  fixtures :companies, :developers

  def test_to_param_should_return_string
    assert_kind_of String, Client.first.to_param
  end

  def test_to_param_returns_nil_if_not_persisted
    client = Client.new
    assert_equal nil, client.to_param
  end

  def test_to_param_returns_id_if_not_persisted_but_id_is_set
    client = Client.new
    client.id = 1
    assert_equal '1', client.to_param
  end

  def test_cache_key_for_existing_record_is_not_timezone_dependent
    ActiveRecord::Base.time_zone_aware_attributes = true

    Time.zone = 'UTC'
    utc_key = Developer.first.cache_key

    Time.zone = 'EST'
    est_key = Developer.first.cache_key

    assert_equal utc_key, est_key
  ensure
    Time.zone = 'UTC'
  end

  def test_cache_key_format_for_existing_record_with_updated_at
    dev = Developer.first
    assert_equal "developers/#{dev.id}-#{dev.updated_at.utc.to_s(:nsec)}", dev.cache_key
  end

  def test_cache_key_format_for_existing_record_with_updated_at_and_custom_cache_timestamp_format
    dev = CachedDeveloper.first
    assert_equal "cached_developers/#{dev.id}-#{dev.updated_at.utc.to_s(:number)}", dev.cache_key
  end

  def test_cache_key_changes_when_child_touched
    car = Car.create
    Bulb.create(car: car)

    key = car.cache_key
    car.bulb.touch
    car.reload
    assert_not_equal key, car.cache_key
  end

  def test_cache_key_format_for_existing_record_with_nil_updated_timestamps
    dev = Developer.first
    dev.update_columns(updated_at: nil, updated_on: nil)
    assert_match(/\/#{dev.id}$/, dev.cache_key)
  end

  def test_cache_key_for_updated_on
    dev = Developer.first
    dev.updated_at = nil
    assert_equal "developers/#{dev.id}-#{dev.updated_on.utc.to_s(:nsec)}", dev.cache_key
  end

  def test_cache_key_for_newer_updated_at
    dev = Developer.first
    dev.updated_at += 3600
    assert_equal "developers/#{dev.id}-#{dev.updated_at.utc.to_s(:nsec)}", dev.cache_key
  end

  def test_cache_key_for_newer_updated_on
    dev = Developer.first
    dev.updated_on += 3600
    assert_equal "developers/#{dev.id}-#{dev.updated_on.utc.to_s(:nsec)}", dev.cache_key
  end

  def test_cache_key_format_is_precise_enough
    dev = Developer.first
    key = dev.cache_key
    dev.touch
    assert_not_equal key, dev.cache_key
  end
end
