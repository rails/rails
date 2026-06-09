# frozen_string_literal: true

require "cases/helper"

class NormalizedAttributeTest < ActiveModel::TestCase
  class Aircraft
    include ActiveModel::API
    include ActiveModel::Attributes
    include ActiveModel::Attributes::Normalization

    attribute :manufactured_at, :datetime, default: -> { Time.current }
    attribute :name, :string
    attribute :nickname, :string
    attribute :wheels_count, :integer, default: 0
    attribute :wheels_owned_at, :datetime
  end

  class NormalizedAircraft < Aircraft
    normalizes :name, with: -> name { name.presence&.titlecase }
    normalizes :manufactured_at, with: -> time { time.noon }

    # Record-aware normalization (self: true): the normalizer runs with the
    # record as +self+, so it can read other attributes. In record-less contexts
    # the value passes through unchanged. A blank nickname defaults to the model
    # (the name without its manufacturer), e.g. "Boeing 777" => "777".
    normalizes :nickname, self: true, with: -> nickname do
      nickname.presence || name.to_s.split.drop(1).join(" ")
    end

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

  test "normalizes using the record on assignment" do
    boeing = NormalizedAircraft.new(name: "Boeing 777")
    boeing.nickname = ""
    assert_equal "777", boeing.nickname
  end

  test "leaves a present record-aware value untouched" do
    airbus = NormalizedAircraft.new(name: "Airbus A380", nickname: "Superjumbo")
    assert_equal "Superjumbo", airbus.nickname
  end

  test "skips record-aware normalization without a record" do
    # With a record a blank nickname is derived from the name (see above);
    # without one there is nothing to read, so the value is left unchanged.
    assert_equal "", NormalizedAircraft.normalize_value_for(:nickname, "")
  end

  test "can stack normalizations" do
    titlecase_then_reverse = Class.new(NormalizedAircraft) do
      normalizes :name, with: -> name { name.reverse }
    end

    assert_equal "esreveR nehT esaceltiT", titlecase_then_reverse.normalize_value_for(:name, "titlecase THEN reverse")
    assert_equal "Only Titlecase", NormalizedAircraft.normalize_value_for(:name, "ONLY titlecase")
  end

  test "does not re-apply normalization on repeated validation" do
    succ = Class.new(Aircraft) do
      normalizes :name, with: -> name { name.succ }
    end

    aircraft = succ.new(name: "a")
    assert_equal "b", aircraft.name

    aircraft.valid?
    aircraft.valid?
    assert_equal "b", aircraft.name
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
