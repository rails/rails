# frozen_string_literal: true

require 'cases/helper'

class Mixin < ActiveRecord::Base
end

class TouchTest < ActiveRecord::TestCase
  fixtures :mixins

  setup do
    travel_to Time.now
  end

  def test_update
    stamped = Mixin.new

    assert_nil stamped.updated_at
    assert_nil stamped.created_at
    stamped.save
    assert_equal Time.now, stamped.updated_at
    assert_equal Time.now, stamped.created_at
  end

  def test_create
    obj = Mixin.create
    assert_equal Time.now, obj.updated_at
    assert_equal Time.now, obj.created_at
  end

  def test_many_updates
    stamped = Mixin.new

    assert_nil stamped.updated_at
    assert_nil stamped.created_at
    stamped.save
    assert_equal Time.now, stamped.created_at
    assert_equal Time.now, stamped.updated_at

    old_updated_at = stamped.updated_at

    travel 5.minutes
    stamped.lft_will_change!
    stamped.save

    assert_equal Time.now, stamped.updated_at
    assert_equal old_updated_at, stamped.created_at
  end

  def test_create_turned_off
    Mixin.record_timestamps = false

    mixin = Mixin.new

    assert_nil mixin.updated_at
    mixin.save
    assert_nil mixin.updated_at

  # Make sure Mixin.record_timestamps gets reset, even if this test fails,
  # so that other tests do not fail because Mixin.record_timestamps == false
  ensure
    Mixin.record_timestamps = true
  end
end
