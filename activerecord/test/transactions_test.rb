require 'abstract_unit'
require 'fixtures/topic'
require 'fixtures/reply'
require 'fixtures/developer'

class TransactionTest < Test::Unit::TestCase
  self.use_transactional_fixtures = false
  fixtures :topics, :developers

  def setup
    @first, @second = Topic.find(1, 2).sort_by { |t| t.id }
  end

  def test_successful
    Topic.transaction do
      @first.approved  = true
      @second.approved = false
      @first.save
      @second.save
    end

    assert Topic.find(1).approved?, "First should have been approved"
    assert !Topic.find(2).approved?, "Second should have been unapproved"
  end

  def transaction_with_return
    Topic.transaction do
      @first.approved  = true
      @second.approved = false
      @first.save
      @second.save
      return
    end
  end

  def test_successful_with_return
    class << Topic.connection
      alias :real_commit_db_transaction :commit_db_transaction
      def commit_db_transaction
        $committed = true
        real_commit_db_transaction
      end
    end

    $committed = false
    transaction_with_return
    assert $committed

    assert Topic.find(1).approved?, "First should have been approved"
    assert !Topic.find(2).approved?, "Second should have been unapproved"
  ensure
    class << Topic.connection
      alias :commit_db_transaction :real_commit_db_transaction rescue nil
    end
  end

  def test_successful_with_instance_method
    @first.transaction do
      @first.approved  = true
      @second.approved = false
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
  
  def test_callback_rollback_in_create
    new_topic = Topic.new(
      :title => "A new topic",
      :author_name => "Ben",
      :author_email_address => "ben@example.com",
      :written_on => "2003-07-16t15:28:11.2233+01:00",
      :last_read => "2004-04-15",
      :bonus_time => "2005-01-30t15:28:00.00+01:00",
      :content => "Have a nice day",
      :approved => false)
    new_record_snapshot = new_topic.new_record?
    id_present = new_topic.has_attribute?(Topic.primary_key)
    id_snapshot = new_topic.id

    # Make sure the second save gets the after_create callback called.
    2.times do
      begin
        add_exception_raising_after_create_callback_to_topic
        new_topic.approved = true
        new_topic.save
        flunk
      rescue => e
        assert_equal "Make the transaction rollback", e.message
        assert_equal new_record_snapshot, new_topic.new_record?, "The topic should have its old new_record value"
        assert_equal id_snapshot, new_topic.id, "The topic should have its old id"
        assert_equal id_present, new_topic.has_attribute?(Topic.primary_key)
      ensure
        remove_exception_raising_after_create_callback_to_topic
      end
    end
  end

  def test_nested_explicit_transactions
    Topic.transaction do
      Topic.transaction do
        @first.approved  = true
        @second.approved = false
        @first.save
        @second.save
      end
    end

    assert Topic.find(1).approved?, "First should have been approved"
    assert !Topic.find(2).approved?, "Second should have been unapproved"
  end

  def test_manually_rolling_back_a_transaction
    Topic.transaction do 
      @first.approved  = true
      @second.approved = false
      @first.save
      @second.save
      
      raise ActiveRecord::Rollback
    end

    assert @first.approved?, "First should still be changed in the objects"
    assert !@second.approved?, "Second should still be changed in the objects"
    
    assert !Topic.find(1).approved?, "First shouldn't have been approved"
    assert Topic.find(2).approved?, "Second should still be approved"
  end


  private
    def add_exception_raising_after_save_callback_to_topic
      Topic.class_eval { def after_save() raise "Make the transaction rollback" end }
    end
    
    def remove_exception_raising_after_save_callback_to_topic
      Topic.class_eval { remove_method :after_save }
    end
    
    def add_exception_raising_after_create_callback_to_topic
      Topic.class_eval { def after_create() raise "Make the transaction rollback" end }
    end
    
    def remove_exception_raising_after_create_callback_to_topic
      Topic.class_eval { remove_method :after_create }
    end
end

if current_adapter?(:PostgreSQLAdapter)
  class ConcurrentTransactionTest < TransactionTest
    def setup
      @allow_concurrency = ActiveRecord::Base.allow_concurrency
      ActiveRecord::Base.allow_concurrency = true
      super
    end

    def teardown
      super
      ActiveRecord::Base.allow_concurrency = @allow_concurrency
    end

    # This will cause transactions to overlap and fail unless they are performed on
    # separate database connections.
    def test_transaction_per_thread
      assert_nothing_raised do
        threads = (1..3).map do
          Thread.new do
            Topic.transaction do
              topic = Topic.find(1)
              topic.approved = !topic.approved?
              topic.save!
              topic.approved = !topic.approved?
              topic.save!
            end
          end
        end

        threads.each { |t| t.join }
      end
    end

    # Test for dirty reads among simultaneous transactions.
    def test_transaction_isolation__read_committed
      # Should be invariant.
      original_salary = Developer.find(1).salary
      temporary_salary = 200000

      assert_nothing_raised do
        threads = (1..3).map do
          Thread.new do
            Developer.transaction do
              # Expect original salary.
              dev = Developer.find(1)
              assert_equal original_salary, dev.salary

              dev.salary = temporary_salary
              dev.save!

              # Expect temporary salary.
              dev = Developer.find(1)
              assert_equal temporary_salary, dev.salary

              dev.salary = original_salary
              dev.save!

              # Expect original salary.
              dev = Developer.find(1)
              assert_equal original_salary, dev.salary
            end
          end
        end

        # Keep our eyes peeled.
        threads << Thread.new do
          10.times do
            sleep 0.05
            Developer.transaction do
              # Always expect original salary.
              assert_equal original_salary, Developer.find(1).salary
            end
          end
        end

        threads.each { |t| t.join }
      end

      assert_equal original_salary, Developer.find(1).salary
    end
  end
end
