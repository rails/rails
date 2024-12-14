# frozen_string_literal: true

require "cases/helper"

class NormalizedAttributeTest < ActiveModel::TestCase
  class Aircraft
    include ActiveModel::API
    include ActiveModel::Attributes
    include ActiveModel::Attributes::Normalization

    attribute :manufactured_at, :datetime, default: -> { Time.current }
    attribute :name, :string
    attribute :wheels_count, :integer, default: 0
    attribute :wheels_owned_at, :datetime
  end

  class NormalizedAircraft < Aircraft
    normalizes :name, with: -> name { name.presence&.titlecase }
    normalizes :manufactured_at, with: -> time { time.noon }

    attr_accessor :validated_name
    validate { self.validated_name = name.dup }
  end

  setup do
    @time = Time.utc(1999, 12, 31, 12, 34, 56)
    @aircraft = NormalizedAircraft.new(name: "fly HIGH", manufactured_at: @time)
  end

  test "normalizes value from validation" do
    @aircraft.validate!

    assert_equal "Fly High", @aircraft.name
  end

  test "normalizes value from assignment" do
    @aircraft.name = "fly HIGHER"
    assert_equal "Fly Higher", @aircraft.name
  end

  test "normalizes changed-in-place value before validation" do
    @aircraft.name.downcase!
    assert_equal "fly high", @aircraft.name

    @aircraft.valid?
    assert_equal "Fly High", @aircraft.validated_name
  end

  test "normalizes value on demand" do
    @aircraft.name.downcase!
    assert_equal "fly high", @aircraft.name

    @aircraft.normalize_attribute(:name)
    assert_equal "Fly High", @aircraft.name
  end

  test "normalizes value without model" do
    assert_equal "Titlecase Me", NormalizedAircraft.normalize_value_for(:name, "titlecase ME")
  end

  test "casts value when no normalization is declared" do
    assert_equal 6, NormalizedAircraft.normalize_value_for(:wheels_count, "6")
  end

  test "casts value before applying normalization" do
    @aircraft.manufactured_at = @time.to_s
    assert_equal @time.noon, @aircraft.manufactured_at
  end

  test "ignores nil by default" do
    assert_nil NormalizedAircraft.normalize_value_for(:name, nil)
  end

  test "normalizes nil if apply_to_nil" do
    including_nil = Class.new(Aircraft) do
      normalizes :name, with: -> name { name&.titlecase || "Untitled" }, apply_to_nil: true
    end

    assert_equal "Untitled", including_nil.normalize_value_for(:name, nil)
  end

  test "can stack normalizations" do
    titlecase_then_reverse = Class.new(NormalizedAircraft) do
      normalizes :name, with: -> name { name.reverse }
    end

    assert_equal "esreveR nehT esaceltiT", titlecase_then_reverse.normalize_value_for(:name, "titlecase THEN reverse")
    assert_equal "Only Titlecase", NormalizedAircraft.normalize_value_for(:name, "ONLY titlecase")
  end

  test "minimizes number of times normalization is applied" do
    count_applied = Class.new(Aircraft) do
      normalizes :name, with: -> name { name.succ }
    end

    aircraft = count_applied.new(name: "0")
    assert_equal "1", aircraft.name

    aircraft.name = "0"
    assert_equal "1", aircraft.name

    aircraft.name.replace("0")
    assert_equal "0", aircraft.name
  end
end
