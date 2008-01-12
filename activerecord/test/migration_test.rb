require 'abstract_unit'
require 'bigdecimal/util'

require 'fixtures/person'
require 'fixtures/topic'
require File.dirname(__FILE__) + '/fixtures/migrations/1_people_have_last_names'
require File.dirname(__FILE__) + '/fixtures/migrations/2_we_need_reminders'
require File.dirname(__FILE__) + '/fixtures/migrations_with_decimal/1_give_me_big_numbers'

if ActiveRecord::Base.connection.supports_migrations?
  class BigNumber < ActiveRecord::Base; end

  class Reminder < ActiveRecord::Base; end

  class ActiveRecord::Migration
    class <<self
      attr_accessor :message_count
      def puts(text="")
        self.message_count ||= 0
        self.message_count += 1
      end
    end
  end

  class MigrationTest < Test::Unit::TestCase
    self.use_transactional_fixtures = false
    
    fixtures :people

    def setup
      ActiveRecord::Migration.verbose = true
      PeopleHaveLastNames.message_count = 0
    end

    def teardown
      ActiveRecord::Base.connection.initialize_schema_information
      ActiveRecord::Base.connection.update "UPDATE #{ActiveRecord::Migrator.schema_info_table_name} SET version = 0"

      %w(reminders people_reminders prefix_reminders_suffix).each do |table|
        Reminder.connection.drop_table(table) rescue nil
      end
      Reminder.reset_column_information

      %w(last_name key bio age height wealth birthday favorite_day
         moment_of_truth male administrator funny).each do |column|
        Person.connection.remove_column('people', column) rescue nil
      end
      Person.connection.remove_column("people", "first_name") rescue nil
      Person.connection.remove_column("people", "middle_name") rescue nil
      Person.connection.add_column("people", "first_name", :string, :limit => 40)
      Person.reset_column_information
    end

    def test_add_index
      # Limit size of last_name and key columns to support Firebird index limitations
      Person.connection.add_column "people", "last_name", :string, :limit => 100
      Person.connection.add_column "people", "key", :string, :limit => 100
      Person.connection.add_column "people", "administrator", :boolean

      assert_nothing_raised { Person.connection.add_index("people", "last_name") }
      assert_nothing_raised { Person.connection.remove_index("people", "last_name") }

      # Orcl nds shrt indx nms.  Sybs 2.
      # OpenBase does not have named indexes.  You must specify a single column name
      unless current_adapter?(:OracleAdapter, :SybaseAdapter, :OpenBaseAdapter)
        assert_nothing_raised { Person.connection.add_index("people", ["last_name", "first_name"]) }
        assert_nothing_raised { Person.connection.remove_index("people", :column => ["last_name", "first_name"]) }
        assert_nothing_raised { Person.connection.add_index("people", ["last_name", "first_name"]) }
        assert_nothing_raised { Person.connection.remove_index("people", :name => "index_people_on_last_name_and_first_name") }
        assert_nothing_raised { Person.connection.add_index("people", ["last_name", "first_name"]) }
        assert_nothing_raised { Person.connection.remove_index("people", "last_name_and_first_name") }
        assert_nothing_raised { Person.connection.add_index("people", ["last_name", "first_name"]) }
        assert_nothing_raised { Person.connection.remove_index("people", ["last_name", "first_name"]) }
      end

      # quoting
      # Note: changed index name from "key" to "key_idx" since "key" is a Firebird reserved word
      # OpenBase does not have named indexes.  You must specify a single column name
      unless current_adapter?(:OpenBaseAdapter)
        assert_nothing_raised { Person.connection.add_index("people", ["key"], :name => "key_idx", :unique => true) }
        assert_nothing_raised { Person.connection.remove_index("people", :name => "key_idx", :unique => true) }
      end
      
      # Sybase adapter does not support indexes on :boolean columns
      # OpenBase does not have named indexes.  You must specify a single column
      unless current_adapter?(:SybaseAdapter, :OpenBaseAdapter)
        assert_nothing_raised { Person.connection.add_index("people", %w(last_name first_name administrator), :name => "named_admin") }
        assert_nothing_raised { Person.connection.remove_index("people", :name => "named_admin") }
      end
    end

    def test_create_table_adds_id
      Person.connection.create_table :testings do |t|
        t.column :foo, :string
      end

      assert_equal %w(foo id),
        Person.connection.columns(:testings).map { |c| c.name }.sort
    ensure
      Person.connection.drop_table :testings rescue nil
    end

    def test_create_table_with_not_null_column
      assert_nothing_raised do
        Person.connection.create_table :testings do |t|
          t.column :foo, :string, :null => false
        end
      end

      assert_raises(ActiveRecord::StatementInvalid) do
        Person.connection.execute "insert into testings (foo) values (NULL)"
      end
    ensure
      Person.connection.drop_table :testings rescue nil
    end

    def test_create_table_with_defaults
      # MySQL doesn't allow defaults on TEXT or BLOB columns.
      mysql = current_adapter?(:MysqlAdapter)

      Person.connection.create_table :testings do |t|
        t.column :one, :string, :default => "hello"
        t.column :two, :boolean, :default => true
        t.column :three, :boolean, :default => false
        t.column :four, :integer, :default => 1
        t.column :five, :text, :default => "hello" unless mysql
      end

      columns = Person.connection.columns(:testings)
      one = columns.detect { |c| c.name == "one" }
      two = columns.detect { |c| c.name == "two" }
      three = columns.detect { |c| c.name == "three" }
      four = columns.detect { |c| c.name == "four" }
      five = columns.detect { |c| c.name == "five" } unless mysql

      assert_equal "hello", one.default
      assert_equal true, two.default
      assert_equal false, three.default
      assert_equal 1, four.default
      assert_equal "hello", five.default unless mysql

    ensure
      Person.connection.drop_table :testings rescue nil
    end

    def test_create_table_with_limits
      assert_nothing_raised do
        Person.connection.create_table :testings do |t|
          t.column :foo, :string, :limit => 255

          t.column :default_int, :integer

          t.column :one_int,   :integer, :limit => 1
          t.column :four_int,  :integer, :limit => 4
          t.column :eight_int, :integer, :limit => 8
        end
      end

      columns = Person.connection.columns(:testings)
      foo = columns.detect { |c| c.name == "foo" }
      assert_equal 255, foo.limit

      default = columns.detect { |c| c.name == "default_int" }
      one     = columns.detect { |c| c.name == "one_int"     }
      four    = columns.detect { |c| c.name == "four_int"    }
      eight   = columns.detect { |c| c.name == "eight_int"   }

      if current_adapter?(:PostgreSQLAdapter)
        assert_equal 'integer', default.sql_type
        assert_equal 'smallint', one.sql_type
        assert_equal 'integer', four.sql_type
        assert_equal 'bigint', eight.sql_type
      elsif current_adapter?(:OracleAdapter)
        assert_equal 'NUMBER(38)', default.sql_type
        assert_equal 'NUMBER(1)', one.sql_type
        assert_equal 'NUMBER(4)', four.sql_type
        assert_equal 'NUMBER(8)', eight.sql_type
      end
    ensure
      Person.connection.drop_table :testings rescue nil
    end

    # SQL Server, Sybase, and SQLite3 will not allow you to add a NOT NULL
    # column to a table without a default value.
    unless current_adapter?(:SQLServerAdapter, :SybaseAdapter, :SQLiteAdapter)
      def test_add_column_not_null_without_default
        Person.connection.create_table :testings do |t|
          t.column :foo, :string
        end
        Person.connection.add_column :testings, :bar, :string, :null => false

        assert_raises(ActiveRecord::StatementInvalid) do
          Person.connection.execute "insert into testings (foo, bar) values ('hello', NULL)"
        end
      ensure
        Person.connection.drop_table :testings rescue nil
      end
    end

    def test_add_column_not_null_with_default
      Person.connection.create_table :testings do |t|
        t.column :foo, :string
      end
      
      con = Person.connection     
      Person.connection.enable_identity_insert("testings", true) if current_adapter?(:SybaseAdapter)
      Person.connection.execute "insert into testings (#{con.quote_column_name('id')}, #{con.quote_column_name('foo')}) values (1, 'hello')"
      Person.connection.enable_identity_insert("testings", false) if current_adapter?(:SybaseAdapter)
      assert_nothing_raised {Person.connection.add_column :testings, :bar, :string, :null => false, :default => "default" }

      assert_raises(ActiveRecord::StatementInvalid) do
        unless current_adapter?(:OpenBaseAdapter)
          Person.connection.execute "insert into testings (#{con.quote_column_name('id')}, #{con.quote_column_name('foo')}, #{con.quote_column_name('bar')}) values (2, 'hello', NULL)"
        else
          Person.connection.insert("INSERT INTO testings (#{con.quote_column_name('id')}, #{con.quote_column_name('foo')}, #{con.quote_column_name('bar')}) VALUES (2, 'hello', NULL)",
            "Testing Insert","id",2)
        end
      end
    ensure
      Person.connection.drop_table :testings rescue nil
    end

    # We specifically do a manual INSERT here, and then test only the SELECT
    # functionality. This allows us to more easily catch INSERT being broken,
    # but SELECT actually working fine.
    def test_native_decimal_insert_manual_vs_automatic
      correct_value = '0012345678901234567890.0123456789'.to_d

      Person.delete_all
      Person.connection.add_column "people", "wealth", :decimal, :precision => '30', :scale => '10'
      Person.reset_column_information

      # Do a manual insertion
      if current_adapter?(:OracleAdapter)
        Person.connection.execute "insert into people (id, wealth) values (people_seq.nextval, 12345678901234567890.0123456789)"
      elsif current_adapter?(:OpenBaseAdapter)
        Person.connection.execute "insert into people (wealth) values ('12345678901234567890.0123456789')"
      else
        Person.connection.execute "insert into people (wealth) values (12345678901234567890.0123456789)"
      end

      # SELECT
      row = Person.find(:first)
      assert_kind_of BigDecimal, row.wealth

      # If this assert fails, that means the SELECT is broken!
      unless current_adapter?(:SQLite3Adapter)
        assert_equal correct_value, row.wealth
      end

      # Reset to old state
      Person.delete_all

      # Now use the Rails insertion
      assert_nothing_raised { Person.create :wealth => BigDecimal.new("12345678901234567890.0123456789") }

      # SELECT
      row = Person.find(:first)
      assert_kind_of BigDecimal, row.wealth

      # If these asserts fail, that means the INSERT (create function, or cast to SQL) is broken!
      unless current_adapter?(:SQLite3Adapter)
        assert_equal correct_value, row.wealth
      end

      # Reset to old state
      Person.connection.del_column "people", "wealth" rescue nil
      Person.reset_column_information
    end

    def test_native_types
      Person.delete_all
      Person.connection.add_column "people", "last_name", :string
      Person.connection.add_column "people", "bio", :text
      Person.connection.add_column "people", "age", :integer
      Person.connection.add_column "people", "height", :float
      Person.connection.add_column "people", "wealth", :decimal, :precision => '30', :scale => '10'
      Person.connection.add_column "people", "birthday", :datetime
      Person.connection.add_column "people", "favorite_day", :date
      Person.connection.add_column "people", "moment_of_truth", :datetime
      Person.connection.add_column "people", "male", :boolean
      Person.reset_column_information

      assert_nothing_raised do
        Person.create :first_name => 'bob', :last_name => 'bobsen',
          :bio => "I was born ....", :age => 18, :height => 1.78,
          :wealth => BigDecimal.new("12345678901234567890.0123456789"),
          :birthday => 18.years.ago, :favorite_day => 10.days.ago,
          :moment_of_truth => "1782-10-10 21:40:18", :male => true
      end

      bob = Person.find(:first)
      assert_equal 'bob', bob.first_name
      assert_equal 'bobsen', bob.last_name
      assert_equal "I was born ....", bob.bio
      assert_equal 18, bob.age

      # Test for 30 significent digits (beyond the 16 of float), 10 of them
      # after the decimal place.
     
      unless current_adapter?(:SQLite3Adapter)
        assert_equal BigDecimal.new("0012345678901234567890.0123456789"), bob.wealth
      end
      
      assert_equal true, bob.male?

      assert_equal String, bob.first_name.class
      assert_equal String, bob.last_name.class
      assert_equal String, bob.bio.class
      assert_equal Fixnum, bob.age.class
      assert_equal Time, bob.birthday.class

      if current_adapter?(:SQLServerAdapter, :OracleAdapter, :SybaseAdapter)
        # Sybase, and Oracle don't differentiate between date/time
        assert_equal Time, bob.favorite_day.class
      else
        assert_equal Date, bob.favorite_day.class
      end

      # Test DateTime column and defaults, including timezone.
      # FIXME: moment of truth may be Time on 64-bit platforms.
      if bob.moment_of_truth.is_a?(DateTime)
        assert_equal DateTime.now.offset, bob.moment_of_truth.offset
        assert_not_equal 0, bob.moment_of_truth.offset
        assert_not_equal "Z", bob.moment_of_truth.zone
        assert_equal DateTime::ITALY, bob.moment_of_truth.start
      end

      assert_equal TrueClass, bob.male?.class
      assert_kind_of BigDecimal, bob.wealth
    end

    if current_adapter?(:MysqlAdapter)
      def test_unabstracted_database_dependent_types
        Person.delete_all

        ActiveRecord::Migration.add_column :people, :intelligence_quotient, :tinyint
        Person.reset_column_information
        Person.create :intelligence_quotient => 300
        jonnyg = Person.find(:first) 
        assert_equal 127, jonnyg.intelligence_quotient
        jonnyg.destroy
      ensure
        ActiveRecord::Migration.remove_column :people, :intelligence_quotient rescue nil
      end
    end

    def test_add_remove_single_field_using_string_arguments
      assert !Person.column_methods_hash.include?(:last_name)

      ActiveRecord::Migration.add_column 'people', 'last_name', :string

      Person.reset_column_information
      assert Person.column_methods_hash.include?(:last_name)

      ActiveRecord::Migration.remove_column 'people', 'last_name'

      Person.reset_column_information
      assert !Person.column_methods_hash.include?(:last_name)
    end

    def test_add_remove_single_field_using_symbol_arguments
      assert !Person.column_methods_hash.include?(:last_name)

      ActiveRecord::Migration.add_column :people, :last_name, :string

      Person.reset_column_information
      assert Person.column_methods_hash.include?(:last_name)

      ActiveRecord::Migration.remove_column :people, :last_name

      Person.reset_column_information
      assert !Person.column_methods_hash.include?(:last_name)
    end

    def test_add_rename
      Person.delete_all

      begin
        Person.connection.add_column "people", "girlfriend", :string
        Person.reset_column_information
        Person.create :girlfriend => 'bobette'

        Person.connection.rename_column "people", "girlfriend", "exgirlfriend"

        Person.reset_column_information
        bob = Person.find(:first)

        assert_equal "bobette", bob.exgirlfriend
      ensure
        Person.connection.remove_column("people", "girlfriend") rescue nil
        Person.connection.remove_column("people", "exgirlfriend") rescue nil
      end

    end

    def test_rename_column_using_symbol_arguments
      begin
        names_before = Person.find(:all).map(&:first_name)
        Person.connection.rename_column :people, :first_name, :nick_name
        Person.reset_column_information
        assert Person.column_names.include?("nick_name")
        assert_equal names_before, Person.find(:all).map(&:nick_name)
      ensure
        Person.connection.remove_column("people","nick_name")
        Person.connection.add_column("people","first_name", :string)
      end
    end

    def test_rename_column
      begin
        names_before = Person.find(:all).map(&:first_name)
        Person.connection.rename_column "people", "first_name", "nick_name"
        Person.reset_column_information
        assert Person.column_names.include?("nick_name")
        assert_equal names_before, Person.find(:all).map(&:nick_name)
      ensure
        Person.connection.remove_column("people","nick_name")
        Person.connection.add_column("people","first_name", :string)
      end
    end

    def test_rename_column_with_sql_reserved_word
      begin
        assert_nothing_raised { Person.connection.rename_column "people", "first_name", "group" }
        Person.reset_column_information
        assert Person.column_names.include?("group")
      ensure
        Person.connection.remove_column("people", "group") rescue nil
        Person.connection.add_column("people", "first_name", :string) rescue nil
      end
    end
    
    def test_rename_column_with_an_index
      ActiveRecord::Base.connection.create_table(:hats) do |table|
        table.column :hat_name, :string, :limit => 100
        table.column :hat_size, :integer
      end
      Person.connection.add_index :people, :first_name
      assert_nothing_raised do
        Person.connection.rename_column "hats", "hat_name", "name"
      end
    ensure
      ActiveRecord::Base.connection.drop_table(:hats)
    end

    def test_remove_column_with_index
      ActiveRecord::Base.connection.create_table(:hats) do |table|
        table.column :hat_name, :string, :limit => 100
        table.column :hat_size, :integer
      end
      ActiveRecord::Base.connection.add_index "hats", "hat_size"

      assert_nothing_raised { Person.connection.remove_column("hats", "hat_size") }
    ensure
      ActiveRecord::Base.connection.drop_table(:hats)
    end

    def test_remove_column_with_multi_column_index
      ActiveRecord::Base.connection.create_table(:hats) do |table|
        table.column :hat_name, :string, :limit => 100
        table.column :hat_size, :integer
        table.column :hat_style, :string, :limit => 100
      end
      ActiveRecord::Base.connection.add_index "hats", ["hat_style", "hat_size"], :unique => true

      assert_nothing_raised { Person.connection.remove_column("hats", "hat_size") }
    ensure
      ActiveRecord::Base.connection.drop_table(:hats)
    end

    def test_change_type_of_not_null_column
      assert_nothing_raised do
        Topic.connection.change_column "topics", "written_on", :datetime, :null => false
        Topic.reset_column_information
        
        Topic.connection.change_column "topics", "written_on", :datetime, :null => false
        Topic.reset_column_information
      end
    end

    def test_rename_table
      begin
        ActiveRecord::Base.connection.create_table :octopuses do |t|
          t.column :url, :string
        end
        ActiveRecord::Base.connection.rename_table :octopuses, :octopi

        # Using explicit id in insert for compatibility across all databases
        con = ActiveRecord::Base.connection     
        con.enable_identity_insert("octopi", true) if current_adapter?(:SybaseAdapter)
        assert_nothing_raised { con.execute "INSERT INTO octopi (#{con.quote_column_name('id')}, #{con.quote_column_name('url')}) VALUES (1, 'http://www.foreverflying.com/octopus-black7.jpg')" }
        con.enable_identity_insert("octopi", false) if current_adapter?(:SybaseAdapter)

        assert_equal 'http://www.foreverflying.com/octopus-black7.jpg', ActiveRecord::Base.connection.select_value("SELECT url FROM octopi WHERE id=1")

      ensure
        ActiveRecord::Base.connection.drop_table :octopuses rescue nil
        ActiveRecord::Base.connection.drop_table :octopi rescue nil
      end
    end
    
    def test_change_column_nullability
      Person.delete_all 
      Person.connection.add_column "people", "funny", :boolean
      Person.reset_column_information
      assert Person.columns_hash["funny"].null, "Column 'funny' must initially allow nulls"
      Person.connection.change_column "people", "funny", :boolean, :null => false, :default => true
      Person.reset_column_information
      assert !Person.columns_hash["funny"].null, "Column 'funny' must *not* allow nulls at this point"
      Person.connection.change_column "people", "funny", :boolean, :null => true
      Person.reset_column_information
      assert Person.columns_hash["funny"].null, "Column 'funny' must allow nulls again at this point"
    end

    def test_rename_table_with_an_index
      begin
        ActiveRecord::Base.connection.create_table :octopuses do |t|
          t.column :url, :string
        end
        ActiveRecord::Base.connection.add_index :octopuses, :url
        
        ActiveRecord::Base.connection.rename_table :octopuses, :octopi

        # Using explicit id in insert for compatibility across all databases
        con = ActiveRecord::Base.connection     
        con.enable_identity_insert("octopi", true) if current_adapter?(:SybaseAdapter)
        assert_nothing_raised { con.execute "INSERT INTO octopi (#{con.quote_column_name('id')}, #{con.quote_column_name('url')}) VALUES (1, 'http://www.foreverflying.com/octopus-black7.jpg')" }
        con.enable_identity_insert("octopi", false) if current_adapter?(:SybaseAdapter)

        assert_equal 'http://www.foreverflying.com/octopus-black7.jpg', ActiveRecord::Base.connection.select_value("SELECT url FROM octopi WHERE id=1")
        assert ActiveRecord::Base.connection.indexes(:octopi).first.columns.include?("url")
      ensure
        ActiveRecord::Base.connection.drop_table :octopuses rescue nil
        ActiveRecord::Base.connection.drop_table :octopi rescue nil
      end
    end

    def test_change_column
      Person.connection.add_column 'people', 'age', :integer
      old_columns = Person.connection.columns(Person.table_name, "#{name} Columns")
      assert old_columns.find { |c| c.name == 'age' and c.type == :integer }

      assert_nothing_raised { Person.connection.change_column "people", "age", :string }

      new_columns = Person.connection.columns(Person.table_name, "#{name} Columns")
      assert_nil new_columns.find { |c| c.name == 'age' and c.type == :integer }
      assert new_columns.find { |c| c.name == 'age' and c.type == :string }

      old_columns = Topic.connection.columns(Topic.table_name, "#{name} Columns")
      assert old_columns.find { |c| c.name == 'approved' and c.type == :boolean and c.default == true }
      assert_nothing_raised { Topic.connection.change_column :topics, :approved, :boolean, :default => false }
      new_columns = Topic.connection.columns(Topic.table_name, "#{name} Columns")
      assert_nil new_columns.find { |c| c.name == 'approved' and c.type == :boolean and c.default == true }
      assert new_columns.find { |c| c.name == 'approved' and c.type == :boolean and c.default == false }
      assert_nothing_raised { Topic.connection.change_column :topics, :approved, :boolean, :default => true }
    end
    
    def test_change_column_with_nil_default
      Person.connection.add_column "people", "contributor", :boolean, :default => true
      Person.reset_column_information
      assert Person.new.contributor?
      
      assert_nothing_raised { Person.connection.change_column "people", "contributor", :boolean, :default => nil }
      Person.reset_column_information
      assert !Person.new.contributor?
      assert_nil Person.new.contributor
    ensure
      Person.connection.remove_column("people", "contributor") rescue nil
    end

    def test_change_column_with_new_default
      Person.connection.add_column "people", "administrator", :boolean, :default => true
      Person.reset_column_information
      assert Person.new.administrator?

      assert_nothing_raised { Person.connection.change_column "people", "administrator", :boolean, :default => false }
      Person.reset_column_information
      assert !Person.new.administrator?
    ensure
      Person.connection.remove_column("people", "administrator") rescue nil
    end
    
    def test_change_column_default
      Person.connection.change_column_default "people", "first_name", "Tester"
      Person.reset_column_information
      assert_equal "Tester", Person.new.first_name
    end

    def test_change_column_quotes_column_names
      Person.connection.create_table :testings do |t|
        t.column :select, :string
      end

      assert_nothing_raised { Person.connection.change_column :testings, :select, :string, :limit => 10 }

      assert_nothing_raised { Person.connection.execute "insert into testings (#{Person.connection.quote_column_name('select')}) values ('7 chars')" }
    ensure
      Person.connection.drop_table :testings rescue nil
    end

    def test_change_column_default_to_null
      Person.connection.change_column_default "people", "first_name", nil
      Person.reset_column_information
      assert_nil Person.new.first_name
    end

    def test_add_table
      assert !Reminder.table_exists?

      WeNeedReminders.up
      
      assert Reminder.create("content" => "hello world", "remind_at" => Time.now)  
      assert_equal "hello world", Reminder.find(:first).content

      WeNeedReminders.down
      assert_raises(ActiveRecord::StatementInvalid) { Reminder.find(:first) }
    end

    def test_add_table_with_decimals
      Person.connection.drop_table :big_numbers rescue nil

      assert !BigNumber.table_exists?
      GiveMeBigNumbers.up

      assert BigNumber.create(
        :bank_balance => 1586.43,
        :big_bank_balance => BigDecimal("1000234000567.95"),
        :world_population => 6000000000,
        :my_house_population => 3,
        :value_of_e => BigDecimal("2.7182818284590452353602875")
      )

      b = BigNumber.find(:first)
      assert_not_nil b

      assert_not_nil b.bank_balance
      assert_not_nil b.big_bank_balance
      assert_not_nil b.world_population
      assert_not_nil b.my_house_population
      assert_not_nil b.value_of_e

      # TODO: set world_population >= 2**62 to cover 64-bit platforms and test
      # is_a?(Bignum)
      assert_kind_of Integer, b.world_population
      assert_equal 6000000000, b.world_population
      assert_kind_of Fixnum, b.my_house_population
      assert_equal 3, b.my_house_population
      assert_kind_of BigDecimal, b.bank_balance
      assert_equal BigDecimal("1586.43"), b.bank_balance
      assert_kind_of BigDecimal, b.big_bank_balance
      assert_equal BigDecimal("1000234000567.95"), b.big_bank_balance

      # This one is fun. The 'value_of_e' field is defined as 'DECIMAL' with
      # precision/scale explicitly left out.  By the SQL standard, numbers
      # assigned to this field should be truncated but that's seldom respected.
      if current_adapter?(:PostgreSQLAdapter, :SQLite2Adapter)
        # - PostgreSQL changes the SQL spec on columns declared simply as
        # "decimal" to something more useful: instead of being given a scale
        # of 0, they take on the compile-time limit for precision and scale,
        # so the following should succeed unless you have used really wacky
        # compilation options
        # - SQLite2 has the default behavior of preserving all data sent in,
        # so this happens there too
        assert_kind_of BigDecimal, b.value_of_e
        assert_equal BigDecimal("2.7182818284590452353602875"), b.value_of_e
      elsif current_adapter?(:SQLiteAdapter)
        # - SQLite3 stores a float, in violation of SQL
        assert_kind_of BigDecimal, b.value_of_e
        assert_equal BigDecimal("2.71828182845905"), b.value_of_e
      elsif current_adapter?(:SQLServer)
        # - SQL Server rounds instead of truncating
        assert_kind_of Fixnum, b.value_of_e
        assert_equal 3, b.value_of_e
      else
        # - SQL standard is an integer
        assert_kind_of Fixnum, b.value_of_e
        assert_equal 2, b.value_of_e
      end

      GiveMeBigNumbers.down
      assert_raises(ActiveRecord::StatementInvalid) { BigNumber.find(:first) }
    end

    def test_migrator
      assert !Person.column_methods_hash.include?(:last_name)
      assert !Reminder.table_exists?

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
      assert !Reminder.table_exists?

      ActiveRecord::Migrator.up(File.dirname(__FILE__) + '/fixtures/migrations/', 1)

      Person.reset_column_information
      assert Person.column_methods_hash.include?(:last_name)
      assert !Reminder.table_exists?

      ActiveRecord::Migrator.up(File.dirname(__FILE__) + '/fixtures/migrations/', 2)

      assert Reminder.create("content" => "hello world", "remind_at" => Time.now)
      assert_equal "hello world", Reminder.find(:first).content
    end

    def test_migrator_one_down
      ActiveRecord::Migrator.up(File.dirname(__FILE__) + '/fixtures/migrations/')

      ActiveRecord::Migrator.down(File.dirname(__FILE__) + '/fixtures/migrations/', 1)

      Person.reset_column_information
      assert Person.column_methods_hash.include?(:last_name)
      assert !Reminder.table_exists?
    end

    def test_migrator_one_up_one_down
      ActiveRecord::Migrator.up(File.dirname(__FILE__) + '/fixtures/migrations/', 1)
      ActiveRecord::Migrator.down(File.dirname(__FILE__) + '/fixtures/migrations/', 0)

      assert !Person.column_methods_hash.include?(:last_name)
      assert !Reminder.table_exists?
    end

    def test_migrator_verbosity
      ActiveRecord::Migrator.up(File.dirname(__FILE__) + '/fixtures/migrations/', 1)
      assert PeopleHaveLastNames.message_count > 0
      PeopleHaveLastNames.message_count = 0

      ActiveRecord::Migrator.down(File.dirname(__FILE__) + '/fixtures/migrations/', 0)
      assert PeopleHaveLastNames.message_count > 0
      PeopleHaveLastNames.message_count = 0
    end

    def test_migrator_verbosity_off
      PeopleHaveLastNames.verbose = false
      ActiveRecord::Migrator.up(File.dirname(__FILE__) + '/fixtures/migrations/', 1)
      assert PeopleHaveLastNames.message_count.zero?
      ActiveRecord::Migrator.down(File.dirname(__FILE__) + '/fixtures/migrations/', 0)
      assert PeopleHaveLastNames.message_count.zero?
    end

    def test_migrator_going_down_due_to_version_target
      ActiveRecord::Migrator.up(File.dirname(__FILE__) + '/fixtures/migrations/', 1)
      ActiveRecord::Migrator.migrate(File.dirname(__FILE__) + '/fixtures/migrations/', 0)

      assert !Person.column_methods_hash.include?(:last_name)
      assert !Reminder.table_exists?

      ActiveRecord::Migrator.migrate(File.dirname(__FILE__) + '/fixtures/migrations/')

      Person.reset_column_information
      assert Person.column_methods_hash.include?(:last_name)
      assert Reminder.create("content" => "hello world", "remind_at" => Time.now)
      assert_equal "hello world", Reminder.find(:first).content
    end

    def test_schema_info_table_name
      ActiveRecord::Base.table_name_prefix = "prefix_"
      ActiveRecord::Base.table_name_suffix = "_suffix"
      Reminder.reset_table_name
      assert_equal "prefix_schema_info_suffix", ActiveRecord::Migrator.schema_info_table_name
      ActiveRecord::Base.table_name_prefix = ""
      ActiveRecord::Base.table_name_suffix = ""
      Reminder.reset_table_name
      assert_equal "schema_info", ActiveRecord::Migrator.schema_info_table_name
    ensure
      ActiveRecord::Base.table_name_prefix = ""
      ActiveRecord::Base.table_name_suffix = ""
    end

    def test_proper_table_name
      assert_equal "table", ActiveRecord::Migrator.proper_table_name('table')
      assert_equal "table", ActiveRecord::Migrator.proper_table_name(:table)
      assert_equal "reminders", ActiveRecord::Migrator.proper_table_name(Reminder)
      Reminder.reset_table_name
      assert_equal Reminder.table_name, ActiveRecord::Migrator.proper_table_name(Reminder)

      # Use the model's own prefix/suffix if a model is given
      ActiveRecord::Base.table_name_prefix = "ARprefix_"
      ActiveRecord::Base.table_name_suffix = "_ARsuffix"
      Reminder.table_name_prefix = 'prefix_'
      Reminder.table_name_suffix = '_suffix'
      Reminder.reset_table_name
      assert_equal "prefix_reminders_suffix", ActiveRecord::Migrator.proper_table_name(Reminder)
      Reminder.table_name_prefix = ''
      Reminder.table_name_suffix = ''
      Reminder.reset_table_name

      # Use AR::Base's prefix/suffix if string or symbol is given
      ActiveRecord::Base.table_name_prefix = "prefix_"
      ActiveRecord::Base.table_name_suffix = "_suffix"
      Reminder.reset_table_name
      assert_equal "prefix_table_suffix", ActiveRecord::Migrator.proper_table_name('table')
      assert_equal "prefix_table_suffix", ActiveRecord::Migrator.proper_table_name(:table)
      ActiveRecord::Base.table_name_prefix = ""
      ActiveRecord::Base.table_name_suffix = ""
      Reminder.reset_table_name
    end

    def test_add_drop_table_with_prefix_and_suffix
      assert !Reminder.table_exists?
      ActiveRecord::Base.table_name_prefix = 'prefix_'
      ActiveRecord::Base.table_name_suffix = '_suffix'
      Reminder.reset_table_name
      Reminder.reset_sequence_name
      WeNeedReminders.up
      assert Reminder.create("content" => "hello world", "remind_at" => Time.now)
      assert_equal "hello world", Reminder.find(:first).content

      WeNeedReminders.down
      assert_raises(ActiveRecord::StatementInvalid) { Reminder.find(:first) }
    ensure
      ActiveRecord::Base.table_name_prefix = ''
      ActiveRecord::Base.table_name_suffix = ''
      Reminder.reset_table_name
      Reminder.reset_sequence_name
    end

    def test_create_table_with_binary_column
      Person.connection.drop_table :binary_testings rescue nil

      assert_nothing_raised {
        Person.connection.create_table :binary_testings do |t|
          t.column "data", :binary, :null => false
        end
      }

      columns = Person.connection.columns(:binary_testings)
      data_column = columns.detect { |c| c.name == "data" }

      if current_adapter?(:MysqlAdapter)      
        assert_equal '', data_column.default
      else
        assert_nil data_column.default
      end

      Person.connection.drop_table :binary_testings rescue nil
    end

    def test_migrator_with_duplicates
      assert_raises(ActiveRecord::DuplicateMigrationVersionError) do
        ActiveRecord::Migrator.migrate(File.dirname(__FILE__) + '/fixtures/migrations_with_duplicate/', nil)
      end
    end

    def test_migrator_with_missing_version_numbers
      ActiveRecord::Migrator.migrate(File.dirname(__FILE__) + '/fixtures/migrations_with_missing_versions/', 500)
      assert !Person.column_methods_hash.include?(:middle_name)
    	assert_equal 4, ActiveRecord::Migrator.current_version
			
			ActiveRecord::Migrator.migrate(File.dirname(__FILE__) + '/fixtures/migrations_with_missing_versions/', 2)
			Person.reset_column_information
			assert !Reminder.table_exists?
      assert Person.column_methods_hash.include?(:last_name)			
			assert_equal 2, ActiveRecord::Migrator.current_version
    end

    def test_create_table_with_custom_sequence_name
      return unless current_adapter? :OracleAdapter

      # table name is 29 chars, the standard sequence name will
      # be 33 chars and fail
      assert_raises(ActiveRecord::StatementInvalid) do
        begin
          Person.connection.create_table :table_with_name_thats_just_ok do |t|
            t.column :foo, :string, :null => false
          end
        ensure
          Person.connection.drop_table :table_with_name_thats_just_ok rescue nil
        end
      end

      # should be all good w/ a custom sequence name
      assert_nothing_raised do
        begin
          Person.connection.create_table :table_with_name_thats_just_ok,
                                         :sequence_name => 'suitably_short_seq' do |t|
            t.column :foo, :string, :null => false
          end

          Person.connection.execute("select suitably_short_seq.nextval from dual")

        ensure
          Person.connection.drop_table :table_with_name_thats_just_ok,
                                       :sequence_name => 'suitably_short_seq' rescue nil
        end
      end

      # confirm the custom sequence got dropped
      assert_raises(ActiveRecord::StatementInvalid) do
        Person.connection.execute("select suitably_short_seq.nextval from dual")
      end
    end
  end

  uses_mocha 'Sexy migration tests' do
    class SexyMigrationsTest < Test::Unit::TestCase
      def test_references_column_type_adds_id
        with_new_table do |t|
          t.expects(:column).with('customer_id', :integer, {})
          t.references :customer
        end
      end
 
      def test_references_column_type_with_polymorphic_adds_type
        with_new_table do |t|
          t.expects(:column).with('taggable_type', :string, {})
          t.expects(:column).with('taggable_id', :integer, {})
          t.references :taggable, :polymorphic => true
        end
      end
      
      def test_references_column_type_with_polymorphic_and_options_null_is_false_adds_table_flag
        with_new_table do |t|
          t.expects(:column).with('taggable_type', :string, {:null => false})
          t.expects(:column).with('taggable_id', :integer, {:null => false})
          t.references :taggable, :polymorphic => true, :null => false
        end
      end

      def test_belongs_to_works_like_references
        with_new_table do |t|
          t.expects(:column).with('customer_id', :integer, {})
          t.belongs_to :customer
        end
      end
      
      def test_timestamps_creates_updated_at_and_created_at
        with_new_table do |t|
          t.expects(:column).with(:created_at, :datetime)
          t.expects(:column).with(:updated_at, :datetime)
          t.timestamps
        end
      end
      
      def test_integer_creates_integer_column
        with_new_table do |t|
          t.expects(:column).with(:foo, 'integer', {})
          t.expects(:column).with(:bar, 'integer', {})
          t.integer :foo, :bar
        end
      end
      
      def test_string_creates_string_column
        with_new_table do |t|
          t.expects(:column).with(:foo, 'string', {})
          t.expects(:column).with(:bar, 'string', {})
          t.string :foo, :bar
        end
      end
      
      protected
      def with_new_table
        Person.connection.create_table :delete_me do |t|
          yield t
        end
      ensure
        Person.connection.drop_table :delete_me rescue nil
      end
      
    end # SexyMigrationsTest
  end # uses_mocha
end

