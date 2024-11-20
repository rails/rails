# frozen_string_literal: true

require "cases/helper"
require "models/person"
require "models/topic"
require "pp"
require "models/cpk"

class NonExistentTable < ActiveRecord::Base; end

class CoreTest < ActiveRecord::TestCase
  fixtures :topics

  def test_inspect_class
    assert_equal "ActiveRecord::Base", ActiveRecord::Base.inspect
    assert_equal "LoosePerson(abstract)", LoosePerson.inspect
    assert_match(/^Topic\(id: integer, title: string/, Topic.inspect)
  end

  def test_inspect_instance
    topic = topics(:first)
    assert_equal %(#<Topic id: 1, title: "The First Topic", author_name: "David", author_email_address: "david@loudthinking.com", written_on: "#{topic.written_on.to_fs(:inspect)}", bonus_time: "#{topic.bonus_time.to_fs(:inspect)}", last_read: "#{topic.last_read.to_fs(:inspect)}", content: "Have a nice day", important: nil, binary_content: nil, approved: false, replies_count: 1, unique_replies_count: 0, parent_id: nil, parent_title: nil, type: nil, group: nil, created_at: "#{topic.created_at.to_fs(:inspect)}", updated_at: "#{topic.updated_at.to_fs(:inspect)}">), topic.inspect
  end

  def test_inspect_includes_attributes_from_attributes_for_inspect
    Topic.stub(:attributes_for_inspect, [:id, :title, :author_name]) do
      topic = topics(:first)

      assert_equal %(#<Topic id: 1, title: "The First Topic", author_name: "David">), topic.inspect
    end
  end

  def test_inspect_instance_with_lambda_date_formatter
    before = Time::DATE_FORMATS[:inspect]

    Topic.stub(:attributes_for_inspect, [:id, :last_read]) do
      Time::DATE_FORMATS[:inspect] = ->(date) { "my_format" }
      topic = topics(:first)

      assert_equal %(#<Topic id: 1, last_read: "2004-04-15">), topic.inspect
    end
  ensure
    Time::DATE_FORMATS[:inspect] = before
  end

  def test_inspect_new_instance
    assert_match(/Topic id: nil/, Topic.new.inspect)
  end

  def test_inspect_singleton_instance
    assert_match(/#<Class:#<Topic:\w+>>/, Topic.new.singleton_class.inspect)
  end

  def test_inspect_limited_select_instance
    Topic.stub(:attributes_for_inspect, [:id, :title]) do
      assert_equal %(#<Topic id: 1>), Topic.all.merge!(select: "id", where: "id = 1").first.inspect
      assert_equal %(#<Topic id: 1, title: "The First Topic">), Topic.all.merge!(select: "id, title", where: "id = 1").first.inspect
    end
  end

  def test_inspect_instance_with_non_primary_key_id_attribute
    topic = topics(:first).becomes(TitlePrimaryKeyTopic)
    assert_match(/id: 1/, topic.inspect)
  end

  def test_inspect_class_without_table
    assert_equal "NonExistentTable(Table doesn't exist)", NonExistentTable.inspect
  end

  def test_inspect_with_attributes_for_inspect_all_lists_all_attributes
    Topic.stub(:attributes_for_inspect, :all) do
      topic = topics(:first)

      assert_equal <<~STRING.squish, topic.inspect
        #<Topic id: 1, title: "The First Topic", author_name: "David", author_email_address: "david@loudthinking.com", written_on: "#{topic.written_on.to_fs(:inspect)}", bonus_time: "#{topic.bonus_time.to_fs(:inspect)}", last_read: "#{topic.last_read.to_fs(:inspect)}", content: "Have a nice day", important: nil, binary_content: nil, approved: false, replies_count: 1, unique_replies_count: 0, parent_id: nil, parent_title: nil, type: nil, group: nil, created_at: "#{topic.created_at.to_fs(:inspect)}", updated_at: "#{topic.updated_at.to_fs(:inspect)}">
      STRING
    end
  end

  def test_inspect_relation_with_virtual_field
    relation = Topic.limit(1).select("1 as virtual_field")
    assert_match(/virtual_field: 1/, relation.first.full_inspect)
  end

  def test_inspect_with_overridden_attribute_for_inspect
    topic = topics(:first)

    topic.instance_eval do
      def attribute_for_inspect(attr_name)
        if attr_name == "title"
          title.upcase.inspect
        else
          super
        end
      end
    end

    assert_match(/title: "THE FIRST TOPIC"/, topic.full_inspect)
  end

  def test_full_inspect_lists_all_attributes
    topic = topics(:first)

    assert_equal <<~STRING.squish, topic.full_inspect
      #<Topic id: 1, title: "The First Topic", author_name: "David", author_email_address: "david@loudthinking.com", written_on: "#{topic.written_on.to_fs(:inspect)}", bonus_time: "#{topic.bonus_time.to_fs(:inspect)}", last_read: "#{topic.last_read.to_fs(:inspect)}", content: "Have a nice day", important: nil, binary_content: nil, approved: false, replies_count: 1, unique_replies_count: 0, parent_id: nil, parent_title: nil, type: nil, group: nil, created_at: "#{topic.created_at.to_fs(:inspect)}", updated_at: "#{topic.updated_at.to_fs(:inspect)}">
    STRING
  end

  def test_pretty_print_new
    topic = Topic.new
    actual = +""
    PP.pp(topic, StringIO.new(actual))
    expected = <<~PRETTY
      #<Topic:0xXXXXXX
       id: nil,
       title: nil,
       author_name: nil,
       author_email_address: "test@test.com",
       written_on: nil,
       bonus_time: nil,
       last_read: nil,
       content: nil,
       important: nil,
       binary_content: nil,
       approved: true,
       replies_count: 0,
       unique_replies_count: 0,
       parent_id: nil,
       parent_title: nil,
       type: nil,
       group: nil,
       created_at: nil,
       updated_at: nil>
    PRETTY
    assert actual.start_with?(expected.split("XXXXXX").first)
    assert actual.end_with?(expected.split("XXXXXX").last)
  end

  def test_pretty_print_persisted
    topic = topics(:first)
    actual = +""
    PP.pp(topic, StringIO.new(actual))
    expected = <<~PRETTY
      #<Topic:0x\\w+
       id: 1,
       title: "The First Topic",
       author_name: "David",
       author_email_address: "david@loudthinking.com",
       written_on: "2003-07-16 14:28:11\\.223300000 \\+0000",
       bonus_time: "2000-01-01 14:28:00\\.000000000 \\+0000",
       last_read: "2004-04-15",
       content: "Have a nice day",
       important: nil,
       binary_content: nil,
       approved: false,
       replies_count: 1,
       unique_replies_count: 0,
       parent_id: nil,
       parent_title: nil,
       type: nil,
       group: nil,
       created_at: [^,]+,
       updated_at: [^,>]+>
    PRETTY
    assert_match(/\A#{expected}\z/, actual)
  end

  def test_pretty_print_full
    Topic.stub(:attributes_for_inspect, :all) do
      topic = topics(:first)
      actual = +""
      PP.pp(topic, StringIO.new(actual))
      expected = <<~PRETTY
        #<Topic:0x\\w+
         id: 1,
         title: "The First Topic",
         author_name: "David",
         author_email_address: "david@loudthinking.com",
         written_on: "2003-07-16 14:28:11\\.223300000 \\+0000",
         bonus_time: "2000-01-01 14:28:00\\.000000000 \\+0000",
         last_read: "2004-04-15",
         content: "Have a nice day",
         important: nil,
         binary_content: nil,
         approved: false,
         replies_count: 1,
         unique_replies_count: 0,
         parent_id: nil,
         parent_title: nil,
         type: nil,
         group: nil,
         created_at: [^,]+,
         updated_at: [^,>]+>
      PRETTY
      assert_match(/\A#{expected}\z/, actual)
    end
  end

  def test_pretty_print_uninitialized
    topic = Topic.allocate
    actual = +""
    PP.pp(topic, StringIO.new(actual))
    expected = "#<Topic:XXXXXX not initialized>\n"
    assert actual.start_with?(expected.split("XXXXXX").first)
    assert actual.end_with?(expected.split("XXXXXX").last)
  end

  def test_pretty_print_overridden_by_inspect
    subtopic = Class.new(Topic) do
      def inspect
        "inspecting topic"
      end
    end
    actual = +""
    PP.pp(subtopic.new, StringIO.new(actual))
    assert_equal "inspecting topic\n", actual
  end

  def test_pretty_print_with_non_primary_key_id_attribute
    topic = topics(:first).becomes(TitlePrimaryKeyTopic)
    actual = +""
    PP.pp(topic, StringIO.new(actual))
    assert_match(/id: 1/, actual)
  end

  def test_pretty_print_with_overridden_attribute_for_inspect
    topic = topics(:first)

    topic.instance_eval do
      def attribute_for_inspect(attr_name)
        if attr_name == "title"
          title.upcase.inspect
        else
          super
        end
      end
    end

    Topic.stub(:attributes_for_inspect, :all) do
      actual = +""
      PP.pp(topic, StringIO.new(actual))
      assert_match(/title: "THE FIRST TOPIC"/, actual)
    end
  end

  def test_find_by_cache_does_not_duplicate_entries
    Topic.initialize_find_by_cache
    using_prepared_statements = Topic.lease_connection.prepared_statements
    topic_find_by_cache = Topic.instance_variable_get("@find_by_statement_cache")[using_prepared_statements]

    assert_difference -> { topic_find_by_cache.size }, +1 do
      Topic.find(1)
    end
    assert_no_difference -> { topic_find_by_cache.size } do
      Topic.find_by(id: 1)
    end
  end

  def test_composite_pk_models_added_to_a_set
    library = Set.new
    # with primary key present
    library << Cpk::Book.new(id: [1, 2])

    # duplicate
    library << Cpk::Book.new(id: [1, 3])
    library << Cpk::Book.new(id: [1, 3])

    # without primary key being set
    library << Cpk::Book.new(title: "Book A")
    library << Cpk::Book.new(title: "Book B")

    assert_equal 4, library.size
  end

  def test_composite_pk_models_equality
    assert Cpk::Book.new(id: [1, 2]) == Cpk::Book.new(id: [1, 2])

    assert_not Cpk::Book.new(id: [1, 2]) == Cpk::Book.new(id: [1, 3])
    assert_not Cpk::Book.new == Cpk::Book.new
    assert_not Cpk::Book.new(title: "Book A") == Cpk::Book.new(title: "Book B")
    assert_not Cpk::Book.new(author_id: 1) == Cpk::Book.new(author_id: 1)
    assert_not Cpk::Book.new(author_id: 1, title: "Same title") == Cpk::Book.new(author_id: 1, title: "Same title")
  end

  def test_composite_pk_models_hash
    assert_equal Cpk::Book.new(id: [1, 2]).hash, Cpk::Book.new(id: [1, 2]).hash

    assert_not_equal Cpk::Book.new(id: [1, 2]).hash, Cpk::Book.new(id: [1, 3]).hash
    assert_not_equal Cpk::Book.new.hash, Cpk::Book.new.hash
    assert_not_equal Cpk::Book.new(title: "Book A").hash, Cpk::Book.new(title: "Book B").hash
    assert_not_equal Cpk::Book.new(author_id: 1).hash, Cpk::Book.new(author_id: 1).hash
    assert_not_equal Cpk::Book.new(author_id: 1, title: "Same title").hash, Cpk::Book.new(author_id: 1, title: "Same title").hash
  end
end
