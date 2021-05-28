# frozen_string_literal: true

require_relative "../../abstract_unit"
require "active_support/core_ext/date/acts_like"
require "active_support/core_ext/time/acts_like"
require "active_support/core_ext/date_time/acts_like"
require "active_support/core_ext/object/acts_like"

class ObjectTests < ActiveSupport::TestCase
  class DuckTime
    def acts_like_time?
      true
    end
  end

  class TimeSubclass < Time
    def acts_like_time?
      false
    end
  end

  class DateSubclass < Date
    def acts_like_date?
      false
    end
  end

  class StringSubclass < String
    def acts_like_string?
      false
    end
  end

  class Duck
    def acts_like_duck?
      true
    end
  end

  class RubberDuck < Duck
    def acts_like_duck?
      false
    end
  end

  class DeprecatedDuck
    def acts_like_duck?; end
  end

  def test_duck_typing
    object = Object.new
    time   = Time.now
    date   = Date.today
    dt     = DateTime.new
    duck   = DuckTime.new

    assert_not object.acts_like?(:time)
    assert_not object.acts_like?(:date)

    assert time.acts_like?(:time)
    assert_not time.acts_like?(:date)

    assert_not date.acts_like?(:time)
    assert date.acts_like?(:date)

    assert dt.acts_like?(:time)
    assert dt.acts_like?(:date)

    assert duck.acts_like?(:time)
    assert_not duck.acts_like?(:date)
  end

  def test_subclasses_can_override
    time_sub = TimeSubclass.now
    date_sub = DateSubclass.today
    string_sub = StringSubclass.new
    duck = Duck.new
    rubber_duck = RubberDuck.new

    assert_not time_sub.acts_like?(:time)
    assert_not date_sub.acts_like?(:date)
    assert_not string_sub.acts_like?(:string)

    assert duck.acts_like?(:duck)
    assert_not rubber_duck.acts_like?(:duck)
  end

  def test_ignore_return_value_deprecated
    with_use_acts_like_return_value(false) do
      deprecated_duck = DeprecatedDuck.new

      deprecated_acts_like = assert_deprecated do
        deprecated_duck.acts_like?(:duck)
      end

      assert deprecated_acts_like
    end
  end

  def test_use_acts_like_return_value
    with_use_acts_like_return_value(true) do
      deprecated_duck = DeprecatedDuck.new

      acts_like = assert_not_deprecated do
        deprecated_duck.acts_like?(:duck)
      end

      assert_not acts_like
    end
  end

  private
    def with_use_acts_like_return_value(value)
      old_acts_like_return_value = ActiveSupport.use_acts_like_return_value
      ActiveSupport.use_acts_like_return_value = value
      yield
    ensure
      ActiveSupport.use_acts_like_return_value = old_acts_like_return_value
    end
end
