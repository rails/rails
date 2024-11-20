# frozen_string_literal: true

require "cases/helper"
require "models/owner"
require "models/pet"
require "models/topic"

class TransactionCallbacksTest < ActiveRecord::TestCase
  fixtures :topics, :owners, :pets

  class ReplyWithCallbacks < ActiveRecord::Base
    self.table_name = :topics

    belongs_to :topic, foreign_key: "parent_id"

    validates_presence_of :content

    after_commit :do_after_commit, on: :create

    attr_accessor :save_on_after_create
    after_create do
      save! if save_on_after_create
    end

    def history
      @history ||= []
    end

    def do_after_commit
      history << :commit_on_create
    end
  end

  class TopicWithCallbacks < ActiveRecord::Base
    self.table_name = :topics

    has_many :replies, class_name: "ReplyWithCallbacks", foreign_key: "parent_id"

    attr_accessor :abort_before_update, :abort_before_destroy

    before_update { throw :abort if abort_before_update }
    before_destroy { throw :abort if abort_before_destroy }

    before_destroy { self.class.find(id).touch if persisted? }

    before_commit { |record| record.do_before_commit(nil) }
    after_commit { |record| record.do_after_commit(nil) }
    after_save_commit { |record| record.do_after_commit(:save) }
    after_create_commit { |record| record.do_after_commit(:create) }
    after_update_commit { |record| record.do_after_commit(:update) }
    after_destroy_commit { |record| record.do_after_commit(:destroy) }
    after_rollback { |record| record.do_after_rollback(nil) }
    after_rollback(on: :create) { |record| record.do_after_rollback(:create) }
    after_rollback(on: :update) { |record| record.do_after_rollback(:update) }
    after_rollback(on: :destroy) { |record| record.do_after_rollback(:destroy) }

    def history
      @history ||= []
    end

    def before_commit_block(on = nil, &block)
      @before_commit ||= {}
      @before_commit[on] ||= []
      @before_commit[on] << block
    end

    def after_commit_block(on = nil, &block)
      @after_commit ||= {}
      @after_commit[on] ||= []
      @after_commit[on] << block
    end

    def after_rollback_block(on = nil, &block)
      @after_rollback ||= {}
      @after_rollback[on] ||= []
      @after_rollback[on] << block
    end

    def do_before_commit(on)
      blocks = @before_commit[on] if defined?(@before_commit)
      blocks.each { |b| b.call(self) } if blocks
    end

    def do_after_commit(on)
      blocks = @after_commit[on] if defined?(@after_commit)
      blocks.each { |b| b.call(self) } if blocks
    end

    def do_after_rollback(on)
      blocks = @after_rollback[on] if defined?(@after_rollback)
      blocks.each { |b| b.call(self) } if blocks
    end
  end

  def setup
    @first = TopicWithCallbacks.find(1)
  end

  # FIXME: Test behavior, not implementation.
  def test_before_commit_exception_should_pop_transaction_stack
    @first.before_commit_block { raise "better pop this txn from the stack!" }

    original_txn = @first.class.lease_connection.current_transaction

    begin
      @first.save!
      fail
    rescue
      assert_equal original_txn, @first.class.lease_connection.current_transaction
    end
  end

  def test_call_after_commit_after_transaction_commits
    @first.after_commit_block { |r| r.history << :after_commit }
    @first.after_rollback_block { |r| r.history << :after_rollback }

    @first.save!
    assert_equal [:after_commit], @first.history
  end

  def test_dont_call_any_callbacks_after_transaction_commits_for_invalid_record
    @first.after_commit_block { |r| r.history << :after_commit }
    @first.after_rollback_block { |r| r.history << :after_rollback }

    def @first.valid?(*)
      false
    end

    assert_not @first.save
    assert_equal [], @first.history
  end

  def test_dont_call_any_callbacks_after_explicit_transaction_commits_for_invalid_record
    @first.after_commit_block { |r| r.history << :after_commit }
    @first.after_rollback_block { |r| r.history << :after_rollback }

    def @first.valid?(*)
      false
    end

    @first.transaction do
      assert_not @first.save
    end
    assert_equal [], @first.history
  end

  def test_dont_call_after_commit_on_update_based_on_previous_transaction
    @first.save!
    add_transaction_execution_blocks(@first)

    @first.abort_before_update = true
    @first.transaction { @first.save }

    assert_empty @first.history
  end

  def test_dont_call_after_commit_on_destroy_based_on_previous_transaction
    @first.destroy!
    add_transaction_execution_blocks(@first)

    @first.abort_before_destroy = true
    @first.transaction { @first.destroy }

    assert_empty @first.history
  end

  def test_only_call_after_commit_on_save_after_transaction_commits_for_saving_record
    record = TopicWithCallbacks.new(title: "New topic", written_on: Date.today)
    record.after_commit_block(:save) { |r| r.history << :after_save }

    record.save!
    assert_equal [:after_save], record.history

    record.update!(title: "Another topic")
    assert_equal [:after_save, :after_save], record.history
  end

  def test_only_call_after_commit_on_update_after_transaction_commits_for_existing_record
    add_transaction_execution_blocks @first

    @first.save!
    assert_equal [:commit_on_update], @first.history
  end

  def test_only_call_after_commit_on_destroy_after_transaction_commits_for_destroyed_record
    add_transaction_execution_blocks @first

    @first.destroy
    assert_equal [:commit_on_destroy], @first.history
  end

  def test_only_call_after_commit_on_create_after_transaction_commits_for_new_record
    new_record = TopicWithCallbacks.new(title: "New topic", written_on: Date.today)
    add_transaction_execution_blocks new_record

    new_record.save!
    assert_equal [:commit_on_create], new_record.history
  end

  def test_only_call_after_commit_on_create_after_transaction_commits_for_new_record_if_create_succeeds_creating_through_association
    topic = TopicWithCallbacks.create!(title: "New topic", written_on: Date.today)
    reply = topic.replies.create

    assert_equal [], reply.history
  end

  def test_no_after_commit_on_destroy_after_transaction_commits_for_destroyed_new_record
    new_record = TopicWithCallbacks.new(title: "New topic", written_on: Date.today)
    add_transaction_execution_blocks new_record

    new_record.destroy
    assert_equal [], new_record.history
  end

  def test_save_in_after_create_commit_wont_invoke_extra_after_create_commit
    new_record = TopicWithCallbacks.new(title: "New topic", written_on: Date.today)
    add_transaction_execution_blocks new_record
    new_record.after_commit_block(:create) { |r| r.save! }

    new_record.save!
    assert_equal [:commit_on_create, :commit_on_update], new_record.history
  end

  def test_only_call_after_commit_on_create_and_doesnt_leaky
    r = ReplyWithCallbacks.new(content: "foo")
    r.save_on_after_create = true
    r.save!
    r.content = "bar"
    r.save!
    r.save!
    assert_equal [:commit_on_create], r.history
  end

  def test_only_call_after_commit_on_update_after_transaction_commits_for_existing_record_on_touch
    add_transaction_execution_blocks @first

    @first.touch
    assert_equal [:commit_on_update], @first.history
  end

  def test_only_call_after_commit_on_top_level_transactions
    @first.after_commit_block { |r| r.history << :after_commit }
    assert_empty @first.history

    @first.transaction do
      @first.transaction(requires_new: true) do
        @first.touch
      end
      assert_empty @first.history
    end
    assert_equal [:after_commit], @first.history
  end

  def test_call_after_rollback_after_transaction_rollsback
    @first.after_commit_block { |r| r.history << :after_commit }
    @first.after_rollback_block { |r| r.history << :after_rollback }

    Topic.transaction do
      @first.save!
      raise ActiveRecord::Rollback
    end

    assert_equal [:after_rollback], @first.history
  end

  def test_only_call_after_rollback_on_update_after_transaction_rollsback_for_existing_record
    add_transaction_execution_blocks @first

    Topic.transaction do
      @first.save!
      raise ActiveRecord::Rollback
    end

    assert_equal [:rollback_on_update], @first.history
  end

  def test_only_call_after_rollback_on_update_after_transaction_rollsback_for_existing_record_on_touch
    add_transaction_execution_blocks @first

    Topic.transaction do
      @first.touch
      raise ActiveRecord::Rollback
    end

    assert_equal [:rollback_on_update], @first.history
  end

  def test_only_call_after_rollback_on_destroy_after_transaction_rollsback_for_destroyed_record
    add_transaction_execution_blocks @first

    Topic.transaction do
      @first.destroy
      raise ActiveRecord::Rollback
    end

    assert_equal [:rollback_on_destroy], @first.history
  end

  def test_only_call_after_rollback_on_create_after_transaction_rollsback_for_new_record
    new_record = TopicWithCallbacks.new(title: "New topic", written_on: Date.today)
    add_transaction_execution_blocks new_record

    Topic.transaction do
      new_record.save!
      raise ActiveRecord::Rollback
    end

    assert_equal [:rollback_on_create], new_record.history
  end

  def test_call_after_rollback_when_commit_fails
    @first.after_commit_block { |r| r.history << :after_commit }
    @first.after_rollback_block { |r| r.history << :after_rollback }

    assert_raises RuntimeError do
      @first.transaction do
        tx = @first.class.lease_connection.transaction_manager.current_transaction
        def tx.commit
          raise
        end

        @first.save
      end
    end

    assert_equal [:after_rollback], @first.history
  end

  def test_only_call_after_rollback_on_records_rolled_back_to_a_savepoint
    def @first.rollbacks(i = 0); @rollbacks ||= 0; @rollbacks += i if i; end
    def @first.commits(i = 0); @commits ||= 0; @commits += i if i; end
    @first.after_rollback_block { |r| r.rollbacks(1) }
    @first.after_commit_block { |r| r.commits(1) }

    second = TopicWithCallbacks.find(3)
    def second.rollbacks(i = 0); @rollbacks ||= 0; @rollbacks += i if i; end
    def second.commits(i = 0); @commits ||= 0; @commits += i if i; end
    second.after_rollback_block { |r| r.rollbacks(1) }
    second.after_commit_block { |r| r.commits(1) }

    Topic.transaction do
      @first.save!
      Topic.transaction(requires_new: true) do
        second.save!
        raise ActiveRecord::Rollback
      end
    end

    assert_equal 1, @first.commits
    assert_equal 0, @first.rollbacks
    assert_equal 0, second.commits
    assert_equal 1, second.rollbacks
  end

  def test_only_call_after_rollback_on_records_rolled_back_to_a_savepoint_when_release_savepoint_fails
    def @first.rollbacks(i = 0); @rollbacks ||= 0; @rollbacks += i if i; end
    def @first.commits(i = 0); @commits ||= 0; @commits += i if i; end

    @first.after_rollback_block { |r| r.rollbacks(1) }
    @first.after_commit_block { |r| r.commits(1) }

    Topic.transaction do
      @first.save
      Topic.transaction(requires_new: true) do
        @first.save!
        raise ActiveRecord::Rollback
      end
      Topic.transaction(requires_new: true) do
        @first.save!
        raise ActiveRecord::Rollback
      end
    end

    assert_equal 1, @first.commits
    assert_equal 2, @first.rollbacks
  end

  def test_after_commit_callback_should_not_swallow_errors
    @first.after_commit_block { fail "boom" }
    assert_raises(RuntimeError) do
      Topic.transaction do
        @first.save!
      end
    end
  end

  def test_after_commit_callback_when_raise_should_not_restore_state
    first = TopicWithCallbacks.new
    second = TopicWithCallbacks.new
    first.after_commit_block { fail "boom" }
    second.after_commit_block { fail "boom" }

    begin
      Topic.transaction do
        first.save!
        assert_not_nil first.id
        second.save!
        assert_not_nil second.id
      end
    rescue
    end
    assert_not_nil first.id
    assert_not_nil second.id
    assert first.reload
  end

  def test_after_rollback_callback_should_not_swallow_errors_when_set_to_raise
    error_class = Class.new(StandardError)
    @first.after_rollback_block { raise error_class }
    assert_raises(error_class) do
      Topic.transaction do
        @first.save!
        raise ActiveRecord::Rollback
      end
    end
  end

  def test_after_commit_callback_should_not_rollback_state_that_already_been_succeeded
    klass = Class.new(TopicWithCallbacks) do
      self.inheritance_column = nil
      validates :title, presence: true
    end

    first = klass.new(title: "foo")
    first.after_commit_block { |r| r.update(title: nil) if r.persisted? }
    first.save!

    assert_predicate first, :persisted?
    assert_not_nil first.id
  ensure
    first.destroy!
  end
  uses_transaction :test_after_commit_callback_should_not_rollback_state_that_already_been_succeeded

  def test_after_rollback_callback_when_raise_should_restore_state
    error_class = Class.new(StandardError)

    first = TopicWithCallbacks.new
    second = TopicWithCallbacks.new
    first.after_rollback_block { raise error_class }
    second.after_rollback_block { raise error_class }

    begin
      Topic.transaction do
        first.save!
        assert_not_nil first.id
        second.save!
        assert_not_nil second.id
        raise ActiveRecord::Rollback
      end
    rescue error_class
    end
    assert_nil first.id
    assert_nil second.id
  end

  def test_after_rollback_callbacks_should_validate_on_condition
    assert_raise(ArgumentError) { Topic.after_rollback(on: :save) }
    e = assert_raise(ArgumentError) { Topic.after_rollback(on: "create") }
    assert_match(/:on conditions for after_commit and after_rollback callbacks have to be one of \[:create, :destroy, :update\]/, e.message)
  end

  def test_after_commit_callbacks_should_validate_on_condition
    assert_raise(ArgumentError) { Topic.after_commit(on: :save) }
    e = assert_raise(ArgumentError) { Topic.after_commit(on: "create") }
    assert_match(/:on conditions for after_commit and after_rollback callbacks have to be one of \[:create, :destroy, :update\]/, e.message)
  end

  def test_after_commit_chain_not_called_on_errors
    record_1 = TopicWithCallbacks.create!
    record_2 = TopicWithCallbacks.create!
    record_3 = TopicWithCallbacks.create!
    callbacks = []
    record_1.after_commit_block { raise }
    record_2.after_commit_block { callbacks << record_2.id }
    record_3.after_commit_block { callbacks << record_3.id }
    begin
      TopicWithCallbacks.transaction do
        record_1.save!
        record_2.save!
        record_3.save!
      end
    rescue
      # From record_1.after_commit
    end
    assert_equal [], callbacks
  end

  def test_saving_a_record_with_a_belongs_to_that_specifies_touching_the_parent_should_call_callbacks_on_the_parent_object
    pet   = Pet.first
    owner = pet.owner
    flag = false

    owner.on_after_commit do
      flag = true
    end

    pet.name = "Fluffy the Third"
    pet.save

    assert flag
  end

  def test_saving_two_records_that_override_object_id_should_run_after_commit_callbacks_for_both
    klass = Class.new(TopicWithCallbacks) do
      silence_warnings do
        define_method(:object_id) { 42 }
      end
    end

    records = [klass.new, klass.new]

    klass.transaction do
      records.each do |record|
        record.after_commit_block { |r| r.history << :after_commit }
        record.save!
      end
    end

    assert_equal [:after_commit], records.first.history
    assert_equal [:after_commit], records.second.history
  end

  def test_saving_two_records_that_override_object_id_should_run_after_rollback_callbacks_for_both
    klass = Class.new(TopicWithCallbacks) do
      silence_warnings do
        define_method(:object_id) { 42 }
      end
    end

    records = [klass.new, klass.new]

    klass.transaction do
      records.each do |record|
        record.after_rollback_block { |r| r.history << :after_rollback }
        record.save!
      end
      raise ActiveRecord::Rollback
    end

    assert_equal [:after_rollback], records.first.history
    assert_equal [:after_rollback], records.second.history
  end

  def test_after_commit_does_not_mutate_the_if_options_array
    opts = []

    Class.new(ActiveRecord::Base) do
      self.table_name = "topics"

      after_commit(if: opts, on: :create) { }
    end

    assert_empty opts
  end

  private
    def add_transaction_execution_blocks(record)
      record.after_commit_block(:create) { |r| r.history << :commit_on_create }
      record.after_commit_block(:update) { |r| r.history << :commit_on_update }
      record.after_commit_block(:destroy) { |r| r.history << :commit_on_destroy }
      record.after_rollback_block(:create) { |r| r.history << :rollback_on_create }
      record.after_rollback_block(:update) { |r| r.history << :rollback_on_update }
      record.after_rollback_block(:destroy) { |r| r.history << :rollback_on_destroy }
    end
