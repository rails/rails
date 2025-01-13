# frozen_string_literal: true

require "cases/helper"
require "models/auto_id"
require "models/aircraft"
require "models/dashboard"
require "models/clothing_item"
require "models/post"
require "models/comment"
require "models/author"
require "models/topic"
require "models/reply"
require "models/category"
require "models/company"
require "models/developer"
require "models/computer"
require "models/project"
require "models/minimalistic"
require "models/parrot"
require "models/minivan"
require "models/car"
require "models/person"
require "models/ship"
require "models/admin"
require "models/admin/user"
require "models/cpk"
require "models/chat_message"
require "models/default"
require "models/post_with_prefetched_pk"
require "models/pk_autopopulated_by_a_trigger_record"

class PersistenceTest < ActiveRecord::TestCase
  fixtures :topics, :companies, :developers, :accounts, :minimalistics, :authors, :author_addresses,
    :posts, :minivans, :clothing_items, :cpk_books, :people, :cars

  def test_populates_non_primary_key_autoincremented_column
    topic = TitlePrimaryKeyTopic.create!(title: "title pk topic")

    assert_not_nil topic.attributes["id"]
  end

  def test_populates_autoincremented_id_pk_regardless_of_its_position_in_columns_list
    auto_populated_column_names = AutoId.columns.select(&:auto_populated?).map(&:name)

    # It's important we test a scenario where tables has more than one auto populated column
    # and the first column is not the primary key. Otherwise it will be a regular test not asserting this special case.
    assert auto_populated_column_names.size > 1
    assert_not_equal AutoId.primary_key, auto_populated_column_names.first

    record = AutoId.create!
    last_id = AutoId.last.id

    assert_not_nil last_id
    assert last_id > 0
    assert_equal last_id, record.id
  end

  def test_populates_non_primary_key_autoincremented_column_for_a_cpk_model
    order = Cpk::Order.create(shop_id: 111_222)

    _shop_id, order_id = order.id

    assert_not_nil order_id
  end

  if current_adapter?(:PostgreSQLAdapter)
    def test_fills_auto_populated_columns_on_creation
      record = Default.create
      assert_not_nil record.id
      assert_equal "Ruby on Rails", record.ruby_on_rails

      if supports_virtual_columns?
        assert_not_nil record.virtual_stored_number
      end

      assert_not_nil record.random_number
      assert_not_nil record.modified_date
      assert_not_nil record.modified_date_function
      assert_not_nil record.modified_time
      assert_not_nil record.modified_time_without_precision
      assert_not_nil record.modified_time_function

      assert_equal "A", record.binary_default_function

      if supports_identity_columns?
        klass = Class.new(ActiveRecord::Base) do
          self.table_name = "postgresql_identity_table"
        end

        record = klass.create!
        assert_not_nil record.id
      end
    end
  elsif current_adapter?(:SQLite3Adapter)
    def test_fills_auto_populated_columns_on_creation
      record = Default.create
      assert_not_nil record.id
      assert_equal "Ruby on Rails", record.ruby_on_rails

      assert_not_nil record.random_number
      assert_not_nil record.modified_date
      assert_not_nil record.modified_date_function
      assert_not_nil record.modified_time
      assert_not_nil record.modified_time_without_precision
      assert_not_nil record.modified_time_function
    end
  elsif current_adapter?(:Mysql2Adapter, :TrilogyAdapter)
    def test_fills_auto_populated_columns_on_creation
      record = Default.create
      assert_not_nil record.id
      assert_not_nil record.char1

      if supports_default_expression? && supports_insert_returning?
        assert_not_nil record.uuid
      end
    end
  end

  def test_update_many
    topic_data = { 1 => { "content" => "1 updated" }, 2 => { "content" => "2 updated" } }
    updated = Topic.update(topic_data.keys, topic_data.values)

    assert_equal [1, 2], updated.map(&:id)
    assert_equal "1 updated", Topic.find(1).content
    assert_equal "2 updated", Topic.find(2).content
  end

  def test_update_many_with_duplicated_ids
    updated = Topic.update([1, 1, 2], [
      { "content" => "1 duplicated" }, { "content" => "1 updated" }, { "content" => "2 updated" }
    ])

    assert_equal [1, 1, 2], updated.map(&:id)
    assert_equal "1 updated", Topic.find(1).content
    assert_equal "2 updated", Topic.find(2).content
  end

  def test_update_many_with_invalid_id
    topic_data = { 1 => { "content" => "1 updated" }, 2 => { "content" => "2 updated" }, 99999 => {} }

    assert_raise(ActiveRecord::RecordNotFound) do
      Topic.update(topic_data.keys, topic_data.values)
    end

    assert_not_equal "1 updated", Topic.find(1).content
    assert_not_equal "2 updated", Topic.find(2).content
  end

  def test_update_many_with_active_record_base_object
    error = assert_raises(ArgumentError) do
      Topic.update(Topic.first, "content" => "1 updated")
    end

    assert_equal "You are passing an instance of ActiveRecord::Base to `update`. " \
    "Please pass the id of the object by calling `.id`.", error.message

    assert_not_equal "1 updated", Topic.first.content
  end

  def test_update_many_with_array_of_active_record_base_objects
    error = assert_raise(ArgumentError) do
      Topic.update(Topic.first(2), content: "updated")
    end

    assert_equal "You are passing an array of ActiveRecord::Base instances to `update`. " \
    "Please pass the ids of the objects by calling `pluck(:id)` or `map(&:id)`.", error.message

    assert_not_equal "updated", Topic.first.content
    assert_not_equal "updated", Topic.second.content
  end

  def test_class_level_update_without_ids
    topics = Topic.all
    assert_equal 5, topics.length
    topics.each do |topic|
      assert_not_equal "updated", topic.content
    end

    updated = Topic.update(content: "updated")
    assert_equal 5, updated.length
    updated.each do |topic|
      assert_equal "updated", topic.content
    end
  end

  def test_class_level_update_is_affected_by_scoping
    topic_data = { 1 => { "content" => "1 updated" }, 2 => { "content" => "2 updated" } }

    assert_raise(ActiveRecord::RecordNotFound) do
      Topic.where("1=0").scoping { Topic.update(topic_data.keys, topic_data.values) }
    end

    assert_not_equal "1 updated", Topic.find(1).content
    assert_not_equal "2 updated", Topic.find(2).content
  end

  def test_returns_object_even_if_validations_failed
    assert_equal Developer.all.to_a, Developer.update(salary: 1_000_000)
  end

  def test_update_many!
    topic_data = { 1 => { "content" => "1 updated" }, 2 => { "content" => "2 updated" } }
    updated = Topic.update!(topic_data.keys, topic_data.values)

    assert_equal [1, 2], updated.map(&:id)
    assert_equal "1 updated", Topic.find(1).content
    assert_equal "2 updated", Topic.find(2).content
  end

  def test_update_many_with_duplicated_ids!
    updated = Topic.update!([1, 1, 2], [
      { "content" => "1 duplicated" }, { "content" => "1 updated" }, { "content" => "2 updated" }
    ])

    assert_equal [1, 1, 2], updated.map(&:id)
    assert_equal "1 updated", Topic.find(1).content
    assert_equal "2 updated", Topic.find(2).content
  end

  def test_update_many_with_invalid_id!
    topic_data = { 1 => { "content" => "1 updated" }, 2 => { "content" => "2 updated" }, 99999 => {} }

    assert_raise(ActiveRecord::RecordNotFound) do
      Topic.update!(topic_data.keys, topic_data.values)
    end

    assert_not_equal "1 updated", Topic.find(1).content
    assert_not_equal "2 updated", Topic.find(2).content
  end

  def test_update_many_with_active_record_base_object!
    error = assert_raises(ArgumentError) do
      Topic.update!(Topic.first, "content" => "1 updated")
    end

    assert_equal "You are passing an instance of ActiveRecord::Base to `update!`. " \
    "Please pass the id of the object by calling `.id`.", error.message

    assert_not_equal "1 updated", Topic.first.content
  end

  def test_update_many_with_array_of_active_record_base_objects!
    error = assert_raise(ArgumentError) do
      Topic.update!(Topic.first(2), content: "updated")
    end

    assert_equal "You are passing an array of ActiveRecord::Base instances to `update!`. " \
    "Please pass the ids of the objects by calling `pluck(:id)` or `map(&:id)`.", error.message

    assert_not_equal "updated", Topic.first.content
    assert_not_equal "updated", Topic.second.content
  end

  def test_class_level_update_without_ids!
    topics = Topic.all
    assert_equal 5, topics.length
    topics.each do |topic|
      assert_not_equal "updated", topic.content
    end

    updated = Topic.update!(content: "updated")
    assert_equal 5, updated.length
    updated.each do |topic|
      assert_equal "updated", topic.content
    end
  end

  def test_class_level_update_is_affected_by_scoping!
    topic_data = { 1 => { "content" => "1 updated" }, 2 => { "content" => "2 updated" } }

    assert_raise(ActiveRecord::RecordNotFound) do
      Topic.where("1=0").scoping { Topic.update!(topic_data.keys, topic_data.values) }
    end

    assert_not_equal "1 updated", Topic.find(1).content
    assert_not_equal "2 updated", Topic.find(2).content
  end

  def test_raises_error_when_validations_failed
    assert_raises(ActiveRecord::RecordInvalid) do
      Developer.update!(salary: 1_000_000)
    end
  end

  def test_delete_all
    assert Topic.count > 0

    assert_equal Topic.count, Topic.delete_all
  end

  def test_increment_attribute
    assert_equal 50, accounts(:signals37).credit_limit

    accounts(:signals37).increment! :credit_limit
    assert_equal 51, accounts(:signals37, :reload).credit_limit

    accounts(:signals37).increment(:credit_limit).increment!(:credit_limit)
    assert_equal 53, accounts(:signals37, :reload).credit_limit
  end

  def test_increment_aliased_attribute
    assert_equal 50, accounts(:signals37).available_credit

    accounts(:signals37).increment!(:available_credit)
    assert_equal 51, accounts(:signals37, :reload).available_credit

    accounts(:signals37).increment(:available_credit).increment!(:available_credit)
    assert_equal 53, accounts(:signals37, :reload).available_credit
  end

  def test_increment_nil_attribute
    assert_nil topics(:first).parent_id
    topics(:first).increment! :parent_id
    assert_equal 1, topics(:first).parent_id
  end

  def test_increment_attribute_by
    assert_equal 50, accounts(:signals37).credit_limit
    accounts(:signals37).increment! :credit_limit, 5
    assert_equal 55, accounts(:signals37, :reload).credit_limit

    accounts(:signals37).increment(:credit_limit, 1).increment!(:credit_limit, 3)
    assert_equal 59, accounts(:signals37, :reload).credit_limit
  end

  def test_increment_updates_counter_in_db_using_offset
    a1 = accounts(:signals37)
    initial_credit = a1.credit_limit
    a2 = Account.find(accounts(:signals37).id)
    a1.increment!(:credit_limit)
    a2.increment!(:credit_limit)
    assert_equal initial_credit + 2, a1.reload.credit_limit
  end

  def test_increment_with_touch_updates_timestamps
    topic = topics(:first)
    assert_equal 1, topic.replies_count
    previously_updated_at = topic.updated_at
    travel(1.second) do
      topic.increment!(:replies_count, touch: true)
    end
    assert_equal 2, topic.reload.replies_count
    assert_operator previously_updated_at, :<, topic.updated_at
  end

  def test_increment_with_touch_an_attribute_updates_timestamps
    topic = topics(:first)
    assert_equal 1, topic.replies_count
    previously_updated_at = topic.updated_at
    previously_written_on = topic.written_on
    travel(1.second) do
      topic.increment!(:replies_count, touch: :written_on)
    end
    assert_equal 2, topic.reload.replies_count
    assert_operator previously_updated_at, :<, topic.updated_at
    assert_operator previously_written_on, :<, topic.written_on
  end

  def test_increment_with_no_arg
    topic = topics(:first)
    assert_raises(ArgumentError) { topic.increment! }
  end

  def test_increment_new_record
    topic = Topic.new

    assert_no_queries do
      assert_raises ActiveRecord::ActiveRecordError do
        topic.increment!(:replies_count)
      end
    end
  end

  def test_increment_destroyed_record
    topic = topics(:first)
    topic.destroy

    assert_no_queries do
      assert_raises ActiveRecord::ActiveRecordError do
        topic.increment!(:replies_count)
      end
    end
  end

  def test_destroy_many
    clients = Client.find([2, 3])

    assert_difference("Client.count", -2) do
      destroyed = Client.destroy([2, 3])
      assert_equal clients, destroyed
      assert destroyed.all?(&:frozen?), "destroyed clients should be frozen"
    end
  end

  def test_destroy_many_with_invalid_id
    clients = Client.find([2, 3])

    assert_raise(ActiveRecord::RecordNotFound) do
      Client.destroy([2, 3, 99999])
    end

    assert_equal clients, Client.find([2, 3])
  end

  def test_destroy_with_single_composite_primary_key
    book = cpk_books(:cpk_great_author_first_book)

    assert_difference("Cpk::Book.count", -1) do
      destroyed = Cpk::Book.destroy(book.id)
      assert_equal destroyed, book
    end
  end

  def test_destroy_with_multiple_composite_primary_keys
    books = [
      cpk_books(:cpk_great_author_first_book),
      cpk_books(:cpk_great_author_second_book),
    ]

    assert_difference("Cpk::Book.count", -2) do
      destroyed = Cpk::Book.destroy(books.map(&:id))
      assert_equal books.sort, destroyed.sort
      assert destroyed.all?(&:frozen?), "destroyed clients should be frozen"
    end
  end

  def test_destroy_with_invalid_ids_for_a_model_that_expects_composite_keys
    books = [
      cpk_books(:cpk_great_author_first_book),
      cpk_books(:cpk_great_author_second_book),
    ]

    assert_raise(ActiveRecord::RecordNotFound) do
      ids = books.map { |book| book.id.first }
      Cpk::Book.destroy(ids)
    end
  end

  def test_becomes
    assert_kind_of Reply, topics(:first).becomes(Reply)
    assert_equal "The First Topic", topics(:first).becomes(Reply).title
  end

  def test_becomes_after_reload_schema_from_cache
    Reply.define_attribute_methods
    Reply.serialize(:content) # invoke reload_schema_from_cache
    assert_kind_of Reply, topics(:first).becomes(Reply)
    assert_equal "The First Topic", topics(:first).becomes(Reply).title
  end

  def test_becomes_includes_errors
    company = Company.new(name: nil)
    assert_not_predicate company, :valid?
    original_errors = company.errors
    client = company.becomes(Client)
    assert_equal original_errors.attribute_names, client.errors.attribute_names
  end

  def test_becomes_errors_base
    child_class = Class.new(Admin::User) do
      store_accessor :settings, :foo

      def self.name; "Admin::ChildUser"; end
    end

    admin = Admin::User.new
    admin.errors.add :token, :invalid
    child = admin.becomes(child_class)

    assert_equal [:token], child.errors.attribute_names
    assert_nothing_raised do
      child.errors.add :foo, :invalid
    end
  end

  def test_duped_becomes_persists_changes_from_the_original
    original = topics(:first)
    copy = original.dup.becomes(Reply)
    copy.save!
    assert_equal "The First Topic", Topic.find(copy.id).title
  end

  def test_becomes_wont_break_mutation_tracking
    topic = topics(:first)
    reply = topic.becomes(Reply)

    assert_equal 1, topic.id_in_database
    assert_empty topic.attributes_in_database

    assert_equal 1, reply.id_in_database
    assert_empty reply.attributes_in_database
  end

  def test_becomes_includes_changed_attributes
    company = Company.new(name: "37signals")
    client = company.becomes(Client)
    assert_equal "37signals", client.name
    assert_equal %w{name}, client.changed
  end

  def test_becomes_preserve_record_status
    company = Company.new(name: "37signals")
    client = company.becomes(Client)
    assert_predicate client, :new_record?

    company.save
    client = company.becomes(Client)
    assert_predicate client, :persisted?
    assert_predicate client, :previously_new_record?
  end

  def test_becomes_initializes_missing_attributes
    company = Company.new(name: "GrowingCompany")

    client = company.becomes(LargeClient)

    assert_equal 50, client.extra_size
  end

  def test_becomes_keeps_extra_attributes
    client = LargeClient.new(name: "ShrinkingCompany")

    company = client.becomes(Company)

    assert_equal 50, company.extra_size
    assert_equal 50, client.extra_size
  end

  def test_delete_many
    original_count = Topic.count
    Topic.delete(deleting = [1, 2])
    assert_equal original_count - deleting.size, Topic.count
  end

  def test_decrement_attribute
    assert_equal 50, accounts(:signals37).credit_limit

    accounts(:signals37).decrement!(:credit_limit)
    assert_equal 49, accounts(:signals37, :reload).credit_limit

    accounts(:signals37).decrement(:credit_limit).decrement!(:credit_limit)
    assert_equal 47, accounts(:signals37, :reload).credit_limit
  end

  def test_decrement_attribute_by
    assert_equal 50, accounts(:signals37).credit_limit
    accounts(:signals37).decrement! :credit_limit, 5
    assert_equal 45, accounts(:signals37, :reload).credit_limit

    accounts(:signals37).decrement(:credit_limit, 1).decrement!(:credit_limit, 3)
    assert_equal 41, accounts(:signals37, :reload).credit_limit
  end

  def test_decrement_with_touch_updates_timestamps
    topic = topics(:first)
    assert_equal 1, topic.replies_count
    previously_updated_at = topic.updated_at
    travel(1.second) do
      topic.decrement!(:replies_count, touch: true)
    end
    assert_equal 0, topic.reload.replies_count
    assert_operator previously_updated_at, :<, topic.updated_at
  end

  def test_decrement_with_touch_an_attribute_updates_timestamps
    topic = topics(:first)
    assert_equal 1, topic.replies_count
    previously_updated_at = topic.updated_at
    previously_written_on = topic.written_on
    travel(1.second) do
      topic.decrement!(:replies_count, touch: :written_on)
    end
    assert_equal 0, topic.reload.replies_count
    assert_operator previously_updated_at, :<, topic.updated_at
    assert_operator previously_written_on, :<, topic.written_on
  end

  def test_create
    topic = Topic.new
    topic.title = "New Topic"
    topic.save
    topic_reloaded = Topic.find(topic.id)
    assert_equal("New Topic", topic_reloaded.title)
  end

  def test_create_prefetched_pk
    post = PostWithPrefetchedPk.create!(title: "New Message", body: "New Body")
    assert_equal 123456, post.id
  end

  def test_create_model_with_uuid_pk_populates_id
    message = ChatMessage.create(content: "New Message")
    assert_not_nil message.id

    message_reloaded = ChatMessage.find(message.id)
    assert_equal "New Message", message_reloaded.content
  end if current_adapter?(:PostgreSQLAdapter)


  def test_create_model_with_custom_named_uuid_pk_populates_id
    message = ChatMessageCustomPk.create(content: "New Message")
    assert_not_nil message.message_id

    message_reloaded = ChatMessageCustomPk.find(message.message_id)
    assert_equal "New Message", message_reloaded.content
  end if current_adapter?(:PostgreSQLAdapter)

  def test_build
    topic = Topic.build(title: "New Topic")
    assert_equal "New Topic", topic.title
    assert_not_predicate topic, :persisted?
  end

  def test_build_many
    topics = Topic.build([{ title: "first" }, { title: "second" }])
    assert_equal ["first", "second"], topics.map(&:title)
    topics.each { |topic| assert_not_predicate topic, :persisted? }
  end

  def test_build_through_factory_with_block
    topic = Topic.build("title" => "New Topic") do |t|
      t.author_name = "David"
    end
    assert_equal("New Topic", topic.title)
    assert_equal("David", topic.author_name)
    assert_not_predicate topic, :persisted?
  end

  def test_build_many_through_factory_with_block
    topics = Topic.build([{ "title" => "first" }, { "title" => "second" }]) do |t|
      t.author_name = "David"
    end
    assert_equal 2, topics.size
    topics.each { |topic| assert_not_predicate topic, :persisted? }
    topic1, topic2 = topics
    assert_equal "first", topic1.title
    assert_equal "David", topic1.author_name
    assert_equal "second", topic2.title
    assert_equal "David", topic2.author_name
  end

  def test_save_valid_record
    topic = Topic.new(title: "New Topic")
    assert topic.save!
  end

  def test_save_invalid_record
    reply = WrongReply.new(title: "New reply")
    error = assert_raise(ActiveRecord::RecordInvalid) { reply.save! }

    assert_equal "Validation failed: Content Empty", error.message
  end

  def test_save_destroyed_object
    topic = Topic.create!(title: "New Topic")
    topic.destroy!

    error = assert_raise(ActiveRecord::RecordNotSaved) { topic.save! }

    assert_equal "Failed to save the record", error.message
  end

  def test_save_null_string_attributes
    topic = Topic.find(1)
    topic.attributes = { "title" => "null", "author_name" => "null" }
    topic.save!
    topic.reload
    assert_equal("null", topic.title)
    assert_equal("null", topic.author_name)
  end

  def test_save_nil_string_attributes
    topic = Topic.find(1)
    topic.title = nil
    topic.save!
    topic.reload
    assert_nil topic.title
  end

  def test_save_for_record_with_only_primary_key
    minimalistic = Minimalistic.new
    assert_nothing_raised { minimalistic.save }
  end

  def test_save_for_record_with_only_primary_key_that_is_provided
    assert_nothing_raised { Minimalistic.create!(id: 2) }
  end

  def test_save_with_duping_of_destroyed_object
    developer = Developer.first
    developer.destroy
    new_developer = developer.dup
    new_developer.save
    assert_predicate new_developer, :persisted?
    assert_not_predicate new_developer, :destroyed?
  end

  def test_create_many
    topics = Topic.create([ { "title" => "first" }, { "title" => "second" }])
    assert_equal 2, topics.size
    assert_equal "first", topics.first.title
  end

  def test_create_columns_not_equal_attributes
    topic = Topic.instantiate(
      "title"          => "Another New Topic",
      "does_not_exist" => "test"
    )
    topic = topic.dup # reset @new_record
    assert_nothing_raised { topic.save }
    assert_predicate topic, :persisted?
    assert_equal "Another New Topic", topic.reload.title
  end

  def test_create_through_factory_with_block
    topic = Topic.create("title" => "New Topic") do |t|
      t.author_name = "David"
    end
    assert_equal("New Topic", topic.title)
    assert_equal("David", topic.author_name)
  end

  def test_create_many_through_factory_with_block
    topics = Topic.create([ { "title" => "first" }, { "title" => "second" }]) do |t|
      t.author_name = "David"
    end
    assert_equal 2, topics.size
    topic1, topic2 = Topic.find(topics[0].id), Topic.find(topics[1].id)
    assert_equal "first", topic1.title
    assert_equal "David", topic1.author_name
    assert_equal "second", topic2.title
    assert_equal "David", topic2.author_name
  end

  def test_update_object
    topic = Topic.new
    topic.title = "Another New Topic"
    topic.written_on = "2003-12-12 23:23:00"
    topic.save
    topic_reloaded = Topic.find(topic.id)
    assert_equal("Another New Topic", topic_reloaded.title)

    topic_reloaded.title = "Updated topic"
    topic_reloaded.save

    topic_reloaded_again = Topic.find(topic.id)

    assert_equal("Updated topic", topic_reloaded_again.title)
  end

  def test_update_columns_not_equal_attributes
    topic = Topic.new
    topic.title = "Still another topic"
    topic.save

    topic_reloaded = Topic.instantiate(topic.attributes.merge("does_not_exist" => "test"))
    topic_reloaded.title = "A New Topic"
    assert_nothing_raised { topic_reloaded.save }
    assert_predicate topic_reloaded, :persisted?
    assert_equal "A New Topic", topic_reloaded.reload.title
  end

  def test_update_for_record_with_only_primary_key
    minimalistic = minimalistics(:first)
    assert_nothing_raised { minimalistic.save }
  end

  def test_update_sti_type
    assert_instance_of Reply, topics(:second)

    topic = topics(:second).becomes!(Topic)
    assert_instance_of Topic, topic
    topic.save!
    assert_instance_of Topic, Topic.find(topic.id)
  end

  def test_preserve_original_sti_type
    reply = topics(:second)
    assert_equal "Reply", reply.type

    topic = reply.becomes(Topic)
    assert_equal "Reply", reply.type

    assert_instance_of Topic, topic
    assert_equal "Reply", topic.type
  end

  def test_update_sti_subclass_type
    assert_instance_of Topic, topics(:first)

    reply = topics(:first).becomes!(Reply)
    assert_instance_of Reply, reply
    reply.save!
    assert_instance_of Reply, Reply.find(reply.id)
  end

  def test_becomes_default_sti_subclass
    original_type = Topic.columns_hash["type"].default
    ActiveRecord::Base.lease_connection.change_column_default :topics, :type, "Reply"
    Topic.reset_column_information

    reply = topics(:second)
    assert_instance_of Reply, reply

    topic = reply.becomes(Topic)
    assert_instance_of Topic, topic

  ensure
    ActiveRecord::Base.lease_connection.change_column_default :topics, :type, original_type
    Topic.reset_column_information
  end

  def test_update_after_create
    klass = Class.new(Topic) do
      def self.name; "Topic"; end
      after_create do
        update_attribute("author_name", "David")
      end
    end
    topic = klass.new
    topic.title = "Another New Topic"
    topic.save

    topic_reloaded = Topic.find(topic.id)
    assert_equal("Another New Topic", topic_reloaded.title)
    assert_equal("David", topic_reloaded.author_name)
  end

  def test_update_attribute_after_update
    klass = Class.new(Topic) do
      def self.name; "Topic"; end
      after_update :update_author, if: :saved_change_to_title?
      def update_author
        update_attribute("author_name", "David")
      end
    end
    topic = klass.create(title: "New Topic")
    topic.update(title: "Another Topic")

    topic_reloaded = Topic.find(topic.id)
    assert_equal("Another Topic", topic_reloaded.title)
    assert_equal("David", topic_reloaded.author_name)
  end

  def test_update_attribute_in_before_validation_respects_callback_chain
    klass = Class.new(Topic) do
      def self.name; "Topic"; end

      before_validation :set_author_name
      after_create :track_create
      after_update :call_once, if: :saved_change_to_author_name?

      attr_reader :counter

      def set_author_name
        update_attribute :author_name, "David"
      end

      def track_create
        call_once if saved_change_to_author_name?
      end

      def call_once
        @counter ||= 0
        @counter += 1
      end
    end

    comment = klass.create(title: "New Topic", author_name: "Not David")

    assert_equal 1, comment.counter
  end

  def test_update_attribute_does_not_run_sql_if_attribute_is_not_changed
    topic = Topic.create(title: "Another New Topic")
    assert_no_queries do
      assert topic.update_attribute(:title, "Another New Topic")
    end
  end

  def test_update_does_not_run_sql_if_record_has_not_changed
    topic = Topic.create(title: "Another New Topic")
    assert_no_queries do
      assert topic.update(title: "Another New Topic")
    end
  end

  def test_delete
    topic = Topic.find(1)
    assert_equal topic, topic.delete, "topic.delete did not return self"
    assert_predicate topic, :frozen?, "topic not frozen after delete"
    assert_raise(ActiveRecord::RecordNotFound) { Topic.find(topic.id) }
  end

  def test_delete_doesnt_run_callbacks
    Topic.find(1).delete
    assert_not_nil Topic.find(2)
  end

  def test_delete_isnt_affected_by_scoping
    topic = Topic.find(1)
    assert_difference("Topic.count", -1) do
      Topic.where("1=0").scoping { topic.delete }
    end
  end

  def test_destroy
    topic = Topic.find(1)
    assert_equal topic, topic.destroy, "topic.destroy did not return self"
    assert_predicate topic, :frozen?, "topic not frozen after destroy"
    assert_raise(ActiveRecord::RecordNotFound) { Topic.find(topic.id) }
  end

  def test_destroy!
    topic = Topic.find(1)
    assert_equal topic, topic.destroy!, "topic.destroy! did not return self"
    assert_predicate topic, :frozen?, "topic not frozen after destroy!"
    assert_raise(ActiveRecord::RecordNotFound) { Topic.find(topic.id) }
  end

  def test_destroy_for_a_failed_to_destroy_cpk_record
    book = cpk_books(:cpk_great_author_first_book)
    book.fail_destroy = true
    assert_raises(ActiveRecord::RecordNotDestroyed, match: /Failed to destroy Cpk::Book with \["author_id", "id"\]=/) do
      book.destroy!
    end
  end

  def test_find_raises_record_not_found_exception
    assert_raise(ActiveRecord::RecordNotFound) { Topic.find(99999) }
  end

  def test_update_raises_record_not_found_exception
    assert_raise(ActiveRecord::RecordNotFound) { Topic.update(99999, approved: true) }
  end

  def test_destroy_raises_record_not_found_exception
    assert_raise(ActiveRecord::RecordNotFound) { Topic.destroy(99999) }
  end

  def test_update_all
    assert_equal Topic.count, Topic.update_all("content = 'bulk updated!'")
    assert_equal "bulk updated!", Topic.find(1).content
    assert_equal "bulk updated!", Topic.find(2).content

    assert_equal Topic.count, Topic.update_all(["content = ?", "bulk updated again!"])
    assert_equal "bulk updated again!", Topic.find(1).content
    assert_equal "bulk updated again!", Topic.find(2).content

    assert_equal Topic.count, Topic.update_all(["content = ?", nil])
    assert_nil Topic.find(1).content
  end

  def test_update_all_with_hash
    assert_not_nil Topic.find(1).last_read
    assert_equal Topic.count, Topic.update_all(content: "bulk updated with hash!", last_read: nil)
    assert_equal "bulk updated with hash!", Topic.find(1).content
    assert_equal "bulk updated with hash!", Topic.find(2).content
    assert_nil Topic.find(1).last_read
    assert_nil Topic.find(2).last_read
  end

  def test_update_all_with_custom_sql_as_value
    person = people(:michael)
    person.update!(cars_count: 0)

    Person.update_all(cars_count: Arel.sql(<<~SQL))
      select count(*) from cars where cars.person_id = people.id
    SQL
    assert_equal 1, person.reload.cars_count
  end

  def test_delete_new_record
    client = Client.new(name: "37signals")
    client.delete
    assert_predicate client, :frozen?

    assert_not client.save
    assert_raise(ActiveRecord::RecordNotSaved) { client.save! }

    assert_predicate client, :frozen?
    assert_raise(RuntimeError) { client.name = "something else" }
  end

  def test_delete_record_with_associations
    client = Client.find(3)
    client.delete
    assert_predicate client, :frozen?
    assert_kind_of Firm, client.firm

    assert_not client.save
    assert_raise(ActiveRecord::RecordNotSaved) { client.save! }

    assert_predicate client, :frozen?
    assert_raise(RuntimeError) { client.name = "something else" }
  end

  def test_destroy_new_record
    client = Client.new(name: "37signals")
    client.destroy
    assert_predicate client, :frozen?

    assert_not client.save
    assert_raise(ActiveRecord::RecordNotSaved) { client.save! }

    assert_predicate client, :frozen?
    assert_raise(RuntimeError) { client.name = "something else" }
  end

  def test_destroy_record_with_associations
    client = Client.find(3)
    client.destroy
    assert_predicate client, :frozen?
    assert_kind_of Firm, client.firm

    assert_not client.save
    assert_raise(ActiveRecord::RecordNotSaved) { client.save! }

    assert_predicate client, :frozen?
    assert_raise(RuntimeError) { client.name = "something else" }
  end

  def test_update_attribute
    assert_not_predicate Topic.find(1), :approved?
    Topic.find(1).update_attribute("approved", true)
    assert_predicate Topic.find(1), :approved?

    Topic.find(1).update_attribute(:approved, false)
    assert_not_predicate Topic.find(1), :approved?

    Topic.find(1).update_attribute(:change_approved_before_save, true)
    assert_predicate Topic.find(1), :approved?
  end

  def test_update_attribute_for_readonly_attribute
    minivan = Minivan.find("m1")
    assert_raises(ActiveRecord::ActiveRecordError) { minivan.update_attribute(:color, "black") }
  end

  def test_update_attribute_with_one_updated
    t = Topic.first
    t.update_attribute(:title, "super_title")
    assert_equal "super_title", t.title
    assert_not t.changed?, "topic should not have changed"
    assert_not t.title_changed?, "title should not have changed"
    assert_nil t.title_change, "title change should be nil"

    t.reload
    assert_equal "super_title", t.title
  end

  def test_update_attribute_for_updated_at_on
    developer = Developer.find(1)
    prev_month = Time.now.prev_month.change(usec: 0)

    developer.update_attribute(:updated_at, prev_month)
    assert_equal prev_month, developer.updated_at

    developer.update_attribute(:salary, 80001)
    assert_not_equal prev_month, developer.updated_at

    developer.reload
    assert_not_equal prev_month, developer.updated_at
  end

  def test_update_attribute!
    assert_not_predicate Topic.find(1), :approved?
    Topic.find(1).update_attribute!("approved", true)
    assert_predicate Topic.find(1), :approved?

    Topic.find(1).update_attribute!(:approved, false)
    assert_not_predicate Topic.find(1), :approved?

    Topic.find(1).update_attribute!(:change_approved_before_save, true)
    assert_predicate Topic.find(1), :approved?
  end

  def test_update_attribute_for_readonly_attribute!
    minivan = Minivan.find("m1")
    assert_raises(ActiveRecord::ActiveRecordError) { minivan.update_attribute!(:color, "black") }
  end

  def test_update_attribute_with_one_updated!
    t = Topic.first
    t.update_attribute!(:title, "super_title")
    assert_equal "super_title", t.title
    assert_not t.changed?, "topic should not have changed"
    assert_not t.title_changed?, "title should not have changed"
    assert_nil t.title_change, "title change should be nil"

    t.reload
    assert_equal "super_title", t.title
  end

  def test_update_attribute_for_updated_at_on!
    developer = Developer.find(1)
    prev_month = Time.now.prev_month.change(usec: 0)

    developer.update_attribute!(:updated_at, prev_month)
    assert_equal prev_month, developer.updated_at

    developer.update_attribute!(:salary, 80001)
    assert_not_equal prev_month, developer.updated_at

    developer.reload
    assert_not_equal prev_month, developer.updated_at
  end

  def test_update_attribute_for_aborted_callback!
    klass = Class.new(Topic) do
      def self.name; "Topic"; end

      before_update :throw_abort

      def throw_abort
        throw(:abort)
      end
    end

    t = klass.create(title: "New Topic", author_name: "Not David")

    assert_raises(ActiveRecord::RecordNotSaved) { t.update_attribute!(:title, "super_title") }

    t_reloaded = Topic.find(t.id)

    assert_equal "New Topic", t_reloaded.title
  end

  def test_update_column
    topic = Topic.find(1)
    topic.update_column("approved", true)
    assert_predicate topic, :approved?
    topic.reload
    assert_predicate topic, :approved?

    topic.update_column(:approved, false)
    assert_not_predicate topic, :approved?
    topic.reload
    assert_not_predicate topic, :approved?
  end

  def test_update_column_should_not_use_setter_method
    dev = Developer.find(1)
    dev.instance_eval { def salary=(value); write_attribute(:salary, value * 2); end }

    dev.update_column(:salary, 80000)
    assert_equal 80000, dev.salary

    dev.reload
    assert_equal 80000, dev.salary
  end

  def test_update_column_should_raise_exception_if_new_record
    topic = Topic.new
    assert_raises(ActiveRecord::ActiveRecordError) { topic.update_column("approved", false) }
  end

  def test_update_column_should_not_leave_the_object_dirty
    topic = Topic.find(1)
    topic.update_column("content", "--- Have a nice day\n...\n")

    topic.reload
    topic.update_column(:content, "--- You too\n...\n")
    assert_equal [], topic.changed

    topic.reload
    topic.update_column("content", "--- Have a nice day\n...\n")
    assert_equal [], topic.changed
  end

  def test_update_column_with_model_having_primary_key_other_than_id
    minivan = Minivan.find("m1")
    new_name = "sebavan"

    minivan.update_column(:name, new_name)
    assert_equal new_name, minivan.name
  end

  def test_update_column_for_readonly_attribute
    minivan = Minivan.find("m1")
    prev_color = minivan.color
    assert_raises(ActiveRecord::ActiveRecordError) { minivan.update_column(:color, "black") }
    assert_equal prev_color, minivan.color
  end

  def test_update_column_should_not_modify_updated_at
    developer = Developer.find(1)
    prev_month = Time.now.prev_month.change(usec: 0)

    developer.update_column(:updated_at, prev_month)
    assert_equal prev_month, developer.updated_at

    developer.update_column(:salary, 80001)
    assert_equal prev_month, developer.updated_at

    developer.reload
    assert_equal prev_month.to_i, developer.updated_at.to_i
  end

  def test_update_column_with_one_changed_and_one_updated
    t = Topic.order("id").limit(1).first
    author_name = t.author_name
    t.author_name = "John"
    t.update_column(:title, "super_title")
    assert_equal "John", t.author_name
    assert_equal "super_title", t.title
    assert_predicate t, :changed?, "topic should have changed"
    assert_predicate t, :author_name_changed?, "author_name should have changed"

    t.reload
    assert_equal author_name, t.author_name
    assert_equal "super_title", t.title
  end

  def test_update_column_with_default_scope
    developer = DeveloperCalledDavid.first
    developer.name = "John"
    developer.save!

    assert developer.update_column(:name, "Will"), "did not update record due to default scope"
  end

  def test_update_columns
    topic = Topic.find(1)
    topic.update_columns("approved" => true, title: "Sebastian Topic")
    assert_predicate topic, :approved?
    assert_equal "Sebastian Topic", topic.title
    topic.reload
    assert_predicate topic, :approved?
    assert_equal "Sebastian Topic", topic.title
  end

  def test_update_columns_should_not_use_setter_method
    dev = Developer.find(1)
    dev.instance_eval { def salary=(value); write_attribute(:salary, value * 2); end }

    dev.update_columns(salary: 80000)
    assert_equal 80000, dev.salary

    dev.reload
    assert_equal 80000, dev.salary
  end

  def test_update_columns_should_raise_exception_if_new_record
    topic = Topic.new
    assert_raises(ActiveRecord::ActiveRecordError) { topic.update_columns(approved: false) }
  end

  def test_update_columns_should_not_leave_the_object_dirty
    topic = Topic.find(1)
    topic.update("content" => "--- Have a nice day\n...\n", :author_name => "Jose")

    topic.reload
    topic.update_columns(content: "--- You too\n...\n", "author_name" => "Sebastian")
    assert_equal [], topic.changed

    topic.reload
    topic.update_columns(content: "--- Have a nice day\n...\n", author_name: "Jose")
    assert_equal [], topic.changed
  end

  def test_update_columns_with_model_having_primary_key_other_than_id
    minivan = Minivan.find("m1")
    new_name = "sebavan"

    minivan.update_columns(name: new_name)
    assert_equal new_name, minivan.name
  end

  def test_update_columns_with_one_readonly_attribute
    minivan = Minivan.find("m1")
    prev_color = minivan.color
    prev_name = minivan.name
    assert_raises(ActiveRecord::ActiveRecordError) { minivan.update_columns(name: "My old minivan", color: "black") }
    assert_equal prev_color, minivan.color
    assert_equal prev_name, minivan.name

    minivan.reload
    assert_equal prev_color, minivan.color
    assert_equal prev_name, minivan.name
  end

  def test_update_columns_should_not_modify_updated_at
    developer = Developer.find(1)
    prev_month = Time.now.prev_month.change(usec: 0)

    developer.update_columns(updated_at: prev_month)
    assert_equal prev_month, developer.updated_at

    developer.update_columns(salary: 80000)
    assert_equal prev_month, developer.updated_at
    assert_equal 80000, developer.salary

    developer.reload
    assert_equal prev_month.to_i, developer.updated_at.to_i
    assert_equal 80000, developer.salary
  end

  def test_update_columns_with_one_changed_and_one_updated
    t = Topic.order("id").limit(1).first
    author_name = t.author_name
    t.author_name = "John"
    t.update_columns(title: "super_title")
    assert_equal "John", t.author_name
    assert_equal "super_title", t.title
    assert_predicate t, :changed?, "topic should have changed"
    assert_predicate t, :author_name_changed?, "author_name should have changed"

    t.reload
    assert_equal author_name, t.author_name
    assert_equal "super_title", t.title
  end

  def test_update_columns_changing_id
    topic = Topic.find(1)
    topic.update_columns(id: 123)
    assert_equal 123, topic.id
    topic.reload
    assert_equal 123, topic.id
  end

  def test_update_columns_returns_boolean
    topic = Topic.find(1)
    assert_equal true, topic.update_columns(title: "New title")
  end

  def test_update_columns_with_default_scope
    developer = DeveloperCalledDavid.first
    developer.name = "John"
    developer.save!

    assert developer.update_columns(name: "Will"), "did not update record due to default scope"
  end

  def test_update
    topic = Topic.find(1)
    assert_not_predicate topic, :approved?
    assert_equal "The First Topic", topic.title

    topic.update("approved" => true, "title" => "The First Topic Updated")
    topic.reload
    assert_predicate topic, :approved?
    assert_equal "The First Topic Updated", topic.title

    topic.update(approved: false, title: "The First Topic")
    topic.reload
    assert_not_predicate topic, :approved?
    assert_equal "The First Topic", topic.title

    error = assert_raise(ActiveRecord::RecordNotUnique, ActiveRecord::StatementInvalid) do
      topic.update(id: 3, title: "Hm is it possible?")
    end
    assert_not_nil error.cause
    assert_not_equal "Hm is it possible?", Topic.find(3).title

    topic.update(id: 1234)
    assert_nothing_raised { topic.reload }
    assert_equal topic.title, Topic.find(1234).title
  end

  def test_update_parameters
    topic = Topic.find(1)
    assert_nothing_raised do
      topic.update({})
    end

    assert_raises(ArgumentError) do
      topic.update(nil)
    end
  end

  def test_update!
    Reply.validates_presence_of(:title)
    reply = Reply.find(2)
    assert_equal "The Second Topic of the day", reply.title
    assert_equal "Have a nice day", reply.content

    reply.update!("title" => "The Second Topic of the day updated", "content" => "Have a nice evening")
    reply.reload
    assert_equal "The Second Topic of the day updated", reply.title
    assert_equal "Have a nice evening", reply.content

    reply.update!(title: "The Second Topic of the day", content: "Have a nice day")
    reply.reload
    assert_equal "The Second Topic of the day", reply.title
    assert_equal "Have a nice day", reply.content

    assert_raise(ActiveRecord::RecordInvalid) { reply.update!(title: nil, content: "Have a nice evening") }
  ensure
    Reply.clear_validators!
  end

  def test_destroyed_returns_boolean
    developer = Developer.first
    assert_equal false, developer.destroyed?
    developer.destroy
    assert_equal true, developer.destroyed?

    developer = Developer.last
    assert_equal false, developer.destroyed?
    developer.delete
    assert_equal true, developer.destroyed?
  end

  def test_persisted_returns_boolean
    developer = Developer.new(name: "Jose")
    assert_equal false, developer.persisted?
    developer.save!
    assert_equal true, developer.persisted?

    developer = Developer.first
    assert_equal true, developer.persisted?
    developer.destroy
    assert_equal false, developer.persisted?

    developer = Developer.last
    assert_equal true, developer.persisted?
    developer.delete
    assert_equal false, developer.persisted?
  end

  def test_class_level_destroy
    should_be_destroyed_reply = Reply.create("title" => "hello", "content" => "world")
    Topic.find(1).replies << should_be_destroyed_reply

    topic = Topic.destroy(1)
    assert_predicate topic, :destroyed?

    assert_raise(ActiveRecord::RecordNotFound) { Topic.find(1) }
    assert_raise(ActiveRecord::RecordNotFound) { Reply.find(should_be_destroyed_reply.id) }
  end

  def test_class_level_destroy_is_affected_by_scoping
    should_not_be_destroyed_reply = Reply.create("title" => "hello", "content" => "world")
    Topic.find(1).replies << should_not_be_destroyed_reply

    assert_raise(ActiveRecord::RecordNotFound) do
      Topic.where("1=0").scoping { Topic.destroy(1) }
    end

    assert_nothing_raised { Topic.find(1) }
    assert_nothing_raised { Reply.find(should_not_be_destroyed_reply.id) }
  end

  def test_class_level_delete
    should_not_be_destroyed_reply = Reply.create("title" => "hello", "content" => "world")
    Topic.find(1).replies << should_not_be_destroyed_reply

    Topic.delete(1)
    assert_raise(ActiveRecord::RecordNotFound) { Topic.find(1) }
    assert_nothing_raised { Reply.find(should_not_be_destroyed_reply.id) }
  end

  def test_class_level_delete_with_invalid_ids
    assert_no_queries do
      assert_equal 0, Topic.delete(nil)
      assert_equal 0, Topic.delete([])
    end

    assert_difference -> { Topic.count }, -1 do
      assert_equal 1, Topic.delete(topics(:first).id)
    end
  end

  def test_class_level_delete_is_affected_by_scoping
    should_not_be_destroyed_reply = Reply.create("title" => "hello", "content" => "world")
    Topic.find(1).replies << should_not_be_destroyed_reply

    Topic.where("1=0").scoping { Topic.delete(1) }
    assert_nothing_raised { Topic.find(1) }
    assert_nothing_raised { Reply.find(should_not_be_destroyed_reply.id) }
  end

  def test_create_with_custom_timestamps
    custom_datetime = 1.hour.ago.beginning_of_day

    %w(created_at created_on updated_at updated_on).each do |attribute|
      parrot = LiveParrot.create(:name => "colombian", attribute => custom_datetime)
      assert_equal custom_datetime, parrot[attribute]
    end
  end

  def test_persist_inherited_class_with_different_table_name
    minimalistic_aircrafts = Class.new(Minimalistic) do
      self.table_name = "aircraft"
    end

    assert_difference "Aircraft.count", 1 do
      aircraft = minimalistic_aircrafts.create(name: "Wright Flyer")
      aircraft.name = "Wright Glider"
      aircraft.save
    end

    assert_equal "Wright Glider", Aircraft.last.name
  end

  def test_instantiate_creates_a_new_instance
    post = Post.instantiate("title" => "appropriate documentation", "type" => "SpecialPost")
    assert_equal "appropriate documentation", post.title
    assert_instance_of SpecialPost, post

    # body was not initialized
    assert_raises ActiveModel::MissingAttributeError do
      post.body
    end
  end

  def test_reload_removes_custom_selects
    post = Post.select("posts.*, 1 as wibble").last!

    assert_equal 1, post[:wibble]
    assert_nil post.reload[:wibble]
  end

  def test_find_via_reload
    post = Post.new

    assert_predicate post, :new_record?

    post.id = 1
    post.reload

    assert_equal "Welcome to the weblog", post.title
    assert_not_predicate post, :new_record?
  end

  def test_reload_via_querycache
    ActiveRecord::Base.lease_connection.enable_query_cache!
    ActiveRecord::Base.lease_connection.clear_query_cache
    assert ActiveRecord::Base.lease_connection.query_cache_enabled, "cache should be on"
    parrot = Parrot.create(name: "Shane")

    # populate the cache with the SELECT result
    found_parrot = Parrot.find(parrot.id)
    assert_equal parrot.id, found_parrot.id

    # Manually update the 'name' attribute in the DB directly
    assert_equal 1, ActiveRecord::Base.lease_connection.query_cache.size
    ActiveRecord::Base.uncached do
      found_parrot.name = "Mary"
      found_parrot.save
    end

    # Now reload, and verify that it gets the DB version, and not the querycache version
    found_parrot.reload
    assert_equal "Mary", found_parrot.name

    found_parrot = Parrot.find(parrot.id)
    assert_equal "Mary", found_parrot.name
  ensure
    ActiveRecord::Base.lease_connection.disable_query_cache!
  end

  def test_save_touch_false
    parrot = Parrot.create!(
      name: "Bob",
      created_at: 1.day.ago,
      updated_at: 1.day.ago)

    created_at = parrot.created_at
    updated_at = parrot.updated_at

    parrot.name = "Barb"
    parrot.save!(touch: false)
    assert_equal parrot.created_at, created_at
    assert_equal parrot.updated_at, updated_at
  end

  def test_reset_column_information_resets_children
    child_class = Class.new(Topic)
    child_class.new # force schema to load

    ActiveRecord::Base.lease_connection.add_column(:topics, :foo, :string)
    Topic.reset_column_information

    # this should redefine attribute methods
    child_class.new

    assert child_class.instance_methods.include?(:foo)
    assert child_class.instance_methods.include?(:foo_changed?)
    assert_equal "bar", child_class.new(foo: :bar).foo
  ensure
    ActiveRecord::Base.lease_connection.remove_column(:topics, :foo)
    Topic.reset_column_information
  end

  def test_update_uses_query_constraints_config
    clothing_item = clothing_items(:green_t_shirt)
    sql = capture_sql { clothing_item.update(description: "Lovely green t-shirt")  }.second
    assert_match(/WHERE .*clothing_type/, sql)
    assert_match(/WHERE .*color/, sql)
  end

  def test_save_uses_query_constraints_config
    clothing_item = clothing_items(:green_t_shirt)
    clothing_item.description = "Lovely green t-shirt"
    sql = capture_sql { clothing_item.save }.second
    assert_match(/WHERE .*clothing_type/, sql)
    assert_match(/WHERE .*color/, sql)
  end

  def test_reload_uses_query_constraints_config
    clothing_item = clothing_items(:green_t_shirt)
    sql = capture_sql { clothing_item.reload  }.first
    assert_match(/WHERE .*clothing_type/, sql)
    assert_match(/WHERE .*color/, sql)
  end

  def test_destroy_uses_query_constraints_config
    clothing_item = clothing_items(:green_t_shirt)
    sql = capture_sql { clothing_item.destroy }.second
    assert_match(/WHERE .*clothing_type/, sql)
    assert_match(/WHERE .*color/, sql)
  end

  def test_delete_uses_query_constraints_config
    clothing_item = clothing_items(:green_t_shirt)
    sql = capture_sql { clothing_item.delete }.first
    assert_match(/WHERE .*clothing_type/, sql)
    assert_match(/WHERE .*color/, sql)
  end

  def test_update_attribute_uses_query_constraints_config
    clothing_item = clothing_items(:green_t_shirt)
    sql = capture_sql { clothing_item.update_attribute(:description, "Lovely green t-shirt") }.second
    assert_match(/WHERE .*clothing_type/, sql)
    assert_match(/WHERE .*color/, sql)
  end

  def test_it_is_possible_to_update_parts_of_the_query_constraints_config
    clothing_item = clothing_items(:green_t_shirt)
    clothing_item.color = "blue"
    clothing_item.description = "Now it's a blue t-shirt"
    sql = capture_sql { clothing_item.save }.second
    assert_match(/WHERE .*clothing_type/, sql)
    assert_match(/WHERE .*color/, sql)

    assert_equal("blue", ClothingItem.find_by(id: clothing_item.id).color)
  end

  def test_model_with_no_auto_populated_fields_still_returns_primary_key_after_insert
    record = PkAutopopulatedByATriggerRecord.create

    assert_not_nil record.id
    assert record.id > 0
  end if supports_insert_returning? && !current_adapter?(:SQLite3Adapter)
