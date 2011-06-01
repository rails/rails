require 'cases/helper'
require 'models/developer'

class TimestampTest < ActiveRecord::TestCase
  def test_load_infinity_and_beyond
    unless current_adapter?(:PostgreSQLAdapter)
      return skip("only tested on postgresql")
    end

    d = Developer.find_by_sql("select 'infinity'::timestamp as updated_at")
    assert d.first.updated_at.infinite?, 'timestamp should be infinite'

    d = Developer.find_by_sql("select '-infinity'::timestamp as updated_at")
    time = d.first.updated_at
    assert time.infinite?, 'timestamp should be infinite'
    assert_operator time, :<, 0
  end

  def test_save_infinity_and_beyond
    unless current_adapter?(:PostgreSQLAdapter)
      return skip("only tested on postgresql")
    end

    d = Developer.create!(:name => 'aaron', :updated_at => 1.0 / 0.0)
    assert_equal(1.0 / 0.0, d.updated_at)

    d = Developer.create!(:name => 'aaron', :updated_at => -1.0 / 0.0)
    assert_equal(-1.0 / 0.0, d.updated_at)
  end
end
