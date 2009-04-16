require 'cases/helper'
require 'models/developer'

class TimestampTest < ActiveRecord::TestCase
  fixtures :developers

  def setup
    @developer = Developer.first
    @previously_updated_at = @developer.updated_at
  end

  def test_saving_a_changed_record_updates_its_timestamp
    @developer.name = "Jack Bauer"
    @developer.save!
    
    assert @previously_updated_at != @developer.updated_at
  end
  
  def test_saving_a_unchanged_record_doesnt_update_its_timestamp
    @developer.save!
    
    assert @previously_updated_at == @developer.updated_at
  end
  
  def test_touching_a_record_updates_its_timestamp
    @developer.touch
    
    assert @previously_updated_at != @developer.updated_at
  end
end