end

class QueryConstraintsTest < ActiveRecord::TestCase
  fixtures :clothing_items, :dashboards, :topics, :posts

  def test_primary_key_stays_the_same
    assert_equal("id", ClothingItem.primary_key)
  end

  def test_query_constraints_list_is_nil_if_primary_key_is_nil
    klass = Class.new(ActiveRecord::Base) do
      self.table_name = "developers_projects"
    end

    assert_nil klass.primary_key
    assert_nil klass.query_constraints_list
  end

  def test_query_constraints_list_is_nil_for_non_cpk_model
    assert_nil Post.query_constraints_list
    assert_nil Dashboard.query_constraints_list
  end

  def test_query_constraints_list_equals_to_composite_primary_key
    assert_equal(["shop_id", "id"], Cpk::Order.query_constraints_list)
    assert_equal(["author_id", "id"], Cpk::Book.query_constraints_list)
  end

  def test_child_keeps_parents_query_constraints
    clothing_item = clothing_items(:green_t_shirt)
    assert_uses_query_constraints_on_reload(clothing_item, ["clothing_type", "color"])

    used_clothing_item = clothing_items(:used_blue_jeans)
    assert_uses_query_constraints_on_reload(used_clothing_item, ["clothing_type", "color"])
  end

  def test_child_keeps_parents_query_contraints_derived_from_composite_pk
    assert_equal(["author_id", "id"], Cpk::BestSeller.query_constraints_list)
  end

  def assert_uses_query_constraints_on_reload(object, columns)
    flunk("columns argument must not be empty") if columns.blank?

    sql = capture_sql { object.reload }.first
    Array(columns).each do |column|
      assert_match(/WHERE .*#{column}/, sql)
    end
  end

  def test_query_constraints_raises_an_error_when_no_columns_provided
    assert_raises(ArgumentError) do
      Class.new(ActiveRecord::Base) do
        self.table_name = "topics"
        query_constraints
      end
    end
  end

  def test_child_class_with_query_constraints_overrides_parents
    assert_equal(["clothing_type", "color", "size"], ClothingItem::Sized.query_constraints_list)
  end
end
