require "cases/helper"
require 'models/house'

class UnvalidatedSaveTest < ActiveRecord::TestCase
  fixtures :houses, :doors

  def test_save_validate_false
    door  = Door.new
    last_house_id = House.order(:id).last.id
    bad_house_id = last_house_id + 10000
    house_count = House.count
    door.house_id = bad_house_id
    assert_raise(ActiveRecord::InvalidForeignKey) { door.save(validate: false) }
    assert_raise(ActiveRecord::RecordNotFound) { door.reload }
    assert_equal bad_house_id, door.house_id
    assert_raises(ActiveRecord::RecordNotFound) { House.find bad_house_id }
    assert_equal house_count, House.count
  end
  
  def test_save_validate_false_after_valid_test
    door  = Door.new
    last_house_id = House.order(:id).last.id
    bad_house_id = last_house_id + 10000
    house_count = House.count
    door.house_id = bad_house_id
    door.valid?
    assert_raise(ActiveRecord::InvalidForeignKey) { door.save(validate: false) }
    assert_raise(ActiveRecord::RecordNotFound) { door.reload }
    assert_equal bad_house_id, door.house_id
    assert_raises(ActiveRecord::RecordNotFound) { House.find bad_house_id }
    assert_equal house_count, House.count
  end
  def test_save_validate_false_after_association_created
    houseA = House.new
    door  = Door.new
    door.house = houseA
    last_house_id = House.order(:id).last.id
    bad_house_id = last_house_id + 10000
    house_count = House.count
    door.house_id = bad_house_id
    assert_raise(ActiveRecord::InvalidForeignKey) { door.save(validate: false) }
    assert_raise(ActiveRecord::RecordNotFound) { door.reload }
    assert_equal bad_house_id, door.house_id
    assert_raises(ActiveRecord::RecordNotFound) { House.find bad_house_id }
    assert_equal house_count, House.count
  end
  
  def test_save_validate_false_after_valid_test_after_association_created
    houseA = House.new
    door  = Door.new
    door.house = houseA
    last_house_id = House.order(:id).last.id
    bad_house_id = last_house_id + 10000
    house_count = House.count
    door.house_id = bad_house_id
    door.valid?
    assert_raise(ActiveRecord::InvalidForeignKey) { door.save(validate: false) }
    assert_raise(ActiveRecord::RecordNotFound) { door.reload }
    assert_equal bad_house_id, door.house_id
    assert_raises(ActiveRecord::RecordNotFound) { House.find bad_house_id }
    assert_equal house_count, House.count
  end
  
end