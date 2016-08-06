require "cases/helper"
require "models/person"
require "models/topic"
require "pp"
require "active_support/core_ext/string/strip"

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
    assert_equal %(#<Topic id: 1, title: "The First Topic", author_name: "David", author_email_address: "david@loudthinking.com", written_on: "#{topic.written_on.to_s(:db)}", bonus_time: "#{topic.bonus_time.to_s(:db)}", last_read: "#{topic.last_read.to_s(:db)}", content: "Have a nice day", important: nil, approved: false, replies_count: 1, unique_replies_count: 0, parent_id: nil, parent_title: nil, type: nil, group: nil, created_at: "#{topic.created_at.to_s(:db)}", updated_at: "#{topic.updated_at.to_s(:db)}">), topic.inspect
  end

  def test_inspect_new_instance
    assert_match(/Topic id: nil/, Topic.new.inspect)
  end

  def test_inspect_limited_select_instance
    assert_equal %(#<Topic id: 1>), Topic.all.merge!(:select => "id", :where => "id = 1").first.inspect
    assert_equal %(#<Topic id: 1, title: "The First Topic">), Topic.all.merge!(:select => "id, title", :where => "id = 1").first.inspect
  end

  def test_inspect_class_without_table
    assert_equal "NonExistentTable(Table doesn't exist)", NonExistentTable.inspect
  end

  def test_pretty_print_new
    topic = Topic.new
    actual = ""
    PP.pp(topic, StringIO.new(actual))
    expected = <<-PRETTY.strip_heredoc
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
    actual = ""
    PP.pp(topic, StringIO.new(actual))
    expected = <<-PRETTY.strip_heredoc
    #<Topic:0x\\w+
     id: 1,
     title: "The First Topic",
     author_name: "David",
     author_email_address: "david@loudthinking.com",
     written_on: 2003-07-16 14:28:11 UTC,
     bonus_time: 2000-01-01 14:28:00 UTC,
     last_read: Thu, 15 Apr 2004,
     content: "Have a nice day",
     important: nil,
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

  def test_pretty_print_uninitialized
    topic = Topic.allocate
    actual = ""
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
    actual = ""
    PP.pp(subtopic.new, StringIO.new(actual))
    assert_equal "inspecting topic\n", actual
  end
end
