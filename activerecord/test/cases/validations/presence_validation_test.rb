# frozen_string_literal: true

require "cases/helper"
require "models/human"
require "models/face"
require "models/interest"
require "models/speedometer"
require "models/dashboard"
require "models/minivan"

class PresenceValidationTest < ActiveRecord::TestCase
  class Boy < Human; end

  repair_validations(Boy)

  def test_validates_presence_of_non_association
    Boy.validates_presence_of(:name)
    b = Boy.new
    assert_predicate b, :invalid?

    b.name = "Alex"
    assert_predicate b, :valid?
  end

  def test_validates_presence_of_has_one
    Boy.validates_presence_of(:face)
    b = Boy.new
    assert_predicate b, :invalid?, "should not be valid if has_one association missing"
    assert_equal 1, b.errors[:face].size, "validates_presence_of should only add one error"
  end

  def test_validates_presence_of_has_one_marked_for_destruction
    Boy.validates_presence_of(:face)
    b = Boy.new
    f = Face.new
    b.face = f
    assert_predicate b, :valid?

    f.mark_for_destruction
    assert_predicate b, :invalid?
  end

  def test_validates_presence_of_has_many_marked_for_destruction
    Boy.validates_presence_of(:interests)
    b = Boy.new
    b.interests << [i1 = Interest.new, i2 = Interest.new]
    assert_predicate b, :valid?

    i1.mark_for_destruction
    assert_predicate b, :valid?

    i2.mark_for_destruction
    assert_predicate b, :invalid?
  end

  def test_validates_presence_doesnt_convert_to_array
    speedometer = Class.new(Speedometer)
    speedometer.validates_presence_of :dashboard

    dash = Dashboard.new

    # dashboard has to_a method
    def dash.to_a; ["(/)", '(\)']; end

    s = speedometer.new
    s.dashboard = dash

    assert_nothing_raised { s.valid? }
  end

  def test_validates_presence_of_virtual_attribute_on_model
    repair_validations(Interest) do
      Interest.attr_accessor(:abbreviation)
      Interest.validates_presence_of(:topic)
      Interest.validates_presence_of(:abbreviation)

      interest = Interest.create!(topic: "Thought Leadering", abbreviation: "tl")
      assert_predicate interest, :valid?

      interest.abbreviation = ""

      assert_predicate interest, :invalid?
    end
  end

  def test_validations_run_on_persisted_record
    repair_validations(Interest) do
      interest = Interest.new
      interest.save!
      assert_predicate interest, :valid?

      Interest.validates_presence_of(:topic)

      assert_not_predicate interest, :valid?
    end
  end

  def test_validates_presence_with_on_context
    repair_validations(Interest) do
      Interest.validates_presence_of(:topic, on: :required_name)
      interest = Interest.new
      interest.save!
      assert_not interest.valid?(:required_name)
    end
  end

  def test_belongs_to_has_many_presence_error_is_aliased_via_foreign_key
    # class Speedometer has belongs_to(:dashboard) and has_many(:minivans)
    repair_validations(Speedometer) do
      Speedometer.validates_presence_of(:dashboard)
      Speedometer.validates_presence_of(:minivans)
      speedometer = Speedometer.new
      speedometer.valid?

      assert speedometer.errors[:dashboard].any?,    "expected error on :dashboard"
      assert speedometer.errors[:dashboard_id].none?, "unexpected error on :dashboard_id, no alias yet"
      assert speedometer.errors[:minivans].any?,    "expected error on :minivans"
      assert speedometer.errors[:minivan_ids].none?, "unexpected error on :minivan_ids, no alias yet"

      speedometer.to_model

      assert speedometer.errors[:dashboard_id].any?, "expected error on :dashboard_id via alias"
      assert_equal speedometer.errors[:dashboard], speedometer.errors[:dashboard_id]
      assert speedometer.errors[:minivan_ids].any?, "expected error on :minivan_ids via alias"
      assert_equal speedometer.errors[:minivans], speedometer.errors[:minivan_ids]
    end
  end

  def test_belongs_to_with_custom_foreign_key_presence_error_is_aliased
    # class Face has belongs_to(:autosave_human, foreign_key: :human_id)
    repair_validations(Face) do
      Face.validates_presence_of(:autosave_human)
      face = Face.new
      face.valid?

      assert face.errors[:autosave_human].any?,    "expected error on :autosave_human"
      assert face.errors[:human_id].none?, "unexpected error on :human_id, no alias yet"

      face.to_model

      assert face.errors[:human_id].any?, "expected error on :autosave_human_id via alias"
      assert_equal face.errors[:autosave_human], face.errors[:human_id]
    end
  end
end
