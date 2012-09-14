require "cases/helper"
require 'models/topic'
require 'models/reply'
require 'models/developer'
require 'models/book'
require 'models/author'
require 'models/post'

class TransactionTest < ActiveRecord::TestCase
  self.use_transactional_fixtures = false
  fixtures :topics, :developers, :authors, :posts

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

  # FIXME: Get rid of this fucking global variable!
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
      remove_method :commit_db_transaction
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

  def test_raising_exception_in_callback_rollbacks_in_save
    def @first.after_save_for_transaction
      raise 'Make the transaction rollback'
    end

    @first.approved = true
    e = assert_raises(RuntimeError) { @first.save }
    assert_equal "Make the transaction rollback", e.message
    assert !Topic.find(1).approved?
  end

  def test_update_attributes_should_rollback_on_failure
    author = Author.find(1)
    posts_count = author.posts.size
    assert posts_count > 0
    status = author.update_attributes(:name => nil, :post_ids => [])
    assert !status
    assert_equal posts_count, author.posts(true).size
  end

  def test_update_attributes_should_rollback_on_failure!
    author = Author.find(1)
    posts_count = author.posts.size
    assert posts_count > 0
    assert_raise(ActiveRecord::RecordInvalid) do
      author.update_attributes!(:name => nil, :post_ids => [])
    end
    assert_equal posts_count, author.posts(true).size
  end

  def test_cancellation_from_before_destroy_rollbacks_in_destroy
    add_cancelling_before_destroy_with_db_side_effect_to_topic @first
    nbooks_before_destroy = Book.count
    status = @first.destroy
    assert !status
    @first.reload
    assert_equal nbooks_before_destroy, Book.count
  end

  %w(validation save).each do |filter|
    define_method("test_cancellation_from_before_filters_rollbacks_in_#{filter}") do
      send("add_cancelling_before_#{filter}_with_db_side_effect_to_topic", @first)
      nbooks_before_save = Book.count
      original_author_name = @first.author_name
      @first.author_name += '_this_should_not_end_up_in_the_db'
      status = @first.save
      assert !status
      assert_equal original_author_name, @first.reload.author_name
      assert_equal nbooks_before_save, Book.count
    end

    define_method("test_cancellation_from_before_filters_rollbacks_in_#{filter}!") do
      send("add_cancelling_before_#{filter}_with_db_side_effect_to_topic", @first)
      nbooks_before_save = Book.count
      original_author_name = @first.author_name
      @first.author_name += '_this_should_not_end_up_in_the_db'

      begin
        @first.save!
      rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved
      end

      assert_equal original_author_name, @first.reload.author_name
      assert_equal nbooks_before_save, Book.count
    end
  end

  def test_callback_rollback_in_create
    topic = Class.new(Topic) {
      def after_create_for_transaction
        raise 'Make the transaction rollback'
      end
    }

    new_topic = topic.new(:title                => "A new topic",
                          :author_name          => "Ben",
                          :author_email_address => "ben@example.com",
                          :written_on           => "2003-07-16t15:28:11.2233+01:00",
                          :last_read            => "2004-04-15",
                          :bonus_time           => "2005-01-30t15:28:00.00+01:00",
                          :content              => "Have a nice day",
                          :approved             => false)

    new_record_snapshot = !new_topic.persisted?
    id_present = new_topic.has_attribute?(Topic.primary_key)
    id_snapshot = new_topic.id

    # Make sure the second save gets the after_create callback called.
    2.times do
      new_topic.approved = true
      e = assert_raises(RuntimeError) { new_topic.save }
      assert_equal "Make the transaction rollback", e.message
      assert_equal new_record_snapshot, !new_topic.persisted?, "The topic should have its old persisted value"
      assert_equal id_snapshot, new_topic.id, "The topic should have its old id"
      assert_equal id_present, new_topic.has_attribute?(Topic.primary_key)
    end
  end

  def test_callback_rollback_in_create_with_record_invalid_exception
    topic = Class.new(Topic) {
      def after_create_for_transaction
        raise ActiveRecord::RecordInvalid.new(Author.new)
      end
    }

    new_topic = topic.create(:title => "A new topic")
    assert !new_topic.persisted?, "The topic should not be persisted"
    assert_nil new_topic.id, "The topic should not have an ID"
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

  def test_invalid_keys_for_transaction
    assert_raise ArgumentError do
      Topic.transaction :nested => true do
      end
    end
  end

  def test_force_savepoint_in_nested_transaction
    Topic.transaction do
      @first.approved = true
      @second.approved = false
      @first.save!
      @second.save!

      begin
        Topic.transaction :requires_new => true do
          @first.happy = false
          @first.save!
          raise
        end
      rescue
      end
    end

    assert @first.reload.approved?
    assert !@second.reload.approved?
  end if Topic.connection.supports_savepoints?

  def test_force_savepoint_on_instance
    @first.transaction do
      @first.approved  = true
      @second.approved = false
      @first.save!
      @second.save!

      begin
        @second.transaction :requires_new => true do
          @first.happy = false
          @first.save!
          raise
        end
      rescue
      end
    end

    assert @first.reload.approved?
    assert !@second.reload.approved?
  end if Topic.connection.supports_savepoints?

  def test_no_savepoint_in_nested_transaction_without_force
    Topic.transaction do
      @first.approved = true
      @second.approved = false
      @first.save!
      @second.save!

      begin
        Topic.transaction do
          @first.approved = false
          @first.save!
          raise
        end
      rescue
      end
    end

    assert !@first.reload.approved?
    assert !@second.reload.approved?
  end if Topic.connection.supports_savepoints?

  def test_many_savepoints
    Topic.transaction do
      @first.content = "One"
      @first.save!

      begin
        Topic.transaction :requires_new => true do
          @first.content = "Two"
          @first.save!

          begin
            Topic.transaction :requires_new => true do
              @first.content = "Three"
              @first.save!

              begin
                Topic.transaction :requires_new => true do
                  @first.content = "Four"
                  @first.save!
                  raise
                end
              rescue
              end

              @three = @first.reload.content
              raise
            end
          rescue
          end

          @two = @first.reload.content
          raise
        end
      rescue
      end

      @one = @first.reload.content
    end

    assert_equal "One", @one
    assert_equal "Two", @two
    assert_equal "Three", @three
  end if Topic.connection.supports_savepoints?

  def test_rollback_when_commit_raises
    Topic.connection.expects(:begin_db_transaction)
    Topic.connection.expects(:commit_db_transaction).raises('OH NOES')
    Topic.connection.expects(:rollback_db_transaction)

    assert_raise RuntimeError do
      Topic.transaction do
        # do nothing
      end
    end
  end

  def test_rollback_when_saving_a_frozen_record
    topic = Topic.new(:title => 'test')
    topic.freeze
    e = assert_raise(RuntimeError) { topic.save }
    assert_equal "can't modify frozen Hash", e.message
    assert !topic.persisted?, 'not persisted'
    assert_nil topic.id
    assert topic.frozen?, 'not frozen'
  end

  def test_restore_active_record_state_for_all_records_in_a_transaction
    topic_1 = Topic.new(:title => 'test_1')
    topic_2 = Topic.new(:title => 'test_2')
    Topic.transaction do
      assert topic_1.save
      assert topic_2.save
      @first.save
      @second.destroy
      assert topic_1.persisted?, 'persisted'
      assert_not_nil topic_1.id
      assert topic_2.persisted?, 'persisted'
      assert_not_nil topic_2.id
      assert @first.persisted?, 'persisted'
      assert_not_nil @first.id
      assert @second.destroyed?, 'destroyed'
      raise ActiveRecord::Rollback
    end

    assert !topic_1.persisted?, 'not persisted'
    assert_nil topic_1.id
    assert !topic_2.persisted?, 'not persisted'
    assert_nil topic_2.id
    assert @first.persisted?, 'persisted'
    assert_not_nil @first.id
    assert !@second.destroyed?, 'not destroyed'
  end

  if current_adapter?(:PostgreSQLAdapter) && defined?(PGconn::PQTRANS_IDLE)
    def test_outside_transaction_works
      assert assert_deprecated { Topic.connection.outside_transaction? }
      Topic.connection.begin_db_transaction
      assert assert_deprecated { !Topic.connection.outside_transaction? }
      Topic.connection.rollback_db_transaction
      assert assert_deprecated { Topic.connection.outside_transaction? }
    end
  end

  def test_sqlite_add_column_in_transaction
    return true unless current_adapter?(:SQLite3Adapter)

    # Test first if column creation/deletion works correctly when no
    # transaction is in place.
    #
    # We go back to the connection for the column queries because
    # Topic.columns is cached and won't report changes to the DB

    assert_nothing_raised do
      Topic.reset_column_information
      Topic.connection.add_column('topics', 'stuff', :string)
      assert Topic.column_names.include?('stuff')

      Topic.reset_column_information
      Topic.connection.remove_column('topics', 'stuff')
      assert !Topic.column_names.include?('stuff')
    end

    if Topic.connection.supports_ddl_transactions?
      assert_nothing_raised do
        Topic.transaction { Topic.connection.add_column('topics', 'stuff', :string) }
      end
    else
      Topic.transaction do
        assert_raise(ActiveRecord::StatementInvalid) { Topic.connection.add_column('topics', 'stuff', :string) }
        raise ActiveRecord::Rollback
      end
    end
  end

  private

  %w(validation save destroy).each do |filter|
    define_method("add_cancelling_before_#{filter}_with_db_side_effect_to_topic") do |topic|
      meta = class << topic; self; end
      meta.send("define_method", "before_#{filter}_for_transaction") do
        Book.create
        false
      end
    end
  end