end

class TransactionAfterCommitCallbacksWithOptimisticLockingTest < ActiveRecord::TestCase
  class PersonWithCallbacks < ActiveRecord::Base
    self.table_name = :people

    after_create_commit { |record| record.history << :commit_on_create }
    after_update_commit { |record| record.history << :commit_on_update }
    after_destroy_commit { |record| record.history << :commit_on_destroy }

    def history
      @history ||= []
    end
  end

  def test_after_commit_callbacks_with_optimistic_locking
    person = PersonWithCallbacks.create!(first_name: "first name")
    person.update!(first_name: "another name")
    person.destroy

    assert_equal [:commit_on_create, :commit_on_update, :commit_on_destroy], person.history
  end
end

class CallbacksOnMultipleActionsTest < ActiveRecord::TestCase
  self.use_transactional_tests = false

  class TopicWithCallbacksOnMultipleActions < ActiveRecord::Base
    self.table_name = :topics

    after_commit(on: [:create, :destroy]) { |record| record.history << :create_and_destroy }
    after_commit(on: [:create, :update]) { |record| record.history << :create_and_update }
    after_commit(on: [:update, :destroy]) { |record| record.history << :update_and_destroy }

    before_commit(if: :save_before_commit_history) { |record| record.history << :before_commit }
    before_commit(if: :update_title) { |record| record.update(title: "before commit title") }

    def clear_history
      @history = []
    end

    def history
      @history ||= []
    end

    attr_accessor :save_before_commit_history, :update_title
  end

  def test_after_commit_on_multiple_actions
    topic = TopicWithCallbacksOnMultipleActions.new
    topic.save
    assert_equal [:create_and_update, :create_and_destroy], topic.history

    topic.clear_history
    topic.approved = true
    topic.save
    assert_equal [:update_and_destroy, :create_and_update], topic.history

    topic.clear_history
    topic.destroy
    assert_equal [:update_and_destroy, :create_and_destroy], topic.history
  end

  def test_before_commit_actions
    topic = TopicWithCallbacksOnMultipleActions.new
    topic.save_before_commit_history = true
    topic.save

    assert_equal [:before_commit, :create_and_update, :create_and_destroy], topic.history
  end

  def test_before_commit_update_in_same_transaction
    topic = TopicWithCallbacksOnMultipleActions.new
    topic.update_title = true
    topic.save

    assert_equal "before commit title", topic.title
    assert_equal "before commit title", topic.reload.title
  end
