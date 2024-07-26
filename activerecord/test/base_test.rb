require 'abstract_unit'
require 'fixtures/topic'
require 'fixtures/reply'
require 'fixtures/company'

class Category < ActiveRecord::Base; end
class Smarts < ActiveRecord::Base; end
class CreditCard < ActiveRecord::Base; end
class MasterCreditCard < ActiveRecord::Base; end

class LoosePerson < ActiveRecord::Base
  attr_protected :credit_rating, :administrator
end

class TightPerson < ActiveRecord::Base
  attr_accessible :name, :address
end

class TightDescendent < TightPerson
  attr_accessible :phone_number
end

class Booleantest < ActiveRecord::Base; end

class BasicsTest < Test::Unit::TestCase
  def setup
    @topic_fixtures = create_fixtures "topics"
  end

  def test_set_attributes
    topic = Topic.find(1)
    topic.attributes = { "title" => "Budget", "author_name" => "Jason" }
    topic.save
    assert_equal("Budget", topic.title)
    assert_equal("Jason", topic.author_name)
    assert_equal(@topic_fixtures["first"]["author_email_address"], Topic.find(1).author_email_address)
  end
  
  def test_set_attributes_with_block
    topic = Topic.new do |t|
      t.title       = "Budget"
      t.author_name = "Jason"
    end

    assert_equal("Budget", topic.title)
    assert_equal("Jason", topic.author_name)
  end
  
  def test_array_content
    topic = Topic.new
    topic.content = %w( one two three )
    topic.save

    assert_equal(%w( one two three ), Topic.find(topic.id).content)
  end

  def test_hash_content
    topic = Topic.new
    topic.content = { "one" => 1, "two" => 2 }
    topic.save

    assert_equal 2, Topic.find(topic.id).content["two"]
    
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
  
  def test_create
    topic = Topic.new
    topic.title = "New Topic"
    topic.save
    id = topic.id
    topicReloaded = Topic.find(id)
    assert_equal("New Topic", topicReloaded.title)
  end
  
  def test_create_through_factory
    topic = Topic.create("title" => "New Topic")
    topicReloaded = Topic.find(topic.id)
    assert_equal(topic, topicReloaded)
  end

  def test_update
    topic = Topic.new
    topic.title = "Another New Topic"
    topic.written_on = "2003-12-12 23:23"
    topic.save
    id = topic.id
    assert_equal(id, topic.id)
    
    topicReloaded = Topic.find(id)
    assert_equal("Another New Topic", topicReloaded.title)

    topicReloaded.title = "Updated topic"
    topicReloaded.save
    
    topicReloadedAgain = Topic.find(id)
    
    assert_equal("Updated topic", topicReloadedAgain.title)
  end

  def test_preserving_objects
    assert_kind_of(
      Time, Topic.find(1).written_on,
      "The written_on attribute should be of the Time class"
    )

    assert_kind_of(
      Date, Topic.find(1).last_read, 
      "The last_read attribute should be of the Date class"
    )
  end
  
  def test_destroy
    topic = Topic.new
    topic.title = "Yet Another New Topic"
    topic.written_on = "2003-12-12 23:23"
    topic.save
    id = topic.id
    topic.destroy
    
    assert_raises(ActiveRecord::RecordNotFound) { topicReloaded = Topic.find(id) }
  end
  
  def test_record_not_found_exception
    assert_raises(ActiveRecord::RecordNotFound) { topicReloaded = Topic.find(id) }
  end
  
  def test_initialize_with_attributes
    topic = Topic.new({ 
      "title" => "initialized from attributes", "written_on" => "2003-12-12 23:23"
    })
    
    assert_equal("initialized from attributes", topic.title)
  end
  
  def test_load
    topics = Topic.find_all nil, "id"    
    assert_equal(2, topics.size)
    assert_equal(@topic_fixtures["first"]["title"], topics.first.title)
  end
  
  def test_load_with_condition
    topics = Topic.find_all "author_name = 'Mary'"
    
    assert_equal(1, topics.size)
    assert_equal(@topic_fixtures["second"]["title"], topics.first.title)
  end

  def test_table_name_guesses
    assert_equal "topics", Topic.table_name
    
    assert_equal "categories", Category.table_name
    assert_equal "smarts", Smarts.table_name
    assert_equal "credit_cards", CreditCard.table_name
    assert_equal "master_credit_cards", MasterCreditCard.table_name

    ActiveRecord::Base.pluralize_table_names = false
    assert_equal "category", Category.table_name
    assert_equal "smarts", Smarts.table_name
    assert_equal "credit_card", CreditCard.table_name
    assert_equal "master_credit_card", MasterCreditCard.table_name
    ActiveRecord::Base.pluralize_table_names = true

    ActiveRecord::Base.table_name_prefix = "test_"
    assert_equal "test_categories", Category.table_name
    ActiveRecord::Base.table_name_suffix = "_test"
    assert_equal "test_categories_test", Category.table_name
    ActiveRecord::Base.table_name_prefix = ""
    assert_equal "categories_test", Category.table_name
    ActiveRecord::Base.table_name_suffix = ""
    assert_equal "categories", Category.table_name

    ActiveRecord::Base.pluralize_table_names = false
    ActiveRecord::Base.table_name_prefix = "test_"
    assert_equal "test_category", Category.table_name
    ActiveRecord::Base.table_name_suffix = "_test"
    assert_equal "test_category_test", Category.table_name
    ActiveRecord::Base.table_name_prefix = ""
    assert_equal "category_test", Category.table_name
    ActiveRecord::Base.table_name_suffix = ""
    assert_equal "category", Category.table_name
    ActiveRecord::Base.pluralize_table_names = true
  end
  
  def test_destroy_all
    assert_equal(2, Topic.find_all.size)

    Topic.destroy_all "author_name = 'Mary'"
    assert_equal(1, Topic.find_all.size)
  end
  
  def test_boolean_attributes
    assert ! Topic.find(1).approved?
    assert Topic.find(2).approved?
  end
  
  def test_increment_counter
    Topic.increment_counter("reply_count", 1)
    assert_equal 1, Topic.find(1).reply_count

    Topic.increment_counter("reply_count", 1)
    assert_equal 2, Topic.find(1).reply_count
  end
  
  def test_decrement_counter
    Topic.decrement_counter("reply_count", 2)
    assert_equal 1, Topic.find(2).reply_count

    Topic.decrement_counter("reply_count", 2)
    assert_equal 0, Topic.find(1).reply_count
  end
  
  def test_update_all
    Topic.update_all "content = 'bulk updated!'"
    assert_equal "bulk updated!", Topic.find(1).content
    assert_equal "bulk updated!", Topic.find(2).content
  end
  
  def test_update_by_condition
    Topic.update_all "content = 'bulk updated!'", "approved = 1"
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
    assert_raises(NoMethodError) { t.title2 }
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
  end
  
  def test_default_values
    topic = Topic.new
    assert_equal 1, topic.approved
    assert_nil topic.written_on
    assert_nil topic.last_read
    
    topic.save

    topic = Topic.find(topic.id)
    assert_equal 1, topic.approved
    assert_nil topic.last_read
  end
  
  def test_default_values_on_empty_strings
    topic = Topic.new
    topic.approved  = nil
    topic.last_read = nil

    topic.save

    topic = Topic.find(topic.id)
    assert_nil topic.last_read
    assert_nil topic.approved
  end
  
  def test_equality
    assert_equal Topic.find(1), Topic.find(2).parent
  end
  
  def test_destroy_new_record
    client = Client.new
    client.destroy
    assert client.frozen?
  end
  
  def test_update_attribute
    assert !Topic.find(1).approved?
    Topic.find(1).update_attribute("approved", true)
    assert Topic.find(1).approved?
  end
  
  def test_mass_assignment_protection
    firm = Firm.new
    firm.attributes = { "name" => "Next Angle", "rating" => 5 }
    assert_equal 1, firm.rating
  end
  
  def test_mass_assignment_accessible
    reply = Reply.new("title" => "hello", "content" => "world", "approved" => 0)
    reply.save
    
    assert_equal 1, reply.approved
    
    reply.approved = 0
    reply.save

    assert_equal 0, reply.approved
  end
  
  def test_mass_assignment_protection_inheritance
    assert_equal [ :credit_rating, :administrator ], LoosePerson.protected_attributes
    assert_nil TightPerson.protected_attributes
  end

  def test_multiparameter_attributes_on_date
    attributes = { "last_read(1i)" => "2004", "last_read(2i)" => "6", "last_read(3i)" => "24" }
    topic = Topic.find(1)
    topic.attributes = attributes
    assert_equal Date.new(2004, 6, 24).to_s, topic.last_read.to_s
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

  def test_boolean
    b_false = Booleantest.create({ "value" => false })
    false_id = b_false.id
    b_true = Booleantest.create({ "value" => true })
    true_id = b_true.id

    b_false = Booleantest.find(false_id)
    assert !b_false.value?
    b_true = Booleantest.find(true_id)
    assert b_true.value?
  end
end
