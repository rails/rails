require 'abstract_unit'
require 'fixtures/person'
require 'fixtures/legacy_thing'

class LockingTest < Test::Unit::TestCase
  fixtures :people, :legacy_things

  def test_lock_existing
    p1 = Person.find(1)
    p2 = Person.find(1)
    
    p1.first_name = "Michael"
    p1.save
    
    assert_raises(ActiveRecord::StaleObjectError) {
      p2.first_name = "should fail"
      p2.save
    }
  end

  def test_lock_new
    p1 = Person.create({ "first_name"=>"anika"})
    p2 = Person.find(p1.id)
    assert_equal p1.id, p2.id
    p1.first_name = "Anika"
    p1.save
    
    assert_raises(ActiveRecord::StaleObjectError) {
      p2.first_name = "should fail"
      p2.save
    }
  end
  
  def test_lock_column_name_existing
    t1 = LegacyThing.find(1)
    t2 = LegacyThing.find(1)
    t1.tps_report_number = 400
    t1.save

    assert_raises(ActiveRecord::StaleObjectError) {
      t2.tps_report_number = 300
      t2.save
    }
  end 

end