end

class CallbackOrderTest < ActiveRecord::TestCase
  self.use_transactional_tests = false

  module Behaviour
    extend ActiveSupport::Concern

    included do
      self.table_name = :topics

      after_commit { |record| record.history << 3 }
      after_commit { |record| record.history << 4 }
      after_save_commit { |record| record.history << "save" }
      after_create_commit { |record| record.history << "create" }
      after_update_commit { |record| record.history << "update" }
      after_destroy_commit { |record| record.history << "destroy" }

      after_rollback { |record| record.history << "rollback1" }
      after_rollback { |record| record.history << "rollback2" }

      before_commit { |record| record.history << 1 }
      before_commit { |record| record.history << 2 }
    end

    def clear_history
      @history = []
    end

    def history
      @history ||= []
    end
  end

  run_after_transaction_callbacks_in_order_defined_was = ActiveRecord.run_after_transaction_callbacks_in_order_defined
  ActiveRecord.run_after_transaction_callbacks_in_order_defined = true
  class TopicWithCallbacksWithSpecificOrderWithSettingTrue < ActiveRecord::Base
    include Behaviour
  end
  ActiveRecord.run_after_transaction_callbacks_in_order_defined = run_after_transaction_callbacks_in_order_defined_was

  run_after_transaction_callbacks_in_order_defined_was = ActiveRecord.run_after_transaction_callbacks_in_order_defined
  ActiveRecord.run_after_transaction_callbacks_in_order_defined = false
  class TopicWithCallbacksWithSpecificOrderWithSettingFalse < ActiveRecord::Base
    include Behaviour
  end
  ActiveRecord.run_after_transaction_callbacks_in_order_defined = run_after_transaction_callbacks_in_order_defined_was

  def test_callbacks_run_in_order_defined_in_model_if_using_run_after_transaction_callbacks_in_order_defined
    topic = TopicWithCallbacksWithSpecificOrderWithSettingTrue.new
    topic.save
    assert_equal [1, 2, 3, 4, "save", "create"], topic.history

    topic.clear_history
    topic.approved = true
    topic.save
    assert_equal [1, 2, 3, 4, "save", "update"], topic.history

    topic.clear_history
    topic.transaction do
      topic.approved = false
      topic.save
      raise ActiveRecord::Rollback
    end
    assert_equal ["rollback1", "rollback2"], topic.history

    topic.clear_history
    topic.destroy
    assert_equal [1, 2, 3, 4, "destroy"], topic.history
  end

  def test_callbacks_run_in_order_defined_in_model_if_not_using_run_after_transaction_callbacks_in_order_defined
    topic = TopicWithCallbacksWithSpecificOrderWithSettingFalse.new
    topic.save
    assert_equal [1, 2, "create", "save", 4, 3], topic.history

    topic.clear_history
    topic.approved = true
    topic.save
    assert_equal [1, 2, "update", "save", 4, 3], topic.history

    topic.clear_history
    topic.transaction do
      topic.approved = false
      topic.save
      raise ActiveRecord::Rollback
    end
    assert_equal ["rollback2", "rollback1"], topic.history

    topic.clear_history
    topic.destroy
    assert_equal [1, 2, "destroy", 4, 3], topic.history
  end
