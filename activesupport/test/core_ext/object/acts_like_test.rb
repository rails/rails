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
end
