require 'cases/helper'
require 'models/developer'
require 'models/owner'
require 'models/pet'
require 'models/toy'
require 'models/car'

class TimestampTest < ActiveRecord::TestCase
  fixtures :developers, :owners, :pets, :toys, :cars

  def setup
    @developer = Developer.first
    @previously_updated_at = @developer.updated_at
    @car = Car.first
  end

  def test_saving_a_changed_record_updates_its_timestamp
    @developer.name = "Jack Bauer"
    @developer.save!

    assert_not_equal @previously_updated_at, @developer.updated_at
  end

  def test_saving_a_unchanged_record_doesnt_update_its_timestamp
    @developer.save!

    assert_equal @previously_updated_at, @developer.updated_at
  end

  def test_touching_a_record_updates_its_timestamp
    previous_salary = @developer.salary
    @developer.salary = previous_salary + 10000
    @developer.touch

    assert_not_equal @previously_updated_at, @developer.updated_at
    assert_equal previous_salary + 10000, @developer.salary
    assert @developer.salary_changed?, 'developer salary should have changed'
    assert @developer.changed?, 'developer should be marked as changed'
    @developer.reload
    assert_equal previous_salary, @developer.salary
  end

  def test_saving_when_record_timestamps_is_false_doesnt_update_its_timestamp
    Developer.record_timestamps = false
    @developer.name = "John Smith"
    @developer.save!

    assert_equal @previously_updated_at, @developer.updated_at
  ensure
    Developer.record_timestamps = true
  end

  def test_touching_a_different_attribute
    previously_created_at = @developer.created_at
    @developer.touch(:created_at)

    assert !@developer.created_at_changed? , 'created_at should not be changed'
    assert !@developer.changed?, 'record should not be changed'
    assert_not_equal previously_created_at, @developer.created_at
    assert_not_equal @previously_updated_at, @developer.updated_at
  end

  def test_touch_a_record_without_timestamps
    assert_nothing_raised { @car.touch }
  end

  def test_saving_a_record_with_a_belongs_to_that_specifies_touching_the_parent_should_update_the_parent_updated_at
    pet   = Pet.first
    owner = pet.owner
    previously_owner_updated_at = owner.updated_at

    pet.name = "Fluffy the Third"
    pet.save

    assert_not_equal previously_owner_updated_at, pet.owner.updated_at
  end

  def test_destroying_a_record_with_a_belongs_to_that_specifies_touching_the_parent_should_update_the_parent_updated_at
    pet   = Pet.first
    owner = pet.owner
    previously_owner_updated_at = owner.updated_at

    pet.destroy

    assert_not_equal previously_owner_updated_at, pet.owner.updated_at
  end

  def test_saving_a_record_with_a_belongs_to_that_specifies_touching_a_specific_attribute_the_parent_should_update_that_attribute
    Pet.belongs_to :owner, :touch => :happy_at

    pet   = Pet.first
    owner = pet.owner
    previously_owner_happy_at = owner.happy_at

    pet.name = "Fluffy the Third"
    pet.save

    assert_not_equal previously_owner_happy_at, pet.owner.happy_at
  ensure
    Pet.belongs_to :owner, :touch => true
  end

  def test_touching_a_record_with_a_belongs_to_that_uses_a_counter_cache_should_update_the_parent
    Pet.belongs_to :owner, :counter_cache => :use_count, :touch => true

    pet = Pet.first
    owner = pet.owner
    owner.update_attribute(:happy_at, (time = 3.days.ago))
    previously_owner_updated_at = owner.updated_at

    pet.name = "I'm a parrot"
    pet.save

    assert_not_equal previously_owner_updated_at, pet.owner.updated_at
  ensure
    Pet.belongs_to :owner, :touch => true
  end

  def test_touching_a_record_touches_parent_record_and_grandparent_record
    Toy.belongs_to :pet, :touch => true
    Pet.belongs_to :owner, :touch => true

    toy = Toy.first
    pet = toy.pet
    owner = pet.owner

    owner.update_attribute(:updated_at, (time = 3.days.ago))
    toy.touch
    owner.reload

    assert_not_equal time, owner.updated_at
  ensure
    Toy.belongs_to :pet
  end
end