end

class CallbacksOnDestroyUpdateActionRaceTest < ActiveRecord::TestCase
  self.use_transactional_tests = false

  class TopicWithHistory < ActiveRecord::Base
    self.table_name = :topics

    def self.clear_history
      @@history = []
    end

    def self.history
      @@history ||= []
    end
  end

  class TopicWithCallbacksOnDestroy < TopicWithHistory
    after_commit(on: :destroy) { |record| record.class.history << :commit_on_destroy }
    after_rollback(on: :destroy) { |record| record.class.history << :rollback_on_destroy }

    before_destroy :before_destroy_for_transaction

    private
      def before_destroy_for_transaction; end
  end

  class TopicWithCallbacksOnUpdate < TopicWithHistory
    after_commit(on: :update) { |record| record.class.history << :commit_on_update }

    before_save :before_save_for_transaction

    private
      def before_save_for_transaction; end
  end

  def test_trigger_once_on_multiple_deletion_within_transaction
    TopicWithCallbacksOnDestroy.clear_history
    topic = TopicWithCallbacksOnDestroy.new
    topic.save
    topic_clone = TopicWithCallbacksOnDestroy.find(topic.id)

    topic.define_singleton_method(:before_destroy_for_transaction) do
      topic_clone.destroy
    end

    topic.destroy

    assert_equal [:commit_on_destroy], TopicWithCallbacksOnDestroy.history
  end

  def test_trigger_once_on_multiple_deletions
    TopicWithCallbacksOnDestroy.clear_history
    topic = TopicWithCallbacksOnDestroy.new
    topic.save
    topic_clone = TopicWithCallbacksOnDestroy.find(topic.id)

    topic.destroy
    topic.destroy
    topic_clone.destroy

    assert_equal [:commit_on_destroy], TopicWithCallbacksOnDestroy.history
  end

  def test_trigger_once_on_multiple_deletions_in_a_transaction
    TopicWithCallbacksOnDestroy.clear_history
    topic = TopicWithCallbacksOnDestroy.new
    topic.save

    TopicWithCallbacksOnDestroy.transaction do
      topic.destroy
      topic.destroy
    end

    assert_equal [:commit_on_destroy], TopicWithCallbacksOnDestroy.history
  end

  def test_rollback_on_multiple_deletions
    TopicWithCallbacksOnDestroy.clear_history
    topic = TopicWithCallbacksOnDestroy.new
    topic.save
    topic_clone = TopicWithCallbacksOnDestroy.find(topic.id)

    topic.define_singleton_method(:before_destroy_for_transaction) do
      topic_clone.update!(author_name: "Test Author Clone")
      topic_clone.destroy
    end

    TopicWithCallbacksOnDestroy.transaction do
      topic.update!(author_name: "Test Author")
      topic.destroy
      raise ActiveRecord::Rollback
    end

    assert_not_predicate topic, :destroyed?
    assert_not_predicate topic_clone, :destroyed?
    assert_equal [nil, "Test Author"], topic.author_name_change_to_be_saved
    assert_equal [nil, "Test Author Clone"], topic_clone.author_name_change_to_be_saved

    assert_equal [:rollback_on_destroy], TopicWithCallbacksOnDestroy.history
  end

  def test_trigger_on_update_where_row_was_deleted
    TopicWithCallbacksOnUpdate.clear_history
    topic = TopicWithCallbacksOnUpdate.new
    topic.save
    topic_clone = TopicWithCallbacksOnUpdate.find(topic.id)

    topic_clone.define_singleton_method(:before_save_for_transaction) do
      topic.destroy
    end

    topic_clone.author_name = "Test Author"
    topic_clone.save

    assert_equal [], TopicWithCallbacksOnUpdate.history
  end
