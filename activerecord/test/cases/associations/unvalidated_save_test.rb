require "cases/helper"
require 'models/house'

class UnvalidatedSaveTest < ActiveRecord::TestCase
  fixtures :houses, :doors

  def test_save_validate_false
    door  = Door.new
#    puts "House IDs: #{House.order(:id).pluck(:id)}"
    last_house_id = House.order(:id).last.id
    bad_house_id = last_house_id + 10000
    house_count = House.count
#    assert_equal house, door.house
#    assert !door.persisted?
    door.house_id = bad_house_id
    door.save(validate: false)
    door.reload
    assert_equal bad_house_id, door.house_id
    assert_raises(ActiveRecord::RecordNotFound) { House.find bad_house_id }
    assert_equal house_count, House.count
  end
  
  def test_save_validate_false_after_valid_test
    door  = Door.new
#    puts "House IDs: #{House.order(:id).pluck(:id)}"
    last_house_id = House.order(:id).last.id
    bad_house_id = last_house_id + 10000
    house_count = House.count
#    assert_equal house, door.house
#    assert !door.persisted?
    door.house_id = bad_house_id
#    assert !door.valid?
#    puts door.inspect
    door.valid?
    door.save(validate: false)
    door.reload
    assert_equal bad_house_id, door.house_id
    assert_raises(ActiveRecord::RecordNotFound) { House.find bad_house_id }
    assert_equal house_count, House.count
  end
end