end

class TransactionsWithTransactionalFixturesTest < ActiveRecord::TestCase
  self.use_transactional_fixtures = true
  fixtures :topics

  def test_automatic_savepoint_in_outer_transaction
    @first = Topic.find(1)

    begin
      Topic.transaction do
        @first.approved = true
        @first.save!
        raise
      end
    rescue
      assert !@first.reload.approved?
    end
  end

  def test_no_automatic_savepoint_for_inner_transaction
    @first = Topic.find(1)

    Topic.transaction do
      @first.approved = true
      @first.save!

      begin
        Topic.transaction do
          @first.approved = false
          @first.save!
          raise
        end
      rescue
      end
    end

    assert !@first.reload.approved?
  end
end if Topic.connection.supports_savepoints?

if current_adapter?(:PostgreSQLAdapter)
  class ConcurrentTransactionTest < TransactionTest
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
            Topic.connection.close
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
            Developer.connection.close
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
          Developer.connection.close
        end

        threads.each { |t| t.join }
      end

      assert_equal original_salary, Developer.find(1).salary
    end

    test "#transaction_joinable= is deprecated" do
      Developer.transaction do
        conn = Developer.connection
        assert conn.current_transaction.joinable?
        assert_deprecated { conn.transaction_joinable = false }
        assert !conn.current_transaction.joinable?
      end
    end
  end
end
