require 'abstract_unit'
require 'fixtures/person'
require File.dirname(__FILE__) + '/fixtures/migrations/1_people_have_last_names'
require File.dirname(__FILE__) + '/fixtures/migrations/2_we_need_reminders'

class Reminder < ActiveRecord::Base; end

class MigrationTest < Test::Unit::TestCase
  def setup
  end

  def teardown
    ActiveRecord::Base.connection.initialize_schema_information
    ActiveRecord::Base.connection.update "UPDATE schema_info SET version = 0"

    Reminder.connection.drop_table("reminders") rescue nil
    Reminder.reset_column_information

    Person.connection.remove_column("people", "last_name") rescue nil
    Person.reset_column_information
  end

  def test_add_remove_single_field
    assert !Person.column_methods_hash.include?(:last_name)

    PeopleHaveLastNames.up

    Person.reset_column_information
    assert Person.column_methods_hash.include?(:last_name)
    
    PeopleHaveLastNames.down

    Person.reset_column_information
    assert !Person.column_methods_hash.include?(:last_name)
  end

  def test_add_table
    assert_raises(ActiveRecord::StatementInvalid) { Reminder.column_methods_hash }
    
    WeNeedReminders.up
    
    assert Reminder.create("content" => "hello world", "remind_at" => Time.now)
    assert "hello world", Reminder.find(:first)
    
    WeNeedReminders.down
    assert_raises(ActiveRecord::StatementInvalid) { Reminder.find(:first) }
  end

  def test_migrator
    assert !Person.column_methods_hash.include?(:last_name)
    assert_raises(ActiveRecord::StatementInvalid) { Reminder.column_methods_hash }

    ActiveRecord::Migrator.up(File.dirname(__FILE__) + '/fixtures/migrations/')

    assert_equal 2, ActiveRecord::Migrator.current_version
    Person.reset_column_information
    assert Person.column_methods_hash.include?(:last_name)
    assert Reminder.create("content" => "hello world", "remind_at" => Time.now)
    assert "hello world", Reminder.find(:first)


    ActiveRecord::Migrator.down(File.dirname(__FILE__) + '/fixtures/migrations/')

    assert_equal 0, ActiveRecord::Migrator.current_version
    Person.reset_column_information
    assert !Person.column_methods_hash.include?(:last_name)
    assert_raises(ActiveRecord::StatementInvalid) { Reminder.find(:first) }
  end

  def test_migrator_one_up
    assert !Person.column_methods_hash.include?(:last_name)
    assert_raises(ActiveRecord::StatementInvalid) { Reminder.column_methods_hash }

    ActiveRecord::Migrator.up(File.dirname(__FILE__) + '/fixtures/migrations/', 1)

    Person.reset_column_information
    assert Person.column_methods_hash.include?(:last_name)
    assert_raises(ActiveRecord::StatementInvalid) { Reminder.column_methods_hash }


    ActiveRecord::Migrator.up(File.dirname(__FILE__) + '/fixtures/migrations/', 2)

    assert Reminder.create("content" => "hello world", "remind_at" => Time.now)
    assert "hello world", Reminder.find(:first)
  end
  
  def test_migrator_one_down
    ActiveRecord::Migrator.up(File.dirname(__FILE__) + '/fixtures/migrations/')
    
    ActiveRecord::Migrator.down(File.dirname(__FILE__) + '/fixtures/migrations/', 1)

    Person.reset_column_information
    assert Person.column_methods_hash.include?(:last_name)
    assert_raises(ActiveRecord::StatementInvalid) { Reminder.column_methods_hash }
  end
  
  def test_migrator_one_up_one_down
    ActiveRecord::Migrator.up(File.dirname(__FILE__) + '/fixtures/migrations/', 1)
    ActiveRecord::Migrator.down(File.dirname(__FILE__) + '/fixtures/migrations/', 0)

    assert !Person.column_methods_hash.include?(:last_name)
    assert_raises(ActiveRecord::StatementInvalid) { Reminder.column_methods_hash }
  end
end
