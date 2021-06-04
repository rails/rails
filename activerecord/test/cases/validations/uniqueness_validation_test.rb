# frozen_string_literal: true

require "cases/helper"
require "models/topic"
require "models/reply"
require "models/warehouse_thing"
require "models/guid"
require "models/event"
require "models/dashboard"
require "models/uuid_item"
require "models/author"
require "models/person"
require "models/essay"

class Wizard < ActiveRecord::Base
  self.abstract_class = true

  validates_uniqueness_of :name
end

class IneptWizard < Wizard
  validates_uniqueness_of :city
end

class Conjurer < IneptWizard
end

class Thaumaturgist < IneptWizard
end

class ReplyTitle; end

class ReplyWithTitleObject < Reply
  validates_uniqueness_of :content, scope: :title

  def title; ReplyTitle.new; end
end

class TopicWithUniqEvent < Topic
  belongs_to :event, foreign_key: :parent_id
  validates :event, uniqueness: true
end

class BigIntTest < ActiveRecord::Base
  INT_MAX_VALUE = 2147483647
  self.table_name = "cars"
  validates :engines_count, uniqueness: true, inclusion: { in: 0..INT_MAX_VALUE }
end

class BigIntReverseTest < ActiveRecord::Base
  INT_MAX_VALUE = 2147483647
  self.table_name = "cars"
  validates :engines_count, inclusion: { in: 0..INT_MAX_VALUE }
  validates :engines_count, uniqueness: true
end

class CoolTopic < Topic
  validates_uniqueness_of :id
end

class TopicWithAfterCreate < Topic
  after_create :set_author

  def set_author
    update!(author_name: "#{title} #{id}")
  end
end