end

class CallbacksOnActionAndConditionTest < ActiveRecord::TestCase
  self.use_transactional_tests = false

  class TopicWithCallbacksOnActionAndCondition < ActiveRecord::Base
    self.table_name = :topics

    after_commit(on: [:create, :update], if: :run_callback?) { |record| record.history << :create_or_update }

    def clear_history
      @history = []
    end

    def history
      @history ||= []
    end

    def run_callback?
      self.history << :run_callback?
      true
    end

    attr_accessor :save_before_commit_history, :update_title
  end

  def test_callback_on_action_with_condition
    topic = TopicWithCallbacksOnActionAndCondition.new
    topic.save
    assert_equal [:run_callback?, :create_or_update], topic.history

    topic.clear_history
    topic.approved = true
    topic.save
    assert_equal [:run_callback?, :create_or_update], topic.history

    topic.clear_history
    topic.destroy
    assert_equal [], topic.history
  end
end

class CallbacksOnMultipleInstancesInATransactionTest < ActiveRecord::TestCase
  class TopicWithTitleHistory < ActiveRecord::Base
    self.table_name = :topics

    def self.clear_history
      @@history = []
    end

    def self.history
      @@history ||= []
    end

    after_create_commit { |record| record.class.history << "Created (title = #{record.title.inspect})" }
    after_update_commit { |record| record.class.history << "Updated (title = #{record.title.inspect})" }
    after_destroy_commit { |record| record.class.history << "Destroyed (title = #{record.title.inspect})" }
  end

  def test_created_callback_called_on_last_to_save_of_separate_instances_in_a_transaction
    with_run_commit_callbacks_on_first_saved_instances_in_transaction(false) do
      TopicWithTitleHistory.clear_history

      TopicWithTitleHistory.transaction do
        topic = TopicWithTitleHistory.create!(title: "A")
        TopicWithTitleHistory.find(topic.id).update!(title: "B")
      end

      assert_equal ['Created (title = "B")'], TopicWithTitleHistory.history
    end
  end

  def test_created_callback_called_on_first_to_save_in_transaction_with_old_configuration
    with_run_commit_callbacks_on_first_saved_instances_in_transaction(true) do
      TopicWithTitleHistory.clear_history

      TopicWithTitleHistory.transaction do
        topic = TopicWithTitleHistory.create!(title: "A")
        TopicWithTitleHistory.find(topic.id).update!(title: "B")
      end

      assert_equal ['Created (title = "A")'], TopicWithTitleHistory.history
    end
  end

  def test_updated_callback_called_on_last_to_save_of_separate_instances_in_a_transaction
    with_run_commit_callbacks_on_first_saved_instances_in_transaction(false) do
      topic = TopicWithTitleHistory.create!(title: "one")
      TopicWithTitleHistory.clear_history

      TopicWithTitleHistory.transaction do
        TopicWithTitleHistory.find(topic.id).update!(title: "two")
        TopicWithTitleHistory.find(topic.id).update!(title: "three")
      end

      assert_equal ['Updated (title = "three")'], TopicWithTitleHistory.history
    end
  end

  def test_updated_callback_called_on_first_to_save_in_transaction_with_old_configuration
    with_run_commit_callbacks_on_first_saved_instances_in_transaction(true) do
      topic = TopicWithTitleHistory.create!(title: "one")
      TopicWithTitleHistory.clear_history

      TopicWithTitleHistory.transaction do
        TopicWithTitleHistory.find(topic.id).update!(title: "two")
        TopicWithTitleHistory.find(topic.id).update!(title: "three")
      end

      assert_equal ['Updated (title = "two")'], TopicWithTitleHistory.history
    end
  end

  def test_destroyed_callback_called_on_destroyed_instance_when_preceded_in_transaction_by_save_from_separate_instance
    with_run_commit_callbacks_on_first_saved_instances_in_transaction(false) do
      topic = TopicWithTitleHistory.create!(title: "one")
      TopicWithTitleHistory.clear_history

      TopicWithTitleHistory.transaction do
        TopicWithTitleHistory.find(topic.id).update!(title: "two")
        TopicWithTitleHistory.find(topic.id).destroy!
      end

      assert_equal ['Destroyed (title = "two")'], TopicWithTitleHistory.history
    end
  end

  def test_updated_callback_called_on_first_to_save_when_followed_in_transaction_by_destroy_from_separate_instance_with_old_configuration
    with_run_commit_callbacks_on_first_saved_instances_in_transaction(true) do
      topic = TopicWithTitleHistory.create!(title: "one")
      TopicWithTitleHistory.clear_history

      TopicWithTitleHistory.transaction do
        TopicWithTitleHistory.find(topic.id).update!(title: "two")
        TopicWithTitleHistory.find(topic.id).destroy!
      end

      assert_equal ['Updated (title = "two")'], TopicWithTitleHistory.history
    end
  end

  def test_destroyed_callbacks_called_on_destroyed_instance_even_when_followed_by_update_from_separate_instances_in_a_transaction
    with_run_commit_callbacks_on_first_saved_instances_in_transaction(false) do
      topic = TopicWithTitleHistory.create!(title: "one")
      TopicWithTitleHistory.clear_history

      TopicWithTitleHistory.transaction do
        TopicWithTitleHistory.find(topic.id).destroy!
        topic.update!(title: "two")
      end

      assert_equal ['Destroyed (title = "one")'], TopicWithTitleHistory.history
    end
  end

  def test_destroyed_callbacks_called_on_first_saved_instance_in_transaction_with_old_configuration
    with_run_commit_callbacks_on_first_saved_instances_in_transaction(true) do
      topic = TopicWithTitleHistory.create!(title: "one")
      TopicWithTitleHistory.clear_history

      TopicWithTitleHistory.transaction do
        TopicWithTitleHistory.find(topic.id).destroy!
        topic.update!(title: "two")
      end

      assert_equal ['Destroyed (title = "one")'], TopicWithTitleHistory.history
    end
  end

  def with_run_commit_callbacks_on_first_saved_instances_in_transaction(value, model: ActiveRecord::Base)
    old = model.run_commit_callbacks_on_first_saved_instances_in_transaction
    model.run_commit_callbacks_on_first_saved_instances_in_transaction = value
    yield
  ensure
    model.run_commit_callbacks_on_first_saved_instances_in_transaction = old
    if model != ActiveRecord::Base && !old
      # reset the class_attribute
      model.singleton_class.remove_method(:run_commit_callbacks_on_first_saved_instances_in_transaction)
    end
  end
