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
    assert o.errors[:pets].any?
    o.pets.build("name" => "apet")
    assert o.valid?
  end

  def test_validates_size_of_association_using_within
    assert_nothing_raised { @owner.validates_size_of :pets, within: 1..2 }
    o = @owner.new("name" => "nopets")
    assert !o.save
    assert o.errors[:pets].any?

    o.pets.build("name" => "apet")
    assert o.valid?

    2.times { o.pets.build("name" => "apet") }
    assert !o.save
    assert o.errors[:pets].any?
  end

  def test_validates_size_of_association_utf8
    @owner.validates_size_of :pets, minimum: 1
    o = @owner.new("name" => "あいうえおかきくけこ")
    assert !o.save
    assert o.errors[:pets].any?
    o.pets.build("name" => "あいうえおかきくけこ")
    assert o.valid?
  end

  def test_validates_size_of_respects_records_marked_for_destruction
    @owner.validates_size_of :pets, minimum: 1
    owner = @owner.new
    assert_not owner.save
    assert owner.errors[:pets].any?
    pet = owner.pets.build
    assert owner.valid?
    assert owner.save

    pet_count = Pet.count
    assert_not owner.update_attributes pets_attributes: [ { _destroy: 1, id: pet.id } ]
    assert_not owner.valid?
    assert owner.errors[:pets].any?
    assert_equal pet_count, Pet.count
  end

  def test_validates_length_of_virtual_attribute_on_model
    repair_validations(Pet) do
      Pet.send(:attr_accessor, :nickname)
      Pet.validates_length_of(:name, minimum: 1)
      Pet.validates_length_of(:nickname, minimum: 1)

      pet = Pet.create!(name: "Fancy Pants", nickname: "Fancy")

      assert pet.valid?

      pet.nickname = ""

      assert pet.invalid?
    end
  end

  def test_validates_size_of_association_using_is
    repair_validations Owner do
      Owner.validates_size_of :pets, :is => 2
      o = Owner.new
      assert !o.save
      assert_equal ["is the wrong length (should have length of 2)"], o.errors[:pets]
    end
  end

  def test_validates_size_of_association_using_minimum
    repair_validations Owner do
      Owner.validates_size_of :pets, :minimum => 2
      o = Owner.new
      assert !o.save
      assert_equal ["is too short (minimum length is 2)"], o.errors[:pets]
    end
  end

  def test_validates_size_of_association_using_maximum
    repair_validations Owner do
      Owner.validates_size_of :pets, :maximum => 2
      o = Owner.new
      3.times { o.pets.build('name' => 'apet') }
      assert !o.save
      assert_equal ["is too long (maximum length is 2)"], o.errors[:pets]
    end
  end
end
