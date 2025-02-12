# frozen_string_literal: true

require "cases/helper"
require "models/topic"
require "models/reply"
require "models/developer"
require "models/computer"
require "models/book"
require "models/author"
require "models/post"
require "models/movie"
require "models/cpk"

module TransactionCallbacksTests
  SomeError = Class.new(StandardError)

  def test_transaction_open?
    assert_predicate Topic.current_transaction, :closed?

    committed_transaction = nil
    Topic.transaction do
      assert_predicate Topic.current_transaction, :open?
      committed_transaction = Topic.current_transaction
    end
    assert_predicate committed_transaction, :closed?

    rolledback_transaction = nil
    assert_raises SomeError do
      Topic.transaction do
        assert_predicate Topic.current_transaction, :open?
        rolledback_transaction = Topic.current_transaction
        raise SomeError
      end
    end
    assert_predicate rolledback_transaction, :closed?
  end

  def test_after_all_transactions_commit
    called = 0
    ActiveRecord.after_all_transactions_commit { called += 1 }
    assert_equal 1, called

    ActiveRecord.after_all_transactions_commit { called += 1 }
    assert_equal 2, called

    called = 0
    Topic.transaction do
      ActiveRecord.after_all_transactions_commit { called += 1 }
      assert_equal 0, called
    end
    assert_equal 1, called

    called = 0
    Topic.transaction do
      Topic.transaction(requires_new: true) do
        ActiveRecord.after_all_transactions_commit { called += 1 }
        assert_equal 0, called
      end
      assert_equal 0, called
    end
    assert_equal 1, called

    called = 0
    Topic.transaction do
      ActiveRecord.after_all_transactions_commit { called += 1 }
      assert_equal 0, called
      raise ActiveRecord::Rollback
    end
    assert_equal 0, called

    called = 0
    Topic.transaction do |transaction|
      transaction.instance_variable_get(:@internal_transaction).invalidate!
      ActiveRecord.after_all_transactions_commit { called += 1 }
      assert_equal 1, called
    end
    assert_equal 1, called
  end

  def test_after_current_transaction_commit_multidb_nested_transactions
    called = 0
    ARUnit2Model.transaction do
      Topic.transaction do
        ActiveRecord.after_all_transactions_commit { called += 1 }
        assert_equal 0, called
      end
      assert_equal 0, called
    end
    assert_equal 1, called
  end

  def test_transaction_after_commit_callback
    called = 0
    Topic.current_transaction.after_commit { called += 1 }
    assert_equal 1, called

    Topic.current_transaction.after_commit { called += 1 }
    assert_equal 2, called

    called = 0
    Topic.transaction do
      Topic.current_transaction.after_commit { called += 1 }
      assert_equal 0, called
    end
    assert_equal 1, called

    called = 0
    Topic.transaction do
      Topic.transaction(requires_new: true) do
        Topic.current_transaction.after_commit { called += 1 }
        assert_equal 0, called
      end
      assert_equal 0, called
    end
    assert_equal 1, called

    called = 0
    Topic.transaction do
      Topic.current_transaction.after_commit { called += 1 }
      assert_equal 0, called
      raise ActiveRecord::Rollback
    end
    assert_equal 0, called

    called = 0
    ARUnit2Model.transaction do
      Topic.transaction do
        Topic.current_transaction.after_commit { called += 1 }
        assert_equal 0, called
      end
      assert_equal 1, called
    end
    assert_equal 1, called

    committed_transaction = nil
    Topic.transaction do
      committed_transaction = Topic.current_transaction
    end
    assert_raises ActiveRecord::ActiveRecordError, match: /Cannot register callbacks on a finalized transaction/ do
      committed_transaction.after_commit { nil }
    end
  end

  def test_transaction_after_rollback_callback
    called = 0
    Topic.current_transaction.after_rollback { called += 1 }
    assert_equal 0, called

    called = 0
    Topic.transaction do
      Topic.current_transaction.after_rollback { called += 1 }
      assert_equal 0, called
    end
    assert_equal 0, called

    called = 0
    Topic.transaction do
      Topic.current_transaction.after_rollback { called += 1 }
      assert_equal 0, called
      raise ActiveRecord::Rollback
    end
    assert_equal 1, called

    called = 0
    Topic.transaction do
      Topic.current_transaction.after_rollback { called += 1 }
      Topic.transaction(requires_new: true) do
        raise ActiveRecord::Rollback
      end
    end
    assert_equal 0, called

    called = 0
    Topic.transaction do
      assert_nothing_raised do
        Topic.transaction(requires_new: true) do
          Topic.current_transaction.after_rollback { called += 1 }
          raise ActiveRecord::Rollback
        end
      end
      assert_equal 1, called
    end
    assert_equal 1, called

    committed_transaction = nil
    Topic.transaction do
      committed_transaction = Topic.current_transaction
    end
    assert_raises ActiveRecord::ActiveRecordError, match: /Cannot register callbacks on a finalized transaction/ do
      committed_transaction.after_rollback { nil }
    end
  end
end

