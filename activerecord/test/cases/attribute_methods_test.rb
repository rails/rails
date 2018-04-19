# frozen_string_literal: true

require "cases/helper"
require "models/minimalistic"
require "models/developer"
require "models/auto_id"
require "models/boolean"
require "models/computer"
require "models/topic"
require "models/company"
require "models/category"
require "models/reply"
require "models/contact"
require "models/keyboard"

class AttributeMethodsTest < ActiveRecord::TestCase
  include InTimeZone

  fixtures :topics, :developers, :companies, :computers

  def setup
    @old_matchers = ActiveRecord::Base.send(:attribute_method_matchers).dup
    @target = Class.new(ActiveRecord::Base)
    @target.table_name = "topics"
  end

  teardown do
    ActiveRecord::Base.send(:attribute_method_matchers).clear
    ActiveRecord::Base.send(:attribute_method_matchers).concat(@old_matchers)
  end

  test "attribute_for_inspect with a string" do
    t = topics(:first)
    t.title = "The First Topic Now Has A Title With\nNewlines And More Than 50 Characters"

    assert_equal '"The First Topic Now Has A Title With\nNewlines And ..."', t.attribute_for_inspect(:title)
  end

  test "attribute_for_inspect with a date" do
    t = topics(:first)

    assert_equal %("#{t.written_on.to_s(:db)}"), t.attribute_for_inspect(:written_on)
  end

  test "attribute_for_inspect with an array" do
    t = topics(:first)
    t.content = [Object.new]

    assert_match %r(\[#<Object:0x[0-9a-f]+>\]), t.attribute_for_inspect(:content)
  end

  test "attribute_for_inspect with a long array" do
    t = topics(:first)
    t.content = (1..11).to_a

    assert_equal "[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]", t.attribute_for_inspect(:content)
  end

  test "attribute_present" do
    t = Topic.new
    t.title = "hello there!"
    t.written_on = Time.now
    t.author_name = ""
    assert t.attribute_present?("title")
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
    assert_called(klass, :reset_primary_key, returns: nil) do
      2.times { klass.primary_key }
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

  # Syck calls respond_to? before actually calling initialize.
  test "respond_to? with an allocated object" do
    klass = Class.new(ActiveRecord::Base) do
      self.table_name = "topics"
    end

    topic = klass.allocate
    assert_not_respond_to topic, "nothingness"
    assert_not_respond_to topic, :nothingness
    assert_respond_to topic, "title"
    assert_respond_to topic, :title
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

  if current_adapter?(:Mysql2Adapter)
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

  test "read attributes_after_type_cast on a date" do
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
    # DB2 is not case-sensitive.
    return true if current_adapter?(:DB2Adapter)

    assert_equal @loaded_fixtures["computers"]["workstation"].to_hash, Computer.first.attributes
  end

  test "attributes without primary key" do
    klass = Class.new(ActiveRecord::Base) do
      self.table_name = "developers_projects"
    end

    assert_equal klass.column_names, klass.new.attributes.keys
    assert_not klass.new.has_attribute?("id")
  end

  test "hashes are not mangled" do
    new_topic = { title: "New Topic" }
    new_topic_values = { title: "AnotherTopic" }

    topic = Topic.new(new_topic)
    assert_equal new_topic[:title], topic.title

    topic.attributes = new_topic_values
    assert_equal new_topic_values[:title], topic.title
  end

  test "create through factory" do
    topic = Topic.create(title: "New Topic")
    topicReloaded = Topic.find(topic.id)
    assert_equal(topic, topicReloaded)
  end

  test "write_attribute" do
    topic = Topic.new
    topic.send(:write_attribute, :title, "Still another topic")
    assert_equal "Still another topic", topic.title

    topic[:title] = "Still another topic: part 2"
    assert_equal "Still another topic: part 2", topic.title

    topic.send(:write_attribute, "title", "Still another topic: part 3")
    assert_equal "Still another topic: part 3", topic.title

    topic["title"] = "Still another topic: part 4"
    assert_equal "Still another topic: part 4", topic.title
  end

  test "write_attribute can write aliased attributes as well" do
    topic = Topic.new(title: "Don't change the topic")
    topic.write_attribute :heading, "New topic"

    assert_equal "New topic", topic.title
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

  test "read_attribute raises ActiveModel::MissingAttributeError when the attribute does not exist" do
    computer = Computer.select("id").first
    assert_raises(ActiveModel::MissingAttributeError) { computer[:developer] }
    assert_raises(ActiveModel::MissingAttributeError) { computer[:extendedWarranty] }
    assert_raises(ActiveModel::MissingAttributeError) { computer[:no_column_exists] = "Hello!" }
    assert_nothing_raised { computer[:developer] = "Hello!" }
  end

  test "read_attribute when false" do
    topic = topics(:first)
    topic.approved = false
    assert !topic.approved?, "approved should be false"
    topic.approved = "false"
    assert !topic.approved?, "approved should be false"
  end

  test "read_attribute when true" do
    topic = topics(:first)
    topic.approved = true
    assert topic.approved?, "approved should be true"
    topic.approved = "true"
    assert topic.approved?, "approved should be true"
  end

  test "boolean attributes writing and reading" do
    topic = Topic.new
    topic.approved = "false"
    assert !topic.approved?, "approved should be false"

    topic.approved = "false"
    assert !topic.approved?, "approved should be false"

    topic.approved = "true"
    assert topic.approved?, "approved should be true"

    topic.approved = "true"
    assert topic.approved?, "approved should be true"
  end

  test "overridden write_attribute" do
    topic = Topic.new
    def topic.write_attribute(attr_name, value)
      super(attr_name, value.downcase)
    end

    topic.send(:write_attribute, :title, "Yet another topic")
    assert_equal "yet another topic", topic.title

    topic[:title] = "Yet another topic: part 2"
    assert_equal "yet another topic: part 2", topic.title

    topic.send(:write_attribute, "title", "Yet another topic: part 3")
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

  test "string attribute predicate" do
    [nil, "", " "].each do |value|
      assert_equal false, Topic.new(author_name: value).author_name?
    end

    assert_equal true, Topic.new(author_name: "Name").author_name?
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

  test "custom field attribute predicate" do
    object = Company.find_by_sql(<<-SQL).first
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
      assert_equal ["title"], topic.send(meth)
      assert_equal ["title", "a"], topic.send(meth, "a")
      assert_equal ["title", 1, 2, 3], topic.send(meth, 1, 2, 3)
    end
  end

  test "declared suffixed attribute method affects respond_to? and method_missing" do
    %w(_default _title_default _it! _candidate= able?).each do |suffix|
      @target.class_eval "def attribute#{suffix}(*args) args end"
      @target.attribute_method_suffix suffix
      topic = @target.new(title: "Budget")

      meth = "title#{suffix}"
      assert_respond_to topic, meth
      assert_equal ["title"], topic.send(meth)
      assert_equal ["title", "a"], topic.send(meth, "a")
      assert_equal ["title", 1, 2, 3], topic.send(meth, 1, 2, 3)
    end
  end

  test "declared affixed attribute method affects respond_to? and method_missing" do
    [["mark_", "_for_update"], ["reset_", "!"], ["default_", "_value?"]].each do |prefix, suffix|
      @target.class_eval "def #{prefix}attribute#{suffix}(*args) args end"
      @target.attribute_method_affix(prefix: prefix, suffix: suffix)
      topic = @target.new(title: "Budget")

      meth = "#{prefix}title#{suffix}"
      assert_respond_to topic, meth
      assert_equal ["title"], topic.send(meth)
      assert_equal ["title", "a"], topic.send(meth, "a")
      assert_equal ["title", 1, 2, 3], topic.send(meth, 1, 2, 3)
    end
  end

  test "should unserialize attributes for frozen records" do
    myobj = { value1: :value2 }
    topic = Topic.create(content: myobj)
    topic.freeze
    assert_equal myobj, topic.content
  end

  test "typecast attribute from select to false" do
    Topic.create(title: "Budget")
    # Oracle does not support boolean expressions in SELECT.
    if current_adapter?(:OracleAdapter, :FbAdapter)
      topic = Topic.all.merge!(select: "topics.*, 0 as is_test").first
    else
      topic = Topic.all.merge!(select: "topics.*, 1=2 as is_test").first
    end
    assert_not_predicate topic, :is_test?
  end

  test "typecast attribute from select to true" do
    Topic.create(title: "Budget")
    # Oracle does not support boolean expressions in SELECT.
    if current_adapter?(:OracleAdapter, :FbAdapter)
      topic = Topic.all.merge!(select: "topics.*, 1 as is_test").first
    else
      topic = Topic.all.merge!(select: "topics.*, 2=2 as is_test").first
    end
    assert_predicate topic, :is_test?
  end

  test "raises ActiveRecord::DangerousAttributeError when defining an AR method in a model" do
    %w(save create_or_update).each do |method|
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
      assert_equal record, YAML.load(YAML.dump(record))
    end
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
    in_time_zone "Pacific Time (US & Canada)" do
      record = @target.new(bonus_time: [])
      assert_nil record.bonus_time
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
    assert_equal "unknown attribute 'hello' for Topic.", error.message
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

  test "define_attribute_method works with both symbol and string" do
    klass = Class.new(ActiveRecord::Base)

    assert_nothing_raised { klass.define_attribute_method(:foo) }
    assert_nothing_raised { klass.define_attribute_method("bar") }
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
    # Sanity check, make sure other columns exist.
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

  test "generated attribute methods ancestors have correct class" do
    mod = Topic.send(:generated_attribute_methods)
    assert_match %r(GeneratedAttributeMethods), mod.inspect
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
end
