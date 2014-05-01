# -*- coding: utf-8 -*-
require "cases/helper"
require 'models/owner'
require 'models/pet'

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
end