class TransactionTest < ActiveRecord::TestCase
  self.use_transactional_tests = false
  fixtures :topics, :developers, :authors, :author_addresses, :posts

  include TransactionCallbacksTests

  def setup
    @first, @second = Topic.find(1, 2).sort_by(&:id)
  end

  def test_blank?
    assert_predicate Topic.current_transaction, :blank?
    Topic.transaction do
      assert_not_predicate Topic.current_transaction, :blank?
    end
  end

  def test_rollback_dirty_changes
    topic = topics(:fifth)

    ActiveRecord::Base.transaction do
      topic.update(title: "Ruby on Rails")
      raise ActiveRecord::Rollback
    end

    title_change = ["The Fifth Topic of the day", "Ruby on Rails"]
    assert_equal title_change, topic.changes["title"]
  end

  def test_transaction_does_not_apply_default_scope
    # Regression test for https://github.com/rails/rails/issues/50368
    topic = topics(:fifth)
    Topic.where.not(id: topic.id).transaction do
      assert_not_nil Topic.find(topic.id)
    end
  end

  if !in_memory_db?
    def test_rollback_dirty_changes_even_with_raise_during_rollback_removes_from_pool
      topic = topics(:fifth)

      connection = Topic.lease_connection

      Topic.lease_connection.class_eval do
        alias :real_exec_rollback_db_transaction :exec_rollback_db_transaction
        define_method(:exec_rollback_db_transaction) do
          raise
        end
      end

      ActiveRecord::Base.transaction do
        topic.update(title: "Rails is broken")
        raise ActiveRecord::Rollback
      end

      assert_not connection.active?
      assert_not Topic.connection_pool.connections.include?(connection)
    ensure
      ActiveRecord::Base.connection_handler.clear_all_connections!(:all)
    end

    def test_rollback_dirty_changes_even_with_raise_during_rollback_doesnt_commit_transaction
      topic = topics(:fifth)

      Topic.lease_connection.class_eval do
        alias :real_exec_rollback_db_transaction :exec_rollback_db_transaction
        define_method(:exec_rollback_db_transaction) do
          raise
        end
      end

      ActiveRecord::Base.transaction do
        topic.update(title: "Rails is broken")
        raise ActiveRecord::Rollback
      end

      topic.reload

      ActiveRecord::Base.transaction do
        topic.update(content: "Ruby on Rails - modified")
      end

      assert_equal "The Fifth Topic of the day", topic.reload.title
    ensure
      ActiveRecord::Base.connection_handler.clear_all_connections!(:all)
    end

    def test_connection_removed_from_pool_when_commit_raises_and_rollback_raises
      connection = Topic.lease_connection

      # Update commit_transaction to raise the first time it is called.
      Topic.lease_connection.transaction_manager.class_eval do
        alias :real_commit_transaction :commit_transaction
        define_method(:commit_transaction) do
          raise "commit failed"
        end
      end

      # Update rollback_transaction to raise.
      Topic.lease_connection.transaction_manager.class_eval do
        alias :real_rollback_transaction :rollback_transaction
        define_method(:rollback_transaction) do |*_args|
          raise "rollback failed"
        end
      end

      # Start a transaction and update a record. The commit and rollback will fail.
      topic = topics(:fifth)
      exception = assert_raises(RuntimeError) do
        ActiveRecord::Base.transaction do
          topic.update(title: "Updated title")
        end
      end
      assert_equal "rollback failed", exception.message
      assert_not connection.active?
      assert_not Topic.connection_pool.connections.include?(connection)
      assert_equal "The Fifth Topic of the day", topic.reload.title
    ensure
      ActiveRecord::Base.connection_handler.clear_all_connections!(:all)
    end

    def test_connection_removed_from_pool_when_begin_raises_after_successfully_beginning_a_transaction
      connection = Topic.lease_connection
      # Disable lazy transactions so that we will begin a transaction before attempting to write.
      connection.disable_lazy_transactions!

      # Update begin_db_transaction to successfully begin a transaction, then raise.
      Topic.lease_connection.class_eval do
        alias :real_begin_db_transaction :begin_db_transaction
        define_method(:begin_db_transaction) do |*_args|
          raise "begin failed"
        end
      end

      # Attempt to begin a transaction. This will raise, causing a rollback.
      exception = assert_raises(RuntimeError) do
        ActiveRecord::Base.transaction { }
      end
      assert_equal "begin failed", exception.message
      assert_not connection.active?
      assert_not Topic.connection_pool.connections.include?(connection)
    ensure
      ActiveRecord::Base.connection_handler.clear_all_connections!(:all)
    end

    def test_connection_removed_from_pool_when_thread_killed_in_begin_after_successfully_beginning_a_transaction
      queue = Queue.new
      connection = nil
      thread = Thread.new do
        connection = Topic.lease_connection

        # Disable lazy transactions so that we will begin a transaction before attempting to write.
        connection.disable_lazy_transactions!

        # Update begin_db_transaction to block.
        connection.class_eval do
          alias :real_begin_db_transaction :begin_db_transaction
          define_method(:begin_db_transaction) do |*_args|
            queue.push nil
            sleep
          end
        end

        ActiveRecord::Base.transaction { }
      end
      queue.pop
      thread.kill
      thread.join
      assert_not connection.active?
      assert_not Topic.connection_pool.connections.include?(connection)
    ensure
      ActiveRecord::Base.connection_handler.clear_all_connections!(:all)
    end
  end

  def test_rollback_dirty_changes_multiple_saves
    topic = topics(:fifth)

    ActiveRecord::Base.transaction do
      topic.update(title: "Ruby on Rails")
      topic.update(title: "Another Title")
      raise ActiveRecord::Rollback
    end

    title_change = ["The Fifth Topic of the day", "Another Title"]
    assert_equal title_change, topic.changes["title"]
  end

  def test_rollback_dirty_changes_then_retry_save
    topic = topics(:fifth)

    ActiveRecord::Base.transaction do
      topic.update(title: "Ruby on Rails")
      raise ActiveRecord::Rollback
    end

    title_change = ["The Fifth Topic of the day", "Ruby on Rails"]
    assert_equal title_change, topic.changes["title"]

    assert topic.save

    assert_equal title_change, topic.saved_changes["title"]
    assert_equal topic.title, topic.reload.title
  end

  def test_rollback_dirty_changes_then_retry_save_on_new_record
    topic = Topic.new(title: "Ruby on Rails")

    ActiveRecord::Base.transaction do
      topic.save
      raise ActiveRecord::Rollback
    end

    title_change = [nil, "Ruby on Rails"]
    assert_equal title_change, topic.changes["title"]

    assert topic.save

    assert_equal title_change, topic.saved_changes["title"]
    assert_equal topic.title, topic.reload.title
  end

  def test_rollback_dirty_changes_then_retry_save_on_new_record_with_autosave_association
    author = Author.new(name: "DHH")
    book = Book.create!
    author.books << book

    author.transaction do
      author.save!
      raise ActiveRecord::Rollback
    end

    author.save!
    assert_equal author, book.reload.author
  end

  def test_persisted_in_a_model_with_custom_primary_key_after_failed_save
    movie = Movie.create
    assert_not_predicate movie, :persisted?
  end

  def test_raise_after_destroy
    assert_not_predicate @first, :frozen?

    assert_raises(RuntimeError) do
      Topic.transaction do
        @first.destroy
        assert_predicate @first, :frozen?
        raise
      end
    end

    assert_not_predicate @first, :frozen?
  end

  def test_successful
    Topic.transaction do
      @first.approved  = true
      @second.approved = false
      @first.save
      @second.save
    end

    assert_predicate Topic.find(1), :approved?, "First should have been approved"
    assert_not_predicate Topic.find(2), :approved?, "Second should have been unapproved"
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

  def transaction_with_shallow_return
    Topic.transaction do
      Topic.transaction(requires_new: true) do
        @first.approved  = true
        @second.approved = false
        @first.save
        @second.save
      end
      return
    end
  end

  def test_add_to_null_transaction
    topic = Topic.new
    assert_nothing_raised do
      topic.send(:add_to_transaction)
    end
  end

  def test_successful_with_return_outside_inner_transaction
    committed = false

    Topic.lease_connection.class_eval do
      alias :real_commit_db_transaction :commit_db_transaction
      define_method(:commit_db_transaction) do
        committed = true
        real_commit_db_transaction
      end
    end

    transaction_with_shallow_return
    assert committed

    assert_predicate Topic.find(1), :approved?, "First should have been approved"
    assert_not_predicate Topic.find(2), :approved?, "Second should have been unapproved"
  ensure
    Topic.lease_connection.class_eval do
      remove_method :commit_db_transaction
      alias :commit_db_transaction :real_commit_db_transaction rescue nil
    end
  end

  def test_deprecation_on_ruby_timeout_outside_inner_transaction
    assert_not_deprecated(ActiveRecord.deprecator) do
      catch do |timeout|
        Topic.transaction do
          Topic.transaction(requires_new: true) do
            @first.approved = true
            @first.save!
          end

          throw timeout
        end
      end
    end

    assert_predicate Topic.find(1), :approved?, "First should have been approved"
  end

  def test_break_from_transaction_commits
    @first.transaction do
      assert_not_predicate @first, :approved?
      @first.update!(approved: true)

      break if true

      # dead code
      assert_predicate @first, :approved?
      @first.update!(approved: false)
    end

    assert_predicate Topic.find(1), :approved?, "First should have been approved"
    assert_predicate Topic.find(2), :approved?, "Second should have been approved"
  end

  def test_throw_from_transaction_commits
    catch(:not_an_error) do
      @first.transaction do
        assert_not_predicate @first, :approved?
        @first.update!(approved: true)

        throw :not_an_error

        # dead code
        assert_predicate @first, :approved?
        @first.update!(approved: false)
      end
    end
    assert_predicate Topic.find(1), :approved?, "First should have been approved"
    assert_predicate Topic.find(2), :approved?, "Second should have been approved"
  end

  def _test_return_from_transaction_7_1_behavior
    @first.transaction do
      assert_not_predicate @first, :approved?
      @first.update!(approved: true)

      return if true

      # dead code
      assert_predicate @first, :approved?
      @first.update!(approved: false)
    end
  end

  def test_return_from_transaction_commits
    _test_return_from_transaction_7_1_behavior
    assert_predicate Topic.find(1), :approved?, "First should have been approved"
    assert_predicate Topic.find(2), :approved?, "Second should have been approved"
  end

  def test_number_of_transactions_in_commit
    num = nil

    Topic.lease_connection.class_eval do
      alias :real_commit_db_transaction :commit_db_transaction
      define_method(:commit_db_transaction) do
        num = transaction_manager.open_transactions
        real_commit_db_transaction
      end
    end

    Topic.transaction do
      @first.approved = true
      @first.save!
    end

    assert_equal 0, num
  ensure
    Topic.lease_connection.class_eval do
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

    assert_predicate Topic.find(1), :approved?, "First should have been approved"
    assert_not_predicate Topic.find(2), :approved?, "Second should have been unapproved"
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

    assert_predicate @first, :approved?, "First should still be changed in the objects"
    assert_not_predicate @second, :approved?, "Second should still be changed in the objects"

    assert_not_predicate Topic.find(1), :approved?, "First shouldn't have been approved"
    assert_predicate Topic.find(2), :approved?, "Second should still be approved"
  end

  def test_raising_exception_in_callback_rollbacks_in_save
    def @first.after_save_for_transaction
      raise "Make the transaction rollback"
    end

    @first.approved = true
    e = assert_raises(RuntimeError) { @first.save }
    assert_equal "Make the transaction rollback", e.message
    assert_not_predicate Topic.find(1), :approved?
  end

  def test_rolling_back_in_a_callback_rollbacks_before_save
    def @first.before_save_for_transaction
      raise ActiveRecord::Rollback
    end
    assert_not_predicate @first, :approved?

    assert_not_called(@first, :rolledback!) do
      Topic.transaction do
        @first.approved = true
        @first.save!
      end
    end
    assert_not_predicate Topic.find(@first.id), :approved?, "Should not commit the approved flag"
  end

  def test_raising_exception_in_nested_transaction_restore_state_in_save
    topic = Topic.new

    def topic.after_save_for_transaction
      raise "Make the transaction rollback"
    end

    assert_raises(RuntimeError) do
      Topic.transaction { topic.save }
    end

    assert_predicate topic, :new_record?, "#{topic.inspect} should be new record"
  end

  def test_transaction_state_is_cleared_when_record_is_persisted
    author = Author.create! name: "foo"
    author.name = nil
    assert_not author.save
    assert_not_predicate author, :new_record?
  end

  def test_update_should_rollback_on_failure
    author = Author.find(1)
    posts_count = author.posts.size
    assert posts_count > 0
    status = author.update(name: nil, post_ids: [])
    assert_not status
    assert_equal posts_count, author.posts.reload.size
  end

  def test_update_should_rollback_on_failure!
    author = Author.find(1)
    posts_count = author.posts.size
    assert posts_count > 0
    assert_raise(ActiveRecord::RecordInvalid) do
      author.update!(name: nil, post_ids: [])
    end
    assert_equal posts_count, author.posts.reload.size
  end

  def test_cancellation_from_before_destroy_rollbacks_in_destroy
    add_cancelling_before_destroy_with_db_side_effect_to_topic @first
    nbooks_before_destroy = Book.count
    status = @first.destroy
    assert_not status
    @first.reload
    assert_equal nbooks_before_destroy, Book.count
  end

  %w(validation save).each do |filter|
    define_method("test_cancellation_from_before_filters_rollbacks_in_#{filter}") do
      send("add_cancelling_before_#{filter}_with_db_side_effect_to_topic", @first)
      nbooks_before_save = Book.count
      original_author_name = @first.author_name
      @first.author_name += "_this_should_not_end_up_in_the_db"
      status = @first.save
      assert_not status
      assert_equal original_author_name, @first.reload.author_name
      assert_equal nbooks_before_save, Book.count
    end

    define_method("test_cancellation_from_before_filters_rollbacks_in_#{filter}!") do
      send("add_cancelling_before_#{filter}_with_db_side_effect_to_topic", @first)
      nbooks_before_save = Book.count
      original_author_name = @first.author_name
      @first.author_name += "_this_should_not_end_up_in_the_db"

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
        raise "Make the transaction rollback"
      end
    }

    new_topic = topic.new(title: "A new topic",
                          author_name: "Ben",
                          author_email_address: "ben@example.com",
                          written_on: "2003-07-16t15:28:11.2233+01:00",
                          last_read: "2004-04-15",
                          bonus_time: "2005-01-30t15:28:00.00+01:00",
                          content: "Have a nice day",
                          approved: false)

    new_record_snapshot = !new_topic.persisted?
    id_present = new_topic.has_attribute?(Topic.primary_key)
    id_snapshot = new_topic.id

    # Make sure the second save gets the after_create callback called.
    2.times do
      new_topic.approved = true
      e = assert_raises(RuntimeError) { new_topic.save }
      assert_equal "Make the transaction rollback", e.message
      assert_equal new_record_snapshot, !new_topic.persisted?, "The topic should have its old persisted value"
      if id_snapshot.nil?
        assert_nil new_topic.id, "The topic should have its old id"
      else
        assert_equal id_snapshot, new_topic.id, "The topic should have its old id"
      end
      assert_equal id_present, new_topic.has_attribute?(Topic.primary_key)
    end
  end

  def test_callback_rollback_in_create_with_record_invalid_exception
    topic = Class.new(Topic) {
      def after_create_for_transaction
        raise ActiveRecord::RecordInvalid.new(Author.new)
      end
    }

    new_topic = topic.create(title: "A new topic")
    assert_not new_topic.persisted?, "The topic should not be persisted"
    assert_nil new_topic.id, "The topic should not have an ID"
  end

  def test_callback_rollback_in_create_with_rollback_exception
    topic = Class.new(Topic) {
      def after_create_for_transaction
        raise ActiveRecord::Rollback
      end
    }

    new_topic = topic.create(title: "A new topic")
    assert_not new_topic.persisted?, "The topic should not be persisted"
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

    assert_predicate Topic.find(1), :approved?, "First should have been approved"
    assert_not Topic.find(2).approved?, "Second should have been unapproved"
  end

  def test_nested_transaction_with_new_transaction_applies_parent_state_on_rollback
    topic_one = Topic.new(title: "A new topic")
    topic_two = Topic.new(title: "Another new topic")

    Topic.transaction do
      topic_one.save

      Topic.transaction(requires_new: true) do
        topic_two.save

        assert_predicate topic_one, :persisted?
        assert_predicate topic_two, :persisted?
      end

      raise ActiveRecord::Rollback
    end

    assert_not_predicate topic_one, :persisted?
    assert_not_predicate topic_two, :persisted?
  end

  def test_nested_transaction_without_new_transaction_applies_parent_state_on_rollback
    topic_one = Topic.new(title: "A new topic")
    topic_two = Topic.new(title: "Another new topic")

    Topic.transaction do
      topic_one.save

      Topic.transaction do
        topic_two.save

        assert_predicate topic_one, :persisted?
        assert_predicate topic_two, :persisted?
      end

      raise ActiveRecord::Rollback
    end

    assert_not_predicate topic_one, :persisted?
    assert_not_predicate topic_two, :persisted?
  end

  def test_double_nested_transaction_applies_parent_state_on_rollback
    topic_one = Topic.new(title: "A new topic")
    topic_two = Topic.new(title: "Another new topic")
    topic_three = Topic.new(title: "Another new topic of course")

    Topic.transaction do
      topic_one.save

      Topic.transaction do
        topic_two.save

        Topic.transaction do
          topic_three.save
        end
      end

      assert_predicate topic_one, :persisted?
      assert_predicate topic_two, :persisted?
      assert_predicate topic_three, :persisted?

      raise ActiveRecord::Rollback
    end

    assert_not_predicate topic_one, :persisted?
    assert_not_predicate topic_two, :persisted?
    assert_not_predicate topic_three, :persisted?
  end

  def test_manually_rolling_back_a_transaction
    Topic.transaction do
      @first.approved  = true
      @second.approved = false
      @first.save
      @second.save

      raise ActiveRecord::Rollback
    end

    assert_predicate @first, :approved?, "First should still be changed in the objects"
    assert_not @second.approved?, "Second should still be changed in the objects"

    assert_not Topic.find(1).approved?, "First shouldn't have been approved"
    assert_predicate Topic.find(2), :approved?, "Second should still be approved"
  end

  def test_invalid_keys_for_transaction
    assert_raise ArgumentError do
      Topic.transaction nested: true do
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
        Topic.transaction requires_new: true do
          @first.approved = false
          @first.save!
          raise
        end
      rescue
      end
    end

    assert_predicate @first.reload, :approved?
    assert_not_predicate @second.reload, :approved?
  end if Topic.lease_connection.supports_savepoints?

  def test_force_savepoint_on_instance
    @first.transaction do
      @first.approved  = true
      @second.approved = false
      @first.save!
      @second.save!

      begin
        @second.transaction requires_new: true do
          @first.approved = false
          @first.save!
          raise
        end
      rescue
      end
    end

    assert_predicate @first.reload, :approved?
    assert_not_predicate @second.reload, :approved?
  end if Topic.lease_connection.supports_savepoints?

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

    assert_not_predicate @first.reload, :approved?
    assert_not_predicate @second.reload, :approved?
  end if Topic.lease_connection.supports_savepoints?

  def test_many_savepoints
    Topic.transaction do
      @first.content = "One"
      @first.save!

      begin
        Topic.transaction requires_new: true do
          @first.content = "Two"
          @first.save!

          begin
            Topic.transaction requires_new: true do
              @first.content = "Three"
              @first.save!

              begin
                Topic.transaction requires_new: true do
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
  end if Topic.lease_connection.supports_savepoints?

  def test_using_named_savepoints
    Topic.transaction do
      @first.approved = true
      @first.save!
      Topic.lease_connection.create_savepoint("first")

      @first.approved = false
      @first.save!
      Topic.lease_connection.rollback_to_savepoint("first")
      assert_predicate @first.reload, :approved?

      @first.approved = false
      @first.save!
      Topic.lease_connection.release_savepoint("first")
      assert_not_predicate @first.reload, :approved?
    end
  end if Topic.lease_connection.supports_savepoints?

  def test_releasing_named_savepoints
    Topic.transaction do
      Topic.lease_connection.materialize_transactions

      Topic.lease_connection.create_savepoint("another")
      Topic.lease_connection.release_savepoint("another")

      # The savepoint is now gone and we can't remove it again.
      assert_raises(ActiveRecord::StatementInvalid) do
        Topic.lease_connection.release_savepoint("another")
      end
    end
  end

  def test_savepoints_name
    Topic.transaction do
      Topic.delete_all # Dirty the transaction to force a savepoint below

      assert_nil Topic.lease_connection.current_savepoint_name
      assert_nil Topic.lease_connection.current_transaction.savepoint_name

      Topic.transaction(requires_new: true) do
        Topic.delete_all # Dirty the transaction to force a savepoint below

        assert_equal "active_record_1", Topic.lease_connection.current_savepoint_name
        assert_equal "active_record_1", Topic.lease_connection.current_transaction.savepoint_name

        Topic.transaction(requires_new: true) do
          assert_equal "active_record_2", Topic.lease_connection.current_savepoint_name
          assert_equal "active_record_2", Topic.lease_connection.current_transaction.savepoint_name
        end

        assert_equal "active_record_1", Topic.lease_connection.current_savepoint_name
        assert_equal "active_record_1", Topic.lease_connection.current_transaction.savepoint_name
      end
    end
  end

  def test_rollback_when_commit_raises
    assert_called(Topic.lease_connection, :begin_db_transaction) do
      Topic.lease_connection.stub(:commit_db_transaction, -> { raise("OH NOES") }) do
        assert_called(Topic.lease_connection, :rollback_db_transaction) do
          e = assert_raise RuntimeError do
            Topic.transaction do
              Topic.lease_connection.materialize_transactions
            end
          end
          assert_equal "OH NOES", e.message
        end
      end
    end
  end

  def test_rollback_when_saving_a_frozen_record
    topic = Topic.new(title: "test")
    topic.freeze
    e = assert_raise(FrozenError) { topic.save }
    # Not good enough, but we can't do much
    # about it since there is no specific error
    # for frozen objects.
    assert_match(/frozen/i, e.message)
    assert_not topic.persisted?, "not persisted"
    assert_nil topic.id
    assert_predicate topic, :frozen?, "not frozen"
  end

  def test_rollback_when_thread_killed
    skip if in_memory_db?

    queue = Queue.new
    thread = Thread.new do
      Topic.transaction do
        @first.approved  = true
        @second.approved = false
        @first.save

        queue.push nil
        sleep

        @second.save
      end
    end

    queue.pop
    thread.kill
    thread.join

    assert_predicate @first, :approved?, "First should still be changed in the objects"
    assert_not @second.approved?, "Second should still be changed in the objects"

    assert_not Topic.find(1).approved?, "First shouldn't have been approved"
    assert_predicate Topic.find(2), :approved?, "Second should still be approved"
  end

  def test_restore_active_record_state_for_all_records_in_a_transaction
    topic_without_callbacks = Class.new(ActiveRecord::Base) do
      self.table_name = "topics"
    end

    topic_1 = Topic.new(title: "test_1")
    topic_2 = Topic.new(title: "test_2")
    topic_3 = topic_without_callbacks.new(title: "test_3")

    Topic.transaction do
      assert topic_1.save
      assert topic_2.save
      assert topic_3.save
      @first.save
      @second.destroy
      assert_predicate topic_1, :persisted?, "persisted"
      assert_not_nil topic_1.id
      assert_predicate topic_2, :persisted?, "persisted"
      assert_not_nil topic_2.id
      assert_predicate topic_3, :persisted?, "persisted"
      assert_not_nil topic_3.id
      assert_predicate @first, :persisted?, "persisted"
      assert_not_nil @first.id
      assert_predicate @second, :destroyed?, "destroyed"
      raise ActiveRecord::Rollback
    end

    assert_not topic_1.persisted?, "not persisted"
    assert_nil topic_1.id
    assert_not topic_2.persisted?, "not persisted"
    assert_nil topic_2.id
    assert_not topic_3.persisted?, "not persisted"
    assert_nil topic_3.id
    assert_predicate @first, :persisted?, "persisted"
    assert_not_nil @first.id
    assert_not @second.destroyed?, "not destroyed"
  end

  def test_restore_frozen_state_after_double_destroy
    topic = Topic.create
    reply = topic.replies.create

    Topic.transaction do
      topic.destroy # calls #destroy on reply (since dependent: destroy)
      reply.destroy

      raise ActiveRecord::Rollback
    end

    assert_not_predicate reply, :frozen?
    assert_not_predicate topic, :frozen?
  end

  def test_restore_new_record_after_double_save
    topic = Topic.new

    Topic.transaction do
      topic.save!
      topic.save!
      raise ActiveRecord::Rollback
    end

    assert_nil topic.id
    assert_predicate topic, :new_record?
  end

  def test_dont_restore_new_record_in_subsequent_transaction
    topic = Topic.new

    Topic.transaction do
      topic.save!
      topic.save!
    end

    Topic.transaction do
      topic.save!
      raise ActiveRecord::Rollback
    end

    assert_predicate topic, :persisted?
    assert_not_predicate topic, :new_record?
  end

  def test_restore_previously_new_record_after_double_save
    topic = Topic.create!

    Topic.transaction do
      topic.save!
      topic.save!
      raise ActiveRecord::Rollback
    end

    assert_predicate topic, :previously_new_record?
  end

  def test_restore_composite_id_after_rollback
    book = Cpk::Book.create!(id: [1, 2])

    Cpk::Book.transaction do
      book.update!(id: [42, 42])
      raise ActiveRecord::Rollback
    end

    assert_equal [1, 2], book.id
  ensure
    Cpk::Book.delete_all
  end

  def test_rollback_on_composite_key_model
    Cpk::Book.create!(id: [1, 3], title: "Charlotte's Web")
    book_two_unpersisted = Cpk::Book.new(id: [1, 3])

    assert_raise(ActiveRecord::RecordNotUnique) do
      Cpk::Book.transaction do
        book_two_unpersisted.save!
      end
    end
  ensure
    Cpk::Book.delete_all
  end

  def test_restore_id_after_rollback
    topic = Topic.new

    Topic.transaction do
      topic.save!
      raise ActiveRecord::Rollback
    end

    assert_nil topic.id
  end

  def test_restore_custom_primary_key_after_rollback
    movie = Movie.new(name: "foo")

    Movie.transaction do
      movie.save!
      raise ActiveRecord::Rollback
    end

    assert_nil movie.movieid
  end

  def test_assign_id_after_rollback
    topic = Topic.create!

    Topic.transaction do
      topic.save!
      raise ActiveRecord::Rollback
    end

    topic.id = nil
    assert_nil topic.id
  end

  def test_assign_custom_primary_key_after_rollback
    movie = Movie.create!(name: "foo")

    Movie.transaction do
      movie.save!
      raise ActiveRecord::Rollback
    end

    movie.movieid = nil
    assert_nil movie.movieid
  end

  def test_read_attribute_after_rollback
    topic = Topic.new

    Topic.transaction do
      topic.save!
      raise ActiveRecord::Rollback
    end

    assert_nil topic.read_attribute(:id)
  end

  def test_read_attribute_with_custom_primary_key_after_rollback
    movie = Movie.new(name: "foo")

    Movie.transaction do
      movie.save!
      raise ActiveRecord::Rollback
    end

    assert_nil movie.read_attribute(:movieid)
  end

  def test_write_attribute_after_rollback
    topic = Topic.create!

    Topic.transaction do
      topic.save!
      raise ActiveRecord::Rollback
    end

    topic.write_attribute(:id, nil)
    assert_nil topic.id
  end

  def test_write_attribute_with_custom_primary_key_after_rollback
    movie = Movie.create!(name: "foo")

    Movie.transaction do
      movie.save!
      raise ActiveRecord::Rollback
    end

    movie.write_attribute(:movieid, nil)
    assert_nil movie.movieid
  end

  def test_rollback_of_frozen_records
    topic = Topic.create.freeze
    Topic.transaction do
      topic.destroy
      raise ActiveRecord::Rollback
    end
    assert_predicate topic, :frozen?, "frozen"
  end

  def test_rollback_for_freshly_persisted_records
    topic = Topic.create
    Topic.transaction do
      topic.destroy
      raise ActiveRecord::Rollback
    end
    assert_predicate topic, :persisted?, "persisted"
  end

  if current_adapter?(:SQLite3Adapter)
    def test_sqlite_add_column_in_transaction
      # Test first if column creation/deletion works correctly when no
      # transaction is in place.
      #
      # We go back to the connection for the column queries because
      # Topic.columns is cached and won't report changes to the DB

      assert_nothing_raised do
        Topic.reset_column_information
        Topic.lease_connection.add_column("topics", "stuff", :string)
        assert_includes Topic.column_names, "stuff"

        Topic.reset_column_information
        Topic.lease_connection.remove_column("topics", "stuff")
        assert_not_includes Topic.column_names, "stuff"
      end

      if Topic.lease_connection.supports_ddl_transactions?
        assert_nothing_raised do
          Topic.transaction { Topic.lease_connection.add_column("topics", "stuff", :string) }
        end
      else
        Topic.transaction do
          assert_raise(ActiveRecord::StatementInvalid) { Topic.lease_connection.add_column("topics", "stuff", :string) }
          raise ActiveRecord::Rollback
        end
      end
    ensure
      begin
        Topic.lease_connection.remove_column("topics", "stuff")
      rescue
      ensure
        Topic.reset_column_information
      end
    end

    def test_sqlite_default_transaction_mode_is_immediate
      assert_queries_match(/BEGIN IMMEDIATE TRANSACTION/i, include_schema: false) do
        Topic.transaction { Topic.lease_connection.materialize_transactions }
      end
    end
  end

  def test_transactions_state_from_rollback
    connection = Topic.lease_connection
    transaction = ActiveRecord::ConnectionAdapters::TransactionManager.new(connection).begin_transaction

    assert_predicate transaction, :open?
    assert_not_predicate transaction.state, :rolledback?
    assert_not_predicate transaction.state, :committed?

    transaction.rollback

    assert_predicate transaction.state, :rolledback?
    assert_not_predicate transaction.state, :committed?
  end

  def test_transactions_state_from_commit
    connection = Topic.lease_connection
    transaction = ActiveRecord::ConnectionAdapters::TransactionManager.new(connection).begin_transaction

    assert_predicate transaction, :open?
    assert_not_predicate transaction.state, :rolledback?
    assert_not_predicate transaction.state, :committed?

    transaction.commit

    assert_not_predicate transaction.state, :rolledback?
    assert_predicate transaction.state, :committed?
  end

  def test_mark_transaction_state_as_committed
    connection = Topic.lease_connection
    transaction = ActiveRecord::ConnectionAdapters::TransactionManager.new(connection).begin_transaction

    transaction.rollback

    assert_equal :committed, transaction.state.commit!
  end

  def test_mark_transaction_state_as_rolledback
    connection = Topic.lease_connection
    transaction = ActiveRecord::ConnectionAdapters::TransactionManager.new(connection).begin_transaction

    transaction.commit

    assert_equal :rolledback, transaction.state.rollback!
  end

  def test_mark_transaction_state_as_nil
    connection = Topic.lease_connection
    transaction = ActiveRecord::ConnectionAdapters::TransactionManager.new(connection).begin_transaction

    transaction.commit

    assert_nil transaction.state.nullify!
  end

  def test_transaction_rollback_with_primarykeyless_tables
    connection = ActiveRecord::Base.lease_connection
    connection.create_table(:transaction_without_primary_keys, force: true, id: false) do |t|
      t.integer :thing_id
    end

    klass = Class.new(ActiveRecord::Base) do
      self.table_name = "transaction_without_primary_keys"
      after_commit { } # necessary to trigger the has_transactional_callbacks branch
    end

    assert_no_difference(-> { klass.count }) do
      ActiveRecord::Base.transaction do
        klass.create!
        raise ActiveRecord::Rollback
      end
    end
  ensure
    connection.drop_table "transaction_without_primary_keys", if_exists: true
  end

  def test_empty_transaction_is_not_materialized
    assert_no_queries do
      Topic.transaction { }
    end
  end

  def test_unprepared_statement_materializes_transaction
    assert_queries_match(/BEGIN|COMMIT/i, include_schema: true) do
      Topic.transaction { Topic.where("1=1").first }
    end
  end

  def test_nested_transactions_skip_excess_savepoints
    actual_queries = capture_sql(include_schema: true) do
      # RealTransaction (begin..commit)
      Topic.transaction(requires_new: true) do
        # ResetParentTransaction (no queries)
        Topic.transaction(requires_new: true) do
          Topic.delete_all
          # SavepointTransaction (savepoint..release)
          Topic.transaction(requires_new: true) do
            # ResetParentTransaction (no queries)
            Topic.transaction(requires_new: true) do
              Topic.delete_all
            end
          end
        end
        Topic.delete_all
      end
    end

    expected_queries = [
      /BEGIN/i,
      /DELETE/i,
      /^SAVEPOINT/i,
      /DELETE/i,
      /^RELEASE/i,
      /DELETE/i,
      /COMMIT/i,
    ]

    assert_equal expected_queries.size, actual_queries.size
    expected_queries.zip(actual_queries) do |expected, actual|
      assert_match expected, actual
    end
  end

  def test_nested_transactions_after_disable_lazy_transactions
    Topic.lease_connection.disable_lazy_transactions!

    actual_queries = capture_sql(include_schema: true) do
      # RealTransaction (begin..commit)
      Topic.transaction(requires_new: true) do
        # ResetParentTransaction (no queries)
        Topic.transaction(requires_new: true) do
          Topic.delete_all
          # SavepointTransaction (savepoint..release)
          Topic.transaction(requires_new: true) do
            # ResetParentTransaction (no queries)
            Topic.transaction(requires_new: true) do
              # no-op
            end
          end
        end
        Topic.delete_all
      end
    end

    expected_queries = [
      /BEGIN/i,
      /DELETE/i,
      /^SAVEPOINT/i,
      /^RELEASE/i,
      /DELETE/i,
      /COMMIT/i,
    ]

    assert_equal expected_queries.size, actual_queries.size
    expected_queries.zip(actual_queries) do |expected, actual|
      assert_match expected, actual
    end
  end

  if ActiveRecord::Base.lease_connection.prepared_statements
    def test_prepared_statement_materializes_transaction
      Topic.first

      assert_queries_match(/BEGIN|COMMIT/i, include_schema: true) do
        Topic.transaction { Topic.first }
      end
    end
  end

  def test_savepoint_does_not_materialize_transaction
    assert_no_queries do
      Topic.transaction do
        Topic.transaction(requires_new: true) { }
      end
    end
  end

  def test_raising_does_not_materialize_transaction
    assert_no_queries do
      assert_raise(RuntimeError) do
        Topic.transaction { raise "Expected" }
      end
    end
  end

  def test_accessing_raw_connection_materializes_transaction
    assert_queries_match(/BEGIN|COMMIT/i, include_schema: true) do
      Topic.transaction { Topic.lease_connection.raw_connection }
    end
  end

  def test_accessing_raw_connection_disables_lazy_transactions
    Topic.lease_connection.raw_connection

    assert_queries_match(/BEGIN|COMMIT/i, include_schema: true) do
      Topic.transaction { }
    end
  end

  def test_checking_in_connection_reenables_lazy_transactions
    connection = Topic.connection_pool.checkout
    connection.raw_connection
    Topic.connection_pool.checkin connection

    assert_no_queries do
      connection.transaction { }
    end
  end

  def test_transactions_can_be_manually_materialized
    assert_queries_match(/BEGIN|COMMIT/i, include_schema: true) do
      Topic.transaction do
        Topic.lease_connection.materialize_transactions
      end
    end
  end

  private
    %w(validation save destroy).each do |filter|
      define_method("add_cancelling_before_#{filter}_with_db_side_effect_to_topic") do |topic|
        meta = class << topic; self; end
        meta.define_method "before_#{filter}_for_transaction" do
          Book.create
          throw(:abort)
        end
      end
    end
