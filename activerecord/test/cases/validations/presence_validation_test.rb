# frozen_string_literal: true

require 'cases/helper'
require 'models/human'
require 'models/face'
require 'models/interest'
require 'models/speedometer'
require 'models/dashboard'

class PresenceValidationTest < ActiveRecord::TestCase
  class Boy < Human; end

  repair_validations(Boy)

  def test_validates_presence_of_non_association
    Boy.validates_presence_of(:name)
    b = Boy.new
    assert_predicate b, :invalid?

    b.name = 'Alex'
    assert_predicate b, :valid?
  end

  def test_validates_presence_of_has_one
    Boy.validates_presence_of(:face)
    b = Boy.new
    assert b.invalid?, 'should not be valid if has_one association missing'
    assert_equal 1, b.errors[:face].size, 'validates_presence_of should only add one error'
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
    def dash.to_a; ['(/)', '(\)']; end

    s = speedometer.new
    s.dashboard = dash

    assert_nothing_raised { s.valid? }
  end

  def test_validates_presence_of_virtual_attribute_on_model
    repair_validations(Interest) do
      Interest.attr_accessor(:abbreviation)
      Interest.validates_presence_of(:topic)
      Interest.validates_presence_of(:abbreviation)

      interest = Interest.create!(topic: 'Thought Leadering', abbreviation: 'tl')
      assert_predicate interest, :valid?

      interest.abbreviation = ''

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
end
