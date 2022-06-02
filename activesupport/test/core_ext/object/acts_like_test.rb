# frozen_string_literal: true

require_relative "../../abstract_unit"
require "active_support/core_ext/date/acts_like"
require "active_support/core_ext/string/behavior"
require "active_support/core_ext/time/acts_like"
require "active_support/core_ext/date_time/acts_like"
require "active_support/core_ext/object/acts_like"

class ObjectTests < ActiveSupport::TestCase
  class DuckTime
    def acts_like_time?
      true
    end
  end

  class Stringish < String
  end

  class DuckString
    def acts_like_string?
      true
    end
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

  def test_acts_like_string
    string = Stringish.new
    duck_string = DuckString.new

    assert string.acts_like?(:string)
    assert_not string.acts_like?(:invalid)

    assert duck_string.acts_like?(:string)
    assert_not duck_string.acts_like?(:invalid)
  end
end
