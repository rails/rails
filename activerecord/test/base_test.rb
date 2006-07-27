require 'abstract_unit'
require 'fixtures/topic'
require 'fixtures/reply'
require 'fixtures/company'
require 'fixtures/customer'
require 'fixtures/developer'
require 'fixtures/project'
require 'fixtures/default'
require 'fixtures/auto_id'
require 'fixtures/column_name'
require 'fixtures/subscriber'
require 'fixtures/keyboard'

class Category < ActiveRecord::Base; end
class Smarts < ActiveRecord::Base; end
class CreditCard < ActiveRecord::Base; end
class MasterCreditCard < ActiveRecord::Base; end
class Post < ActiveRecord::Base; end
class Computer < ActiveRecord::Base; end
class NonExistentTable < ActiveRecord::Base; end
class TestOracleDefault < ActiveRecord::Base; end

class LoosePerson < ActiveRecord::Base
  attr_protected :credit_rating, :administrator
  self.abstract_class = true
end

class LooseDescendant < LoosePerson
  attr_protected :phone_number
end

class TightPerson < ActiveRecord::Base
  attr_accessible :name, :address
end

class TightDescendant < TightPerson
  attr_accessible :phone_number
end

class Booleantest < ActiveRecord::Base; end

class Task < ActiveRecord::Base
  attr_protected :starting
end

