require 'abstract_unit'
require 'fixtures/topic'


class TransactionTest < Test::Unit::TestCase
  self.use_transactional_fixtures = false

  fixtures :topics

  def setup
    # sqlite does not seem to return these in the right order, so we sort them
    # explicitly for sqlite's sake. sqlite3 does fine.
    @first, @second = Topic.find(1, 2).sort_by { |t| t.id }
  end

  def test_successful
    Topic.transaction do
      @first.approved  = 1
      @second.approved = 0
      @first.save
      @second.save
    end

    assert Topic.find(1).approved?, "First should have been approved"
    assert !Topic.find(2).approved?, "Second should have been unapproved"
  end

  def test_successful_with_instance_method
    @first.transaction do
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
    assert !@first.approved?, "First should be unapproved initially"

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
  
  def test_callback_rollback_in_save
    add_exception_raising_after_save_callback_to_topic

    begin
      @first.approved = true
      @first.save
      flunk
    rescue => e
      assert_equal "Make the transaction rollback", e.message
      assert !Topic.find(1).approved?
    ensure
      remove_exception_raising_after_save_callback_to_topic
    end
  end

  def test_nested_explicit_transactions
    Topic.transaction do
      Topic.transaction do
        @first.approved  = 1
        @second.approved = 0
        @first.save
        @second.save
      end
    end

    assert Topic.find(1).approved?, "First should have been approved"
    assert !Topic.find(2).approved?, "Second should have been unapproved"
  end
    

  private
    def add_exception_raising_after_save_callback_to_topic
      Topic.class_eval { def after_save() raise "Make the transaction rollback" end }
    end
    
    def remove_exception_raising_after_save_callback_to_topic
      Topic.class_eval { remove_method :after_save }
    end
end
