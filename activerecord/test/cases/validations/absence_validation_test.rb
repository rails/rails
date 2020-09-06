# frozen_string_literal: true

require 'cases/helper'
require 'models/face'
require 'models/interest'
require 'models/human'
require 'models/topic'

class AbsenceValidationTest < ActiveRecord::TestCase
  def test_non_association
    boy_klass = Class.new(Human) do
      def self.name; 'Boy' end
      validates_absence_of :name
    end

    assert_predicate boy_klass.new, :valid?
    assert_not_predicate boy_klass.new(name: 'Alex'), :valid?
  end

  def test_has_one_marked_for_destruction
    boy_klass = Class.new(Human) do
      def self.name; 'Boy' end
      validates_absence_of :face
    end

    boy = boy_klass.new(face: Face.new)
    assert_not boy.valid?, 'should not be valid if has_one association is present'
    assert_equal 1, boy.errors[:face].size, 'should only add one error'

    boy.face.mark_for_destruction
    assert boy.valid?, 'should be valid if association is marked for destruction'
  end

  def test_has_many_marked_for_destruction
    boy_klass = Class.new(Human) do
      def self.name; 'Boy' end
      validates_absence_of :interests
    end
    boy = boy_klass.new
    boy.interests << [i1 = Interest.new, i2 = Interest.new]
    assert_not boy.valid?, 'should not be valid if has_many association is present'

    i1.mark_for_destruction
    assert_not boy.valid?, 'should not be valid if has_many association is present'

    i2.mark_for_destruction
    assert_predicate boy, :valid?
  end

  def test_does_not_call_to_a_on_associations
    boy_klass = Class.new(Human) do
      def self.name; 'Boy' end
      validates_absence_of :face
    end

    face_with_to_a = Face.new
    def face_with_to_a.to_a; ['(/)', '(\)']; end

    assert_nothing_raised { boy_klass.new(face: face_with_to_a).valid? }
  end

  def test_validates_absence_of_virtual_attribute_on_model
    repair_validations(Interest) do
      Interest.attr_accessor(:token)
      Interest.validates_absence_of(:token)

      interest = Interest.create!(topic: 'Thought Leadering')
      assert_predicate interest, :valid?

      interest.token = 'tl'

      assert_predicate interest, :invalid?
    end
  end
end