end

class TransactionsWithTransactionalFixturesTest < ActiveRecord::TestCase
  self.use_transactional_tests = true
  fixtures :topics

  include TransactionCallbacksTests

  def setup
    @first, @second = Topic.find(1, 2).sort_by(&:id)
  end

  def test_automatic_savepoint_in_outer_transaction
    @first = Topic.find(1)

    begin
      Topic.transaction do
        @first.approved = true
        @first.save!
        raise
      end
    rescue
      assert_not_predicate @first.reload, :approved?
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

    assert_not_predicate @first.reload, :approved?
  end
end if Topic.lease_connection.supports_savepoints?

class TransactionUUIDTest < ActiveRecord::TestCase
  def test_the_uuid_is_lazily_computed
    Topic.transaction do
      transaction = Topic.current_transaction
      assert_nil transaction.instance_variable_get(:@uuid)
    end
  end

  def test_the_uuid_for_regular_transactions_is_generated_and_memoized
    Topic.transaction do
      transaction = Topic.current_transaction
      uuid = transaction.uuid
      assert_match(/\A[[:xdigit:]]{8}-(?:[[:xdigit:]]{4}-){3}[[:xdigit:]]{12}\z/, uuid)
      assert_equal uuid, transaction.uuid
    end
  end

  def test_the_uuid_for_null_transactions_is_nil
    null_transaction = ActiveRecord::Transaction::NULL_TRANSACTION
    assert_nil null_transaction.uuid
  end
end

class ConcurrentTransactionTest < ActiveRecord::TestCase
  if ActiveRecord::Base.lease_connection.supports_transaction_isolation? && !current_adapter?(:SQLite3Adapter)
    self.use_transactional_tests = false
    fixtures :topics, :developers

    # This will cause transactions to overlap and fail unless they are performed on
    # separate database connections.
    def test_transaction_per_thread
      threads = 3.times.map do
        Thread.new do
          Topic.transaction do
            topic = Topic.find(1)
            topic.approved = !topic.approved?
            assert topic.save!
            topic.approved = !topic.approved?
            assert topic.save!
          end
          Topic.lease_connection.close
        end
      end

      threads.each(&:join)
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
            Developer.lease_connection.close
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
          Developer.lease_connection.close
        end

        threads.each(&:join)
      end

      assert_equal original_salary, Developer.find(1).salary
    end
  end
end
