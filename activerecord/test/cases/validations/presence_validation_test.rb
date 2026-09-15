# frozen_string_literal: true

require "cases/helper"
require "models/human"
require "models/face"
require "models/interest"
require "models/speedometer"
require "models/dashboard"
require "models/minivan"
require "models/cpk/car"
require "models/cpk/car_review"
require "models/cpk/book"
require "models/cpk/order"
require "models/developer"
require "models/project"

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

      assert speedometer.errors[:dashboard].any?, "expected error on :dashboard"
      assert speedometer.errors[:dashboard_id].none?, "unexpected error on :dashboard_id, no alias yet"
      assert_not speedometer.errors.include?(:dashboard_id)
      assert speedometer.errors[:minivans].any?, "expected error on :minivans"
      assert speedometer.errors[:minivan_ids].none?, "unexpected error on :minivan_ids, no alias yet"

      model = speedometer.to_model

      assert_same speedometer, model
      assert speedometer.errors[:dashboard_id].any?, "expected error on :dashboard_id via alias"
      assert_equal speedometer.errors[:dashboard], speedometer.errors[:dashboard_id]
      assert speedometer.errors.include?(:dashboard_id)
      assert speedometer.errors.has_key?(:dashboard_id)
      assert_equal speedometer.errors[:dashboard_id], speedometer.errors["dashboard_id"]
      assert speedometer.errors[:minivan_ids].any?, "expected error on :minivan_ids via alias"
      assert_equal speedometer.errors[:minivans], speedometer.errors[:minivan_ids]
      assert_not_includes speedometer.errors.messages.keys, :dashboard_id
      assert_not_includes speedometer.errors.details.keys, :dashboard_id
    end
  end

  def test_belongs_to_with_composite_foreign_key_presence_error_is_aliased
    repair_validations(Cpk::CarReview) do
      Cpk::CarReview.validates_presence_of(:car)
      review = Cpk::CarReview.new
      review.valid?

      assert review.errors[:car].any?, "expected error on :car"
      assert review.errors[:car_make].none?, "unexpected error on :car_make, no alias yet"
      assert review.errors[:car_model].none?, "unexpected error on :car_model, no alias yet"

      review.to_model

      assert review.errors[:car_make].any?, "expected error on :car_make via alias"
      assert review.errors[:car_model].any?, "expected error on :car_model via alias"
      assert_equal review.errors[:car], review.errors[:car_make]
      assert_equal review.errors[:car], review.errors[:car_model]
      assert review.errors.include?(:car_make)
      assert review.errors.include?(:car_model)
    end
  end

  def test_required_belongs_to_with_composite_foreign_key_aliases_each_key
    book = Cpk::BookWithRequiredOrder.new
    book.valid?

    assert book.errors[:order].any?, "expected error on :order"
    assert book.errors[:shop_id].none?
    assert book.errors[:order_id].none?

    book.to_model

    assert_equal book.errors[:order], book.errors[:shop_id]
    assert_equal book.errors[:order], book.errors[:order_id]
  end

  def test_has_many_with_composite_foreign_key_presence_error_is_aliased_via_ids
    repair_validations(Cpk::Order) do
      Cpk::Order.validates_presence_of(:books)
      order = Cpk::Order.new
      order.valid?

      assert order.errors[:books].any?, "expected error on :books"
      assert order.errors[:book_ids].none?, "unexpected error on :book_ids, no alias yet"

      order.to_model

      assert order.errors[:book_ids].any?, "expected error on :book_ids via alias"
      assert_equal order.errors[:books], order.errors[:book_ids]
    end
  end

  def test_belongs_to_aliases_custom_foreign_key_and_polymorphic_type
    repair_validations(Face) do
      Face.validates_presence_of(:autosave_human)
      Face.validates_presence_of(:super_human)
      face = Face.new
      face.valid?

      assert face.errors[:autosave_human].any?
      assert face.errors[:human_id].none?
      assert face.errors[:super_human].any?
      assert face.errors[:super_human_id].none?
      assert face.errors[:super_human_type].none?

      face.to_model

      assert_equal face.errors[:autosave_human], face.errors[:human_id]
      assert_equal face.errors[:super_human], face.errors[:super_human_id]
      assert_equal face.errors[:super_human], face.errors[:super_human_type]
    end
  end

  def test_habtm_presence_error_is_aliased_via_ids
    developer = Developer.new
    developer.errors.add(:projects, :blank)
    developer.to_model

    assert_equal developer.errors[:projects], developer.errors[:project_ids]
  end

  def test_to_model_is_idempotent
    repair_validations(Speedometer) do
      Speedometer.validates_presence_of(:dashboard)
      speedometer = Speedometer.new
      speedometer.valid?
      error_count = speedometer.errors.size

      model = speedometer.to_model
      errors = model.errors

      assert_equal error_count, model.errors.size
      assert_same model, model.to_model
      assert_same errors, model.to_model.errors
      assert_equal model.errors[:dashboard], model.errors[:dashboard_id]
    end
  end

  def test_aliased_errors_include_both_foreign_key_and_association_messages
    repair_validations(Speedometer) do
      speedometer = Speedometer.new
      speedometer.errors.add(:dashboard, :blank)
      speedometer.errors.add(:dashboard_id, :taken)
      speedometer.to_model

      assert_equal 2, speedometer.errors[:dashboard_id].size
      assert_includes speedometer.errors[:dashboard_id], speedometer.errors[:dashboard].first
    end
  end
end
