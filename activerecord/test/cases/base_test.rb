require "cases/helper"
require 'models/author'
require 'models/topic'
require 'models/reply'
require 'models/category'
require 'models/company'
require 'models/customer'
require 'models/developer'
require 'models/project'
require 'models/default'
require 'models/auto_id'
require 'models/column_name'
require 'models/subscriber'
require 'models/keyboard'
require 'models/post'
require 'models/comment'
require 'models/minimalistic'
require 'models/warehouse_thing'
require 'models/parrot'
require 'rexml/document'

class Category < ActiveRecord::Base; end
class Categorization < ActiveRecord::Base; end
class Smarts < ActiveRecord::Base; end
class CreditCard < ActiveRecord::Base
  class PinNumber < ActiveRecord::Base
    class CvvCode < ActiveRecord::Base; end
    class SubCvvCode < CvvCode; end
  end
  class SubPinNumber < PinNumber; end
  class Brand < Category; end
end
class MasterCreditCard < ActiveRecord::Base; end
class Post < ActiveRecord::Base; end
class Computer < ActiveRecord::Base; end
class NonExistentTable < ActiveRecord::Base; end
class TestOracleDefault < ActiveRecord::Base; end

class LoosePerson < ActiveRecord::Base
  self.table_name = 'people'
  self.abstract_class = true
  attr_protected :credit_rating, :administrator
end

class LooseDescendant < LoosePerson
  attr_protected :phone_number
end

class LooseDescendantSecond< LoosePerson
  attr_protected :phone_number
  attr_protected :name
end

class TightPerson < ActiveRecord::Base
  self.table_name = 'people'
  attr_accessible :name, :address
end

class TightDescendant < TightPerson
  attr_accessible :phone_number
end

class ReadonlyTitlePost < Post
  attr_readonly :title
end

class Booleantest < ActiveRecord::Base; end

class Task < ActiveRecord::Base
  attr_protected :starting
end

class TopicWithProtectedContentAndAccessibleAuthorName < ActiveRecord::Base
  self.table_name = 'topics'
  attr_accessible :author_name
  attr_protected  :content
end

