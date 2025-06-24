# frozen_string_literal: true

require "cases/helper"
require "models/minimalistic"
require "models/developer"
require "models/auto_id"
require "models/author"
require "models/boolean"
require "models/computer"
require "models/topic"
require "models/company"
require "models/category"
require "models/reply"
require "models/contact"
require "models/keyboard"
require "models/numeric_data"
require "models/cpk"

class AttributeMethodsTest < ActiveRecord::TestCase
  include InTimeZone

  class EpochTimestamp < ActiveRecord::Type::DateTime
    def deserialize(time_or_int)
      Time.at(time_or_int).utc if time_or_int
    end

    def serialize(time)
      time.to_i if time
    end
  end

  ActiveRecord::Type.register(:epoch_timestamp, EpochTimestamp)

  fixtures :topics, :developers, :companies, :computers

  def setup
    @old_matchers = ActiveRecord::Base.send(:attribute_method_patterns).dup
    @target = Class.new(ActiveRecord::Base)
    @target.table_name = "topics"
  end

  teardown do
    ActiveRecord::Base.send(:attribute_method_patterns).clear
    ActiveRecord::Base.send(:attribute_method_patterns).concat(@old_matchers)
  end

  test "#id_value alias is defined if id column exist" do
    new_topic_model = Class.new(ActiveRecord::Base) do
      self.table_name = "topics"
    end

    new_topic_model.define_attribute_methods
    assert_includes new_topic_model.attribute_names, "id"
    assert_includes new_topic_model.attribute_aliases, "id_value"
  end

  test "aliasing `id` attribute allows reading the column value" do
    topic = Topic.create(id: 123_456, title: "title").becomes(TitlePrimaryKeyTopic)

    assert_equal(123_456, topic.id_value)
  end

  test "aliasing `id` attribute allows reading the column value for a CPK model" do
    order = ::Cpk::Order.create(id: [1, 123_456])

    assert_not_nil(order.id_value)
    assert_equal(123_456, order.id_value)
  end

  test "#id_value alias returns the value in the id column, when id column exists" do
    topic = Topic.new
    assert_nil topic.id_value

    topic = Topic.find(1)
    assert_equal 1, topic.id_value
  end

  test "#id_value alias is not defined if id column doesn't exist" do
    keyboard = Keyboard.create!

    assert_empty keyboard.attribute_aliases
  end

  test "#id_value alias returns id column only for composite primary key models" do
    order = ::Cpk::Order.create(id: [1, 2])

    assert_equal 2, order.id_value
  end

  test "attribute_for_inspect with a string" do
    t = topics(:first)
    t.title = "The First Topic Now Has A Title With\nNewlines And More Than 50 Characters"

    assert_equal '"The First Topic Now Has A Title With\nNewlines And ..."', t.attribute_for_inspect(:title)
    assert_equal '"The First Topic Now Has A Title With\nNewlines And ..."', t.attribute_for_inspect(:heading)
  end

  test "attribute_for_inspect with a date" do
    t = topics(:first)

    assert_equal %("#{t.written_on.to_fs(:inspect)}"), t.attribute_for_inspect(:written_on)
  end

  test "attribute_for_inspect with an array" do
    t = topics(:first)
    t.content = ["some_value"]
    assert_match %r(\["some_value"\]), t.attribute_for_inspect(:content)
  end

  test "attribute_for_inspect with a long array" do
    t = topics(:first)
    t.content = (1..11).to_a

    assert_equal "[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]", t.attribute_for_inspect(:content)
  end

  test "attribute_for_inspect with a non-primary key id attribute" do
    t = topics(:first).becomes(TitlePrimaryKeyTopic)
    t.title = "The First Topic Now Has A Title With\nNewlines And More Than 50 Characters"

    assert_equal "1", t.attribute_for_inspect(:id)
  end

  test "attribute_present" do
    t = Topic.new
    t.title = "hello there!"
    t.written_on = Time.now
    t.author_name = ""
    assert t.attribute_present?("title")
    assert t.attribute_present?("heading")
    assert t.attribute_present?("written_on")
    assert_not t.attribute_present?("content")
    assert_not t.attribute_present?("author_name")
  end

  test "attribute_present with booleans" do
    b1 = Boolean.new
    b1.value = false
    assert b1.attribute_present?(:value)

    b2 = Boolean.new
    b2.value = true
    assert b2.attribute_present?(:value)

    b3 = Boolean.new
    assert_not b3.attribute_present?(:value)

    b4 = Boolean.new
    b4.value = false
    b4.save!
    assert Boolean.find(b4.id).attribute_present?(:value)
  end

  test "caching a nil primary key" do
    klass = Class.new(Minimalistic)
    klass.primary_key # warm once

    assert_not_called(klass, :reset_primary_key) do
      klass.primary_key
    end
  end

  test "attribute keys on a new instance" do
    t = Topic.new
    assert_nil t.title, "The topics table has a title column, so it should be nil"
    assert_raise(NoMethodError) { t.title2 }
  end

  test "boolean attributes" do
    assert_not_predicate Topic.find(1), :approved?
    assert_predicate Topic.find(2), :approved?
  end

  test "set attributes" do
    topic = Topic.find(1)
    topic.attributes = { title: "Budget", author_name: "Jason" }
    topic.save
    assert_equal("Budget", topic.title)
    assert_equal("Jason", topic.author_name)
    assert_equal(topics(:first).author_email_address, Topic.find(1).author_email_address)
  end

  test "set attributes without a hash" do
    topic = Topic.new
    assert_raise(ArgumentError) { topic.attributes = "" }
  end

  test "integers as nil" do
    test = AutoId.create(value: "")
    assert_nil AutoId.find(test.id).value
  end

  test "set attributes with a block" do
    topic = Topic.new do |t|
      t.title       = "Budget"
      t.author_name = "Jason"
    end

    assert_equal("Budget", topic.title)
    assert_equal("Jason", topic.author_name)
  end

  test "respond_to?" do
    topic = Topic.find(1)
    assert_respond_to topic, "title"
    assert_respond_to topic, "title?"
    assert_respond_to topic, "title="
    assert_respond_to topic, :title
    assert_respond_to topic, :title?
    assert_respond_to topic, :title=
    assert_respond_to topic, "author_name"
    assert_respond_to topic, "attribute_names"
    assert_not_respond_to topic, "nothingness"
    assert_not_respond_to topic, :nothingness
  end

  test "respond_to? with a custom primary key" do
    keyboard = Keyboard.create
    assert_not_nil keyboard.key_number
    assert_equal keyboard.key_number, keyboard.id
    assert_respond_to keyboard, "key_number"
    assert_respond_to keyboard, "id"
  end

  test "id_before_type_cast with a custom primary key" do
    keyboard = Keyboard.create
    keyboard.key_number = "10"
    assert_equal "10", keyboard.id_before_type_cast
    assert_nil keyboard.read_attribute_before_type_cast("id")
    assert_equal "10", keyboard.read_attribute_before_type_cast("key_number")
    assert_equal "10", keyboard.read_attribute_before_type_cast(:key_number)
  end

  # IRB inspects the return value of MyModel.allocate.
  test "allocated objects can be inspected" do
    topic = Topic.allocate
    assert_equal "#<Topic not initialized>", topic.inspect
  end

  test "array content" do
    content = %w( one two three )
    topic = Topic.new
    topic.content = content
    topic.save

    assert_equal content, Topic.find(topic.id).content
  end

  test "read attributes_before_type_cast" do
    category = Category.new(name: "Test category", type: nil)
    category_attrs = { "name" => "Test category", "id" => nil, "type" => nil, "categorizations_count" => nil }
    assert_equal category_attrs, category.attributes_before_type_cast
  end

  if current_adapter?(:Mysql2Adapter, :TrilogyAdapter)
    test "read attributes_before_type_cast on a boolean" do
      bool = Boolean.create!("value" => false)
      assert_equal 0, bool.reload.attributes_before_type_cast["value"]
    end
  end

  test "read attributes_before_type_cast on a datetime" do
    in_time_zone "Pacific Time (US & Canada)" do
      record = @target.new

      record.written_on = "345643456"
      assert_equal "345643456", record.written_on_before_type_cast
      assert_nil record.written_on

      record.written_on = "2009-10-11 12:13:14"
      assert_equal "2009-10-11 12:13:14", record.written_on_before_type_cast
      assert_equal Time.zone.parse("2009-10-11 12:13:14"), record.written_on
      assert_equal ActiveSupport::TimeZone["Pacific Time (US & Canada)"], record.written_on.time_zone
    end
  end

  test "read_attribute_for_database" do
    topic = Topic.new(content: ["ok"])
    assert_equal "---\n- ok\n", topic.read_attribute_for_database("content")
  end

  test "read_attribute_for_database with aliased attribute" do
    topic = Topic.new(title: "Hello")
    assert_equal "Hello", topic.read_attribute_for_database(:heading)
  end

  test "attributes_for_database" do
    topic = Topic.new
    topic.content = { "one" => 1, "two" => 2 }

    db_attributes = Topic.instantiate(topic.attributes_for_database).attributes
    assert_equal topic.attributes, db_attributes
  end

  test "read attributes after type cast on a date" do
    tz = "Pacific Time (US & Canada)"

    in_time_zone tz do
      record = @target.new

      date_string = "2011-03-24"
      time        = Time.zone.parse date_string

      record.written_on = date_string
      assert_equal date_string, record.written_on_before_type_cast
      assert_equal time, record.written_on
      assert_equal ActiveSupport::TimeZone[tz], record.written_on.time_zone

      record.save
      record.reload

      assert_equal time, record.written_on
    end
  end

  test "hash content" do
    topic = Topic.new
    topic.content = { "one" => 1, "two" => 2 }
    topic.save

    assert_equal 2, Topic.find(topic.id).content["two"]

    topic.content_will_change!
    topic.content["three"] = 3
    topic.save

    assert_equal 3, Topic.find(topic.id).content["three"]
  end

  test "update array content" do
    topic = Topic.new
    topic.content = %w( one two three )

    topic.content.push "four"
    assert_equal(%w( one two three four ), topic.content)

    topic.save

    topic = Topic.find(topic.id)
    topic.content << "five"
    assert_equal(%w( one two three four five ), topic.content)
  end

  test "case-sensitive attributes hash" do
    expected = ["created_at", "developer", "extendedWarranty", "id", "system", "timezone", "updated_at"]
    assert_equal expected, Computer.first.attributes.keys.sort
  end

  test "attributes without primary key" do
    klass = Class.new(ActiveRecord::Base) do
      self.table_name = "developers_projects"
    end

    assert_equal klass.column_names, klass.new.attributes.keys
    assert_not klass.new.has_attribute?("id")
  end

  test "hashes are not mangled" do
    new_topic = { "title" => "New Topic", "content" => { "key" => "First value" } }
    new_topic_values = { "title" => "AnotherTopic", "content" => { "key" => "Second value" } }

    topic = Topic.new(new_topic)
    assert_equal new_topic["title"], topic.title
    assert_equal new_topic["content"], topic.content

    topic.attributes = new_topic_values
    assert_equal new_topic_values["title"], topic.title
    assert_equal new_topic_values["content"], topic.content
  end

  test "create through factory" do
    topic = Topic.create(title: "New Topic")
    topicReloaded = Topic.find(topic.id)
    assert_equal(topic, topicReloaded)
  end

  test "write_attribute" do
    topic = Topic.new
    topic.write_attribute :title, "Still another topic"
    assert_equal "Still another topic", topic.title

    topic[:title] = "Still another topic: part 2"
    assert_equal "Still another topic: part 2", topic.title

    topic.write_attribute "title", "Still another topic: part 3"
    assert_equal "Still another topic: part 3", topic.title

    topic["title"] = "Still another topic: part 4"
    assert_equal "Still another topic: part 4", topic.title
  end

  test "write_attribute can write aliased attributes as well" do
    topic = Topic.new(title: "Don't change the topic")
    topic.write_attribute :heading, "New topic"

    assert_equal "New topic", topic.title
  end

  test "write_attribute raises ActiveModel::MissingAttributeError when the attribute does not exist" do
    topic = Topic.first
    assert_raises(ActiveModel::MissingAttributeError) { topic.update_columns(no_column_exists: "Hello!") }
    assert_raises(ActiveModel::UnknownAttributeError) { topic.update(no_column_exists: "Hello!") }
    assert_raises(ActiveModel::MissingAttributeError) { topic[:no_column_exists] = "Hello!" }
  end

  test "write_attribute does not raise when the attribute isn't selected" do
    topic = Topic.select(:id).first
    assert_nothing_raised { topic[:title] = "Hello!" }
  end

  test "write_attribute allows writing to aliased attributes" do
    topic = Topic.first
    assert_nothing_raised { topic.update_columns(heading: "Hello!") }
    assert_nothing_raised { topic.update(heading: "Hello!") }
  end

  test "read_attribute" do
    topic = Topic.new
    topic.title = "Don't change the topic"
    assert_equal "Don't change the topic", topic.read_attribute("title")
    assert_equal "Don't change the topic", topic["title"]

    assert_equal "Don't change the topic", topic.read_attribute(:title)
    assert_equal "Don't change the topic", topic[:title]
  end

  test "read_attribute can read aliased attributes as well" do
    topic = Topic.new(title: "Don't change the topic")

    assert_equal "Don't change the topic", topic.read_attribute("heading")
    assert_equal "Don't change the topic", topic["heading"]

    assert_equal "Don't change the topic", topic.read_attribute(:heading)
    assert_equal "Don't change the topic", topic[:heading]
  end

  test "read_attribute raises ActiveModel::MissingAttributeError when the attribute isn't selected" do
    computer = Computer.select(:id, :extendedWarranty).first
    assert_raises(ActiveModel::MissingAttributeError, match: /attribute 'developer' for Computer/) do
      computer[:developer]
    end
    assert_nothing_raised { computer[:extendedWarranty] }
    assert_nothing_raised { computer[:no_column_exists] }
  end

  test "read_attribute when false" do
    topic = topics(:first)
    topic.approved = false
    assert_not topic.approved?, "approved should be false"
    topic.approved = "false"
    assert_not topic.approved?, "approved should be false"
  end

  test "read_attribute when true" do
    topic = topics(:first)
    topic.approved = true
    assert_predicate topic, :approved?, "approved should be true"
    topic.approved = "true"
    assert_predicate topic, :approved?, "approved should be true"
  end

  test "boolean attributes writing and reading" do
    topic = Topic.new
    topic.approved = "false"
    assert_not topic.approved?, "approved should be false"

    topic.approved = "false"
    assert_not topic.approved?, "approved should be false"

    topic.approved = "true"
    assert_predicate topic, :approved?, "approved should be true"

    topic.approved = "true"
    assert_predicate topic, :approved?, "approved should be true"
  end

  test "overridden write_attribute" do
    topic = Topic.new
    def topic.write_attribute(attr_name, value)
      super(attr_name, value.downcase)
    end

    topic.write_attribute :title, "Yet another topic"
    assert_equal "yet another topic", topic.title

    topic[:title] = "Yet another topic: part 2"
    assert_equal "yet another topic: part 2", topic.title

    topic.write_attribute "title", "Yet another topic: part 3"
    assert_equal "yet another topic: part 3", topic.title

    topic["title"] = "Yet another topic: part 4"
    assert_equal "yet another topic: part 4", topic.title
  end

  test "overridden read_attribute" do
    topic = Topic.new
    topic.title = "Stop changing the topic"
    def topic.read_attribute(attr_name)
      super(attr_name).upcase
    end

    assert_equal "STOP CHANGING THE TOPIC", topic.read_attribute("title")
    assert_equal "STOP CHANGING THE TOPIC", topic["title"]

    assert_equal "STOP CHANGING THE TOPIC", topic.read_attribute(:title)
    assert_equal "STOP CHANGING THE TOPIC", topic[:title]
  end

  test "read overridden attribute" do
    topic = Topic.new(title: "a")
    def topic.title() "b" end
    assert_equal "a", topic[:title]
  end

  test "read overridden attribute with predicate respects override" do
    topic = Topic.new

    topic.approved = true

    def topic.approved; false; end

    assert_not topic.approved?, "overridden approved should be false"
  end

  test "string attribute predicate" do
    [nil, "", " "].each do |value|
      assert_equal false, Topic.new(author_name: value).author_name?
    end

    assert_equal true, Topic.new(author_name: "Name").author_name?

    ActiveModel::Type::Boolean::FALSE_VALUES.each do |value|
      assert_predicate Topic.new(author_name: value), :author_name?
    end
  end

  test "number attribute predicate" do
    [nil, 0, "0"].each do |value|
      assert_equal false, Developer.new(salary: value).salary?
    end

    assert_equal true, Developer.new(salary: 1).salary?
    assert_equal true, Developer.new(salary: "1").salary?
  end

  test "boolean attribute predicate" do
    [nil, "", false, "false", "f", 0].each do |value|
      assert_equal false, Topic.new(approved: value).approved?
    end

    [true, "true", "1", 1].each do |value|
      assert_equal true, Topic.new(approved: value).approved?
    end
  end

  test "user-defined text attribute predicate" do
    klass = Class.new(ActiveRecord::Base) do
      self.table_name = Topic.table_name

      attribute :user_defined_text, :text
    end

    topic = klass.new(user_defined_text: "text")
    assert_predicate topic, :user_defined_text?

    ActiveModel::Type::Boolean::FALSE_VALUES.each do |value|
      topic = klass.new(user_defined_text: value)
      assert_predicate topic, :user_defined_text?
    end
  end

  test "user-defined date attribute predicate" do
    klass = Class.new(ActiveRecord::Base) do
      self.table_name = Topic.table_name

      attribute :user_defined_date, :date
    end

    topic = klass.new(user_defined_date: Date.current)
    assert_predicate topic, :user_defined_date?
  end

  test "user-defined datetime attribute predicate" do
    klass = Class.new(ActiveRecord::Base) do
      self.table_name = Topic.table_name

      attribute :user_defined_datetime, :datetime
    end

    topic = klass.new(user_defined_datetime: Time.current)
    assert_predicate topic, :user_defined_datetime?
  end

  test "user-defined time attribute predicate" do
    klass = Class.new(ActiveRecord::Base) do
      self.table_name = Topic.table_name

      attribute :user_defined_time, :time
    end

    topic = klass.new(user_defined_time: Time.current)
    assert_predicate topic, :user_defined_time?
  end

  test "user-defined JSON attribute predicate" do
    klass = Class.new(ActiveRecord::Base) do
      self.table_name = Topic.table_name

      attribute :user_defined_json, :json
    end

    topic = klass.new(user_defined_json: { key: "value" })
    assert_predicate topic, :user_defined_json?

    topic = klass.new(user_defined_json: {})
    assert_not_predicate topic, :user_defined_json?
  end

  test "custom field attribute predicate" do
    object = Company.find_by_sql(<<~SQL).first
      SELECT c1.*, c2.type as string_value, c2.rating as int_value
        FROM companies c1, companies c2
       WHERE c1.firm_id = c2.id
         AND c1.id = 2
    SQL

    assert_equal "Firm", object.string_value
    assert_predicate object, :string_value?

    object.string_value = "  "
    assert_not_predicate object, :string_value?

    assert_equal 1, object.int_value.to_i
    assert_predicate object, :int_value?

    object.int_value = "0"
    assert_not_predicate object, :int_value?
  end

  test "non-attribute read and write" do
    topic = Topic.new
    assert_not_respond_to topic, "mumbo"
    assert_raise(NoMethodError) { topic.mumbo }
    assert_raise(NoMethodError) { topic.mumbo = 5 }
  end

  test "undeclared attribute method does not affect respond_to? and method_missing" do
    topic = @target.new(title: "Budget")
    assert_respond_to topic, "title"
    assert_equal "Budget", topic.title
    assert_not_respond_to topic, "title_hello_world"
    assert_raise(NoMethodError) { topic.title_hello_world }
  end

  test "declared prefixed attribute method affects respond_to? and method_missing" do
    topic = @target.new(title: "Budget")
    %w(default_ title_).each do |prefix|
      @target.class_eval "def #{prefix}attribute(*args) args end"
      @target.attribute_method_prefix prefix

      meth = "#{prefix}title"
      assert_respond_to topic, meth
      assert_equal ["title"], topic.public_send(meth)
      assert_equal ["title", "a"], topic.public_send(meth, "a")
      assert_equal ["title", 1, 2, 3], topic.public_send(meth, 1, 2, 3)
    end
  end

  test "declared suffixed attribute method affects respond_to? and method_missing" do
    %w(_default _title_default _it! _candidate= able?).each do |suffix|
      @target.class_eval "def attribute#{suffix}(*args) args end"
      @target.attribute_method_suffix suffix
      topic = @target.new(title: "Budget")

      meth = "title#{suffix}"
      assert_respond_to topic, meth
      assert_equal ["title"], topic.public_send(meth)
      assert_equal ["title", "a"], topic.public_send(meth, "a")
      assert_equal ["title", 1, 2, 3], topic.public_send(meth, 1, 2, 3)
    end
  end

  test "declared affixed attribute method affects respond_to? and method_missing" do
    [["mark_", "_for_update"], ["reset_", "!"], ["default_", "_value?"]].each do |prefix, suffix|
      @target.class_eval "def #{prefix}attribute#{suffix}(*args) args end"
      @target.attribute_method_affix(prefix: prefix, suffix: suffix)
      topic = @target.new(title: "Budget")

      meth = "#{prefix}title#{suffix}"
      assert_respond_to topic, meth
      assert_equal ["title"], topic.public_send(meth)
      assert_equal ["title", "a"], topic.public_send(meth, "a")
      assert_equal ["title", 1, 2, 3], topic.public_send(meth, 1, 2, 3)
    end
  end

  test "should unserialize attributes for frozen records" do
    myobj = { "value1" => "value2" }
    topic = Topic.create(content: myobj)
    topic.freeze
    assert_equal myobj, topic.content
  end

  test "typecast attribute from select to false" do
    Topic.create(title: "Budget")
    topic = Topic.all.merge!(select: "topics.*, 1=2 as is_test").first
    assert_not_predicate topic, :is_test?
  end

  test "typecast attribute from select to true" do
    Topic.create(title: "Budget")
    topic = Topic.all.merge!(select: "topics.*, 2=2 as is_test").first
    assert_predicate topic, :is_test?
  end

  test "raises ActiveRecord::DangerousAttributeError when defining an AR method or dangerous Object method in a model" do
    %w(save create_or_update hash dup frozen?).each do |method|
      klass = Class.new(ActiveRecord::Base)
      klass.class_eval "def #{method}() 'defined #{method}' end"
      assert_raise ActiveRecord::DangerousAttributeError do
        klass.instance_method_already_implemented?(method)
      end
    end
  end

  test "converted values are returned after assignment" do
    developer = Developer.new(name: 1337, salary: "50000")

    assert_equal "50000", developer.salary_before_type_cast
    assert_equal 1337, developer.name_before_type_cast

    assert_equal 50000, developer.salary
    assert_equal "1337", developer.name

    developer.save!

    assert_equal 50000, developer.salary
    assert_equal "1337", developer.name
  end

  test "write nil to time attribute" do
    in_time_zone "Pacific Time (US & Canada)" do
      record = @target.new
      record.written_on = nil
      assert_nil record.written_on
    end
  end

  test "write time to date attribute" do
    in_time_zone "Pacific Time (US & Canada)" do
      record = @target.new
      record.last_read = Time.utc(2010, 1, 1, 10)
      assert_equal Date.civil(2010, 1, 1), record.last_read
    end
  end

  test "time attributes are retrieved in the current time zone" do
    in_time_zone "Pacific Time (US & Canada)" do
      utc_time = Time.utc(2008, 1, 1)
      record   = @target.new
      record[:written_on] = utc_time
      assert_equal utc_time, record.written_on # record.written on is equal to (i.e., simultaneous with) utc_time
      assert_kind_of ActiveSupport::TimeWithZone, record.written_on # but is a TimeWithZone
      assert_equal ActiveSupport::TimeZone["Pacific Time (US & Canada)"], record.written_on.time_zone # and is in the current Time.zone
      assert_equal Time.utc(2007, 12, 31, 16), record.written_on.time # and represents time values adjusted accordingly
    end
  end

  test "setting a time zone-aware attribute to UTC" do
    in_time_zone "Pacific Time (US & Canada)" do
      utc_time = Time.utc(2008, 1, 1)
      record   = @target.new
      record.written_on = utc_time
      assert_equal utc_time, record.written_on
      assert_equal ActiveSupport::TimeZone["Pacific Time (US & Canada)"], record.written_on.time_zone
      assert_equal Time.utc(2007, 12, 31, 16), record.written_on.time
    end
  end

  test "setting time zone-aware attribute in other time zone" do
    utc_time = Time.utc(2008, 1, 1)
    cst_time = utc_time.in_time_zone("Central Time (US & Canada)")
    in_time_zone "Pacific Time (US & Canada)" do
      record = @target.new
      record.written_on = cst_time
      assert_equal utc_time, record.written_on
      assert_equal ActiveSupport::TimeZone["Pacific Time (US & Canada)"], record.written_on.time_zone
      assert_equal Time.utc(2007, 12, 31, 16), record.written_on.time
    end
  end

  test "setting time zone-aware read attribute" do
    utc_time = Time.utc(2008, 1, 1)
    cst_time = utc_time.in_time_zone("Central Time (US & Canada)")
    in_time_zone "Pacific Time (US & Canada)" do
      record = @target.create(written_on: cst_time).reload
      assert_equal utc_time, record[:written_on]
      assert_equal ActiveSupport::TimeZone["Pacific Time (US & Canada)"], record[:written_on].time_zone
      assert_equal Time.utc(2007, 12, 31, 16), record[:written_on].time
    end
  end

  test "setting time zone-aware attribute with a string" do
    utc_time = Time.utc(2008, 1, 1)
    (-11..13).each do |timezone_offset|
      time_string = utc_time.in_time_zone(timezone_offset).to_s
      in_time_zone "Pacific Time (US & Canada)" do
        record = @target.new
        record.written_on = time_string
        assert_equal Time.zone.parse(time_string), record.written_on
        assert_equal ActiveSupport::TimeZone["Pacific Time (US & Canada)"], record.written_on.time_zone
        assert_equal Time.utc(2007, 12, 31, 16), record.written_on.time
      end
    end
  end

  test "time zone-aware attribute saved" do
    in_time_zone 1 do
      record = @target.create(written_on: "2012-02-20 10:00")

      record.written_on = "2012-02-20 09:00"
      record.save
      assert_equal Time.zone.local(2012, 02, 20, 9), record.reload.written_on
    end
  end

  test "setting a time zone-aware attribute to a blank string returns nil" do
    in_time_zone "Pacific Time (US & Canada)" do
      record = @target.new
      record.written_on = " "
      assert_nil record.written_on
      assert_nil record[:written_on]
    end
  end

  test "setting a time zone-aware attribute interprets time zone-unaware string in time zone" do
    time_string = "Tue Jan 01 00:00:00 2008"
    (-11..13).each do |timezone_offset|
      in_time_zone timezone_offset do
        record = @target.new
        record.written_on = time_string
        assert_equal Time.zone.parse(time_string), record.written_on
        assert_equal ActiveSupport::TimeZone[timezone_offset], record.written_on.time_zone
        assert_equal Time.utc(2008, 1, 1), record.written_on.time
      end
    end
  end

  test "setting a time zone-aware datetime in the current time zone" do
    utc_time = Time.utc(2008, 1, 1)
    in_time_zone "Pacific Time (US & Canada)" do
      record = @target.new
      record.written_on = utc_time.in_time_zone
      assert_equal utc_time, record.written_on
      assert_equal ActiveSupport::TimeZone["Pacific Time (US & Canada)"], record.written_on.time_zone
      assert_equal Time.utc(2007, 12, 31, 16), record.written_on.time
    end
  end

  test "YAML dumping a record with time zone-aware attribute" do
    in_time_zone "Pacific Time (US & Canada)" do
      record = Topic.new(id: 1)
      record.written_on = "Jan 01 00:00:00 2014"
      payload = YAML.dump(record)
      assert_equal record, YAML.respond_to?(:unsafe_load) ? YAML.unsafe_load(payload) : YAML.load(payload)
    end
  ensure
    # NOTE: Reset column info because global topics
    # don't have tz-aware attributes by default.
    Topic.reset_column_information
  end

  test "setting a time zone-aware time in the current time zone" do
    in_time_zone "Pacific Time (US & Canada)" do
      record = @target.new
      time_string = "10:00:00"
      expected_time = Time.zone.parse("2000-01-01 #{time_string}")

      record.bonus_time = time_string
      assert_equal expected_time, record.bonus_time
      assert_equal ActiveSupport::TimeZone["Pacific Time (US & Canada)"], record.bonus_time.time_zone

      record.bonus_time = ""
      assert_nil record.bonus_time
    end
  end

  test "setting a time zone-aware time with DST" do
    in_time_zone "Pacific Time (US & Canada)" do
      current_time = Time.zone.local(2014, 06, 15, 10)
      record = @target.new(bonus_time: current_time)
      time_before_save = record.bonus_time

      record.save
      record.reload

      assert_equal time_before_save, record.bonus_time
      assert_equal ActiveSupport::TimeZone["Pacific Time (US & Canada)"], record.bonus_time.time_zone
    end
  end

  test "setting invalid string to a zone-aware time attribute" do
    in_time_zone "Pacific Time (US & Canada)" do
      record = @target.new
      time_string = "ABC"

      record.bonus_time = time_string
      assert_nil record.bonus_time
    end
  end

  test "removing time zone-aware types" do
    with_time_zone_aware_types(:datetime) do
      in_time_zone "Pacific Time (US & Canada)" do
        record = @target.new(bonus_time: "10:00:00")
        expected_time = Time.utc(2000, 01, 01, 10)

        assert_equal expected_time, record.bonus_time
        assert_predicate record.bonus_time, :utc?
      end
    end
  end

  test "time zone-aware attributes do not recurse infinitely on invalid values" do
    model = new_topic_like_ar_class { }

    type = model.type_for_attribute(:bonus_time)
    assert_kind_of ActiveRecord::Type::Time, type

    invalid_time = []
    record = model.new(bonus_time: invalid_time)
    assert_equal invalid_time, record.bonus_time

    invalid_time = Time.current.utc.to_i
    record = model.new(bonus_time: invalid_time)
    assert_equal invalid_time, record.bonus_time

    in_time_zone "Pacific Time (US & Canada)" do
      model = new_topic_like_ar_class { }

      type = model.type_for_attribute(:bonus_time)
      assert_kind_of ActiveRecord::AttributeMethods::TimeZoneConversion::TimeZoneConverter, type

      invalid_time = []
      record = model.new(bonus_time: invalid_time)
      assert_equal invalid_time, record.bonus_time

      invalid_time = Time.current.utc.to_i
      record = model.new(bonus_time: invalid_time)
      assert_equal invalid_time, record.bonus_time
    end
  end

  test "time zone-aware custom attributes" do
    timestamp = Time.current.utc.to_i

    model = Class.new(ActiveRecord::Base)
    model.table_name = "minimalistics"

    model.attribute :expires_at, :epoch_timestamp

    type = model.type_for_attribute(:expires_at)
    assert_kind_of EpochTimestamp, type

    record_1 = model.create!(expires_at: timestamp)
    assert_equal timestamp, record_1.expires_at.to_i

    model.insert!({ expires_at: timestamp })
    record_2 = model.last
    assert_not_equal record_1, record_2
    assert_equal timestamp, record_2.expires_at.to_i

    in_time_zone "Pacific Time (US & Canada)" do
      model.attribute :expires_at, :epoch_timestamp

      type = model.type_for_attribute(:expires_at)
      assert_kind_of ActiveRecord::AttributeMethods::TimeZoneConversion::TimeZoneConverter, type

      record_1 = model.create!(expires_at: timestamp)
      assert_equal timestamp, record_1.expires_at.to_i

      model.insert!({ expires_at: timestamp })
      record_2 = model.last
      assert_not_equal record_1, record_2
      assert_equal timestamp, record_2.expires_at.to_i
    end
  end

  test "setting a time_zone_conversion_for_attributes should write the value on a class variable" do
    Topic.skip_time_zone_conversion_for_attributes = [:field_a]
    Minimalistic.skip_time_zone_conversion_for_attributes = [:field_b]

    assert_equal [:field_a], Topic.skip_time_zone_conversion_for_attributes
    assert_equal [:field_b], Minimalistic.skip_time_zone_conversion_for_attributes
  end

  test "attribute readers respect access control" do
    privatize("title")

    topic = @target.new(title: "The pros and cons of programming naked.")
    assert_not_respond_to topic, :title
    exception = assert_raise(NoMethodError) { topic.title }
    assert_includes exception.message, "private method"
    assert_equal "I'm private", topic.send(:title)
  end

  test "attribute writers respect access control" do
    privatize("title=(value)")

    topic = @target.new
    assert_not_respond_to topic, :title=
    exception = assert_raise(NoMethodError) { topic.title = "Pants" }
    assert_includes exception.message, "private method"
    topic.send(:title=, "Very large pants")
  end

  test "attribute predicates respect access control" do
    privatize("title?")

    topic = @target.new(title: "Isaac Newton's pants")
    assert_not_respond_to topic, :title?
    exception = assert_raise(NoMethodError) { topic.title? }
    assert_includes exception.message, "private method"
    assert topic.send(:title?)
  end

  test "bulk updates respect access control" do
    privatize("title=(value)")

    assert_raise(ActiveRecord::UnknownAttributeError) { @target.new(title: "Rants about pants") }
    assert_raise(ActiveRecord::UnknownAttributeError) { @target.new.attributes = { title: "Ants in pants" } }
  end

  test "bulk update raises ActiveRecord::UnknownAttributeError" do
    error = assert_raises(ActiveRecord::UnknownAttributeError) {
      Topic.new(hello: "world")
    }
    assert_instance_of Topic, error.record
    assert_equal "hello", error.attribute
    assert_match "unknown attribute 'hello' for Topic.", error.message
  end

  test "method overrides in multi-level subclasses" do
    klass = Class.new(Developer) do
      def name
        "dev:#{read_attribute(:name)}"
      end
    end

    2.times { klass = Class.new(klass) }
    dev = klass.new(name: "arthurnn")
    dev.save!
    assert_equal "dev:arthurnn", dev.reload.name
  end

  test "global methods are overwritten" do
    klass = Class.new(ActiveRecord::Base) do
      self.table_name = "computers"
    end

    assert_not klass.instance_method_already_implemented?(:system)
    computer = klass.new
    assert_nil computer.system
  end

  test "global methods are overwritten when subclassing" do
    klass = Class.new(ActiveRecord::Base) do
      self.abstract_class = true
    end

    subklass = Class.new(klass) do
      self.table_name = "computers"
    end

    assert_not klass.instance_method_already_implemented?(:system)
    assert_not subklass.instance_method_already_implemented?(:system)
    computer = subklass.new
    assert_nil computer.system
  end

  test "instance methods should be defined on the base class" do
    subklass = Class.new(Topic)

    Topic.define_attribute_methods

    instance = subklass.new
    instance.id = 5
    assert_equal 5, instance.id
    assert subklass.method_defined?(:id), "subklass is missing id method"

    Topic.undefine_attribute_methods

    assert_equal 5, instance.id
    assert subklass.method_defined?(:id), "subklass is missing id method"
  end

  test "#undefine_attribute_methods undefines alias attribute methods" do
    topic_class = Class.new(ActiveRecord::Base) do
      self.table_name = "topics"

      alias_attribute :subject_to_be_undefined, :title
    end

    topic = topic_class.new(title: "New topic")
    assert_equal("New topic", topic.subject_to_be_undefined)
    assert_equal true, topic_class.method_defined?(:subject_to_be_undefined)
    topic_class.undefine_attribute_methods
    assert_equal false, topic_class.method_defined?(:subject_to_be_undefined)

    topic.subject_to_be_undefined
    assert_equal true, topic_class.method_defined?(:subject_to_be_undefined)

    topic_class.undefine_attribute_methods
    assert_equal true, topic.respond_to?(:subject_to_be_undefined)
    assert_equal true, topic_class.method_defined?(:subject_to_be_undefined)
  end

  test "#define_attribute_methods brings back undefined aliases" do
    topic_class = Class.new(ActiveRecord::Base) do
      self.table_name = "topics"

      alias_attribute :title_alias_to_be_undefined, :title
    end

    topic = topic_class.new(title: "New topic")
    assert_equal("New topic", topic.title_alias_to_be_undefined)
    topic_class.undefine_attribute_methods

    assert_equal false, topic_class.method_defined?(:title_alias_to_be_undefined)

    topic_class.define_attribute_methods

    assert_equal true, topic_class.method_defined?(:title_alias_to_be_undefined)
    assert_equal "New topic", topic.title_alias_to_be_undefined
  end

  test "#define_attribute_methods doesn't connect to the database when schema cache is present" do
    with_temporary_connection_pool do
      if in_memory_db?
        # Separate connections to an in-memory database create an entirely new database,
        # with an empty schema etc, so we just stub out this schema on the fly.
        ActiveRecord::Base.connection_pool.with_connection do |connection|
          connection.create_table :tasks do |t|
            t.datetime :starting
            t.datetime :ending
          end
        end
      end

      @target.table_name = "tasks"

      @target.connection_pool.schema_cache.load!
      @target.connection_pool.schema_cache.add("tasks")
      @target.connection_pool.disconnect!

      assert_no_queries(include_schema: true) do
        @target.define_attribute_methods
      end
    ensure
      ActiveRecord::Base.connection_pool.disconnect!
    end
  end

  test "define_attribute_method works with both symbol and string" do
    klass = Class.new(ActiveRecord::Base)
    klass.table_name = "foo"

    assert_nothing_raised { klass.define_attribute_method(:foo) }
    assert_nothing_raised { klass.define_attribute_method("bar") }
  end

  test "#method_missing define methods on the fly in a thread safe way" do
    topic_class = Class.new(ActiveRecord::Base) do
      self.table_name = "topics"
    end

    topic = topic_class.new(title: "New topic")
    topic_class.undefine_attribute_methods
    def topic.method_missing(...)
      sleep 0.1 # required to cause a race condition
      super
    end

    threads = 5.times.map do
      Thread.new do
        assert_equal "New topic", topic.title
      end
    end
    threads.each(&:join)
  ensure
    threads&.each(&:kill)
  end

  test "#method_missing define methods on the fly in a thread safe way, even when decorated" do
    topic_class = Class.new(ActiveRecord::Base) do
      self.table_name = "topics"

      def title
        "title:#{super}"
      end
    end

    topic = topic_class.new(title: "New topic")
    topic_class.undefine_attribute_methods
    def topic.method_missing(...)
      sleep 0.1 # required to cause a race condition
      super
    end

    threads = 5.times.map do
      Thread.new do
        assert_equal "title:New topic", topic.title
      end
    end
    threads.each(&:join)
  ensure
    threads&.each(&:kill)
  end

  test "read_attribute with nil should not asplode" do
    assert_nil Topic.new.read_attribute(nil)
  end

  # If B < A, and A defines an accessor for 'foo', we don't want to override
  # that by defining a 'foo' method in the generated methods module for B.
  # (That module will be inserted between the two, e.g. [B, <GeneratedAttributes>, A].)
  test "inherited custom accessors" do
    klass = new_topic_like_ar_class do
      self.abstract_class = true
      def title; "omg"; end
      def title=(val); self.author_name = val; end
    end
    subklass = Class.new(klass)
    [klass, subklass].each(&:define_attribute_methods)

    topic = subklass.find(1)
    assert_equal "omg", topic.title

    topic.title = "lol"
    assert_equal "lol", topic.author_name
  end

  test "inherited custom accessors with reserved names" do
    klass = Class.new(ActiveRecord::Base) do
      self.table_name = "computers"
      self.abstract_class = true
      def system; "omg"; end
      def system=(val); self.developer = val; end
    end

    subklass = Class.new(klass)
    [klass, subklass].each(&:define_attribute_methods)

    computer = subklass.find(1)
    assert_equal "omg", computer.system

    computer.developer = 99
    assert_equal 99, computer.developer
  end

  test "on_the_fly_super_invokable_generated_attribute_methods_via_method_missing" do
    klass = new_topic_like_ar_class do
      def title
        super + "!"
      end
    end

    real_topic = topics(:first)
    assert_equal real_topic.title + "!", klass.find(real_topic.id).title
  end

  test "on-the-fly super-invokable generated attribute predicates via method_missing" do
    klass = new_topic_like_ar_class do
      def title?
        !super
      end
    end

    real_topic = topics(:first)
    assert_equal !real_topic.title?, klass.find(real_topic.id).title?
  end

  test "calling super when the parent does not define method raises NoMethodError" do
    klass = new_topic_like_ar_class do
      def some_method_that_is_not_on_super
        super
      end
    end

    assert_raise(NoMethodError) do
      klass.new.some_method_that_is_not_on_super
    end
  end

  test "attribute_method?" do
    assert @target.attribute_method?(:title)
    assert @target.attribute_method?(:title=)
    assert_not @target.attribute_method?(:wibble)
  end

  test "attribute_method? returns false if the table does not exist" do
    @target.table_name = "wibble"
    assert_not @target.attribute_method?(:title)
  end

  test "attribute_names on a new record" do
    model = @target.new

    assert_equal @target.column_names, model.attribute_names
  end

  test "attribute_names on a queried record" do
    model = @target.last!

    assert_equal @target.column_names, model.attribute_names
  end

  test "attribute_names with a custom select" do
    model = @target.select("id").last!

    assert_equal ["id"], model.attribute_names
    # Ensure other columns exist.
    assert_not_equal ["id"], @target.column_names
  end

  test "came_from_user?" do
    model = @target.first

    assert_not_predicate model, :id_came_from_user?
    model.id = "omg"
    assert_predicate model, :id_came_from_user?
  end

  test "accessed_fields" do
    model = @target.first

    assert_equal [], model.accessed_fields

    model.title

    assert_equal ["title"], model.accessed_fields
  end

  test "generated attribute methods ancestors have correct module" do
    mod = Topic.send(:generated_attribute_methods)
    assert_equal "Topic::GeneratedAttributeMethods", mod.inspect
  end

  test "read_attribute_before_type_cast with aliased attribute" do
    model = NumericData.new(new_bank_balance: "abcd")
    assert_equal "abcd", model.read_attribute_before_type_cast("new_bank_balance")
  end

  ToBeLoadedFirst = Class.new(ActiveRecord::Base) do
    self.table_name = "topics"
    alias_attribute :subject, :author_name
  end

  ToBeLoadedSecond = Class.new(ActiveRecord::Base) do
    self.table_name = "topics"
    alias_attribute :subject, :title
  end

  test "#alias_attribute override methods defined in parent models" do
    parent_model = Class.new(ActiveRecord::Base) do
      self.abstract_class = true

      def subject
        "Abstract Subject"
      end
    end

    subclass = Class.new(parent_model) do
      self.table_name = "topics"
      alias_attribute :subject, :title
    end

    obj = subclass.new
    obj.title = "hey"
    assert_equal("hey", obj.subject)
  end

  test "aliases to the same attribute name do not conflict with each other" do
    first_model_object = ToBeLoadedFirst.new(author_name: "author 1")
    assert_equal("author 1", first_model_object.subject)
    assert_equal([nil, "author 1"], first_model_object.subject_change)
    second_model_object = ToBeLoadedSecond.new(title: "foo")
    assert_equal("foo", second_model_object.subject)
    assert_equal([nil, "foo"], second_model_object.subject_change)
  end

  test "#alias_attribute with an overridden original method does not use the overridden original method" do
    class_with_deprecated_alias_attribute_behavior = Class.new(ActiveRecord::Base) do
      self.table_name = "topics"
      alias_attribute :subject, :title

      def title_was
        "overridden_title_was"
      end
    end

    obj = class_with_deprecated_alias_attribute_behavior.new
    obj.title = "hey"
    assert_equal("hey", obj.subject)
    assert_nil(obj.subject_was)
  end

  test "#alias_attribute with an overridden original method from a module does not use the overridden original method" do
    title_was_override = Module.new do
      def title_was
        "overridden_title_was"
      end
    end

    class_with_deprecated_alias_attribute_behavior_from_module = Class.new(ActiveRecord::Base) do
      self.table_name = "topics"
      include title_was_override
      alias_attribute :subject, :title
    end

    obj = class_with_deprecated_alias_attribute_behavior_from_module.new
    obj.title = "hey"
    assert_equal("hey", obj.subject)
    assert_nil(obj.subject_was)
  end

  ClassWithDeprecatedAliasAttributeBehaviorResolved = Class.new(ActiveRecord::Base) do
    self.table_name = "topics"
    alias_attribute :subject, :title

    def title_was
      "overridden_title_was"
    end

    def subject_was
      "overridden_subject_was"
    end
  end

  test "#alias_attribute with an overridden original method along with an overridden alias method uses the overridden alias method" do
    obj = ClassWithDeprecatedAliasAttributeBehaviorResolved.new
    obj.title = "hey"
    assert_equal("hey", obj.subject)
    assert_equal("overridden_subject_was", obj.subject_was)
  end

  test "#alias_attribute with an overridden original method along with an overridden alias method in a parent class uses the overridden alias method" do
    child_with_deprecated_behavior_resolved = Class.new(ClassWithDeprecatedAliasAttributeBehaviorResolved)

    obj = child_with_deprecated_behavior_resolved.new
    obj.title = "hey"
    assert_equal("hey", obj.subject)
    assert_equal("overridden_subject_was", obj.subject_was)
  end

  ParentWithAlias = Class.new(ActiveRecord::Base) do
    self.table_name = "topics"
    alias_attribute :parents_subject, :title
  end

  AbstractClassInBetween = Class.new(ParentWithAlias) do
    self.abstract_class = true
    alias_attribute :parents_subject, :title
  end

  ChildWithAnAliasFromAbstractClass = Class.new(AbstractClassInBetween) do
  end

  test "#alias_attribute with the same alias as parent doesn't issue a deprecation" do
    ParentWithAlias.new # eagerly generate parents alias methods
    obj = assert_not_deprecated(ActiveRecord.deprecator) do
      ChildWithAnAliasFromAbstractClass.new
    end
    obj.title = "hey"
    assert_equal("hey", obj.parents_subject)
  end

  test "#alias_attribute method on an abstract class is available on subclasses" do
    superclass = Class.new(ActiveRecord::Base) do
      self.abstract_class = true
      alias_attribute :id_value, :id
    end
    subclass = Class.new(superclass) { self.table_name = "topics" }

    object = subclass.build(id: 123_456)

    assert_equal 123_456, object.id_value
  end

  test "#alias_attribute with an _in_database method issues raises an error" do
    class_with_generated_attribute_method_target = Class.new(ActiveRecord::Base) do
      def self.name
        "ClassWithGeneratedAttributeMethodTarget"
      end

      self.table_name = "topics"

      alias_attribute :saved_title, :title_in_database
    end

    message = <<~MESSAGE.squish
      ClassWithGeneratedAttributeMethodTarget model aliases
      `title_in_database`, but `title_in_database` is not an attribute.
      Use `alias_method :saved_title, :title_in_database` or define the method manually.
    MESSAGE

    error = assert_raises(ArgumentError) do
      class_with_generated_attribute_method_target.new
    end

    assert_equal message, error.message
  end

  test "#alias_attribute with enum method raises an error" do
    class_with_enum_method_target = Class.new(ActiveRecord::Base) do
      def self.name
        "ClassWithEnumMethodTarget"
      end

      self.table_name = "books"

      attribute :status, :string

      enum :status, {
        pending: "0",
        completed: "1",
      }
      alias_attribute :is_pending?, :pending?
    end

    message = <<~MESSAGE.squish
      ClassWithEnumMethodTarget model aliases `pending?`, but `pending?` is not an attribute. Use `alias_method :is_pending?, :pending?` or define the method manually.
    MESSAGE

    error = assert_raises(ArgumentError) do
      class_with_enum_method_target.new
    end
    assert_equal message, error.message
  end

  test "#alias_attribute with an association method raises an error" do
    class_with_association_target = Class.new(ActiveRecord::Base) do
      def self.name
        "ClassWithAssociationTarget"
      end

      self.table_name = "books"

      belongs_to :author

      alias_attribute :written_by, :author
    end

    message = <<~MESSAGE.squish
      ClassWithAssociationTarget model aliases `author`, but `author` is not an attribute. Use `alias_method :written_by, :author` or define the method manually.
    MESSAGE

    error = assert_raises(ArgumentError) do
      class_with_association_target.new
    end
    assert_equal message, error.message
  end

  test "#alias_attribute method on a STI class is available on subclasses" do
    superclass = Class.new(ActiveRecord::Base) do
      self.table_name = "comments"
      alias_attribute :text, :body
    end

    subclass = Class.new(superclass) do
      self.abstract_class = true
    end

    subsubclass = Class.new(subclass)

    comment = subsubclass.build(body: "Text")
    assert_equal "Text", comment.text
  end

  test "#alias_attribute with a manually defined method raises an error" do
    class_with_aliased_manually_defined_method = Class.new(ActiveRecord::Base) do
      def self.name
        "ClassWithAliasedManuallyDefinedMethod"
      end

      self.table_name = "books"

      alias_attribute :print, :publish

      def publish
        "Publishing!"
      end
    end

    message = <<~MESSAGE.squish
      ClassWithAliasedManuallyDefinedMethod model aliases `publish`, but `publish` is not an attribute.
      Use `alias_method :print, :publish` or define the method manually.
    MESSAGE

    error = assert_raises(ArgumentError) do
      class_with_aliased_manually_defined_method.new
    end
    assert_equal message, error.message
  end

  private
    def new_topic_like_ar_class(&block)
      klass = Class.new(ActiveRecord::Base) do
        self.table_name = "topics"
        class_eval(&block)
      end

      assert_empty klass.send(:generated_attribute_methods).instance_methods(false)
      klass
    end

    def with_time_zone_aware_types(*types)
      old_types = ActiveRecord::Base.time_zone_aware_types
      ActiveRecord::Base.time_zone_aware_types = types
      yield
    ensure
      ActiveRecord::Base.time_zone_aware_types = old_types
    end

    def privatize(method_signature)
      @target.class_eval(<<-private_method, __FILE__, __LINE__ + 1)
        private
        def #{method_signature}
          "I'm private"
        end
      private_method
    end

    def with_temporary_connection_pool(&block)
      pool_config = ActiveRecord::Base.lease_connection.pool.pool_config
      new_pool = ActiveRecord::ConnectionAdapters::ConnectionPool.new(pool_config)

      pool_config.stub(:pool, new_pool, &block)
    end
end
