require 'abstract_unit'

class Mixin < ActiveRecord::Base
end

# Let us control what Time.now returns for the TouchTest suite
class Time
  @@forced_now_time = nil
  cattr_accessor :forced_now_time
  
  class << self
    def now_with_forcing
      if @@forced_now_time
        @@forced_now_time
      else
        now_without_forcing
      end
    end
    alias_method_chain :now, :forcing
  end
end


class TouchTest < Test::Unit::TestCase
  fixtures :mixins
  
  def setup
    Time.forced_now_time = Time.now
  end
  
  def teardown
    Time.forced_now_time = nil
  end

  def test_time_mocking
    five_minutes_ago = 5.minutes.ago
    Time.forced_now_time = five_minutes_ago
    assert_equal five_minutes_ago, Time.now
    
    Time.forced_now_time = nil
    assert_not_equal five_minutes_ago, Time.now
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

    Time.forced_now_time = 5.minutes.from_now
    stamped.save

    assert_equal Time.now, stamped.updated_at
    assert_equal old_updated_at, stamped.created_at
  end

  def test_create_turned_off
    Mixin.record_timestamps = false

    assert_nil mixins(:set_1).updated_at
    mixins(:set_1).save
    assert_nil mixins(:set_1).updated_at

    Mixin.record_timestamps = true
  end

end
