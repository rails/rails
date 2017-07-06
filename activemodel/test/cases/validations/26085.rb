require "active_record"
require "minitest/autorun"
require "logger"

# This connection will do for database-independent bug reports.
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Base.logger = Logger.new(STDOUT)

ActiveRecord::Schema.define do
  create_table :number_ranges, force: true do |t|
    t.decimal :high
    t.decimal :low
  end
end

class NumberRange < ActiveRecord::Base
  validates :high, numericality: { greater_than_or_equal_to: :low }
end

class BugTest < Minitest::Test
  def test_26085
    assert NumberRange.new(low: '65.6', high: '65.6').valid?
    assert NumberRange.new(low: '65.6', high: '75.6').valid?
    assert !NumberRange.new(low: '65.6', high: '55.6').valid?
  end
end
