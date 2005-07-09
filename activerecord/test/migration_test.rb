require 'abstract_unit'
require 'fixtures/person'
require File.dirname(__FILE__) + '/fixtures/migrations/1_people_have_last_names'
require File.dirname(__FILE__) + '/fixtures/migrations/2_we_need_reminders'

if ActiveRecord::Base.connection.supports_migrations? 

  class Reminder < ActiveRecord::Base; end

  class MigrationTest < Test::Unit::TestCase
    def setup
    end

    def teardown
      ActiveRecord::Base.connection.initialize_schema_information
      ActiveRecord::Base.connection.update "UPDATE schema_info SET version = 0"

      Reminder.connection.drop_table("reminders") rescue nil
      Reminder.connection.drop_table("people_reminders") rescue nil
      Reminder.reset_column_information

      Person.connection.remove_column("people", "last_name") rescue nil
      Person.connection.remove_column("people", "bio") rescue nil
      Person.connection.remove_column("people", "age") rescue nil
      Person.connection.remove_column("people", "height") rescue nil
      Person.connection.remove_column("people", "birthday") rescue nil
      Person.connection.remove_column("people", "favorite_day") rescue nil
      Person.connection.remove_column("people", "male") rescue nil
      Person.connection.remove_column("people", "administrator") rescue nil
      Person.reset_column_information
    end
    
    def test_add_index
      Person.connection.add_column "people", "last_name", :string        
      
      assert_nothing_raised { Person.connection.add_index("people", "last_name") }
      assert_nothing_raised { Person.connection.remove_index("people", "last_name") }

      assert_nothing_raised { Person.connection.add_index("people", ["last_name", "first_name"]) }
      assert_nothing_raised { Person.connection.remove_index("people", "last_name") }
    end
  
    def test_native_types
      Person.delete_all
      Person.connection.add_column "people", "last_name", :string
      Person.connection.add_column "people", "bio", :text
      Person.connection.add_column "people", "age", :integer
      Person.connection.add_column "people", "height", :float
      Person.connection.add_column "people", "birthday", :datetime
      Person.connection.add_column "people", "favorite_day", :date
      Person.connection.add_column "people", "male", :boolean
      assert_nothing_raised { Person.create :first_name => 'bob', :last_name => 'bobsen', :bio => "I was born ....", :age => 18, :height => 1.78, :birthday => 18.years.ago, :favorite_day => 10.days.ago, :male => true }
      bob = Person.find(:first)
        
      assert_equal bob.first_name, 'bob'
      assert_equal bob.last_name, 'bobsen'
      assert_equal bob.bio, "I was born ...."
      assert_equal bob.age, 18
      assert_equal bob.male?, true
    
      assert_equal String, bob.first_name.class
      assert_equal String, bob.last_name.class
      assert_equal String, bob.bio.class
      assert_equal Fixnum, bob.age.class
      assert_equal Time, bob.birthday.class
      assert_equal Date, bob.favorite_day.class
      assert_equal TrueClass, bob.male?.class
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
    
    def test_add_rename
      Person.delete_all
            
      Person.connection.add_column "people", "girlfriend", :string      
      Person.create :girlfriend => 'bobette'      
      
      begin
        Person.connection.rename_column "people", "girlfriend", "exgirlfriend"
      
        Person.reset_column_information      
        bob = Person.find(:first)
      
        assert_equal "bobette", bob.exgirlfriend
      ensure
        Person.connection.remove_column("people", "girlfriend") rescue nil
        Person.connection.remove_column("people", "exgirlfriend") rescue nil
      end
      
    end
    
    def test_change_column
      Person.connection.add_column "people", "bio", :string
      assert_nothing_raised { Person.connection.change_column "people", "bio", :text }
    end    

    def test_change_column_with_new_default
      Person.connection.add_column "people", "administrator", :boolean, :default => 1
      Person.reset_column_information            
      assert Person.new.administrator?
      
      assert_nothing_raised { Person.connection.change_column "people", "administrator", :boolean, :default => 0 }
      Person.reset_column_information            
      assert !Person.new.administrator?
    end    

    def test_add_table
      assert_raises(ActiveRecord::StatementInvalid) { Reminder.column_methods_hash }
    
      WeNeedReminders.up
    
      assert Reminder.create("content" => "hello world", "remind_at" => Time.now)
      assert_equal "hello world", Reminder.find(:first).content
    
      WeNeedReminders.down
      assert_raises(ActiveRecord::StatementInvalid) { Reminder.find(:first) }
    end

    def test_migrator
      assert !Person.column_methods_hash.include?(:last_name)
      assert_raises(ActiveRecord::StatementInvalid) { Reminder.column_methods_hash }

      ActiveRecord::Migrator.up(File.dirname(__FILE__) + '/fixtures/migrations/')

      assert_equal 3, ActiveRecord::Migrator.current_version
      Person.reset_column_information
      assert Person.column_methods_hash.include?(:last_name)
      assert Reminder.create("content" => "hello world", "remind_at" => Time.now)
      assert_equal "hello world", Reminder.find(:first).content

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
      assert_equal "hello world", Reminder.find(:first).content
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
    
    def test_migrator_going_down_due_to_version_target
      ActiveRecord::Migrator.up(File.dirname(__FILE__) + '/fixtures/migrations/', 1)
      ActiveRecord::Migrator.migrate(File.dirname(__FILE__) + '/fixtures/migrations/', 0)

      assert !Person.column_methods_hash.include?(:last_name)
      assert_raises(ActiveRecord::StatementInvalid) { Reminder.column_methods_hash }

      ActiveRecord::Migrator.migrate(File.dirname(__FILE__) + '/fixtures/migrations/')

      Person.reset_column_information
      assert Person.column_methods_hash.include?(:last_name)
      assert Reminder.create("content" => "hello world", "remind_at" => Time.now)
      assert_equal "hello world", Reminder.find(:first).content
    end
  end
end