end

class SetCallbackTest < ActiveRecord::TestCase
  self.use_transactional_tests = false

  class TopicWithHistory < ActiveRecord::Base
    self.table_name = :topics
    self.run_commit_callbacks_on_first_saved_instances_in_transaction = true

    def self.clear_history
      @@history = []
    end

    def self.history
      @@history ||= []
    end
  end

  class TopicWithCallbacksOnUpdate < TopicWithHistory
    after_commit :after_commit_on_update_1, on: :update
    after_update_commit :after_commit_on_update_2

    private
      def after_commit_on_update_1
        self.class.history << :after_commit_on_update_1
      end

      def after_commit_on_update_2
        self.class.history << :after_commit_on_update_2
      end
  end

  def test_set_callback_with_on
    topic = TopicWithCallbacksOnUpdate.create!(title: "New topic", written_on: Date.today)
    assert_empty TopicWithCallbacksOnUpdate.history

    topic.update!(title: "Updated topic 1")
    expected_history = [:after_commit_on_update_2, :after_commit_on_update_1]
    assert_equal expected_history, TopicWithCallbacksOnUpdate.history

    TopicWithCallbacksOnUpdate.skip_callback(:commit, :after, :after_commit_on_update_2)
    topic.update!(title: "Updated topic 2")
    expected_history << :after_commit_on_update_1
    assert_equal expected_history, TopicWithCallbacksOnUpdate.history

    TopicWithCallbacksOnUpdate.set_callback(:commit, :after, :after_commit_on_update_2, on: :update)
    topic = TopicWithCallbacksOnUpdate.create!(title: "New topic", written_on: Date.today)
    topic.update!(title: "Updated topic 3")
    expected_history << :after_commit_on_update_2
    expected_history << :after_commit_on_update_1
    assert_equal expected_history, TopicWithCallbacksOnUpdate.history
  end
end
