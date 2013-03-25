# -*- coding: utf-8 -*-
require "cases/helper"
require 'models/owner'
require 'models/pet'
require 'models/person'

class LengthValidationTest < ActiveRecord::TestCase
  fixtures :owners
  repair_validations(Owner)

  def test_validates_size_of_association
    repair_validations Owner do
      assert_nothing_raised { Owner.validates_size_of :pets, :minimum => 1 }
      o = Owner.new('name' => 'nopets')
      assert !o.save
      assert o.errors[:pets].any?
      o.pets.build('name' => 'apet')
      assert o.valid?
    end
  end

  def test_validates_size_of_association_using_within
    repair_validations Owner do
      assert_nothing_raised { Owner.validates_size_of :pets, :within => 1..2 }
      o = Owner.new('name' => 'nopets')
      assert !o.save
      assert o.errors[:pets].any?

      o.pets.build('name' => 'apet')
      assert o.valid?

      2.times { o.pets.build('name' => 'apet') }
      assert !o.save
      assert o.errors[:pets].any?
    end
  end

  def test_validates_size_of_association_utf8
    repair_validations Owner do
      assert_nothing_raised { Owner.validates_size_of :pets, :minimum => 1 }
      o = Owner.new('name' => 'あいうえおかきくけこ')
      assert !o.save
      assert o.errors[:pets].any?
      o.pets.build('name' => 'あいうえおかきくけこ')
      assert o.valid?
    end
  end

  def test_validates_size_of_reprects_records_marked_for_destruction
    assert_nothing_raised { Owner.validates_size_of :pets, minimum: 1 }
    owner = Owner.new
    assert_not owner.save
    assert owner.errors[:pets].any?
    pet = owner.pets.build
    assert owner.valid?
    assert owner.save

    pet_count = Pet.count
    assert_not owner.update_attributes pets_attributes: [ {_destroy: 1, id: pet.id} ]
    assert_not owner.valid?
    assert owner.errors[:pets].any?
    assert_equal pet_count, Pet.count
  end

end