class BasicsTest < ActiveRecord::TestCase
  fixtures :topics, :companies, :developers, :projects, :computers, :accounts, :minimalistics, 'warehouse-things', :authors, :categorizations, :categories, :posts

  def test_table_exists
    assert !NonExistentTable.table_exists?
    assert Topic.table_exists?
  end

  def test_set_attributes
    topic = Topic.find(1)
    topic.attributes = { "title" => "Budget", "author_name" => "Jason" }
    topic.save
    assert_equal("Budget", topic.title)
    assert_equal("Jason", topic.author_name)
    assert_equal(topics(:first).author_email_address, Topic.find(1).author_email_address)
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
    assert topic.respond_to?("title")
    assert topic.respond_to?("title?")
    assert topic.respond_to?("title=")
    assert topic.respond_to?(:title)
    assert topic.respond_to?(:title?)
    assert topic.respond_to?(:title=)
    assert topic.respond_to?("author_name")
    assert topic.respond_to?("attribute_names")
    assert !topic.respond_to?("nothingness")
    assert !topic.respond_to?(:nothingness)
  end

  def test_array_content
    topic = Topic.new
    topic.content = %w( one two three )
    topic.save

    assert_equal(%w( one two three ), Topic.find(topic.id).content)
  end

  def test_read_attributes_before_type_cast
    category = Category.new({:name=>"Test categoty", :type => nil})
    category_attrs = {"name"=>"Test categoty", "type" => nil, "categorizations_count" => nil}
    assert_equal category_attrs , category.attributes_before_type_cast
  end

  if current_adapter?(:MysqlAdapter)
    def test_read_attributes_before_type_cast_on_boolean
      bool = Booleantest.create({ "value" => false })
      assert_equal "0", bool.reload.attributes_before_type_cast["value"]
    end
  end

  def test_read_attributes_before_type_cast_on_datetime
    developer = Developer.find(:first)
    assert_equal developer.created_at.to_s(:db) , developer.attributes_before_type_cast["created_at"]
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

    assert_equal @loaded_fixtures['computers']['workstation'].to_hash, Computer.find(:first).attributes
  end

  def test_create
    topic = Topic.new
    topic.title = "New Topic"
    topic.save
    topic_reloaded = Topic.find(topic.id)
    assert_equal("New Topic", topic_reloaded.title)
  end

  def test_save!
    topic = Topic.new(:title => "New Topic")
    assert topic.save!

    reply = Reply.new
    assert_raise(ActiveRecord::RecordInvalid) { reply.save! }
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
    assert_nothing_raised { Minimalistic.create!(:id => 2) }
  end

  def test_hashes_not_mangled
    new_topic = { :title => "New Topic" }
    new_topic_values = { :title => "AnotherTopic" }

    topic = Topic.new(new_topic)
    assert_equal new_topic[:title], topic.title

    topic.attributes= new_topic_values
    assert_equal new_topic_values[:title], topic.title
  end

  def test_create_many
    topics = Topic.create([ { "title" => "first" }, { "title" => "second" }])
    assert_equal 2, topics.size
    assert_equal "first", topics.first.title
  end

  def test_create_columns_not_equal_attributes
    topic = Topic.new
    topic.title = 'Another New Topic'
    topic.send :write_attribute, 'does_not_exist', 'test'
    assert_nothing_raised { topic.save }
  end

  def test_create_through_factory
    topic = Topic.create("title" => "New Topic")
    topicReloaded = Topic.find(topic.id)
    assert_equal(topic, topicReloaded)
  end

  def test_create_through_factory_with_block
    topic = Topic.create("title" => "New Topic") do |t|
      t.author_name = "David"
    end
    topicReloaded = Topic.find(topic.id)
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

  def test_update
    topic = Topic.new
    topic.title = "Another New Topic"
    topic.written_on = "2003-12-12 23:23:00"
    topic.save
    topicReloaded = Topic.find(topic.id)
    assert_equal("Another New Topic", topicReloaded.title)

    topicReloaded.title = "Updated topic"
    topicReloaded.save

    topicReloadedAgain = Topic.find(topic.id)

    assert_equal("Updated topic", topicReloadedAgain.title)
  end

  def test_update_columns_not_equal_attributes
    topic = Topic.new
    topic.title = "Still another topic"
    topic.save

    topicReloaded = Topic.find(topic.id)
    topicReloaded.title = "A New Topic"
    topicReloaded.send :write_attribute, 'does_not_exist', 'test'
    assert_nothing_raised { topicReloaded.save }
  end

  def test_update_for_record_with_only_primary_key
    minimalistic = minimalistics(:first)
    assert_nothing_raised { minimalistic.save }
  end

  def test_write_attribute
    topic = Topic.new
    topic.send(:write_attribute, :title, "Still another topic")
    assert_equal "Still another topic", topic.title

    topic.send(:write_attribute, "title", "Still another topic: part 2")
    assert_equal "Still another topic: part 2", topic.title
  end

  def test_read_attribute
    topic = Topic.new
    topic.title = "Don't change the topic"
    assert_equal "Don't change the topic", topic.send(:read_attribute, "title")
    assert_equal "Don't change the topic", topic["title"]

    assert_equal "Don't change the topic", topic.send(:read_attribute, :title)
    assert_equal "Don't change the topic", topic[:title]
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
    # puts ""
    # puts "New Topic"
    # puts topic.inspect
    topic.approved = "false"
    # puts "Expecting false"
    # puts topic.inspect
    assert !topic.approved?, "approved should be false"
    topic.approved = "false"
    # puts "Expecting false"
    # puts topic.inspect
    assert !topic.approved?, "approved should be false"
    topic.approved = "true"
    # puts "Expecting true"
    # puts topic.inspect
    assert topic.approved?, "approved should be true"
    topic.approved = "true"
    # puts "Expecting true"
    # puts topic.inspect
    assert topic.approved?, "approved should be true"
    # puts ""
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
      SELECT c1.*, c2.ruby_type as string_value, c2.rating as int_value
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


  def test_reader_for_invalid_column_names
    Topic.send(:define_read_method, "mumub-jumbo".to_sym, "mumub-jumbo", nil)
    assert !Topic.generated_methods.include?("mumub-jumbo")
  end

  def test_non_attribute_access_and_assignment
    topic = Topic.new
    assert !topic.respond_to?("mumbo")
    assert_raise(NoMethodError) { topic.mumbo }
    assert_raise(NoMethodError) { topic.mumbo = 5 }
  end

  def test_preserving_date_objects
    if current_adapter?(:SybaseAdapter, :OracleAdapter)
      # Sybase ctlib does not (yet?) support the date type; use datetime instead.
      # Oracle treats all dates/times as Time.
      assert_kind_of(
        Time, Topic.find(1).last_read,
        "The last_read attribute should be of the Time class"
      )
    else
      assert_kind_of(
        Date, Topic.find(1).last_read,
        "The last_read attribute should be of the Date class"
      )
    end
  end

  def test_preserving_time_objects
    assert_kind_of(
      Time, Topic.find(1).bonus_time,
      "The bonus_time attribute should be of the Time class"
    )

    assert_kind_of(
      Time, Topic.find(1).written_on,
      "The written_on attribute should be of the Time class"
    )

    # For adapters which support microsecond resolution.
    if current_adapter?(:PostgreSQLAdapter)
      assert_equal 11, Topic.find(1).written_on.sec
      assert_equal 223300, Topic.find(1).written_on.usec
      assert_equal 9900, Topic.find(2).written_on.usec
    end
  end

  def test_custom_mutator
    topic = Topic.find(1)
    # This mutator is protected in the class definition
    topic.send(:approved=, true)
    assert topic.instance_variable_get("@custom_approved")
  end

  def test_delete
    topic = Topic.find(1)
    assert_equal topic, topic.delete, 'topic.delete did not return self'
    assert topic.frozen?, 'topic not frozen after delete'
    assert_raise(ActiveRecord::RecordNotFound) { Topic.find(topic.id) }
  end

  def test_delete_doesnt_run_callbacks
    Topic.find(1).delete
    assert_not_nil Topic.find(2)
  end

  def test_destroy
    topic = Topic.find(1)
    assert_equal topic, topic.destroy, 'topic.destroy did not return self'
    assert topic.frozen?, 'topic not frozen after destroy'
    assert_raise(ActiveRecord::RecordNotFound) { Topic.find(topic.id) }
  end

  def test_record_not_found_exception
    assert_raise(ActiveRecord::RecordNotFound) { topicReloaded = Topic.find(99999) }
  end

  def test_initialize_with_attributes
    topic = Topic.new({
      "title" => "initialized from attributes", "written_on" => "2003-12-12 23:23"
    })

    assert_equal("initialized from attributes", topic.title)
  end

  def test_initialize_with_invalid_attribute
    begin
      topic = Topic.new({ "title" => "test",
        "last_read(1i)" => "2005", "last_read(2i)" => "2", "last_read(3i)" => "31"})
    rescue ActiveRecord::MultiparameterAssignmentErrors => ex
      assert_equal(1, ex.errors.size)
      assert_equal("last_read", ex.errors[0].attribute)
    end
  end

  def test_load
    topics = Topic.find(:all, :order => 'id')
    assert_equal(4, topics.size)
    assert_equal(topics(:first).title, topics.first.title)
  end

  def test_load_with_condition
    topics = Topic.find(:all, :conditions => "author_name = 'Mary'")

    assert_equal(1, topics.size)
    assert_equal(topics(:second).title, topics.first.title)
  end

  def test_table_name_guesses
    classes = [Category, Smarts, CreditCard, CreditCard::PinNumber, CreditCard::PinNumber::CvvCode, CreditCard::SubPinNumber, CreditCard::Brand, MasterCreditCard]

    assert_equal "topics", Topic.table_name

    assert_equal "categories", Category.table_name
    assert_equal "smarts", Smarts.table_name
    assert_equal "credit_cards", CreditCard.table_name
    assert_equal "credit_card_pin_numbers", CreditCard::PinNumber.table_name
    assert_equal "credit_card_pin_number_cvv_codes", CreditCard::PinNumber::CvvCode.table_name
    assert_equal "credit_card_pin_numbers", CreditCard::SubPinNumber.table_name
    assert_equal "categories", CreditCard::Brand.table_name
    assert_equal "master_credit_cards", MasterCreditCard.table_name

    ActiveRecord::Base.pluralize_table_names = false
    classes.each(&:reset_table_name)

    assert_equal "category", Category.table_name
    assert_equal "smarts", Smarts.table_name
    assert_equal "credit_card", CreditCard.table_name
    assert_equal "credit_card_pin_number", CreditCard::PinNumber.table_name
    assert_equal "credit_card_pin_number_cvv_code", CreditCard::PinNumber::CvvCode.table_name
    assert_equal "credit_card_pin_number", CreditCard::SubPinNumber.table_name
    assert_equal "category", CreditCard::Brand.table_name
    assert_equal "master_credit_card", MasterCreditCard.table_name

    ActiveRecord::Base.pluralize_table_names = true
    classes.each(&:reset_table_name)

    ActiveRecord::Base.table_name_prefix = "test_"
    Category.reset_table_name
    assert_equal "test_categories", Category.table_name
    ActiveRecord::Base.table_name_suffix = "_test"
    Category.reset_table_name
    assert_equal "test_categories_test", Category.table_name
    ActiveRecord::Base.table_name_prefix = ""
    Category.reset_table_name
    assert_equal "categories_test", Category.table_name
    ActiveRecord::Base.table_name_suffix = ""
    Category.reset_table_name
    assert_equal "categories", Category.table_name

    ActiveRecord::Base.pluralize_table_names = false
    ActiveRecord::Base.table_name_prefix = "test_"
    Category.reset_table_name
    assert_equal "test_category", Category.table_name
    ActiveRecord::Base.table_name_suffix = "_test"
    Category.reset_table_name
    assert_equal "test_category_test", Category.table_name
    ActiveRecord::Base.table_name_prefix = ""
    Category.reset_table_name
    assert_equal "category_test", Category.table_name
    ActiveRecord::Base.table_name_suffix = ""
    Category.reset_table_name
    assert_equal "category", Category.table_name

    ActiveRecord::Base.pluralize_table_names = true
    classes.each(&:reset_table_name)
  end

  def test_destroy_all
    original_count = Topic.count
    topics_by_mary = Topic.count(:conditions => mary = "author_name = 'Mary'")

    Topic.destroy_all mary
    assert_equal original_count - topics_by_mary, Topic.count
  end

  def test_destroy_many
    assert_equal 3, Client.count
    Client.destroy([2, 3])
    assert_equal 1, Client.count
  end

  def test_delete_many
    original_count = Topic.count
    Topic.delete(deleting = [1, 2])
    assert_equal original_count - deleting.size, Topic.count
  end

  def test_boolean_attributes
    assert ! Topic.find(1).approved?
    assert Topic.find(2).approved?
  end

  def test_increment_counter
    Topic.increment_counter("replies_count", 1)
    assert_equal 2, Topic.find(1).replies_count

    Topic.increment_counter("replies_count", 1)
    assert_equal 3, Topic.find(1).replies_count
  end

  def test_decrement_counter
    Topic.decrement_counter("replies_count", 2)
    assert_equal -1, Topic.find(2).replies_count

    Topic.decrement_counter("replies_count", 2)
    assert_equal -2, Topic.find(2).replies_count
  end

  def test_update_counter
    category = categories(:general)
    assert_nil category.categorizations_count
    assert_equal 2, category.categorizations.count

    Category.update_counters(category.id, "categorizations_count" => category.categorizations.count)
    category.reload
    assert_not_nil category.categorizations_count
    assert_equal 2, category.categorizations_count

    Category.update_counters(category.id, "categorizations_count" => category.categorizations.count)
    category.reload
    assert_not_nil category.categorizations_count
    assert_equal 4, category.categorizations_count

    category_2 = categories(:technology)
    count_1, count_2 = (category.categorizations_count || 0), (category_2.categorizations_count || 0)
    Category.update_counters([category.id, category_2.id], "categorizations_count" => 2)
    category.reload; category_2.reload
    assert_equal count_1 + 2, category.categorizations_count
    assert_equal count_2 + 2, category_2.categorizations_count
  end

  def test_update_all
    assert_equal Topic.count, Topic.update_all("content = 'bulk updated!'")
    assert_equal "bulk updated!", Topic.find(1).content
    assert_equal "bulk updated!", Topic.find(2).content

    assert_equal Topic.count, Topic.update_all(['content = ?', 'bulk updated again!'])
    assert_equal "bulk updated again!", Topic.find(1).content
    assert_equal "bulk updated again!", Topic.find(2).content

    assert_equal Topic.count, Topic.update_all(['content = ?', nil])
    assert_nil Topic.find(1).content
  end

  def test_update_all_with_hash
    assert_not_nil Topic.find(1).last_read
    assert_equal Topic.count, Topic.update_all(:content => 'bulk updated with hash!', :last_read => nil)
    assert_equal "bulk updated with hash!", Topic.find(1).content
    assert_equal "bulk updated with hash!", Topic.find(2).content
    assert_nil Topic.find(1).last_read
    assert_nil Topic.find(2).last_read
  end

  def test_update_all_with_non_standard_table_name
    assert_equal 1, WarehouseThing.update_all(['value = ?', 0], ['id = ?', 1])
    assert_equal 0, WarehouseThing.find(1).value
  end

  if current_adapter?(:MysqlAdapter)
    def test_update_all_with_order_and_limit
      assert_equal 1, Topic.update_all("content = 'bulk updated!'", nil, :limit => 1, :order => 'id DESC')
    end
  end

  def test_update_all_ignores_order_without_limit_from_association
    author = authors(:david)
    assert_nothing_raised do
      assert_equal author.posts_with_comments_and_categories.length, author.posts_with_comments_and_categories.update_all([ "body = ?", "bulk update!" ])
    end
  end

  def test_update_all_with_order_and_limit_updates_subset_only
    author = authors(:david)
    assert_nothing_raised do
      assert_equal 1, author.posts_sorted_by_id_limited.size
      assert_equal 2, author.posts_sorted_by_id_limited.find(:all, :limit => 2).size
      assert_equal 1, author.posts_sorted_by_id_limited.update_all([ "body = ?", "bulk update!" ])
      assert_equal "bulk update!", posts(:welcome).body
      assert_not_equal "bulk update!", posts(:thinking).body
    end
  end

  def test_update_many
    topic_data = { 1 => { "content" => "1 updated" }, 2 => { "content" => "2 updated" } }
    updated = Topic.update(topic_data.keys, topic_data.values)

    assert_equal 2, updated.size
    assert_equal "1 updated", Topic.find(1).content
    assert_equal "2 updated", Topic.find(2).content
  end

  def test_delete_all
    assert Topic.count > 0

    assert_equal Topic.count, Topic.delete_all
  end

  def test_update_by_condition
    Topic.update_all "content = 'bulk updated!'", ["approved = ?", true]
    assert_equal "Have a nice day", Topic.find(1).content
    assert_equal "bulk updated!", Topic.find(2).content
  end

  def test_attribute_present
    t = Topic.new
    t.title = "hello there!"
    t.written_on = Time.now
    assert t.attribute_present?("title")
    assert t.attribute_present?("written_on")
    assert !t.attribute_present?("content")
  end

  def test_attribute_keys_on_new_instance
    t = Topic.new
    assert_equal nil, t.title, "The topics table has a title column, so it should be nil"
    assert_raise(NoMethodError) { t.title2 }
  end

  def test_class_name
    assert_equal "Firm", ActiveRecord::Base.class_name("firms")
    assert_equal "Category", ActiveRecord::Base.class_name("categories")
    assert_equal "AccountHolder", ActiveRecord::Base.class_name("account_holder")

    ActiveRecord::Base.pluralize_table_names = false
    assert_equal "Firms", ActiveRecord::Base.class_name( "firms" )
    ActiveRecord::Base.pluralize_table_names = true

    ActiveRecord::Base.table_name_prefix = "test_"
    assert_equal "Firm", ActiveRecord::Base.class_name( "test_firms" )
    ActiveRecord::Base.table_name_suffix = "_tests"
    assert_equal "Firm", ActiveRecord::Base.class_name( "test_firms_tests" )
    ActiveRecord::Base.table_name_prefix = ""
    assert_equal "Firm", ActiveRecord::Base.class_name( "firms_tests" )
    ActiveRecord::Base.table_name_suffix = ""
    assert_equal "Firm", ActiveRecord::Base.class_name( "firms" )
  end

  def test_null_fields
    assert_nil Topic.find(1).parent_id
    assert_nil Topic.create("title" => "Hey you").parent_id
  end

  def test_default_values
    topic = Topic.new
    assert topic.approved?
    assert_nil topic.written_on
    assert_nil topic.bonus_time
    assert_nil topic.last_read

    topic.save

    topic = Topic.find(topic.id)
    assert topic.approved?
    assert_nil topic.last_read

    # Oracle has some funky default handling, so it requires a bit of
    # extra testing. See ticket #2788.
    if current_adapter?(:OracleAdapter)
      test = TestOracleDefault.new
      assert_equal "X", test.test_char
      assert_equal "hello", test.test_string
      assert_equal 3, test.test_int
    end
  end

  # Oracle, and Sybase do not have a TIME datatype.
  unless current_adapter?(:OracleAdapter, :SybaseAdapter)
    def test_utc_as_time_zone
      Topic.default_timezone = :utc
      attributes = { "bonus_time" => "5:42:00AM" }
      topic = Topic.find(1)
      topic.attributes = attributes
      assert_equal Time.utc(2000, 1, 1, 5, 42, 0), topic.bonus_time
      Topic.default_timezone = :local
    end

    def test_utc_as_time_zone_and_new
      Topic.default_timezone = :utc
      attributes = { "bonus_time(1i)"=>"2000",
                     "bonus_time(2i)"=>"1",
                     "bonus_time(3i)"=>"1",
                     "bonus_time(4i)"=>"10",
                     "bonus_time(5i)"=>"35",
                     "bonus_time(6i)"=>"50" }
      topic = Topic.new(attributes)
      assert_equal Time.utc(2000, 1, 1, 10, 35, 50), topic.bonus_time
      Topic.default_timezone = :local
    end
  end

  def test_default_values_on_empty_strings
    topic = Topic.new
    topic.approved  = nil
    topic.last_read = nil

    topic.save

    topic = Topic.find(topic.id)
    assert_nil topic.last_read

    # Sybase adapter does not allow nulls in boolean columns
    if current_adapter?(:SybaseAdapter)
      assert topic.approved == false
    else
      assert_nil topic.approved
    end
  end

  def test_equality
    assert_equal Topic.find(1), Topic.find(2).topic
  end

  def test_equality_of_new_records
    assert_not_equal Topic.new, Topic.new
  end

  def test_hashing
    assert_equal [ Topic.find(1) ], [ Topic.find(2).topic ] & [ Topic.find(1) ]
  end

  def test_delete_new_record
    client = Client.new
    client.delete
    assert client.frozen?
  end

  def test_delete_record_with_associations
    client = Client.find(3)
    client.delete
    assert client.frozen?
    assert_kind_of Firm, client.firm
    assert_raise(ActiveSupport::FrozenObjectError) { client.name = "something else" }
  end

  def test_destroy_new_record
    client = Client.new
    client.destroy
    assert client.frozen?
  end

  def test_destroy_record_with_associations
    client = Client.find(3)
    client.destroy
    assert client.frozen?
    assert_kind_of Firm, client.firm
    assert_raise(ActiveSupport::FrozenObjectError) { client.name = "something else" }
  end

  def test_update_attribute
    assert !Topic.find(1).approved?
    Topic.find(1).update_attribute("approved", true)
    assert Topic.find(1).approved?

    Topic.find(1).update_attribute(:approved, false)
    assert !Topic.find(1).approved?
  end

  def test_update_attributes
    topic = Topic.find(1)
    assert !topic.approved?
    assert_equal "The First Topic", topic.title

    topic.update_attributes("approved" => true, "title" => "The First Topic Updated")
    topic.reload
    assert topic.approved?
    assert_equal "The First Topic Updated", topic.title

    topic.update_attributes(:approved => false, :title => "The First Topic")
    topic.reload
    assert !topic.approved?
    assert_equal "The First Topic", topic.title
  end

  def test_update_attributes!
    reply = Reply.find(2)
    assert_equal "The Second Topic of the day", reply.title
    assert_equal "Have a nice day", reply.content

    reply.update_attributes!("title" => "The Second Topic of the day updated", "content" => "Have a nice evening")
    reply.reload
    assert_equal "The Second Topic of the day updated", reply.title
    assert_equal "Have a nice evening", reply.content

    reply.update_attributes!(:title => "The Second Topic of the day", :content => "Have a nice day")
    reply.reload
    assert_equal "The Second Topic of the day", reply.title
    assert_equal "Have a nice day", reply.content

    assert_raise(ActiveRecord::RecordInvalid) { reply.update_attributes!(:title => nil, :content => "Have a nice evening") }
  end

  def test_mass_assignment_should_raise_exception_if_accessible_and_protected_attribute_writers_are_both_used
    topic = TopicWithProtectedContentAndAccessibleAuthorName.new
    assert_raise(RuntimeError) { topic.attributes = { "author_name" => "me" } }
    assert_raise(RuntimeError) { topic.attributes = { "content" => "stuff" } }
  end

  def test_mass_assignment_protection
    firm = Firm.new
    firm.attributes = { "name" => "Next Angle", "rating" => 5 }
    assert_equal 1, firm.rating
  end

  def test_mass_assignment_protection_against_class_attribute_writers
    [:logger, :configurations, :primary_key_prefix_type, :table_name_prefix, :table_name_suffix, :pluralize_table_names, :colorize_logging,
      :default_timezone, :schema_format, :lock_optimistically, :record_timestamps].each do |method|
      assert  Task.respond_to?(method)
      assert  Task.respond_to?("#{method}=")
      assert  Task.new.respond_to?(method)
      assert !Task.new.respond_to?("#{method}=")
    end
  end

  def test_customized_primary_key_remains_protected
    subscriber = Subscriber.new(:nick => 'webster123', :name => 'nice try')
    assert_nil subscriber.id

    keyboard = Keyboard.new(:key_number => 9, :name => 'nice try')
    assert_nil keyboard.id
  end

  def test_customized_primary_key_remains_protected_when_referred_to_as_id
    subscriber = Subscriber.new(:id => 'webster123', :name => 'nice try')
    assert_nil subscriber.id

    keyboard = Keyboard.new(:id => 9, :name => 'nice try')
    assert_nil keyboard.id
  end

  def test_mass_assigning_invalid_attribute
    firm = Firm.new

    assert_raise(ActiveRecord::UnknownAttributeError) do
      firm.attributes = { "id" => 5, "type" => "Client", "i_dont_even_exist" => 20 }
    end
  end

  def test_mass_assignment_protection_on_defaults
    firm = Firm.new
    firm.attributes = { "id" => 5, "type" => "Client" }
    assert_nil firm.id
    assert_equal "Firm", firm[:type]
  end

  def test_mass_assignment_accessible
    reply = Reply.new("title" => "hello", "content" => "world", "approved" => true)
    reply.save

    assert reply.approved?

    reply.approved = false
    reply.save

    assert !reply.approved?
  end

  def test_mass_assignment_protection_inheritance
    assert_nil LoosePerson.accessible_attributes
    assert_equal Set.new([ 'credit_rating', 'administrator' ]), LoosePerson.protected_attributes

    assert_nil LooseDescendant.accessible_attributes
    assert_equal Set.new([ 'credit_rating', 'administrator', 'phone_number' ]), LooseDescendant.protected_attributes

    assert_nil LooseDescendantSecond.accessible_attributes
    assert_equal Set.new([ 'credit_rating', 'administrator', 'phone_number', 'name' ]), LooseDescendantSecond.protected_attributes, 'Running attr_protected twice in one class should merge the protections'

    assert_nil TightPerson.protected_attributes
    assert_equal Set.new([ 'name', 'address' ]), TightPerson.accessible_attributes

    assert_nil TightDescendant.protected_attributes
    assert_equal Set.new([ 'name', 'address', 'phone_number' ]), TightDescendant.accessible_attributes
  end

  def test_readonly_attributes
    assert_equal Set.new([ 'title' , 'comments_count' ]), ReadonlyTitlePost.readonly_attributes

    post = ReadonlyTitlePost.create(:title => "cannot change this", :body => "changeable")
    post.reload
    assert_equal "cannot change this", post.title

    post.update_attributes(:title => "try to change", :body => "changed")
    post.reload
    assert_equal "cannot change this", post.title
    assert_equal "changed", post.body
  end

  def test_multiparameter_attributes_on_date
    attributes = { "last_read(1i)" => "2004", "last_read(2i)" => "6", "last_read(3i)" => "24" }
    topic = Topic.find(1)
    topic.attributes = attributes
    # note that extra #to_date call allows test to pass for Oracle, which
    # treats dates/times the same
    assert_date_from_db Date.new(2004, 6, 24), topic.last_read.to_date
  end

  def test_multiparameter_attributes_on_date_with_empty_date
    attributes = { "last_read(1i)" => "2004", "last_read(2i)" => "6", "last_read(3i)" => "" }
    topic = Topic.find(1)
    topic.attributes = attributes
    # note that extra #to_date call allows test to pass for Oracle, which
    # treats dates/times the same
    assert_date_from_db Date.new(2004, 6, 1), topic.last_read.to_date
  end

  def test_multiparameter_attributes_on_date_with_all_empty
    attributes = { "last_read(1i)" => "", "last_read(2i)" => "", "last_read(3i)" => "" }
    topic = Topic.find(1)
    topic.attributes = attributes
    assert_nil topic.last_read
  end

  def test_multiparameter_attributes_on_time
    attributes = {
      "written_on(1i)" => "2004", "written_on(2i)" => "6", "written_on(3i)" => "24",
      "written_on(4i)" => "16", "written_on(5i)" => "24", "written_on(6i)" => "00"
    }
    topic = Topic.find(1)
    topic.attributes = attributes
    assert_equal Time.local(2004, 6, 24, 16, 24, 0), topic.written_on
  end

  def test_multiparameter_attributes_on_time_with_old_date
    attributes = {
      "written_on(1i)" => "1850", "written_on(2i)" => "6", "written_on(3i)" => "24",
      "written_on(4i)" => "16", "written_on(5i)" => "24", "written_on(6i)" => "00"
    }
    topic = Topic.find(1)
    topic.attributes = attributes
    # testing against to_s(:db) representation because either a Time or a DateTime might be returned, depending on platform
    assert_equal "1850-06-24 16:24:00", topic.written_on.to_s(:db)
  end

  def test_multiparameter_attributes_on_time_with_utc
    ActiveRecord::Base.default_timezone = :utc
    attributes = {
      "written_on(1i)" => "2004", "written_on(2i)" => "6", "written_on(3i)" => "24",
      "written_on(4i)" => "16", "written_on(5i)" => "24", "written_on(6i)" => "00"
    }
    topic = Topic.find(1)
    topic.attributes = attributes
    assert_equal Time.utc(2004, 6, 24, 16, 24, 0), topic.written_on
  ensure
    ActiveRecord::Base.default_timezone = :local
  end

  def test_multiparameter_attributes_on_time_with_time_zone_aware_attributes
    ActiveRecord::Base.time_zone_aware_attributes = true
    ActiveRecord::Base.default_timezone = :utc
    Time.zone = ActiveSupport::TimeZone[-28800]
    attributes = {
      "written_on(1i)" => "2004", "written_on(2i)" => "6", "written_on(3i)" => "24",
      "written_on(4i)" => "16", "written_on(5i)" => "24", "written_on(6i)" => "00"
    }
    topic = Topic.find(1)
    topic.attributes = attributes
    assert_equal Time.utc(2004, 6, 24, 23, 24, 0), topic.written_on
    assert_equal Time.utc(2004, 6, 24, 16, 24, 0), topic.written_on.time
    assert_equal Time.zone, topic.written_on.time_zone
  ensure
    ActiveRecord::Base.time_zone_aware_attributes = false
    ActiveRecord::Base.default_timezone = :local
    Time.zone = nil
  end

  def test_multiparameter_attributes_on_time_with_time_zone_aware_attributes_false
    ActiveRecord::Base.time_zone_aware_attributes = false
    Time.zone = ActiveSupport::TimeZone[-28800]
    attributes = {
      "written_on(1i)" => "2004", "written_on(2i)" => "6", "written_on(3i)" => "24",
      "written_on(4i)" => "16", "written_on(5i)" => "24", "written_on(6i)" => "00"
    }
    topic = Topic.find(1)
    topic.attributes = attributes
    assert_equal Time.local(2004, 6, 24, 16, 24, 0), topic.written_on
    assert_equal false, topic.written_on.respond_to?(:time_zone)
  ensure
    Time.zone = nil
  end

  def test_multiparameter_attributes_on_time_with_skip_time_zone_conversion_for_attributes
    ActiveRecord::Base.time_zone_aware_attributes = true
    ActiveRecord::Base.default_timezone = :utc
    Time.zone = ActiveSupport::TimeZone[-28800]
    Topic.skip_time_zone_conversion_for_attributes = [:written_on]
    attributes = {
      "written_on(1i)" => "2004", "written_on(2i)" => "6", "written_on(3i)" => "24",
      "written_on(4i)" => "16", "written_on(5i)" => "24", "written_on(6i)" => "00"
    }
    topic = Topic.find(1)
    topic.attributes = attributes
    assert_equal Time.utc(2004, 6, 24, 16, 24, 0), topic.written_on
    assert_equal false, topic.written_on.respond_to?(:time_zone)
  ensure
    ActiveRecord::Base.time_zone_aware_attributes = false
    ActiveRecord::Base.default_timezone = :local
    Time.zone = nil
    Topic.skip_time_zone_conversion_for_attributes = []
  end
  
  def test_multiparameter_attributes_on_time_only_column_with_time_zone_aware_attributes_does_not_do_time_zone_conversion
    ActiveRecord::Base.time_zone_aware_attributes = true
    ActiveRecord::Base.default_timezone = :utc
    Time.zone = ActiveSupport::TimeZone[-28800]
    attributes = {
      "bonus_time(1i)" => "2000", "bonus_time(2i)" => "1", "bonus_time(3i)" => "1",
      "bonus_time(4i)" => "16", "bonus_time(5i)" => "24"
    }
    topic = Topic.find(1)
    topic.attributes = attributes
    assert_equal Time.utc(2000, 1, 1, 16, 24, 0), topic.bonus_time
    assert topic.bonus_time.utc?
  ensure
    ActiveRecord::Base.time_zone_aware_attributes = false
    ActiveRecord::Base.default_timezone = :local
    Time.zone = nil
  end

  def test_multiparameter_attributes_on_time_with_empty_seconds
    attributes = {
      "written_on(1i)" => "2004", "written_on(2i)" => "6", "written_on(3i)" => "24",
      "written_on(4i)" => "16", "written_on(5i)" => "24", "written_on(6i)" => ""
    }
    topic = Topic.find(1)
    topic.attributes = attributes
    assert_equal Time.local(2004, 6, 24, 16, 24, 0), topic.written_on
  end

  def test_multiparameter_mass_assignment_protector
    task = Task.new
    time = Time.mktime(2000, 1, 1, 1)
    task.starting = time
    attributes = { "starting(1i)" => "2004", "starting(2i)" => "6", "starting(3i)" => "24" }
    task.attributes = attributes
    assert_equal time, task.starting
  end

  def test_multiparameter_assignment_of_aggregation
    customer = Customer.new
    address = Address.new("The Street", "The City", "The Country")
    attributes = { "address(1)" => address.street, "address(2)" => address.city, "address(3)" => address.country }
    customer.attributes = attributes
    assert_equal address, customer.address
  end

  def test_attributes_on_dummy_time
    # Oracle, and Sybase do not have a TIME datatype.
    return true if current_adapter?(:OracleAdapter, :SybaseAdapter)

    attributes = {
      "bonus_time" => "5:42:00AM"
    }
    topic = Topic.find(1)
    topic.attributes = attributes
    assert_equal Time.local(2000, 1, 1, 5, 42, 0), topic.bonus_time
  end

  def test_boolean
    b_nil = Booleantest.create({ "value" => nil })
    nil_id = b_nil.id
    b_false = Booleantest.create({ "value" => false })
    false_id = b_false.id
    b_true = Booleantest.create({ "value" => true })
    true_id = b_true.id

    b_nil = Booleantest.find(nil_id)
    assert_nil b_nil.value
    b_false = Booleantest.find(false_id)
    assert !b_false.value?
    b_true = Booleantest.find(true_id)
    assert b_true.value?
  end

  def test_boolean_cast_from_string
    b_blank = Booleantest.create({ "value" => "" })
    blank_id = b_blank.id
    b_false = Booleantest.create({ "value" => "0" })
    false_id = b_false.id
    b_true = Booleantest.create({ "value" => "1" })
    true_id = b_true.id

    b_blank = Booleantest.find(blank_id)
    assert_nil b_blank.value
    b_false = Booleantest.find(false_id)
    assert !b_false.value?
    b_true = Booleantest.find(true_id)
    assert b_true.value?
  end

  def test_new_record_returns_boolean
    assert_equal Topic.new.new_record?, true
    assert_equal Topic.find(1).new_record?, false
  end

  def test_clone
    topic = Topic.find(1)
    cloned_topic = nil
    assert_nothing_raised { cloned_topic = topic.clone }
    assert_equal topic.title, cloned_topic.title
    assert cloned_topic.new_record?

    # test if the attributes have been cloned
    topic.title = "a"
    cloned_topic.title = "b"
    assert_equal "a", topic.title
    assert_equal "b", cloned_topic.title

    # test if the attribute values have been cloned
    topic.title = {"a" => "b"}
    cloned_topic = topic.clone
    cloned_topic.title["a"] = "c"
    assert_equal "b", topic.title["a"]

    #test if attributes set as part of after_initialize are cloned correctly
    assert_equal topic.author_email_address, cloned_topic.author_email_address

    # test if saved clone object differs from original
    cloned_topic.save
    assert !cloned_topic.new_record?
    assert cloned_topic.id != topic.id
  end

  def test_clone_with_aggregate_of_same_name_as_attribute
    dev = DeveloperWithAggregate.find(1)
    assert_kind_of DeveloperSalary, dev.salary

    clone = nil
    assert_nothing_raised { clone = dev.clone }
    assert_kind_of DeveloperSalary, clone.salary
    assert_equal dev.salary.amount, clone.salary.amount
    assert clone.new_record?

    # test if the attributes have been cloned
    original_amount = clone.salary.amount
    dev.salary.amount = 1
    assert_equal original_amount, clone.salary.amount

    assert clone.save
    assert !clone.new_record?
    assert clone.id != dev.id
  end

  def test_clone_preserves_subtype
    clone = nil
    assert_nothing_raised { clone = Company.find(3).clone }
    assert_kind_of Client, clone
  end

  def test_bignum
    company = Company.find(1)
    company.rating = 2147483647
    company.save
    company = Company.find(1)
    assert_equal 2147483647, company.rating
  end

  # TODO: extend defaults tests to other databases!
  if current_adapter?(:PostgreSQLAdapter)
    def test_default
      default = Default.new

      # fixed dates / times
      assert_equal Date.new(2004, 1, 1), default.fixed_date
      assert_equal Time.local(2004, 1,1,0,0,0,0), default.fixed_time

      # char types
      assert_equal 'Y', default.char1
      assert_equal 'a varchar field', default.char2
      assert_equal 'a text field', default.char3
    end

    class Geometric < ActiveRecord::Base; end
    def test_geometric_content

      # accepted format notes:
      # ()'s aren't required
      # values can be a mix of float or integer

      g = Geometric.new(
        :a_point        => '(5.0, 6.1)',
        #:a_line         => '((2.0, 3), (5.5, 7.0))' # line type is currently unsupported in postgresql
        :a_line_segment => '(2.0, 3), (5.5, 7.0)',
        :a_box          => '2.0, 3, 5.5, 7.0',
        :a_path         => '[(2.0, 3), (5.5, 7.0), (8.5, 11.0)]',  # [ ] is an open path
        :a_polygon      => '((2.0, 3), (5.5, 7.0), (8.5, 11.0))',
        :a_circle       => '<(5.3, 10.4), 2>'
      )

      assert g.save

      # Reload and check that we have all the geometric attributes.
      h = Geometric.find(g.id)

      assert_equal '(5,6.1)', h.a_point
      assert_equal '[(2,3),(5.5,7)]', h.a_line_segment
      assert_equal '(5.5,7),(2,3)', h.a_box   # reordered to store upper right corner then bottom left corner
      assert_equal '[(2,3),(5.5,7),(8.5,11)]', h.a_path
      assert_equal '((2,3),(5.5,7),(8.5,11))', h.a_polygon
      assert_equal '<(5.3,10.4),2>', h.a_circle

      # use a geometric function to test for an open path
      objs = Geometric.find_by_sql ["select isopen(a_path) from geometrics where id = ?", g.id]
      assert_equal objs[0].isopen, 't'

      # test alternate formats when defining the geometric types

      g = Geometric.new(
        :a_point        => '5.0, 6.1',
        #:a_line         => '((2.0, 3), (5.5, 7.0))' # line type is currently unsupported in postgresql
        :a_line_segment => '((2.0, 3), (5.5, 7.0))',
        :a_box          => '(2.0, 3), (5.5, 7.0)',
        :a_path         => '((2.0, 3), (5.5, 7.0), (8.5, 11.0))',  # ( ) is a closed path
        :a_polygon      => '2.0, 3, 5.5, 7.0, 8.5, 11.0',
        :a_circle       => '((5.3, 10.4), 2)'
      )

      assert g.save

      # Reload and check that we have all the geometric attributes.
      h = Geometric.find(g.id)

      assert_equal '(5,6.1)', h.a_point
      assert_equal '[(2,3),(5.5,7)]', h.a_line_segment
      assert_equal '(5.5,7),(2,3)', h.a_box   # reordered to store upper right corner then bottom left corner
      assert_equal '((2,3),(5.5,7),(8.5,11))', h.a_path
      assert_equal '((2,3),(5.5,7),(8.5,11))', h.a_polygon
      assert_equal '<(5.3,10.4),2>', h.a_circle

      # use a geometric function to test for an closed path
      objs = Geometric.find_by_sql ["select isclosed(a_path) from geometrics where id = ?", g.id]
      assert_equal objs[0].isclosed, 't'
    end
  end

  class NumericData < ActiveRecord::Base
    self.table_name = 'numeric_data'
  end

  def test_numeric_fields
    m = NumericData.new(
      :bank_balance => 1586.43,
      :big_bank_balance => BigDecimal("1000234000567.95"),
      :world_population => 6000000000,
      :my_house_population => 3
    )
    assert m.save

    m1 = NumericData.find(m.id)
    assert_not_nil m1

    # As with migration_test.rb, we should make world_population >= 2**62
    # to cover 64-bit platforms and test it is a Bignum, but the main thing
    # is that it's an Integer.
    assert_kind_of Integer, m1.world_population
    assert_equal 6000000000, m1.world_population

    assert_kind_of Fixnum, m1.my_house_population
    assert_equal 3, m1.my_house_population

    assert_kind_of BigDecimal, m1.bank_balance
    assert_equal BigDecimal("1586.43"), m1.bank_balance

    assert_kind_of BigDecimal, m1.big_bank_balance
    assert_equal BigDecimal("1000234000567.95"), m1.big_bank_balance
  end

  def test_auto_id
    auto = AutoId.new
    auto.save
    assert (auto.id > 0)
  end

  def quote_column_name(name)
    "<#{name}>"
  end

  def test_quote_keys
    ar = AutoId.new
    source = {"foo" => "bar", "baz" => "quux"}
    actual = ar.send(:quote_columns, self, source)
    inverted = actual.invert
    assert_equal("<foo>", inverted["bar"])
    assert_equal("<baz>", inverted["quux"])
  end

  def test_sql_injection_via_find
    assert_raise(ActiveRecord::RecordNotFound, ActiveRecord::StatementInvalid) do
      Topic.find("123456 OR id > 0")
    end
  end

  def test_column_name_properly_quoted
    col_record = ColumnName.new
    col_record.references = 40
    assert col_record.save
    col_record.references = 41
    assert col_record.save
    assert_not_nil c2 = ColumnName.find(col_record.id)
    assert_equal(41, c2.references)
  end

  def test_quoting_arrays
    replies = Reply.find(:all, :conditions => [ "id IN (?)", topics(:first).replies.collect(&:id) ])
    assert_equal topics(:first).replies.size, replies.size

    replies = Reply.find(:all, :conditions => [ "id IN (?)", [] ])
    assert_equal 0, replies.size
  end

  MyObject = Struct.new :attribute1, :attribute2

  def test_serialized_attribute
    myobj = MyObject.new('value1', 'value2')
    topic = Topic.create("content" => myobj)
    Topic.serialize("content", MyObject)
    assert_equal(myobj, topic.content)
  end

  def test_serialized_time_attribute
    myobj = Time.local(2008,1,1,1,0)
    topic = Topic.create("content" => myobj).reload
    assert_equal(myobj, topic.content)
  end
  
  def test_serialized_string_attribute
    myobj = "Yes"
    topic = Topic.create("content" => myobj).reload
    assert_equal(myobj, topic.content)
  end

  def test_nil_serialized_attribute_with_class_constraint
    myobj = MyObject.new('value1', 'value2')
    topic = Topic.new
    assert_nil topic.content
  end

  def test_should_raise_exception_on_serialized_attribute_with_type_mismatch
    myobj = MyObject.new('value1', 'value2')
    topic = Topic.new(:content => myobj)
    assert topic.save
    Topic.serialize(:content, Hash)
    assert_raise(ActiveRecord::SerializationTypeMismatch) { Topic.find(topic.id).content }
  ensure
    Topic.serialize(:content)
  end

  def test_serialized_attribute_with_class_constraint
    settings = { "color" => "blue" }
    Topic.serialize(:content, Hash)
    topic = Topic.new(:content => settings)
    assert topic.save
    assert_equal(settings, Topic.find(topic.id).content)
  ensure
    Topic.serialize(:content)
  end

  def test_quote
    author_name = "\\ \001 ' \n \\n \""
    topic = Topic.create('author_name' => author_name)
    assert_equal author_name, Topic.find(topic.id).author_name
  end

  if RUBY_VERSION < '1.9'
    def test_quote_chars
      with_kcode('UTF8') do
        str = 'The Narrator'
        topic = Topic.create(:author_name => str)
        assert_equal str, topic.author_name

        assert_kind_of ActiveSupport::Multibyte.proxy_class, str.mb_chars
        topic = Topic.find_by_author_name(str.mb_chars)

        assert_kind_of Topic, topic
        assert_equal str, topic.author_name, "The right topic should have been found by name even with name passed as Chars"
      end
    end
  end

  def test_class_level_destroy
    should_be_destroyed_reply = Reply.create("title" => "hello", "content" => "world")
    Topic.find(1).replies << should_be_destroyed_reply

    Topic.destroy(1)
    assert_raise(ActiveRecord::RecordNotFound) { Topic.find(1) }
    assert_raise(ActiveRecord::RecordNotFound) { Reply.find(should_be_destroyed_reply.id) }
  end

  def test_class_level_delete
    should_be_destroyed_reply = Reply.create("title" => "hello", "content" => "world")
    Topic.find(1).replies << should_be_destroyed_reply

    Topic.delete(1)
    assert_raise(ActiveRecord::RecordNotFound) { Topic.find(1) }
    assert_nothing_raised { Reply.find(should_be_destroyed_reply.id) }
  end

  def test_increment_attribute
    assert_equal 50, accounts(:signals37).credit_limit
    accounts(:signals37).increment! :credit_limit
    assert_equal 51, accounts(:signals37, :reload).credit_limit

    accounts(:signals37).increment(:credit_limit).increment!(:credit_limit)
    assert_equal 53, accounts(:signals37, :reload).credit_limit
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

  def test_toggle_attribute
    assert !topics(:first).approved?
    topics(:first).toggle!(:approved)
    assert topics(:first).approved?
    topic = topics(:first)
    topic.toggle(:approved)
    assert !topic.approved?
    topic.reload
    assert topic.approved?
  end

  def test_reload
    t1 = Topic.find(1)
    t2 = Topic.find(1)
    t1.title = "something else"
    t1.save
    t2.reload
    assert_equal t1.title, t2.title
  end

  def test_define_attr_method_with_value
    k = Class.new( ActiveRecord::Base )
    k.send(:define_attr_method, :table_name, "foo")
    assert_equal "foo", k.table_name
  end

  def test_define_attr_method_with_block
    k = Class.new( ActiveRecord::Base )
    k.send(:define_attr_method, :primary_key) { "sys_" + original_primary_key }
    assert_equal "sys_id", k.primary_key
  end

  def test_set_table_name_with_value
    k = Class.new( ActiveRecord::Base )
    k.table_name = "foo"
    assert_equal "foo", k.table_name
    k.set_table_name "bar"
    assert_equal "bar", k.table_name
  end

  def test_set_table_name_with_block
    k = Class.new( ActiveRecord::Base )
    k.set_table_name { "ks" }
    assert_equal "ks", k.table_name
  end

  def test_set_primary_key_with_value
    k = Class.new( ActiveRecord::Base )
    k.primary_key = "foo"
    assert_equal "foo", k.primary_key
    k.set_primary_key "bar"
    assert_equal "bar", k.primary_key
  end

  def test_set_primary_key_with_block
    k = Class.new( ActiveRecord::Base )
    k.set_primary_key { "sys_" + original_primary_key }
    assert_equal "sys_id", k.primary_key
  end

  def test_set_inheritance_column_with_value
    k = Class.new( ActiveRecord::Base )
    k.inheritance_column = "foo"
    assert_equal "foo", k.inheritance_column
    k.set_inheritance_column "bar"
    assert_equal "bar", k.inheritance_column
  end

  def test_set_inheritance_column_with_block
    k = Class.new( ActiveRecord::Base )
    k.set_inheritance_column { original_inheritance_column + "_id" }
    assert_equal "type_id", k.inheritance_column
  end

  def test_count_with_join
    res = Post.count_by_sql "SELECT COUNT(*) FROM posts LEFT JOIN comments ON posts.id=comments.post_id WHERE posts.#{QUOTED_TYPE} = 'Post'"

    res2 = Post.count(:conditions => "posts.#{QUOTED_TYPE} = 'Post'", :joins => "LEFT JOIN comments ON posts.id=comments.post_id")
    assert_equal res, res2

    res3 = nil
    assert_nothing_raised do
      res3 = Post.count(:conditions => "posts.#{QUOTED_TYPE} = 'Post'",
                        :joins => "LEFT JOIN comments ON posts.id=comments.post_id")
    end
    assert_equal res, res3

    res4 = Post.count_by_sql "SELECT COUNT(p.id) FROM posts p, comments co WHERE p.#{QUOTED_TYPE} = 'Post' AND p.id=co.post_id"
    res5 = nil
    assert_nothing_raised do
      res5 = Post.count(:conditions => "p.#{QUOTED_TYPE} = 'Post' AND p.id=co.post_id",
                        :joins => "p, comments co",
                        :select => "p.id")
    end

    assert_equal res4, res5

    unless current_adapter?(:SQLite2Adapter, :DeprecatedSQLiteAdapter)
      res6 = Post.count_by_sql "SELECT COUNT(DISTINCT p.id) FROM posts p, comments co WHERE p.#{QUOTED_TYPE} = 'Post' AND p.id=co.post_id"
      res7 = nil
      assert_nothing_raised do
        res7 = Post.count(:conditions => "p.#{QUOTED_TYPE} = 'Post' AND p.id=co.post_id",
                          :joins => "p, comments co",
                          :select => "p.id",
                          :distinct => true)
      end
      assert_equal res6, res7
    end
  end

  def test_clear_association_cache_stored
    firm = Firm.find(1)
    assert_kind_of Firm, firm

    firm.clear_association_cache
    assert_equal Firm.find(1).clients.collect{ |x| x.name }.sort, firm.clients.collect{ |x| x.name }.sort
  end

  def test_clear_association_cache_new_record
     firm            = Firm.new
     client_stored   = Client.find(3)
     client_new      = Client.new
     client_new.name = "The Joneses"
     clients         = [ client_stored, client_new ]

     firm.clients    << clients
     assert_equal clients.map(&:name).to_set, firm.clients.map(&:name).to_set

     firm.clear_association_cache
     assert_equal clients.map(&:name).to_set, firm.clients.map(&:name).to_set
  end

  def test_interpolate_sql
    assert_nothing_raised { Category.new.send(:interpolate_sql, 'foo@bar') }
    assert_nothing_raised { Category.new.send(:interpolate_sql, 'foo bar) baz') }
    assert_nothing_raised { Category.new.send(:interpolate_sql, 'foo bar} baz') }
  end

  def test_scoped_find_conditions
    scoped_developers = Developer.with_scope(:find => { :conditions => 'salary > 90000' }) do
      Developer.find(:all, :conditions => 'id < 5')
    end
    assert !scoped_developers.include?(developers(:david)) # David's salary is less than 90,000
    assert_equal 3, scoped_developers.size
  end

  def test_scoped_find_limit_offset
    scoped_developers = Developer.with_scope(:find => { :limit => 3, :offset => 2 }) do
      Developer.find(:all, :order => 'id')
    end
    assert !scoped_developers.include?(developers(:david))
    assert !scoped_developers.include?(developers(:jamis))
    assert_equal 3, scoped_developers.size

    # Test without scoped find conditions to ensure we get the whole thing
    developers = Developer.find(:all, :order => 'id')
    assert_equal Developer.count, developers.size
  end

  def test_scoped_find_order
    # Test order in scope
    scoped_developers = Developer.with_scope(:find => { :limit => 1, :order => 'salary DESC' }) do
      Developer.find(:all)
    end
    assert_equal 'Jamis', scoped_developers.first.name
    assert scoped_developers.include?(developers(:jamis))
    # Test scope without order and order in find
    scoped_developers = Developer.with_scope(:find => { :limit => 1 }) do
      Developer.find(:all, :order => 'salary DESC')
    end
    # Test scope order + find order, find has priority
    scoped_developers = Developer.with_scope(:find => { :limit => 3, :order => 'id DESC' }) do
      Developer.find(:all, :order => 'salary ASC')
    end
    assert scoped_developers.include?(developers(:poor_jamis))
    assert scoped_developers.include?(developers(:david))
    assert scoped_developers.include?(developers(:dev_10))
    # Test without scoped find conditions to ensure we get the right thing
    developers = Developer.find(:all, :order => 'id', :limit => 1)
    assert scoped_developers.include?(developers(:david))
  end

  def test_scoped_find_limit_offset_including_has_many_association
    topics = Topic.with_scope(:find => {:limit => 1, :offset => 1, :include => :replies}) do
      Topic.find(:all, :order => "topics.id")
    end
    assert_equal 1, topics.size
    assert_equal 2, topics.first.id
  end

  def test_scoped_find_order_including_has_many_association
    developers = Developer.with_scope(:find => { :order => 'developers.salary DESC', :include => :projects }) do
      Developer.find(:all)
    end
    assert developers.size >= 2
    for i in 1...developers.size
      assert developers[i-1].salary >= developers[i].salary
    end
  end

  def test_scoped_find_with_group_and_having
    developers = Developer.with_scope(:find => { :group => 'salary', :having => "SUM(salary) > 10000", :select => "SUM(salary) as salary" }) do
      Developer.find(:all)
    end
    assert_equal 3, developers.size
  end

  def test_find_last
    last  = Developer.find :last
    assert_equal last, Developer.find(:first, :order => 'id desc')
  end

  def test_last
    assert_equal Developer.find(:first, :order => 'id desc'), Developer.last
  end

  def test_all_with_conditions
    assert_equal Developer.find(:all, :order => 'id desc'), Developer.all(:order => 'id desc')
  end

  def test_find_ordered_last
    last  = Developer.find :last, :order => 'developers.salary ASC'
    assert_equal last, Developer.find(:all, :order => 'developers.salary ASC').last
  end

  def test_find_reverse_ordered_last
    last  = Developer.find :last, :order => 'developers.salary DESC'
    assert_equal last, Developer.find(:all, :order => 'developers.salary DESC').last
  end

  def test_find_multiple_ordered_last
    last  = Developer.find :last, :order => 'developers.name, developers.salary DESC'
    assert_equal last, Developer.find(:all, :order => 'developers.name, developers.salary DESC').last
  end

  def test_find_symbol_ordered_last
    last  = Developer.find :last, :order => :salary
    assert_equal last, Developer.find(:all, :order => :salary).last
  end

  def test_find_scoped_ordered_last
    last_developer = Developer.with_scope(:find => { :order => 'developers.salary ASC' }) do
      Developer.find(:last)
    end
    assert_equal last_developer, Developer.find(:all, :order => 'developers.salary ASC').last
  end

  def test_abstract_class
    assert !ActiveRecord::Base.abstract_class?
    assert LoosePerson.abstract_class?
    assert !LooseDescendant.abstract_class?
  end

  def test_base_class
    assert_equal LoosePerson,     LoosePerson.base_class
    assert_equal LooseDescendant, LooseDescendant.base_class
    assert_equal TightPerson,     TightPerson.base_class
    assert_equal TightPerson,     TightDescendant.base_class

    assert_equal Post, Post.base_class
    assert_equal Post, SpecialPost.base_class
    assert_equal Post, StiPost.base_class
    assert_equal SubStiPost, SubStiPost.base_class
  end

  def test_descends_from_active_record
    # Tries to call Object.abstract_class?
    assert_raise(NoMethodError) do
      ActiveRecord::Base.descends_from_active_record?
    end

    # Abstract subclass of AR::Base.
    assert LoosePerson.descends_from_active_record?

    # Concrete subclass of an abstract class.
    assert LooseDescendant.descends_from_active_record?

    # Concrete subclass of AR::Base.
    assert TightPerson.descends_from_active_record?

    # Concrete subclass of a concrete class but has no type column.
    assert TightDescendant.descends_from_active_record?

    # Concrete subclass of AR::Base.
    assert Post.descends_from_active_record?

    # Abstract subclass of a concrete class which has a type column.
    # This is pathological, as you'll never have Sub < Abstract < Concrete.
    assert !StiPost.descends_from_active_record?

    # Concrete subclasses an abstract class which has a type column.
    assert !SubStiPost.descends_from_active_record?
  end

  def test_find_on_abstract_base_class_doesnt_use_type_condition
    old_class = LooseDescendant
    Object.send :remove_const, :LooseDescendant

    descendant = old_class.create! :first_name => 'bob'
    assert_not_nil LoosePerson.find(descendant.id), "Should have found instance of LooseDescendant when finding abstract LoosePerson: #{descendant.inspect}"
  ensure
    unless Object.const_defined?(:LooseDescendant)
      Object.const_set :LooseDescendant, old_class
    end
  end

  def test_assert_queries
    query = lambda { ActiveRecord::Base.connection.execute 'select count(*) from developers' }
    assert_queries(2) { 2.times { query.call } }
    assert_queries 1, &query
    assert_no_queries { assert true }
  end

  def test_to_xml
    xml = REXML::Document.new(topics(:first).to_xml(:indent => 0))
    bonus_time_in_current_timezone = topics(:first).bonus_time.xmlschema
    written_on_in_current_timezone = topics(:first).written_on.xmlschema
    last_read_in_current_timezone = topics(:first).last_read.xmlschema

    assert_equal "topic", xml.root.name
    assert_equal "The First Topic" , xml.elements["//title"].text
    assert_equal "David" , xml.elements["//author-name"].text

    assert_equal "1", xml.elements["//id"].text
    assert_equal "integer" , xml.elements["//id"].attributes['type']

    assert_equal "1", xml.elements["//replies-count"].text
    assert_equal "integer" , xml.elements["//replies-count"].attributes['type']

    assert_equal written_on_in_current_timezone, xml.elements["//written-on"].text
    assert_equal "datetime" , xml.elements["//written-on"].attributes['type']

    assert_equal "--- Have a nice day\n" , xml.elements["//content"].text
    assert_equal "yaml" , xml.elements["//content"].attributes['type']

    assert_equal "david@loudthinking.com", xml.elements["//author-email-address"].text

    assert_equal nil, xml.elements["//parent-id"].text
    assert_equal "integer", xml.elements["//parent-id"].attributes['type']
    assert_equal "true", xml.elements["//parent-id"].attributes['nil']

    if current_adapter?(:SybaseAdapter, :OracleAdapter)
      assert_equal last_read_in_current_timezone, xml.elements["//last-read"].text
      assert_equal "datetime" , xml.elements["//last-read"].attributes['type']
    else
      assert_equal "2004-04-15", xml.elements["//last-read"].text
      assert_equal "date" , xml.elements["//last-read"].attributes['type']
    end

    # Oracle and DB2 don't have true boolean or time-only fields
    unless current_adapter?(:OracleAdapter, :DB2Adapter)
      assert_equal "false", xml.elements["//approved"].text
      assert_equal "boolean" , xml.elements["//approved"].attributes['type']

      assert_equal bonus_time_in_current_timezone, xml.elements["//bonus-time"].text
      assert_equal "datetime" , xml.elements["//bonus-time"].attributes['type']
    end
  end

  def test_to_xml_skipping_attributes
    xml = topics(:first).to_xml(:indent => 0, :skip_instruct => true, :except => [:title, :replies_count])
    assert_equal "<topic>", xml.first(7)
    assert !xml.include?(%(<title>The First Topic</title>))
    assert xml.include?(%(<author-name>David</author-name>))

    xml = topics(:first).to_xml(:indent => 0, :skip_instruct => true, :except => [:title, :author_name, :replies_count])
    assert !xml.include?(%(<title>The First Topic</title>))
    assert !xml.include?(%(<author-name>David</author-name>))
  end

  def test_to_xml_including_has_many_association
    xml = topics(:first).to_xml(:indent => 0, :skip_instruct => true, :include => :replies, :except => :replies_count)
    assert_equal "<topic>", xml.first(7)
    assert xml.include?(%(<replies type="array"><reply>))
    assert xml.include?(%(<title>The Second Topic of the day</title>))
  end

  def test_array_to_xml_including_has_many_association
    xml = [ topics(:first), topics(:second) ].to_xml(:indent => 0, :skip_instruct => true, :include => :replies)
    assert xml.include?(%(<replies type="array"><reply>))
  end

  def test_array_to_xml_including_methods
    xml = [ topics(:first), topics(:second) ].to_xml(:indent => 0, :skip_instruct => true, :methods => [ :topic_id ])
    assert xml.include?(%(<topic-id type="integer">#{topics(:first).topic_id}</topic-id>)), xml
    assert xml.include?(%(<topic-id type="integer">#{topics(:second).topic_id}</topic-id>)), xml
  end

  def test_array_to_xml_including_has_one_association
    xml = [ companies(:first_firm), companies(:rails_core) ].to_xml(:indent => 0, :skip_instruct => true, :include => :account)
    assert xml.include?(companies(:first_firm).account.to_xml(:indent => 0, :skip_instruct => true))
    assert xml.include?(companies(:rails_core).account.to_xml(:indent => 0, :skip_instruct => true))
  end

  def test_array_to_xml_including_belongs_to_association
    xml = [ companies(:first_client), companies(:second_client), companies(:another_client) ].to_xml(:indent => 0, :skip_instruct => true, :include => :firm)
    assert xml.include?(companies(:first_client).to_xml(:indent => 0, :skip_instruct => true))
    assert xml.include?(companies(:second_client).firm.to_xml(:indent => 0, :skip_instruct => true))
    assert xml.include?(companies(:another_client).firm.to_xml(:indent => 0, :skip_instruct => true))
  end

  def test_to_xml_including_belongs_to_association
    xml = companies(:first_client).to_xml(:indent => 0, :skip_instruct => true, :include => :firm)
    assert !xml.include?("<firm>")

    xml = companies(:second_client).to_xml(:indent => 0, :skip_instruct => true, :include => :firm)
    assert xml.include?("<firm>")
  end

  def test_to_xml_including_multiple_associations
    xml = companies(:first_firm).to_xml(:indent => 0, :skip_instruct => true, :include => [ :clients, :account ])
    assert_equal "<firm>", xml.first(6)
    assert xml.include?(%(<account>))
    assert xml.include?(%(<clients type="array"><client>))
  end

  def test_to_xml_including_multiple_associations_with_options
    xml = companies(:first_firm).to_xml(
      :indent  => 0, :skip_instruct => true,
      :include => { :clients => { :only => :name } }
    )

    assert_equal "<firm>", xml.first(6)
    assert xml.include?(%(<client><name>Summit</name></client>))
    assert xml.include?(%(<clients type="array"><client>))
  end

  def test_to_xml_including_methods
    xml = Company.new.to_xml(:methods => :arbitrary_method, :skip_instruct => true)
    assert_equal "<company>", xml.first(9)
    assert xml.include?(%(<arbitrary-method>I am Jack's profound disappointment</arbitrary-method>))
  end

  def test_to_xml_with_block
    value = "Rockin' the block"
    xml = Company.new.to_xml(:skip_instruct => true) do |xml|
      xml.tag! "arbitrary-element", value
    end
    assert_equal "<company>", xml.first(9)
    assert xml.include?(%(<arbitrary-element>#{value}</arbitrary-element>))
  end

  def test_type_name_with_module_should_handle_beginning
    assert_equal 'ActiveRecord::Person', ActiveRecord::Base.send(:type_name_with_module, 'Person')
    assert_equal '::Person', ActiveRecord::Base.send(:type_name_with_module, '::Person')
  end

  def test_to_param_should_return_string
    assert_kind_of String, Client.find(:first).to_param
  end

  def test_inspect_class
    assert_equal 'ActiveRecord::Base', ActiveRecord::Base.inspect
    assert_equal 'LoosePerson(abstract)', LoosePerson.inspect
    assert_match(/^Topic\(id: integer, title: string/, Topic.inspect)
  end

  def test_inspect_instance
    topic = topics(:first)
    assert_equal %(#<Topic id: 1, title: "The First Topic", author_name: "David", author_email_address: "david@loudthinking.com", written_on: "#{topic.written_on.to_s(:db)}", bonus_time: "#{topic.bonus_time.to_s(:db)}", last_read: "#{topic.last_read.to_s(:db)}", content: "Have a nice day", approved: false, replies_count: 1, parent_id: nil, type: nil>), topic.inspect
  end

  def test_inspect_new_instance
    assert_match /Topic id: nil/, Topic.new.inspect
  end

  def test_inspect_limited_select_instance
    assert_equal %(#<Topic id: 1>), Topic.find(:first, :select => 'id', :conditions => 'id = 1').inspect
    assert_equal %(#<Topic id: 1, title: "The First Topic">), Topic.find(:first, :select => 'id, title', :conditions => 'id = 1').inspect
  end

  def test_inspect_class_without_table
    assert_equal "NonExistentTable(Table doesn't exist)", NonExistentTable.inspect
  end

  def test_attribute_for_inspect
    t = topics(:first)
    t.title = "The First Topic Now Has A Title With\nNewlines And More Than 50 Characters"

    assert_equal %("#{t.written_on.to_s(:db)}"), t.attribute_for_inspect(:written_on)
    assert_equal '"The First Topic Now Has A Title With\nNewlines And M..."', t.attribute_for_inspect(:title)
  end

  def test_becomes
    assert_kind_of Reply, topics(:first).becomes(Reply)
    assert_equal "The First Topic", topics(:first).becomes(Reply).title
  end

  def test_silence_sets_log_level_to_error_in_block
    original_logger = ActiveRecord::Base.logger
    log = StringIO.new
    ActiveRecord::Base.logger = Logger.new(log)
    ActiveRecord::Base.logger.level = Logger::DEBUG
    ActiveRecord::Base.silence do
      ActiveRecord::Base.logger.warn "warn"
      ActiveRecord::Base.logger.error "error"
    end
    assert_equal "error\n", log.string
  ensure
    ActiveRecord::Base.logger = original_logger
  end

  def test_silence_sets_log_level_back_to_level_before_yield
    original_logger = ActiveRecord::Base.logger
    log = StringIO.new
    ActiveRecord::Base.logger = Logger.new(log)
    ActiveRecord::Base.logger.level = Logger::WARN
    ActiveRecord::Base.silence do
    end
    assert_equal Logger::WARN, ActiveRecord::Base.logger.level
  ensure
    ActiveRecord::Base.logger = original_logger
  end

  def test_benchmark_with_log_level
    original_logger = ActiveRecord::Base.logger
    log = StringIO.new
    ActiveRecord::Base.logger = Logger.new(log)
    ActiveRecord::Base.logger.level = Logger::WARN
    ActiveRecord::Base.benchmark("Debug Topic Count", Logger::DEBUG) { Topic.count }
    ActiveRecord::Base.benchmark("Warn Topic Count",  Logger::WARN)  { Topic.count }
    ActiveRecord::Base.benchmark("Error Topic Count", Logger::ERROR) { Topic.count }
    assert_no_match /Debug Topic Count/, log.string
    assert_match /Warn Topic Count/, log.string
    assert_match /Error Topic Count/, log.string
  ensure
    ActiveRecord::Base.logger = original_logger
  end

  def test_benchmark_with_use_silence
    original_logger = ActiveRecord::Base.logger
    log = StringIO.new
    ActiveRecord::Base.logger = Logger.new(log)
    ActiveRecord::Base.benchmark("Logging", Logger::DEBUG, true) { ActiveRecord::Base.logger.debug "Loud" }
    ActiveRecord::Base.benchmark("Logging", Logger::DEBUG, false)  { ActiveRecord::Base.logger.debug "Quiet" }
    assert_no_match /Loud/, log.string
    assert_match /Quiet/, log.string
  ensure
    ActiveRecord::Base.logger = original_logger
  end

  def test_create_with_custom_timestamps
    custom_datetime = 1.hour.ago.beginning_of_day

    %w(created_at created_on updated_at updated_on).each do |attribute|
      parrot = LiveParrot.create(:name => "colombian", attribute => custom_datetime)
      assert_equal custom_datetime, parrot[attribute]
    end
  end
end
