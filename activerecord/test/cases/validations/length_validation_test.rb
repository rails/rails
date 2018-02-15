# frozen_string_literal: true

require "cases/helper"
require "models/owner"
require "models/pet"
require "models/person"

class LengthValidationTest < ActiveRecord::TestCase
  fixtures :owners

  setup do
    @owner = Class.new(Owner) do
      def self.name; "Owner"; end
    end
  end

  def test_validates_size_of_association
    assert_nothing_raised { @owner.validates_size_of :pets, minimum: 1 }
    o = @owner.new("name" => "nopets")
    assert !o.save
    assert_predicate o.errors[:pets], :any?
    o.pets.build("name" => "apet")
    assert_predicate o, :valid?
  end

  def test_validates_size_of_association_using_within
    assert_nothing_raised { @owner.validates_size_of :pets, within: 1..2 }
    o = @owner.new("name" => "nopets")
    assert !o.save
    assert_predicate o.errors[:pets], :any?

    o.pets.build("name" => "apet")
    assert_predicate o, :valid?

    2.times { o.pets.build("name" => "apet") }
    assert !o.save
    assert_predicate o.errors[:pets], :any?
  end

  def test_validates_size_of_association_utf8
    @owner.validates_size_of :pets, minimum: 1
    o = @owner.new("name" => "あいうえおかきくけこ")
    assert !o.save
    assert_predicate o.errors[:pets], :any?
    o.pets.build("name" => "あいうえおかきくけこ")
    assert_predicate o, :valid?
  end

  def test_validates_size_of_respects_records_marked_for_destruction
    @owner.validates_size_of :pets, minimum: 1
    owner = @owner.new
    assert_not owner.save
    assert_predicate owner.errors[:pets], :any?
    pet = owner.pets.build
    assert_predicate owner, :valid?
    assert owner.save

    pet_count = Pet.count
    assert_not owner.update pets_attributes: [ { _destroy: 1, id: pet.id } ]
    assert_not_predicate owner, :valid?
    assert_predicate owner.errors[:pets], :any?
    assert_equal pet_count, Pet.count
  end

  def test_validates_length_of_virtual_attribute_on_model
    repair_validations(Pet) do
      Pet.send(:attr_accessor, :nickname)
      Pet.validates_length_of(:name, minimum: 1)
      Pet.validates_length_of(:nickname, minimum: 1)

      pet = Pet.create!(name: "Fancy Pants", nickname: "Fancy")

      assert_predicate pet, :valid?

      pet.nickname = ""

      assert_predicate pet, :invalid?
    end
  end
end