class BasicsTest < Test::Unit::TestCase
  fixtures :topics, :companies, :developers, :projects, :computers

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

  def test_reader_generation
    Topic.find(:first).title
    Firm.find(:first).name
    Client.find(:first).name
    if ActiveRecord::Base.generate_read_methods
      assert_readers(Topic,  %w(type replies_count))
      assert_readers(Firm,   %w(type))
      assert_readers(Client, %w(type ruby_type rating?))
    else
      [Topic, Firm, Client].each {|klass| assert_equal klass.read_methods, {}}
    end
  end

  def test_reader_for_invalid_column_names
    # column names which aren't legal ruby ids
    topic = Topic.find(:first)
    topic.send(:define_read_method, "mumub-jumbo".to_sym, "mumub-jumbo", nil)
    assert !Topic.read_methods.include?("mumub-jumbo")
  end

  def test_non_attribute_access_and_assignment
    topic = Topic.new
    assert !topic.respond_to?("mumbo")
    assert_raises(NoMethodError) { topic.mumbo }
    assert_raises(NoMethodError) { topic.mumbo = 5 }
  end

  def test_preserving_date_objects
    # SQL Server doesn't have a separate column type just for dates, so all are returned as time
    return true if current_adapter?(:SQLServerAdapter)

    if current_adapter?(:SybaseAdapter)
      # Sybase ctlib does not (yet?) support the date type; use datetime instead.
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
  end
  
  def test_destroy
    topic = Topic.new
    topic.title = "Yet Another New Topic"
    topic.written_on = "2003-12-12 23:23:00"
    topic.save
    topic.destroy
    assert_raise(ActiveRecord::RecordNotFound) { Topic.find(topic.id) }
  end
  
  def test_destroy_returns_self
    topic = Topic.new("title" => "Yet Another Title")
    assert topic.save
    assert_equal topic, topic.destroy, "destroy did not return destroyed object"
  end
  
  def test_record_not_found_exception
    assert_raises(ActiveRecord::RecordNotFound) { topicReloaded = Topic.find(99999) }
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
    assert_equal(2, topics.size)
    assert_equal(topics(:first).title, topics.first.title)
  end
  
  def test_load_with_condition
    topics = Topic.find(:all, :conditions => "author_name = 'Mary'")
    
    assert_equal(1, topics.size)
    assert_equal(topics(:second).title, topics.first.title)
  end

  def test_table_name_guesses
    assert_equal "topics", Topic.table_name
    
    assert_equal "categories", Category.table_name
    assert_equal "smarts", Smarts.table_name
    assert_equal "credit_cards", CreditCard.table_name
    assert_equal "master_credit_cards", MasterCreditCard.table_name

    ActiveRecord::Base.pluralize_table_names = false
    [Category, Smarts, CreditCard, MasterCreditCard].each{|c| c.reset_table_name}
    assert_equal "category", Category.table_name
    assert_equal "smarts", Smarts.table_name
    assert_equal "credit_card", CreditCard.table_name
    assert_equal "master_credit_card", MasterCreditCard.table_name
    ActiveRecord::Base.pluralize_table_names = true
    [Category, Smarts, CreditCard, MasterCreditCard].each{|c| c.reset_table_name}

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
    [Category, Smarts, CreditCard, MasterCreditCard].each{|c| c.reset_table_name}
  end
  
  def test_destroy_all
    assert_equal 2, Topic.count

    Topic.destroy_all "author_name = 'Mary'"
    assert_equal 1, Topic.count
  end

  def test_destroy_many
    assert_equal 3, Client.count
    Client.destroy([2, 3])
    assert_equal 1, Client.count
  end

  def test_delete_many
    Topic.delete([1, 2])
    assert_equal 0, Topic.count
  end

  def test_boolean_attributes
    assert ! Topic.find(1).approved?
    assert Topic.find(2).approved?
  end
  
  def test_increment_counter
    Topic.increment_counter("replies_count", 1)
    assert_equal 1, Topic.find(1).replies_count

    Topic.increment_counter("replies_count", 1)
    assert_equal 2, Topic.find(1).replies_count
  end
  
  def test_decrement_counter
    Topic.decrement_counter("replies_count", 2)
    assert_equal 1, Topic.find(2).replies_count

    Topic.decrement_counter("replies_count", 2)
    assert_equal 0, Topic.find(1).replies_count
  end
  
  def test_update_all
    # The ADO library doesn't support the number of affected rows
    return true if current_adapter?(:SQLServerAdapter)

    assert_equal 2, Topic.update_all("content = 'bulk updated!'")
    assert_equal "bulk updated!", Topic.find(1).content
    assert_equal "bulk updated!", Topic.find(2).content
    assert_equal 2, Topic.update_all(['content = ?', 'bulk updated again!'])
    assert_equal "bulk updated again!", Topic.find(1).content
    assert_equal "bulk updated again!", Topic.find(2).content
  end

  def test_update_many
    topic_data = { 1 => { "content" => "1 updated" }, 2 => { "content" => "2 updated" } }
    updated = Topic.update(topic_data.keys, topic_data.values)

    assert_equal 2, updated.size
    assert_equal "1 updated", Topic.find(1).content
    assert_equal "2 updated", Topic.find(2).content
  end

  def test_delete_all
    # The ADO library doesn't support the number of affected rows
    return true if current_adapter?(:SQLServerAdapter)

    assert_equal 2, Topic.delete_all
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

  def test_utc_as_time_zone
    # Oracle and SQLServer do not have a TIME datatype.
    return true if current_adapter?(:SQLServerAdapter) || current_adapter?(:OracleAdapter)

    Topic.default_timezone = :utc
    attributes = { "bonus_time" => "5:42:00AM" }
    topic = Topic.find(1)
    topic.attributes = attributes
    assert_equal Time.utc(2000, 1, 1, 5, 42, 0), topic.bonus_time
    Topic.default_timezone = :local
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
    assert_raises(TypeError) { client.name = "something else" }
  end
  
  def test_update_attribute
    assert !Topic.find(1).approved?
    Topic.find(1).update_attribute("approved", true)
    assert Topic.find(1).approved?

    Topic.find(1).update_attribute(:approved, false)
    assert !Topic.find(1).approved?
  end
  
  def test_mass_assignment_protection
    firm = Firm.new
    firm.attributes = { "name" => "Next Angle", "rating" => 5 }
    assert_equal 1, firm.rating
  end

  def test_customized_primary_key_remains_protected
    subscriber = Subscriber.new(:nick => 'webster123', :name => 'nice try')
    assert_nil subscriber.id

    keyboard = Keyboard.new(:key_number => 9, :name => 'nice try')
    assert_nil keyboard.id
  end

  def test_customized_primary_key_remains_protected_when_refered_to_as_id
    subscriber = Subscriber.new(:id => 'webster123', :name => 'nice try')
    assert_nil subscriber.id

    keyboard = Keyboard.new(:id => 9, :name => 'nice try')
    assert_nil keyboard.id
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
    assert_equal [ :credit_rating, :administrator ], LoosePerson.protected_attributes

    assert_nil LooseDescendant.accessible_attributes
    assert_equal [ :credit_rating, :administrator, :phone_number  ], LooseDescendant.protected_attributes

    assert_nil TightPerson.protected_attributes
    assert_equal [ :name, :address ], TightPerson.accessible_attributes

    assert_nil TightDescendant.protected_attributes
    assert_equal [ :name, :address, :phone_number  ], TightDescendant.accessible_attributes
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
    # Oracle and SQL Server do not have a TIME datatype.
    return true if current_adapter?(:SQLServerAdapter) || current_adapter?(:OracleAdapter)

    attributes = {
      "bonus_time" => "5:42:00AM"
    }
    topic = Topic.find(1)
    topic.attributes = attributes
    assert_equal Time.local(2000, 1, 1, 5, 42, 0), topic.bonus_time
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

  def test_boolean_cast_from_string
    b_false = Booleantest.create({ "value" => "0" })
    false_id = b_false.id
    b_true = Booleantest.create({ "value" => "1" })
    true_id = b_true.id

    b_false = Booleantest.find(false_id)
    assert !b_false.value?
    b_true = Booleantest.find(true_id)
    assert b_true.value?    
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
    assert_raises(ActiveRecord::RecordNotFound) do
      Topic.find("123456 OR id > 0")
    end

    assert_raises(ActiveRecord::RecordNotFound) do
      Topic.find(";;; this should raise an RecordNotFound error")
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

  MyObject = Struct.new :attribute1, :attribute2
  
  def test_serialized_attribute
    myobj = MyObject.new('value1', 'value2')
    topic = Topic.create("content" => myobj)  
    Topic.serialize("content", MyObject)
    assert_equal(myobj, topic.content)
  end

  def test_serialized_attribute_with_class_constraint
    myobj = MyObject.new('value1', 'value2')
    topic = Topic.create("content" => myobj)
    Topic.serialize(:content, Hash)

    assert_raise(ActiveRecord::SerializationTypeMismatch) { Topic.find(topic.id).content }

    settings = { "color" => "blue" }
    Topic.find(topic.id).update_attribute("content", settings)
    assert_equal(settings, Topic.find(topic.id).content)
    Topic.serialize(:content)
  end

  def test_quote
    author_name = "\\ \001 ' \n \\n \""
    topic = Topic.create('author_name' => author_name)
    assert_equal author_name, Topic.find(topic.id).author_name
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
    assert_equal 0, topics(:first).replies_count
    topics(:first).increment! :replies_count
    assert_equal 1, topics(:first, :reload).replies_count
    
    topics(:first).increment(:replies_count).increment!(:replies_count)
    assert_equal 3, topics(:first, :reload).replies_count
  end
  
  def test_increment_nil_attribute
    assert_nil topics(:first).parent_id
    topics(:first).increment! :parent_id
    assert_equal 1, topics(:first).parent_id
  end
  
  def test_decrement_attribute
    topics(:first).increment(:replies_count).increment!(:replies_count)
    assert_equal 2, topics(:first).replies_count
    
    topics(:first).decrement!(:replies_count)
    assert_equal 1, topics(:first, :reload).replies_count

    topics(:first).decrement(:replies_count).decrement!(:replies_count)
    assert_equal -1, topics(:first, :reload).replies_count
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
    res2 = nil
    assert_nothing_raised do
      res2 = Post.count("posts.#{QUOTED_TYPE} = 'Post'",
                        "LEFT JOIN comments ON posts.id=comments.post_id")
    end
    assert_equal res, res2
    
    res3 = nil
    assert_nothing_raised do
      res3 = Post.count(:conditions => "posts.#{QUOTED_TYPE} = 'Post'",
                        :joins => "LEFT JOIN comments ON posts.id=comments.post_id")
    end
    assert_equal res, res3
    
    res4 = Post.count_by_sql "SELECT COUNT(p.id) FROM posts p, comments c WHERE p.#{QUOTED_TYPE} = 'Post' AND p.id=c.post_id"
    res5 = nil
    assert_nothing_raised do
      res5 = Post.count(:conditions => "p.#{QUOTED_TYPE} = 'Post' AND p.id=c.post_id",
                        :joins => "p, comments c",
                        :select => "p.id")
    end

    assert_equal res4, res5 

    res6 = Post.count_by_sql "SELECT COUNT(DISTINCT p.id) FROM posts p, comments c WHERE p.#{QUOTED_TYPE} = 'Post' AND p.id=c.post_id"
    res7 = nil
    assert_nothing_raised do
      res7 = Post.count(:conditions => "p.#{QUOTED_TYPE} = 'Post' AND p.id=c.post_id",
                        :joins => "p, comments c",
                        :select => "p.id",
                        :distinct => true)
    end
    assert_equal res6, res7
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

     firm.clear_association_cache

     assert_equal    firm.clients.collect{ |x| x.name }.sort, clients.collect{ |x| x.name }.sort
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

  def test_base_class
    assert LoosePerson.abstract_class?
    assert !LooseDescendant.abstract_class?
    assert_equal LoosePerson,     LoosePerson.base_class
    assert_equal LooseDescendant, LooseDescendant.base_class
    assert_equal TightPerson,     TightPerson.base_class
    assert_equal TightPerson,     TightDescendant.base_class
  end

  def test_assert_queries
    query = lambda { ActiveRecord::Base.connection.execute 'select count(*) from developers' }
    assert_queries(2) { 2.times { query.call } }
    assert_queries 1, &query
    assert_no_queries { assert true }
  end

  def test_to_xml
    xml = topics(:first).to_xml(:indent => 0, :skip_instruct => true)
    bonus_time_in_current_timezone = topics(:first).bonus_time.xmlschema
    written_on_in_current_timezone = topics(:first).written_on.xmlschema
    last_read_in_current_timezone = topics(:first).last_read.xmlschema
    assert_equal "<topic>", xml.first(7)
    assert xml.include?(%(<title>The First Topic</title>))
    assert xml.include?(%(<author-name>David</author-name>))
    assert xml.include?(%(<id type="integer">1</id>))
    assert xml.include?(%(<replies-count type="integer">0</replies-count>))
    assert xml.include?(%(<written-on type="datetime">#{written_on_in_current_timezone}</written-on>))
    assert xml.include?(%(<content>Have a nice day</content>))
    assert xml.include?(%(<author-email-address>david@loudthinking.com</author-email-address>))
    assert xml.include?(%(<parent-id></parent-id>))
    if current_adapter?(:SybaseAdapter) or current_adapter?(:SQLServerAdapter)
      assert xml.include?(%(<last-read type="datetime">#{last_read_in_current_timezone}</last-read>))
    else
      assert xml.include?(%(<last-read type="date">2004-04-15</last-read>))
    end
    # Oracle and DB2 don't have true boolean or time-only fields
    unless current_adapter?(:OracleAdapter) || current_adapter?(:DB2Adapter)
      assert xml.include?(%(<approved type="boolean">false</approved>)), "Approved should be a boolean"
      assert xml.include?(%(<bonus-time type="datetime">#{bonus_time_in_current_timezone}</bonus-time>))
    end
  end
  
  def test_to_xml_skipping_attributes
    xml = topics(:first).to_xml(:indent => 0, :skip_instruct => true, :except => :title)
    assert_equal "<topic>", xml.first(7)
    assert !xml.include?(%(<title>The First Topic</title>))
    assert xml.include?(%(<author-name>David</author-name>))    

    xml = topics(:first).to_xml(:indent => 0, :skip_instruct => true, :except => [ :title, :author_name ])
    assert !xml.include?(%(<title>The First Topic</title>))
    assert !xml.include?(%(<author-name>David</author-name>))    
  end
  
  def test_to_xml_including_has_many_association
    xml = topics(:first).to_xml(:indent => 0, :skip_instruct => true, :include => :replies)
    assert_equal "<topic>", xml.first(7)
    assert xml.include?(%(<replies><reply>))
    assert xml.include?(%(<title>The Second Topic's of the day</title>))
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
    assert xml.include?(%(<clients><client>))
  end

  def test_to_xml_including_multiple_associations_with_options
    xml = companies(:first_firm).to_xml(
      :indent  => 0, :skip_instruct => true, 
      :include => { :clients => { :only => :name } }
    )
    
    assert_equal "<firm>", xml.first(6)
    assert xml.include?(%(<client><name>Summit</name></client>))
    assert xml.include?(%(<clients><client>))
  end
  
  def test_except_attributes
    assert_equal(
      %w( author_name type id approved replies_count bonus_time written_on content author_email_address parent_id last_read), 
      topics(:first).attributes(:except => :title).keys
    )

    assert_equal(
      %w( replies_count bonus_time written_on content author_email_address parent_id last_read), 
      topics(:first).attributes(:except => [ :title, :id, :type, :approved, :author_name ]).keys
    )
  end
  
  def test_include_attributes
    assert_equal(%w( title ), topics(:first).attributes(:only => :title).keys)
    assert_equal(%w( title author_name type id approved ), topics(:first).attributes(:only => [ :title, :id, :type, :approved, :author_name ]).keys)
  end
  
  def test_type_name_with_module_should_handle_beginning
    assert_equal 'ActiveRecord::Person', ActiveRecord::Base.send(:type_name_with_module, 'Person')
    assert_equal '::Person', ActiveRecord::Base.send(:type_name_with_module, '::Person')
  end

  # FIXME: this test ought to run, but it needs to run sandboxed so that it
  # doesn't b0rk the current test environment by undefing everything.
  #
  #def test_dev_mode_memory_leak
  #  counts = []
  #  2.times do
  #    require_dependency 'fixtures/company'
  #    Firm.find(:first)
  #    Dependencies.clear
  #    ActiveRecord::Base.reset_subclasses
  #    Dependencies.remove_subclasses_for(ActiveRecord::Base)
  #
  #    GC.start
  #    
  #    count = 0
  #    ObjectSpace.each_object(Proc) { count += 1 }
  #    counts << count
  #  end
  #  assert counts.last <= counts.first,
  #    "expected last count (#{counts.last}) to be <= first count (#{counts.first})"
  #end
  
  private
    def assert_readers(model, exceptions)
      expected_readers = Set.new(model.column_names - (model.serialized_attributes.keys + ['id']))
      expected_readers += expected_readers.map { |col| "#{col}?" }
      expected_readers -= exceptions
      assert_equal expected_readers, model.read_methods
    end
end
