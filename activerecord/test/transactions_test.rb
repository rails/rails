require 'abstract_unit'
require 'fixtures/topic'

class TransactionTest < Test::Unit::TestCase
  def setup
    @topics         = create_fixtures "topics"
    @first, @second = Topic.find(1, 2)
  end

  def test_succesful
    Topic.transaction do
      @first.approved  = 1
      @second.approved = 0
      @first.save
      @second.save
    end
    
    assert Topic.find(1).approved?, "First should have been approved"
    assert !Topic.find(2).approved?, "Second should have been unapproved"
  end
  
  def test_failing_on_exception
    begin
      Topic.transaction do
        @first.approved  = true
        @second.approved = false
        @first.save
        @second.save
        raise "Bad things!"
      end
    rescue
      # caught it
    end

    assert @first.approved?, "First should still be changed in the objects"
    assert !@second.approved?, "Second should still be changed in the objects"
    
    assert !Topic.find(1).approved?, "First shouldn't have been approved"
    assert Topic.find(2).approved?, "Second should still be approved"
  end
  
  def test_failing_with_object_rollback
    begin
      Topic.transaction(@first, @second) do
        @first.approved  = true
        @second.approved = false
        @first.save
        @second.save
        raise "Bad things!"
      end
    rescue
      # caught it
    end
    
    assert !@first.approved?, "First shouldn't have been approved"
    assert @second.approved?, "Second should still be approved"
  end
end