# frozen_string_literal: true

require "cases/helper"
require "models/aircraft"
require "active_support/core_ext/string/inflections"

class NormalizedAttributeTest < ActiveRecord::TestCase
  class NormalizedAircraft < Aircraft
    normalizes :name, with: -> name { name.presence&.titlecase }
    normalizes :manufactured_at, with: -> time { time.noon }

    attr_accessor :validated_name
    validate { self.validated_name = name.dup }
  end

  setup do
    @time = Time.utc(1999, 12, 31, 12, 34, 56)
    @aircraft = NormalizedAircraft.create!(name: "fly HIGH", manufactured_at: @time)
  end

  test "normalizes value from create" do
    assert_equal "Fly High", @aircraft.name
  end

  test "normalizes value from update" do
    @aircraft.update!(name: "fly HIGHER")
    assert_equal "Fly Higher", @aircraft.name
  end

  test "does not automatically normalize value from database" do
    from_database = NormalizedAircraft.find(Aircraft.create(name: "NOT titlecase").id)
    assert_equal "NOT titlecase", from_database.name
  end

  test "finds record by normalized value" do
    assert_equal @time.noon, @aircraft.manufactured_at
    assert_equal @aircraft, NormalizedAircraft.find_by(manufactured_at: @time.to_s)
  end

  test "uses the same query when finding record by nil and normalized nil values" do
    assert_equal NormalizedAircraft.where(name: nil).to_sql, NormalizedAircraft.where(name: "").to_sql
  end

  test "minimizes number of times normalization is applied" do
    count_applied = Class.new(Aircraft) do
      normalizes :name, with: -> name { name.succ }
    end

    aircraft = count_applied.create!(name: "0")
    assert_equal "1", aircraft.name

    aircraft.name = "0"
    assert_equal "1", aircraft.name
    aircraft.save
    assert_equal "1", aircraft.name

    aircraft.name.replace("0")
    assert_equal "0", aircraft.name
    aircraft.save
    assert_equal "1", aircraft.name
  end
end
