# frozen_string_literal: true

require "abstract_unit"
require "active_support/core_ext/object"

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

    assert !object.acts_like?(:time)
    assert !object.acts_like?(:date)

    assert time.acts_like?(:time)
    assert !time.acts_like?(:date)

    assert !date.acts_like?(:time)
    assert date.acts_like?(:date)

    assert dt.acts_like?(:time)
    assert dt.acts_like?(:date)

    assert duck.acts_like?(:time)
    assert !duck.acts_like?(:date)
  end
end