class UniquenessValidationTest < ActiveRecord::TestCase
  INT_MAX_VALUE = 2147483647

  fixtures :topics, "warehouse-things"

  repair_validations(Topic, Reply)

  def test_validate_uniqueness
    Topic.validates_uniqueness_of(:title)

    t = Topic.new("title" => "I'm uniqué!")
    assert t.save, "Should save t as unique"

    t.content = "Remaining unique"
    assert t.save, "Should still save t as unique"

    t2 = Topic.new("title" => "I'm uniqué!")
    assert_not t2.valid?, "Shouldn't be valid"
    assert_not t2.save, "Shouldn't save t2 as unique"
    assert_equal ["has already been taken"], t2.errors[:title]

    t2.title = "Now I am really also unique"
    assert t2.save, "Should now save t2 as unique"
  end

  def test_validate_uniqueness_with_alias_attribute
    Topic.alias_attribute :new_title, :title
    Topic.validates_uniqueness_of(:new_title)

    topic = Topic.new(new_title: "abc")
    assert_predicate topic, :valid?
  end

  def test_validates_uniqueness_with_nil_value
    Topic.validates_uniqueness_of(:title)

    t = Topic.new("title" => nil)
    assert t.save, "Should save t as unique"

    t2 = Topic.new("title" => nil)
    assert_not t2.valid?, "Shouldn't be valid"
    assert_not t2.save, "Shouldn't save t2 as unique"
    assert_equal ["has already been taken"], t2.errors[:title]
  end

  def test_validates_uniqueness_with_validates
    Topic.validates :title, uniqueness: true
    Topic.create!("title" => "abc")

    t2 = Topic.new("title" => "abc")
    assert_not_predicate t2, :valid?
    assert t2.errors[:title]
  end

  def test_validate_uniqueness_when_integer_out_of_range
    entry = BigIntTest.create(engines_count: INT_MAX_VALUE + 1)
    assert_equal entry.errors[:engines_count], ["is not included in the list"]
  end

  def test_validate_uniqueness_when_integer_out_of_range_show_order_does_not_matter
    entry = BigIntReverseTest.create(engines_count: INT_MAX_VALUE + 1)
    assert_equal entry.errors[:engines_count], ["is not included in the list"]
  end

  def test_validates_uniqueness_with_newline_chars
    Topic.validates_uniqueness_of(:title, case_sensitive: false)

    t = Topic.new("title" => "new\nline")
    assert t.save, "Should save t as unique"
  end

  def test_validate_uniqueness_with_scope
    Reply.validates_uniqueness_of(:content, scope: "parent_id")

    t = Topic.create("title" => "I'm unique!")

    r1 = t.replies.create "title" => "r1", "content" => "hello world"
    assert r1.valid?, "Saving r1"

    r2 = t.replies.create "title" => "r2", "content" => "hello world"
    assert_not r2.valid?, "Saving r2 first time"

    r2.content = "something else"
    assert r2.save, "Saving r2 second time"

    t2 = Topic.create("title" => "I'm unique too!")
    r3 = t2.replies.create "title" => "r3", "content" => "hello world"
    assert r3.valid?, "Saving r3"
  end

  def test_validate_uniqueness_with_aliases
    Reply.validates_uniqueness_of(:new_content, scope: :new_parent_id)

    t = Topic.create(title: "I'm unique!")

    r1 = t.replies.create(title: "r1", content: "hello world")
    assert_predicate r1, :valid?, "Saving r1"

    r2 = t.replies.create(title: "r2", content: "hello world")
    assert_not_predicate r2, :valid?, "Saving r2 first time"

    r2.content = "something else"
    assert r2.save, "Saving r2 second time"

    t2 = Topic.create("title" => "I'm unique too!")
    r3 = t2.replies.create(title: "r3", content: "hello world")
    assert_predicate r3, :valid?, "Saving r3"
  end

  def test_validate_uniqueness_with_scope_invalid_syntax
    error = assert_raises(ArgumentError) do
      Reply.validates_uniqueness_of(:content, scope: { parent_id: false })
    end
    assert_match(/Pass a symbol or an array of symbols instead/, error.to_s)
  end

  def test_validate_uniqueness_with_object_scope
    Reply.validates_uniqueness_of(:content, scope: :topic)

    t = Topic.create("title" => "I'm unique!")

    r1 = t.replies.create "title" => "r1", "content" => "hello world"
    assert r1.valid?, "Saving r1"

    r2 = t.replies.create "title" => "r2", "content" => "hello world"
    assert_not r2.valid?, "Saving r2 first time"
  end

  def test_validate_uniqueness_with_polymorphic_object_scope
    repair_validations(Essay) do
      Essay.validates_uniqueness_of(:name, scope: :writer)

      a = Author.create(name: "Sergey")
      p = Person.create(first_name: "Sergey")

      e1 = a.essays.create(name: "Essay")
      assert e1.valid?, "Saving e1"

      e2 = p.essays.create(name: "Essay")
      assert e2.valid?, "Saving e2"
    end
  end

  def test_validate_uniqueness_with_composed_attribute_scope
    r1 = ReplyWithTitleObject.create "title" => "r1", "content" => "hello world"
    assert r1.valid?, "Saving r1"

    r2 = ReplyWithTitleObject.create "title" => "r1", "content" => "hello world"
    assert_not r2.valid?, "Saving r2 first time"
  end

  def test_validate_uniqueness_with_object_arg
    Reply.validates_uniqueness_of(:topic)

    t = Topic.create("title" => "I'm unique!")

    r1 = t.replies.create "title" => "r1", "content" => "hello world"
    assert r1.valid?, "Saving r1"

    r2 = t.replies.create "title" => "r2", "content" => "hello world"
    assert_not r2.valid?, "Saving r2 first time"
  end

  def test_validate_uniqueness_scoped_to_defining_class
    t = Topic.create("title" => "What, me worry?")

    r1 = t.unique_replies.create "title" => "r1", "content" => "a barrel of fun"
    assert r1.valid?, "Saving r1"

    r2 = t.silly_unique_replies.create "title" => "r2", "content" => "a barrel of fun"
    assert_not r2.valid?, "Saving r2"

    # Should succeed as validates_uniqueness_of only applies to
    # UniqueReply and its subclasses
    r3 = t.replies.create "title" => "r2", "content" => "a barrel of fun"
    assert r3.valid?, "Saving r3"
  end

  def test_validate_uniqueness_with_scope_array
    Reply.validates_uniqueness_of(:author_name, scope: [:author_email_address, :parent_id])

    t = Topic.create("title" => "The earth is actually flat!")

    r1 = t.replies.create "author_name" => "jeremy", "author_email_address" => "jeremy@rubyonrails.com", "title" => "You're crazy!", "content" => "Crazy reply"
    assert r1.valid?, "Saving r1"

    r2 = t.replies.create "author_name" => "jeremy", "author_email_address" => "jeremy@rubyonrails.com", "title" => "You're crazy!", "content" => "Crazy reply again..."
    assert_not r2.valid?, "Saving r2. Double reply by same author."

    r2.author_email_address = "jeremy_alt_email@rubyonrails.com"
    assert r2.save, "Saving r2 the second time."

    r3 = t.replies.create "author_name" => "jeremy", "author_email_address" => "jeremy_alt_email@rubyonrails.com", "title" => "You're wrong", "content" => "It's cubic"
    assert_not r3.valid?, "Saving r3"

    r3.author_name = "jj"
    assert r3.save, "Saving r3 the second time."

    r3.author_name = "jeremy"
    assert_not r3.save, "Saving r3 the third time."
  end

  def test_validate_case_insensitive_uniqueness
    Topic.validates_uniqueness_of(:title, :parent_id, case_sensitive: false, allow_nil: true)

    t = Topic.new("title" => "I'm unique!", :parent_id => 2)
    assert t.save, "Should save t as unique"

    t.content = "Remaining unique"
    assert t.save, "Should still save t as unique"

    t2 = Topic.new("title" => "I'm UNIQUE!", :parent_id => 1)
    assert_not t2.valid?, "Shouldn't be valid"
    assert_not t2.save, "Shouldn't save t2 as unique"
    assert_predicate t2.errors[:title], :any?
    assert_predicate t2.errors[:parent_id], :any?
    assert_equal ["has already been taken"], t2.errors[:title]

    t2.title = "I'm truly UNIQUE!"
    assert_not t2.valid?, "Shouldn't be valid"
    assert_not t2.save, "Shouldn't save t2 as unique"
    assert_empty t2.errors[:title]
    assert_predicate t2.errors[:parent_id], :any?

    t2.parent_id = 4
    assert t2.save, "Should now save t2 as unique"

    t2.parent_id = nil
    t2.title = nil
    assert t2.valid?, "should validate with nil"
    assert t2.save, "should save with nil"

    t_utf8 = Topic.new("title" => "Я тоже уникальный!")
    assert t_utf8.save, "Should save t_utf8 as unique"

    # If database hasn't UTF-8 character set, this test fails
    if Topic.all.merge!(select: "LOWER(title) AS title").find(t_utf8.id).title == "я тоже уникальный!"
      t2_utf8 = Topic.new("title" => "я тоже УНИКАЛЬНЫЙ!")
      assert_not t2_utf8.valid?, "Shouldn't be valid"
      assert_not t2_utf8.save, "Shouldn't save t2_utf8 as unique"
    end
  end

  def test_validate_case_sensitive_uniqueness_with_special_sql_like_chars
    Topic.validates_uniqueness_of(:title, case_sensitive: true)

    t = Topic.new("title" => "I'm unique!")
    assert t.save, "Should save t as unique"

    t2 = Topic.new("title" => "I'm %")
    assert t2.save, "Should save t2 as unique"

    t3 = Topic.new("title" => "I'm uniqu_!")
    assert t3.save, "Should save t3 as unique"
  end

  def test_validate_case_insensitive_uniqueness_with_special_sql_like_chars
    Topic.validates_uniqueness_of(:title, case_sensitive: false)

    t = Topic.new("title" => "I'm unique!")
    assert t.save, "Should save t as unique"

    t2 = Topic.new("title" => "I'm %")
    assert t2.save, "Should save t2 as unique"

    t3 = Topic.new("title" => "I'm uniqu_!")
    assert t3.save, "Should save t3 as unique"
  end

  def test_validate_uniqueness_by_default_database_collation
    Topic.validates_uniqueness_of(:author_email_address)

    topic1 = Topic.new(author_email_address: "david@loudthinking.com")
    topic2 = Topic.new(author_email_address: "David@loudthinking.com")

    assert_equal 1, Topic.where(author_email_address: "david@loudthinking.com").count

    assert_not topic1.valid?
    assert_not topic1.save

    if current_adapter?(:Mysql2Adapter)
      # Case insensitive collation (utf8mb4_0900_ai_ci) by default.
      # Should not allow "David" if "david" exists.
      assert_not topic2.valid?
      assert_not topic2.save
    else
      assert topic2.valid?
      assert topic2.save
    end

    assert_equal 1, Topic.where(author_email_address: "david@loudthinking.com").count
    assert_equal 1, Topic.where(author_email_address: "David@loudthinking.com").count
  end

  def test_validate_case_sensitive_uniqueness
    Topic.validates_uniqueness_of(:title, case_sensitive: true, allow_nil: true)

    t = Topic.new("title" => "I'm unique!")
    assert t.save, "Should save t as unique"

    t.content = "Remaining unique"
    assert t.save, "Should still save t as unique"

    t2 = Topic.new("title" => "I'M UNIQUE!")
    assert t2.valid?, "Should be valid"
    assert t2.save, "Should save t2 as unique"
    assert_empty t2.errors[:title]
    assert_empty t2.errors[:parent_id]
    assert_not_equal ["has already been taken"], t2.errors[:title]

    t3 = Topic.new("title" => "I'M uNiQUe!")
    assert t3.valid?, "Should be valid"
    assert t3.save, "Should save t2 as unique"
    assert_empty t3.errors[:title]
    assert_empty t3.errors[:parent_id]
    assert_not_equal ["has already been taken"], t3.errors[:title]
  end

  def test_validate_case_sensitive_uniqueness_with_attribute_passed_as_integer
    Topic.validates_uniqueness_of(:title, case_sensitive: true)
    Topic.create!("title" => 101)

    t2 = Topic.new("title" => 101)
    assert_not_predicate t2, :valid?
    assert t2.errors[:title]
  end

  def test_validate_uniqueness_with_non_standard_table_names
    i1 = WarehouseThing.create(value: 1000)
    assert_not i1.valid?, "i1 should not be valid"
    assert i1.errors[:value].any?, "Should not be empty"
  end

  def test_validates_uniqueness_inside_scoping
    Topic.validates_uniqueness_of(:title)

    Topic.where(author_name: "David").scoping do
      t1 = Topic.new("title" => "I'm unique!", "author_name" => "Mary")
      assert t1.save
      t2 = Topic.new("title" => "I'm unique!", "author_name" => "David")
      assert_not_predicate t2, :valid?
    end
  end

  def test_validate_uniqueness_with_columns_which_are_sql_keywords
    repair_validations(Guid) do
      Guid.validates_uniqueness_of :key
      g = Guid.new
      g.key = "foo"
      assert_nothing_raised { !g.valid? }
    end
  end

  def test_validate_uniqueness_with_limit
    if current_adapter?(:SQLite3Adapter)
      # Event.title has limit 5, but SQLite doesn't truncate.
      e1 = Event.create(title: "abcdefgh")
      assert e1.valid?, "Could not create an event with a unique 8 characters title"

      e2 = Event.create(title: "abcdefgh")
      assert_not e2.valid?, "Created an event whose title is not unique"
    elsif current_adapter?(:Mysql2Adapter, :PostgreSQLAdapter, :OracleAdapter, :SQLServerAdapter)
      assert_raise(ActiveRecord::ValueTooLong) do
        Event.create(title: "abcdefgh")
      end
    else
      assert_raise(ActiveRecord::StatementInvalid) do
        Event.create(title: "abcdefgh")
      end
    end
  end

  def test_validate_uniqueness_with_limit_and_utf8
    if current_adapter?(:SQLite3Adapter)
      # Event.title has limit 5, but SQLite doesn't truncate.
      e1 = Event.create(title: "一二三四五六七八")
      assert e1.valid?, "Could not create an event with a unique 8 characters title"

      e2 = Event.create(title: "一二三四五六七八")
      assert_not e2.valid?, "Created an event whose title is not unique"
    elsif current_adapter?(:Mysql2Adapter, :PostgreSQLAdapter, :OracleAdapter, :SQLServerAdapter)
      assert_raise(ActiveRecord::ValueTooLong) do
        Event.create(title: "一二三四五六七八")
      end
    else
      assert_raise(ActiveRecord::StatementInvalid) do
        Event.create(title: "一二三四五六七八")
      end
    end
  end

  def test_validate_straight_inheritance_uniqueness
    w1 = IneptWizard.create(name: "Rincewind", city: "Ankh-Morpork")
    assert w1.valid?, "Saving w1"

    # Should use validation from base class (which is abstract)
    w2 = IneptWizard.new(name: "Rincewind", city: "Quirm")
    assert_not w2.valid?, "w2 shouldn't be valid"
    assert w2.errors[:name].any?, "Should have errors for name"
    assert_equal ["has already been taken"], w2.errors[:name], "Should have uniqueness message for name"

    w3 = Conjurer.new(name: "Rincewind", city: "Quirm")
    assert_not w3.valid?, "w3 shouldn't be valid"
    assert w3.errors[:name].any?, "Should have errors for name"
    assert_equal ["has already been taken"], w3.errors[:name], "Should have uniqueness message for name"

    w4 = Conjurer.create(name: "The Amazing Bonko", city: "Quirm")
    assert w4.valid?, "Saving w4"

    w5 = Thaumaturgist.new(name: "The Amazing Bonko", city: "Lancre")
    assert_not w5.valid?, "w5 shouldn't be valid"
    assert w5.errors[:name].any?, "Should have errors for name"
    assert_equal ["has already been taken"], w5.errors[:name], "Should have uniqueness message for name"

    w6 = Thaumaturgist.new(name: "Mustrum Ridcully", city: "Quirm")
    assert_not w6.valid?, "w6 shouldn't be valid"
    assert w6.errors[:city].any?, "Should have errors for city"
    assert_equal ["has already been taken"], w6.errors[:city], "Should have uniqueness message for city"
  end

  def test_validate_uniqueness_with_conditions
    Topic.validates_uniqueness_of :title, conditions: -> { where(approved: true) }
    Topic.create("title" => "I'm a topic", "approved" => true)
    Topic.create("title" => "I'm an unapproved topic", "approved" => false)

    t3 = Topic.new("title" => "I'm a topic", "approved" => true)
    assert_not t3.valid?, "t3 shouldn't be valid"

    t4 = Topic.new("title" => "I'm an unapproved topic", "approved" => false)
    assert t4.valid?, "t4 should be valid"
  end

  def test_validate_uniqueness_with_non_callable_conditions_is_not_supported
    assert_raises(ArgumentError) {
      Topic.validates_uniqueness_of :title, conditions: Topic.where(approved: true)
    }
  end

  def test_validate_uniqueness_with_conditions_with_record_arg
    Topic.validates_uniqueness_of :title, conditions: ->(record) {
      where(written_on: record.written_on.beginning_of_day..record.written_on.end_of_day)
    }

    today_midday = Time.current.midday

    todays_topic = Topic.new(title: "Highlights of the Day", written_on: today_midday)
    assert todays_topic.save, "1st topic written today with this title should save"

    todays_topic_duplicate = Topic.new(title: "Highlights of the Day", written_on: today_midday + 1.minute)
    assert todays_topic_duplicate.invalid?, "2nd topic written today with this title should be invalid"

    tomorrows_topic = Topic.new(title: "Highlights of the Day", written_on: today_midday + 1.day)
    assert tomorrows_topic.valid?, "1st topic written tomorrow with this title should be valid"
  end

  def test_validate_uniqueness_on_existing_relation
    event = Event.create
    assert_predicate TopicWithUniqEvent.create(event: event), :valid?

    topic = TopicWithUniqEvent.new(event: event)
    assert_not_predicate topic, :valid?
    assert_equal ["has already been taken"], topic.errors[:event]
  end

  def test_validate_uniqueness_on_empty_relation
    topic = TopicWithUniqEvent.new
    assert_predicate topic, :valid?
  end

  def test_validate_uniqueness_of_custom_primary_key
    klass = Class.new(ActiveRecord::Base) do
      self.table_name = "keyboards"
      self.primary_key = :key_number

      validates_uniqueness_of :key_number

      def self.name
        "Keyboard"
      end
    end

    klass.create!(key_number: 10)
    key2 = klass.create!(key_number: 11)

    key2.key_number = 10
    assert_not_predicate key2, :valid?
  end

  def test_validate_uniqueness_without_primary_key
    klass = Class.new(ActiveRecord::Base) do
      self.table_name = "dashboards"

      validates_uniqueness_of :dashboard_id

      def self.name; "Dashboard" end
    end

    abc = klass.create!(dashboard_id: "abc")
    assert_predicate klass.new(dashboard_id: "xyz"), :valid?
    assert_not_predicate klass.new(dashboard_id: "abc"), :valid?

    abc.dashboard_id = "def"

    e = assert_raises ActiveRecord::UnknownPrimaryKey do
      abc.save!
    end
    assert_match(/\AUnknown primary key for table dashboards in model/, e.message)
    assert_match(/Cannot validate uniqueness for persisted record without primary key.\z/, e.message)
  end

  def test_validate_uniqueness_ignores_itself_when_primary_key_changed
    Topic.validates_uniqueness_of(:title)

    t = Topic.new("title" => "This is a unique title")
    assert t.save, "Should save t as unique"

    t.id += 1
    assert t.valid?, "Should be valid"
    assert t.save, "Should still save t as unique"
  end

  def test_validate_uniqueness_with_after_create_performing_save
    TopicWithAfterCreate.validates_uniqueness_of(:title)
    topic = TopicWithAfterCreate.create!(title: "Title1")
    assert topic.author_name.start_with?("Title1")

    topic2 = TopicWithAfterCreate.new(title: "Title1")
    assert_not_predicate topic2, :valid?
    assert_equal(["has already been taken"], topic2.errors[:title])
  end

  def test_validate_uniqueness_uuid
    skip unless current_adapter?(:PostgreSQLAdapter)
    item = UuidItem.create!(uuid: SecureRandom.uuid, title: "item1")
    item.update(title: "item1-title2")
    assert_empty item.errors

    item2 = UuidValidatingItem.create!(uuid: SecureRandom.uuid, title: "item2")
    item2.update(title: "item2-title2")
    assert_empty item2.errors
  end

  def test_validate_uniqueness_regular_id
    item = CoolTopic.create!(title: "MyItem")
    assert_empty item.errors

    item2 = CoolTopic.new(id: item.id, title: "MyItem2")
    assert_not_predicate item2, :valid?

    assert_equal(["has already been taken"], item2.errors[:id])
  end
end
