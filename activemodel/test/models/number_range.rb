require "active_record"
require "minitest/autorun"
require "logger"

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
