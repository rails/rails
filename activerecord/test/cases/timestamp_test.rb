require 'cases/helper'
require 'models/developer'
require 'models/owner'
require 'models/pet'

class TimestampTest < ActiveRecord::TestCase
  fixtures :developers, :owners, :pets

  def setup
    @developer = Developer.first
    @previously_updated_at = @developer.updated_at
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
  
  def test_touching_a_different_attribute
    previously_created_at = @developer.created_at
    @developer.touch(:created_at)

    assert !@developer.created_at_changed? , 'created_at should not be changed'
    assert !@developer.changed?, 'record should not be changed'
    assert_not_equal previously_created_at, @developer.created_at
    assert_not_equal @previously_updated_at, @developer.updated_at
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
end
