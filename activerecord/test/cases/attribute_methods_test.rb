require "cases/helper"
require 'models/minimalistic'
require 'models/developer'
require 'models/auto_id'
require 'models/boolean'
require 'models/computer'
require 'models/topic'
require 'models/company'
require 'models/category'
require 'models/reply'
require 'models/contact'
require 'models/keyboard'

class AttributeMethodsTest < ActiveRecord::TestCase
  include InTimeZone

  fixtures :topics, :developers, :companies, :computers

  def setup
    @old_matchers = ActiveRecord::Base.send(:attribute_method_matchers).dup
    @target = Class.new(ActiveRecord::Base)
    @target.table_name = 'topics'
  end

  teardown do
    ActiveRecord::Base.send(:attribute_method_matchers).clear
    ActiveRecord::Base.send(:attribute_method_matchers).concat(@old_matchers)
  end

  def test_attribute_for_inspect_string
    t = topics(:first)
    t.title = "The First Topic Now Has A Title With\nNewlines And More Than 50 Characters"

    assert_equal '"The First Topic Now Has A Title With\nNewlines And ..."', t.attribute_for_inspect(:title)
  end

  def test_attribute_for_inspect_date
    t = topics(:first)

    assert_equal %("#{t.written_on.to_s(:db)}"), t.attribute_for_inspect(:written_on)
  end

  def test_attribute_for_inspect_array
    t = topics(:first)
    t.content = [Object.new]

    assert_match %r(\[#<Object:0x[0-9a-f]+>\]), t.attribute_for_inspect(:content)
  end

  def test_attribute_for_inspect_long_array
    t = topics(:first)
    t.content = (1..11).to_a

    assert_equal "[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]", t.attribute_for_inspect(:content)
  end

  def test_attribute_present
    t = Topic.new
    t.title = "hello there!"
    t.written_on = Time.now
    t.author_name = ""
    assert t.attribute_present?("title")
    assert t.attribute_present?("written_on")
    assert !t.attribute_present?("content")
    assert !t.attribute_present?("author_name")
  end

  def test_attribute_present_with_booleans
    b1 = Boolean.new
    b1.value = false
    assert b1.attribute_present?(:value)

    b2 = Boolean.new
    b2.value = true
    assert b2.attribute_present?(:value)

    b3 = Boolean.new
    assert !b3.attribute_present?(:value)

    b4 = Boolean.new
    b4.value = false
    b4.save!
    assert Boolean.find(b4.id).attribute_present?(:value)
  end

  def test_caching_nil_primary_key
    klass = Class.new(Minimalistic)
    assert_called(klass, :reset_primary_key, returns: nil) do
      2.times { klass.primary_key }
    end
  end

  def test_attribute_keys_on_new_instance
    t = Topic.new
    assert_equal nil, t.title, "The topics table has a title column, so it should be nil"
    assert_raise(NoMethodError) { t.title2 }
  end

  def test_boolean_attributes
    assert !Topic.find(1).approved?
    assert Topic.find(2).approved?
  end

  def test_set_attributes
    topic = Topic.find(1)
    topic.attributes = { "title" => "Budget", "author_name" => "Jason" }
    topic.save
    assert_equal("Budget", topic.title)
    assert_equal("Jason", topic.author_name)
    assert_equal(topics(:first).author_email_address, Topic.find(1).author_email_address)
  end

  def test_set_attributes_without_hash
    topic = Topic.new
    assert_raise(ArgumentError) { topic.attributes = '' }
  end

  def test_integers_as_nil
    test = AutoId.create('value' => '')
    assert_nil AutoId.find(test.id).value
  end

  def test_set_attributes_with_block
    topic = Topic.new do |t|
      t.title       = "Budget"
      t.author_name = "Jason"
    end

    assert_equal("Budget", topic.title)
    assert_equal("Jason", topic.author_name)
  end

  def test_respond_to?
    topic = Topic.find(1)
    assert_respond_to topic, "title"
    assert_respond_to topic, "title?"
    assert_respond_to topic, "title="
    assert_respond_to topic, :title
    assert_respond_to topic, :title?
    assert_respond_to topic, :title=
    assert_respond_to topic, "author_name"
    assert_respond_to topic, "attribute_names"
    assert !topic.respond_to?("nothingness")
    assert !topic.respond_to?(:nothingness)
  end

  def test_respond_to_with_custom_primary_key
    keyboard = Keyboard.create
    assert_not_nil keyboard.key_number
    assert_equal keyboard.key_number, keyboard.id
    assert keyboard.respond_to?('key_number')
    assert keyboard.respond_to?('id')
  end

  def test_id_before_type_cast_with_custom_primary_key
    keyboard = Keyboard.create
    keyboard.key_number = '10'
    assert_equal '10', keyboard.id_before_type_cast
    assert_equal nil, keyboard.read_attribute_before_type_cast('id')
    assert_equal '10', keyboard.read_attribute_before_type_cast('key_number')
    assert_equal '10', keyboard.read_attribute_before_type_cast(:key_number)
  end

  # Syck calls respond_to? before actually calling initialize
  def test_respond_to_with_allocated_object
    klass = Class.new(ActiveRecord::Base) do
      self.table_name = 'topics'
    end

    topic = klass.allocate
    assert !topic.respond_to?("nothingness")
    assert !topic.respond_to?(:nothingness)
    assert_respond_to topic, "title"
    assert_respond_to topic, :title
  end

  # IRB inspects the return value of "MyModel.allocate".
  def test_allocated_object_can_be_inspected
    topic = Topic.allocate
    assert_equal "#<Topic not initialized>", topic.inspect
  end

  def test_array_content
    topic = Topic.new
    topic.content = %w( one two three )
    topic.save

    assert_equal(%w( one two three ), Topic.find(topic.id).content)
  end

  def test_read_attributes_before_type_cast
    category = Category.new({:name=>"Test category", :type => nil})
    category_attrs = {"name"=>"Test category", "id" => nil, "type" => nil, "categorizations_count" => nil}
    assert_equal category_attrs , category.attributes_before_type_cast
  end

  if current_adapter?(:Mysql2Adapter)
    def test_read_attributes_before_type_cast_on_boolean
      bool = Boolean.create!({ "value" => false })
      if RUBY_PLATFORM =~ /java/
        # JRuby will return the value before typecast as string
        assert_equal "0", bool.reload.attributes_before_type_cast["value"]
      else
        assert_equal 0, bool.reload.attributes_before_type_cast["value"]
      end
    end
  end

  def test_read_attributes_before_type_cast_on_datetime
    in_time_zone "Pacific Time (US & Canada)" do
      record = @target.new

      record.written_on = "345643456"
      assert_equal "345643456", record.written_on_before_type_cast
      assert_equal nil, record.written_on

      record.written_on = "2009-10-11 12:13:14"
      assert_equal "2009-10-11 12:13:14", record.written_on_before_type_cast
      assert_equal Time.zone.parse("2009-10-11 12:13:14"), record.written_on
      assert_equal ActiveSupport::TimeZone["Pacific Time (US & Canada)"], record.written_on.time_zone
    end
  end

  def test_read_attributes_after_type_cast_on_datetime
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

  def test_hash_content
    topic = Topic.new
    topic.content = { "one" => 1, "two" => 2 }
    topic.save

    assert_equal 2, Topic.find(topic.id).content["two"]

    topic.content_will_change!
    topic.content["three"] = 3
    topic.save

    assert_equal 3, Topic.find(topic.id).content["three"]
  end

  def test_update_array_content
    topic = Topic.new
    topic.content = %w( one two three )

    topic.content.push "four"
    assert_equal(%w( one two three four ), topic.content)

    topic.save

    topic = Topic.find(topic.id)
    topic.content << "five"
    assert_equal(%w( one two three four five ), topic.content)
  end

  def test_case_sensitive_attributes_hash
    # DB2 is not case-sensitive
    return true if current_adapter?(:DB2Adapter)

    assert_equal @loaded_fixtures['computers']['workstation'].to_hash, Computer.first.attributes
  end

  def test_attributes_without_primary_key
    klass = Class.new(ActiveRecord::Base) do
      self.table_name = 'developers_projects'
    end

    assert_equal klass.column_names, klass.new.attributes.keys
    assert_not klass.new.has_attribute?('id')
  end

  def test_hashes_not_mangled
    new_topic = { :title => "New Topic" }
    new_topic_values = { :title => "AnotherTopic" }

    topic = Topic.new(new_topic)
    assert_equal new_topic[:title], topic.title

    topic.attributes= new_topic_values
    assert_equal new_topic_values[:title], topic.title
  end

  def test_create_through_factory
    topic = Topic.create("title" => "New Topic")
    topicReloaded = Topic.find(topic.id)
    assert_equal(topic, topicReloaded)
  end

  def test_write_attribute
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

  def test_read_attribute
    topic = Topic.new
    topic.title = "Don't change the topic"
    assert_equal "Don't change the topic", topic.read_attribute("title")
    assert_equal "Don't change the topic", topic["title"]

    assert_equal "Don't change the topic", topic.read_attribute(:title)
    assert_equal "Don't change the topic", topic[:title]
  end

  def test_read_attribute_raises_missing_attribute_error_when_not_exists
    computer = Computer.select('id').first
    assert_raises(ActiveModel::MissingAttributeError) { computer[:developer] }
    assert_raises(ActiveModel::MissingAttributeError) { computer[:extendedWarranty] }
    assert_raises(ActiveModel::MissingAttributeError) { computer[:no_column_exists] = 'Hello!' }
    assert_nothing_raised { computer[:developer] = 'Hello!' }
  end

  def test_read_attribute_when_false
    topic = topics(:first)
    topic.approved = false
    assert !topic.approved?, "approved should be false"
    topic.approved = "false"
    assert !topic.approved?, "approved should be false"
  end

  def test_read_attribute_when_true
    topic = topics(:first)
    topic.approved = true
    assert topic.approved?, "approved should be true"
    topic.approved = "true"
    assert topic.approved?, "approved should be true"
  end

  def test_read_write_boolean_attribute
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

  def test_overridden_write_attribute
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

  def test_overridden_read_attribute
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

  def test_read_overridden_attribute
    topic = Topic.new(:title => 'a')
    def topic.title() 'b' end
    assert_equal 'a', topic[:title]
  end

  def test_query_attribute_string
    [nil, "", " "].each do |value|
      assert_equal false, Topic.new(:author_name => value).author_name?
    end

    assert_equal true, Topic.new(:author_name => "Name").author_name?
  end

  def test_query_attribute_number
    [nil, 0, "0"].each do |value|
      assert_equal false, Developer.new(:salary => value).salary?
    end

    assert_equal true, Developer.new(:salary => 1).salary?
    assert_equal true, Developer.new(:salary => "1").salary?
  end

  def test_query_attribute_boolean
    [nil, "", false, "false", "f", 0].each do |value|
      assert_equal false, Topic.new(:approved => value).approved?
    end

    [true, "true", "1", 1].each do |value|
      assert_equal true, Topic.new(:approved => value).approved?
    end
  end

  def test_query_attribute_with_custom_fields
    object = Company.find_by_sql(<<-SQL).first
      SELECT c1.*, c2.type as string_value, c2.rating as int_value
        FROM companies c1, companies c2
       WHERE c1.firm_id = c2.id
         AND c1.id = 2
    SQL

    assert_equal "Firm", object.string_value
    assert object.string_value?

    object.string_value = "  "
    assert !object.string_value?

    assert_equal 1, object.int_value.to_i
    assert object.int_value?

    object.int_value = "0"
    assert !object.int_value?
  end

  def test_non_attribute_access_and_assignment
    topic = Topic.new
    assert !topic.respond_to?("mumbo")
    assert_raise(NoMethodError) { topic.mumbo }
    assert_raise(NoMethodError) { topic.mumbo = 5 }
  end

  def test_undeclared_attribute_method_does_not_affect_respond_to_and_method_missing
    topic = @target.new(:title => 'Budget')
    assert topic.respond_to?('title')
    assert_equal 'Budget', topic.title
    assert !topic.respond_to?('title_hello_world')
    assert_raise(NoMethodError) { topic.title_hello_world }
  end

  def test_declared_prefixed_attribute_method_affects_respond_to_and_method_missing
    topic = @target.new(:title => 'Budget')
    %w(default_ title_).each do |prefix|
      @target.class_eval "def #{prefix}attribute(*args) args end"
      @target.attribute_method_prefix prefix

      meth = "#{prefix}title"
      assert topic.respond_to?(meth)
      assert_equal ['title'], topic.send(meth)
      assert_equal ['title', 'a'], topic.send(meth, 'a')
      assert_equal ['title', 1, 2, 3], topic.send(meth, 1, 2, 3)
    end
  end

  def test_declared_suffixed_attribute_method_affects_respond_to_and_method_missing
    %w(_default _title_default _it! _candidate= able?).each do |suffix|
      @target.class_eval "def attribute#{suffix}(*args) args end"
      @target.attribute_method_suffix suffix
      topic = @target.new(:title => 'Budget')

      meth = "title#{suffix}"
      assert topic.respond_to?(meth)
      assert_equal ['title'], topic.send(meth)
      assert_equal ['title', 'a'], topic.send(meth, 'a')
      assert_equal ['title', 1, 2, 3], topic.send(meth, 1, 2, 3)
    end
  end

  def test_declared_affixed_attribute_method_affects_respond_to_and_method_missing
    [['mark_', '_for_update'], ['reset_', '!'], ['default_', '_value?']].each do |prefix, suffix|
      @target.class_eval "def #{prefix}attribute#{suffix}(*args) args end"
      @target.attribute_method_affix({ :prefix => prefix, :suffix => suffix })
      topic = @target.new(:title => 'Budget')

      meth = "#{prefix}title#{suffix}"
      assert topic.respond_to?(meth)
      assert_equal ['title'], topic.send(meth)
      assert_equal ['title', 'a'], topic.send(meth, 'a')
      assert_equal ['title', 1, 2, 3], topic.send(meth, 1, 2, 3)
    end
  end

  def test_should_unserialize_attributes_for_frozen_records
    myobj = {:value1 => :value2}
    topic = Topic.create("content" => myobj)
    topic.freeze
    assert_equal myobj, topic.content
  end

  def test_typecast_attribute_from_select_to_false
    Topic.create(:title => 'Budget')
    # Oracle does not support boolean expressions in SELECT
    if current_adapter?(:OracleAdapter, :FbAdapter)
      topic = Topic.all.merge!(:select => "topics.*, 0 as is_test").first
    else
      topic = Topic.all.merge!(:select => "topics.*, 1=2 as is_test").first
    end
    assert !topic.is_test?
  end

  def test_typecast_attribute_from_select_to_true
    Topic.create(:title => 'Budget')
    # Oracle does not support boolean expressions in SELECT
    if current_adapter?(:OracleAdapter, :FbAdapter)
      topic = Topic.all.merge!(:select => "topics.*, 1 as is_test").first
    else
      topic = Topic.all.merge!(:select => "topics.*, 2=2 as is_test").first
    end
    assert topic.is_test?
  end

  def test_raises_dangerous_attribute_error_when_defining_activerecord_method_in_model
    %w(save create_or_update).each do |method|
      klass = Class.new ActiveRecord::Base
      klass.class_eval "def #{method}() 'defined #{method}' end"
      assert_raise ActiveRecord::DangerousAttributeError do
        klass.instance_method_already_implemented?(method)
      end
    end
  end

  def test_converted_values_are_returned_after_assignment
    developer = Developer.new(name: 1337, salary: "50000")

    assert_equal "50000", developer.salary_before_type_cast
    assert_equal 1337, developer.name_before_type_cast

    assert_equal 50000, developer.salary
    assert_equal "1337", developer.name

    developer.save!

    assert_equal 50000, developer.salary
    assert_equal "1337", developer.name
  end

  def test_write_nil_to_time_attributes
    in_time_zone "Pacific Time (US & Canada)" do
      record = @target.new
      record.written_on = nil
      assert_nil record.written_on
    end
  end

  def test_write_time_to_date_attributes
    in_time_zone "Pacific Time (US & Canada)" do
      record = @target.new
      record.last_read = Time.utc(2010, 1, 1, 10)
      assert_equal Date.civil(2010, 1, 1), record.last_read
    end
  end

  def test_time_attributes_are_retrieved_in_current_time_zone
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

  def test_setting_time_zone_aware_attribute_to_utc
    in_time_zone "Pacific Time (US & Canada)" do
      utc_time = Time.utc(2008, 1, 1)
      record   = @target.new
      record.written_on = utc_time
      assert_equal utc_time, record.written_on
      assert_equal ActiveSupport::TimeZone["Pacific Time (US & Canada)"], record.written_on.time_zone
      assert_equal Time.utc(2007, 12, 31, 16), record.written_on.time
    end
  end

  def test_setting_time_zone_aware_attribute_in_other_time_zone
    utc_time = Time.utc(2008, 1, 1)
    cst_time = utc_time.in_time_zone("Central Time (US & Canada)")
    in_time_zone "Pacific Time (US & Canada)" do
      record   = @target.new
      record.written_on = cst_time
      assert_equal utc_time, record.written_on
      assert_equal ActiveSupport::TimeZone["Pacific Time (US & Canada)"], record.written_on.time_zone
      assert_equal Time.utc(2007, 12, 31, 16), record.written_on.time
    end
  end

  def test_setting_time_zone_aware_read_attribute
    utc_time = Time.utc(2008, 1, 1)
    cst_time = utc_time.in_time_zone("Central Time (US & Canada)")
    in_time_zone "Pacific Time (US & Canada)" do
      record = @target.create(:written_on => cst_time).reload
      assert_equal utc_time, record[:written_on]
      assert_equal ActiveSupport::TimeZone["Pacific Time (US & Canada)"], record[:written_on].time_zone
      assert_equal Time.utc(2007, 12, 31, 16), record[:written_on].time
    end
  end

  def test_setting_time_zone_aware_attribute_with_string
    utc_time = Time.utc(2008, 1, 1)
    (-11..13).each do |timezone_offset|
      time_string = utc_time.in_time_zone(timezone_offset).to_s
      in_time_zone "Pacific Time (US & Canada)" do
        record   = @target.new
        record.written_on = time_string
        assert_equal Time.zone.parse(time_string), record.written_on
        assert_equal ActiveSupport::TimeZone["Pacific Time (US & Canada)"], record.written_on.time_zone
        assert_equal Time.utc(2007, 12, 31, 16), record.written_on.time
      end
    end
  end

  def test_time_zone_aware_attribute_saved
    in_time_zone 1 do
      record = @target.create(:written_on => '2012-02-20 10:00')

      record.written_on = '2012-02-20 09:00'
      record.save
      assert_equal Time.zone.local(2012, 02, 20, 9), record.reload.written_on
    end
  end

  def test_setting_time_zone_aware_attribute_to_blank_string_returns_nil
    in_time_zone "Pacific Time (US & Canada)" do
      record   = @target.new
      record.written_on = ' '
      assert_nil record.written_on
      assert_nil record[:written_on]
    end
  end

  def test_setting_time_zone_aware_attribute_interprets_time_zone_unaware_string_in_time_zone
    time_string = 'Tue Jan 01 00:00:00 2008'
    (-11..13).each do |timezone_offset|
      in_time_zone timezone_offset do
        record   = @target.new
        record.written_on = time_string
        assert_equal Time.zone.parse(time_string), record.written_on
        assert_equal ActiveSupport::TimeZone[timezone_offset], record.written_on.time_zone
        assert_equal Time.utc(2008, 1, 1), record.written_on.time
      end
    end
  end

  def test_setting_time_zone_aware_datetime_in_current_time_zone
    utc_time = Time.utc(2008, 1, 1)
    in_time_zone "Pacific Time (US & Canada)" do
      record   = @target.new
      record.written_on = utc_time.in_time_zone
      assert_equal utc_time, record.written_on
      assert_equal ActiveSupport::TimeZone["Pacific Time (US & Canada)"], record.written_on.time_zone
      assert_equal Time.utc(2007, 12, 31, 16), record.written_on.time
    end
  end

  def test_yaml_dumping_record_with_time_zone_aware_attribute
    in_time_zone "Pacific Time (US & Canada)" do
      record = Topic.new(id: 1)
      record.written_on = "Jan 01 00:00:00 2014"
      assert_equal record, YAML.load(YAML.dump(record))
    end
  end

  def test_setting_time_zone_aware_time_in_current_time_zone
    in_time_zone "Pacific Time (US & Canada)" do
      record = @target.new
      time_string = "10:00:00"
      expected_time = Time.zone.parse("2000-01-01 #{time_string}")

      record.bonus_time = time_string
      assert_equal expected_time, record.bonus_time
      assert_equal ActiveSupport::TimeZone["Pacific Time (US & Canada)"], record.bonus_time.time_zone

      record.bonus_time = ''
      assert_nil record.bonus_time
    end
  end

  def test_setting_time_zone_aware_time_with_dst
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

  def test_removing_time_zone_aware_types
    with_time_zone_aware_types(:datetime) do
      in_time_zone "Pacific Time (US & Canada)" do
        record = @target.new(bonus_time: "10:00:00")
        expected_time = Time.utc(2000, 01, 01, 10)

        assert_equal expected_time, record.bonus_time
        assert record.bonus_time.utc?
      end
    end
  end

  def test_time_zone_aware_attributes_dont_recurse_infinitely_on_invalid_values
    in_time_zone "Pacific Time (US & Canada)" do
      record = @target.new(bonus_time: [])
      assert_equal nil, record.bonus_time
    end
  end

  def test_setting_time_zone_conversion_for_attributes_should_write_value_on_class_variable
    Topic.skip_time_zone_conversion_for_attributes = [:field_a]
    Minimalistic.skip_time_zone_conversion_for_attributes = [:field_b]

    assert_equal [:field_a], Topic.skip_time_zone_conversion_for_attributes
    assert_equal [:field_b], Minimalistic.skip_time_zone_conversion_for_attributes
  end

  def test_read_attributes_respect_access_control
    privatize("title")

    topic = @target.new(:title => "The pros and cons of programming naked.")
    assert !topic.respond_to?(:title)
    exception = assert_raise(NoMethodError) { topic.title }
    assert exception.message.include?("private method")
    assert_equal "I'm private", topic.send(:title)
  end

  def test_write_attributes_respect_access_control
    privatize("title=(value)")

    topic = @target.new
    assert !topic.respond_to?(:title=)
    exception = assert_raise(NoMethodError) { topic.title = "Pants"}
    assert exception.message.include?("private method")
    topic.send(:title=, "Very large pants")
  end

  def test_question_attributes_respect_access_control
    privatize("title?")

    topic = @target.new(:title => "Isaac Newton's pants")
    assert !topic.respond_to?(:title?)
    exception = assert_raise(NoMethodError) { topic.title? }
    assert exception.message.include?("private method")
    assert topic.send(:title?)
  end

  def test_bulk_update_respects_access_control
    privatize("title=(value)")

    assert_raise(ActiveRecord::UnknownAttributeError) { @target.new(:title => "Rants about pants") }
    assert_raise(ActiveRecord::UnknownAttributeError) { @target.new.attributes = { :title => "Ants in pants" } }
  end

  def test_bulk_update_raise_unknown_attribute_error
    error = assert_raises(ActiveRecord::UnknownAttributeError) {
      Topic.new(hello: "world")
    }
    assert_instance_of Topic, error.record
    assert_equal "hello", error.attribute
    assert_equal "unknown attribute 'hello' for Topic.", error.message
  end

  def test_methods_override_in_multi_level_subclass
    klass = Class.new(Developer) do
      def name
        "dev:#{read_attribute(:name)}"
      end
    end

    2.times { klass = Class.new klass }
    dev = klass.new(name: 'arthurnn')
    dev.save!
    assert_equal 'dev:arthurnn', dev.reload.name
  end

  def test_global_methods_are_overwritten
    klass = Class.new(ActiveRecord::Base) do
      self.table_name = 'computers'
    end

    assert !klass.instance_method_already_implemented?(:system)
    computer = klass.new
    assert_nil computer.system
  end

  def test_global_methods_are_overwritten_when_subclassing
    klass = Class.new(ActiveRecord::Base) { self.abstract_class = true }

    subklass = Class.new(klass) do
      self.table_name = 'computers'
    end

    assert !klass.instance_method_already_implemented?(:system)
    assert !subklass.instance_method_already_implemented?(:system)
    computer = subklass.new
    assert_nil computer.system
  end

  def test_instance_method_should_be_defined_on_the_base_class
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

  def test_read_attribute_with_nil_should_not_asplode
    assert_equal nil, Topic.new.read_attribute(nil)
  end

  # If B < A, and A defines an accessor for 'foo', we don't want to override
  # that by defining a 'foo' method in the generated methods module for B.
  # (That module will be inserted between the two, e.g. [B, <GeneratedAttributes>, A].)
  def test_inherited_custom_accessors
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

  def test_inherited_custom_accessors_with_reserved_names
    klass = Class.new(ActiveRecord::Base) do
      self.table_name = 'computers'
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

  def test_on_the_fly_super_invokable_generated_attribute_methods_via_method_missing
    klass = new_topic_like_ar_class do
      def title
        super + '!'
      end
    end

    real_topic = topics(:first)
    assert_equal real_topic.title + '!', klass.find(real_topic.id).title
  end

  def test_on_the_fly_super_invokable_generated_predicate_attribute_methods_via_method_missing
    klass = new_topic_like_ar_class do
      def title?
        !super
      end
    end

    real_topic = topics(:first)
    assert_equal !real_topic.title?, klass.find(real_topic.id).title?
  end

  def test_calling_super_when_parent_does_not_define_method_raises_error
    klass = new_topic_like_ar_class do
      def some_method_that_is_not_on_super
        super
      end
    end

    assert_raise(NoMethodError) do
      klass.new.some_method_that_is_not_on_super
    end
  end

  def test_attribute_method?
    assert @target.attribute_method?(:title)
    assert @target.attribute_method?(:title=)
    assert_not @target.attribute_method?(:wibble)
  end

  def test_attribute_method_returns_false_if_table_does_not_exist
    @target.table_name = 'wibble'
    assert_not @target.attribute_method?(:title)
  end

  def test_attribute_names_on_new_record
    model = @target.new

    assert_equal @target.column_names, model.attribute_names
  end

  def test_attribute_names_on_queried_record
    model = @target.last!

    assert_equal @target.column_names, model.attribute_names
  end

  def test_attribute_names_with_custom_select
    model = @target.select('id').last!

    assert_equal ['id'], model.attribute_names
    # Sanity check, make sure other columns exist
    assert_not_equal ['id'], @target.column_names
  end

  def test_came_from_user
    model = @target.first

    assert_not model.id_came_from_user?
    model.id = "omg"
    assert model.id_came_from_user?
  end

  def test_accessed_fields
    model = @target.first

    assert_equal [], model.accessed_fields

    model.title

    assert_equal ["title"], model.accessed_fields
  end

  private

  def new_topic_like_ar_class(&block)
    klass = Class.new(ActiveRecord::Base) do
      self.table_name = 'topics'
      class_eval(&block)
    end

    assert_empty klass.generated_attribute_methods.instance_methods(false)
    klass
  end

  def with_time_zone_aware_types(*types)
    old_types = ActiveRecord::Base.time_zone_aware_types
    ActiveRecord::Base.time_zone_aware_types = types
    yield
  ensure
    ActiveRecord::Base.time_zone_aware_types = old_types
  end

  def cached_columns
    Topic.columns.map(&:name)
  end

  def time_related_columns_on_topic
    Topic.columns.select { |c| [:time, :date, :datetime, :timestamp].include?(c.type) }
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
