require "cases/helper"
require 'models/post'
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
require 'models/boolean'
require 'models/column_name'
require 'models/subscriber'
require 'models/keyboard'
require 'models/comment'
require 'models/minimalistic'
require 'models/warehouse_thing'
require 'models/parrot'
require 'models/person'
require 'models/edge'
require 'models/joke'
require 'models/bulb'
require 'models/bird'
require 'rexml/document'
require 'active_support/core_ext/exception'
require 'bcrypt'

class FirstAbstractClass < ActiveRecord::Base
  self.abstract_class = true
end
class SecondAbstractClass < FirstAbstractClass
  self.abstract_class = true
end
class Photo < SecondAbstractClass; end
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

class ReadonlyTitlePost < Post
  attr_readonly :title
end

class ProtectedTitlePost < Post
  attr_protected :title
end

class Weird < ActiveRecord::Base; end

class Boolean < ActiveRecord::Base
  def has_fun
    super
  end
end

class LintTest < ActiveRecord::TestCase
  include ActiveModel::Lint::Tests

  class LintModel < ActiveRecord::Base; end

  def setup
    @model = LintModel.new
  end
end

class BasicsTest < ActiveRecord::TestCase
  fixtures :topics, :companies, :developers, :projects, :computers, :accounts, :minimalistics, 'warehouse-things', :authors, :categorizations, :categories, :posts

  def test_generated_methods_modules
    modules = Computer.ancestors
    assert modules.include?(Computer::GeneratedFeatureMethods)
    assert_equal(Computer::GeneratedFeatureMethods, Computer.generated_feature_methods)
    assert(modules.index(Computer.generated_attribute_methods) > modules.index(Computer.generated_feature_methods),
           "generated_attribute_methods must be higher in inheritance hierarchy than generated_feature_methods")
    assert_not_equal Computer.generated_feature_methods, Post.generated_feature_methods
  end

  def test_column_names_are_escaped
    conn      = ActiveRecord::Base.connection
    classname = conn.class.name[/[^:]*$/]
    badchar   = {
      'SQLite3Adapter'    => '"',
      'MysqlAdapter'      => '`',
      'Mysql2Adapter'     => '`',
      'PostgreSQLAdapter' => '"',
      'OracleAdapter'     => '"',
    }.fetch(classname) {
      raise "need a bad char for #{classname}"
    }

    quoted = conn.quote_column_name "foo#{badchar}bar"
    if current_adapter?(:OracleAdapter)
      # Oracle does not allow double quotes in table and column names at all
      # therefore quoting removes them
      assert_equal("#{badchar}foobar#{badchar}", quoted)
    else
      assert_equal("#{badchar}foo#{badchar * 2}bar#{badchar}", quoted)
    end
  end

  def test_columns_should_obey_set_primary_key
    pk = Subscriber.columns.find { |x| x.name == 'nick' }
    assert pk.primary, 'nick should be primary key'
  end

  def test_primary_key_with_no_id
    assert_nil Edge.primary_key
  end

  unless current_adapter?(:PostgreSQLAdapter,:OracleAdapter,:SQLServerAdapter)
    def test_limit_with_comma
      assert_nothing_raised do
        Topic.limit("1,2").all
      end
    end
  end

  def test_limit_without_comma
    assert_nothing_raised do
      assert_equal 1, Topic.limit("1").all.length
    end

    assert_nothing_raised do
      assert_equal 1, Topic.limit(1).all.length
    end
  end

  def test_invalid_limit
    assert_raises(ArgumentError) do
      Topic.limit("asdfadf").all
    end
  end

  def test_limit_should_sanitize_sql_injection_for_limit_without_comas
    assert_raises(ArgumentError) do
      Topic.limit("1 select * from schema").all
    end
  end

  def test_limit_should_sanitize_sql_injection_for_limit_with_comas
    assert_raises(ArgumentError) do
      Topic.limit("1, 7 procedure help()").all
    end
  end

  unless current_adapter?(:MysqlAdapter) || current_adapter?(:Mysql2Adapter)
    def test_limit_should_allow_sql_literal
      assert_equal 1, Topic.limit(Arel.sql('2-1')).all.length
    end
  end

  def test_select_symbol
    topic_ids = Topic.select(:id).map(&:id).sort
    assert_equal Topic.all.map(&:id).sort, topic_ids
  end

  def test_table_exists
    assert !NonExistentTable.table_exists?
    assert Topic.table_exists?
  end

  def test_preserving_date_objects
    if current_adapter?(:SybaseAdapter)
      # Sybase ctlib does not (yet?) support the date type; use datetime instead.
      assert_kind_of(
        Time, Topic.find(1).last_read,
        "The last_read attribute should be of the Time class"
      )
    else
      # Oracle enhanced adapter allows to define Date attributes in model class (see topic.rb)
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
    if current_adapter?(:PostgreSQLAdapter) || current_adapter?(:SQLiteAdapter)
      assert_equal 11, Topic.find(1).written_on.sec
      assert_equal 223300, Topic.find(1).written_on.usec
      assert_equal 9900, Topic.find(2).written_on.usec
      assert_equal 129346, Topic.find(3).written_on.usec
    end
  end

  def test_preserving_time_objects_with_local_time_conversion_to_default_timezone_utc
    with_env_tz 'America/New_York' do
      with_active_record_default_timezone :utc do
        time = Time.local(2000)
        topic = Topic.create('written_on' => time)
        saved_time = Topic.find(topic.id).reload.written_on
        assert_equal time, saved_time
        assert_equal [0, 0, 0, 1, 1, 2000, 6, 1, false, "EST"], time.to_a
        assert_equal [0, 0, 5, 1, 1, 2000, 6, 1, false, "UTC"], saved_time.to_a
      end
    end
  end

  def test_preserving_time_objects_with_time_with_zone_conversion_to_default_timezone_utc
    with_env_tz 'America/New_York' do
      with_active_record_default_timezone :utc do
        Time.use_zone 'Central Time (US & Canada)' do
          time = Time.zone.local(2000)
          topic = Topic.create('written_on' => time)
          saved_time = Topic.find(topic.id).reload.written_on
          assert_equal time, saved_time
          assert_equal [0, 0, 0, 1, 1, 2000, 6, 1, false, "CST"], time.to_a
          assert_equal [0, 0, 6, 1, 1, 2000, 6, 1, false, "UTC"], saved_time.to_a
        end
      end
    end
  end

  def test_preserving_time_objects_with_utc_time_conversion_to_default_timezone_local
    with_env_tz 'America/New_York' do
      time = Time.utc(2000)
      topic = Topic.create('written_on' => time)
      saved_time = Topic.find(topic.id).reload.written_on
      assert_equal time, saved_time
      assert_equal [0, 0, 0, 1, 1, 2000, 6, 1, false, "UTC"], time.to_a
      assert_equal [0, 0, 19, 31, 12, 1999, 5, 365, false, "EST"], saved_time.to_a
    end
  end

  def test_preserving_time_objects_with_time_with_zone_conversion_to_default_timezone_local
    with_env_tz 'America/New_York' do
      with_active_record_default_timezone :local do
        Time.use_zone 'Central Time (US & Canada)' do
          time = Time.zone.local(2000)
          topic = Topic.create('written_on' => time)
          saved_time = Topic.find(topic.id).reload.written_on
          assert_equal time, saved_time
          assert_equal [0, 0, 0, 1, 1, 2000, 6, 1, false, "CST"], time.to_a
          assert_equal [0, 0, 1, 1, 1, 2000, 6, 1, false, "EST"], saved_time.to_a
        end
      end
    end
  end

  def test_custom_mutator
    topic = Topic.find(1)
    # This mutator is protected in the class definition
    topic.send(:approved=, true)
    assert topic.instance_variable_get("@custom_approved")
  end

  def test_initialize_with_attributes
    topic = Topic.new({
      "title" => "initialized from attributes", "written_on" => "2003-12-12 23:23"
    })

    assert_equal("initialized from attributes", topic.title)
  end

  def test_initialize_with_invalid_attribute
    begin
      Topic.new({ "title" => "test",
        "last_read(1i)" => "2005", "last_read(2i)" => "2", "last_read(3i)" => "31"})
    rescue ActiveRecord::MultiparameterAssignmentErrors => ex
      assert_equal(1, ex.errors.size)
      assert_equal("last_read", ex.errors[0].attribute)
    end
  end

  def test_create_after_initialize_without_block
    cb = CustomBulb.create(:name => 'Dude')
    assert_equal('Dude', cb.name)
    assert_equal(true, cb.frickinawesome)
  end

  def test_create_after_initialize_with_block
    cb = CustomBulb.create {|c| c.name = 'Dude' }
    assert_equal('Dude', cb.name)
    assert_equal(true, cb.frickinawesome)
  end

  def test_first_or_create
    parrot = Bird.first_or_create(:color => 'green', :name => 'parrot')
    assert parrot.persisted?
    the_same_parrot = Bird.first_or_create(:color => 'yellow', :name => 'macaw')
    assert_equal parrot, the_same_parrot
  end

  def test_first_or_create_bang
    assert_raises(ActiveRecord::RecordInvalid) { Bird.first_or_create! }
    parrot = Bird.first_or_create!(:color => 'green', :name => 'parrot')
    assert parrot.persisted?
    the_same_parrot = Bird.first_or_create!(:color => 'yellow', :name => 'macaw')
    assert_equal parrot, the_same_parrot
  end

  def test_first_or_initialize
    parrot = Bird.first_or_initialize(:color => 'green', :name => 'parrot')
    assert_kind_of Bird, parrot
    assert !parrot.persisted?
    assert parrot.new_record?
    assert parrot.valid?
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

  GUESSED_CLASSES = [Category, Smarts, CreditCard, CreditCard::PinNumber, CreditCard::PinNumber::CvvCode, CreditCard::SubPinNumber, CreditCard::Brand, MasterCreditCard]

  def test_table_name_guesses
    assert_equal "topics", Topic.table_name

    assert_equal "categories", Category.table_name
    assert_equal "smarts", Smarts.table_name
    assert_equal "credit_cards", CreditCard.table_name
    assert_equal "credit_card_pin_numbers", CreditCard::PinNumber.table_name
    assert_equal "credit_card_pin_number_cvv_codes", CreditCard::PinNumber::CvvCode.table_name
    assert_equal "credit_card_pin_numbers", CreditCard::SubPinNumber.table_name
    assert_equal "categories", CreditCard::Brand.table_name
    assert_equal "master_credit_cards", MasterCreditCard.table_name
  ensure
    GUESSED_CLASSES.each(&:reset_table_name)
  end

  def test_singular_table_name_guesses
    ActiveRecord::Base.pluralize_table_names = false
    GUESSED_CLASSES.each(&:reset_table_name)

    assert_equal "category", Category.table_name
    assert_equal "smarts", Smarts.table_name
    assert_equal "credit_card", CreditCard.table_name
    assert_equal "credit_card_pin_number", CreditCard::PinNumber.table_name
    assert_equal "credit_card_pin_number_cvv_code", CreditCard::PinNumber::CvvCode.table_name
    assert_equal "credit_card_pin_number", CreditCard::SubPinNumber.table_name
    assert_equal "category", CreditCard::Brand.table_name
    assert_equal "master_credit_card", MasterCreditCard.table_name
  ensure
    ActiveRecord::Base.pluralize_table_names = true
    GUESSED_CLASSES.each(&:reset_table_name)
  end

  def test_table_name_guesses_with_prefixes_and_suffixes
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
  ensure
    ActiveRecord::Base.table_name_prefix = ""
    ActiveRecord::Base.table_name_suffix = ""
    GUESSED_CLASSES.each(&:reset_table_name)
  end

  def test_singular_table_name_guesses_with_prefixes_and_suffixes
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
  ensure
    ActiveRecord::Base.pluralize_table_names = true
    ActiveRecord::Base.table_name_prefix = ""
    ActiveRecord::Base.table_name_suffix = ""
    GUESSED_CLASSES.each(&:reset_table_name)
  end

  def test_table_name_guesses_with_inherited_prefixes_and_suffixes
    GUESSED_CLASSES.each(&:reset_table_name)

    CreditCard.table_name_prefix = "test_"
    CreditCard.reset_table_name
    Category.reset_table_name
    assert_equal "test_credit_cards", CreditCard.table_name
    assert_equal "categories", Category.table_name
    CreditCard.table_name_suffix = "_test"
    CreditCard.reset_table_name
    Category.reset_table_name
    assert_equal "test_credit_cards_test", CreditCard.table_name
    assert_equal "categories", Category.table_name
    CreditCard.table_name_prefix = ""
    CreditCard.reset_table_name
    Category.reset_table_name
    assert_equal "credit_cards_test", CreditCard.table_name
    assert_equal "categories", Category.table_name
    CreditCard.table_name_suffix = ""
    CreditCard.reset_table_name
    Category.reset_table_name
    assert_equal "credit_cards", CreditCard.table_name
    assert_equal "categories", Category.table_name
  ensure
    CreditCard.table_name_prefix = ""
    CreditCard.table_name_suffix = ""
    GUESSED_CLASSES.each(&:reset_table_name)
  end

  def test_singular_table_name_guesses_for_individual_table
    CreditCard.pluralize_table_names = false
    CreditCard.reset_table_name
    assert_equal "credit_card", CreditCard.table_name
    assert_equal "categories", Category.table_name
  ensure
    CreditCard.pluralize_table_names = true
    CreditCard.reset_table_name
  end

  if current_adapter?(:MysqlAdapter) or current_adapter?(:Mysql2Adapter)
    def test_update_all_with_order_and_limit
      assert_equal 1, Topic.update_all("content = 'bulk updated!'", nil, :limit => 1, :order => 'id DESC')
    end
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

  def test_find_by_slug
    assert_equal Topic.find('1-meowmeow'), Topic.find(1)
  end

  def test_equality_of_new_records
    assert_not_equal Topic.new, Topic.new
  end

  def test_equality_of_destroyed_records
    topic_1 = Topic.new(:title => 'test_1')
    topic_1.save
    topic_2 = Topic.find(topic_1.id)
    topic_1.destroy
    assert_equal topic_1, topic_2
    assert_equal topic_2, topic_1
  end

  def test_hashing
    assert_equal [ Topic.find(1) ], [ Topic.find(2).topic ] & [ Topic.find(1) ]
  end

  def test_comparison
    topic_1 = Topic.create!
    topic_2 = Topic.create!

    assert_equal [topic_2, topic_1].sort, [topic_1, topic_2]
  end

  def test_comparison_with_different_objects
    topic = Topic.create
    category = Category.create(:name => "comparison")
    assert_nil topic <=> category
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

  def test_non_valid_identifier_column_name
    weird = Weird.create('a$b' => 'value')
    weird.reload
    assert_equal 'value', weird.send('a$b')
    assert_equal 'value', weird.read_attribute('a$b')

    weird.update_column('a$b', 'value2')
    weird.reload
    assert_equal 'value2', weird.send('a$b')
    assert_equal 'value2', weird.read_attribute('a$b')
  end

  def test_multiparameter_attributes_on_date
    attributes = { "last_read(1i)" => "2004", "last_read(2i)" => "6", "last_read(3i)" => "24" }
    topic = Topic.find(1)
    topic.attributes = attributes
    # note that extra #to_date call allows test to pass for Oracle, which
    # treats dates/times the same
    assert_date_from_db Date.new(2004, 6, 24), topic.last_read.to_date
  end

  def test_multiparameter_attributes_on_date_with_empty_year
    attributes = { "last_read(1i)" => "", "last_read(2i)" => "6", "last_read(3i)" => "24" }
    topic = Topic.find(1)
    topic.attributes = attributes
    # note that extra #to_date call allows test to pass for Oracle, which
    # treats dates/times the same
    assert_nil topic.last_read
  end

  def test_multiparameter_attributes_on_date_with_empty_month
    attributes = { "last_read(1i)" => "2004", "last_read(2i)" => "", "last_read(3i)" => "24" }
    topic = Topic.find(1)
    topic.attributes = attributes
    # note that extra #to_date call allows test to pass for Oracle, which
    # treats dates/times the same
    assert_nil topic.last_read
  end

  def test_multiparameter_attributes_on_date_with_empty_day
    attributes = { "last_read(1i)" => "2004", "last_read(2i)" => "6", "last_read(3i)" => "" }
    topic = Topic.find(1)
    topic.attributes = attributes
    # note that extra #to_date call allows test to pass for Oracle, which
    # treats dates/times the same
    assert_nil topic.last_read
  end

  def test_multiparameter_attributes_on_date_with_empty_day_and_year
    attributes = { "last_read(1i)" => "", "last_read(2i)" => "6", "last_read(3i)" => "" }
    topic = Topic.find(1)
    topic.attributes = attributes
    # note that extra #to_date call allows test to pass for Oracle, which
    # treats dates/times the same
    assert_nil topic.last_read
  end

  def test_multiparameter_attributes_on_date_with_empty_day_and_month
    attributes = { "last_read(1i)" => "2004", "last_read(2i)" => "", "last_read(3i)" => "" }
    topic = Topic.find(1)
    topic.attributes = attributes
    # note that extra #to_date call allows test to pass for Oracle, which
    # treats dates/times the same
    assert_nil topic.last_read
  end

  def test_multiparameter_attributes_on_date_with_empty_year_and_month
    attributes = { "last_read(1i)" => "", "last_read(2i)" => "", "last_read(3i)" => "24" }
    topic = Topic.find(1)
    topic.attributes = attributes
    # note that extra #to_date call allows test to pass for Oracle, which
    # treats dates/times the same
    assert_nil topic.last_read
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

  def test_multiparameter_attributes_on_time_with_no_date
    ex = assert_raise(ActiveRecord::MultiparameterAssignmentErrors) do
      attributes = {
        "written_on(4i)" => "16", "written_on(5i)" => "24", "written_on(6i)" => "00"
      }
      topic = Topic.find(1)
      topic.attributes = attributes
    end
    assert_equal("written_on", ex.errors[0].attribute)
  end

  def test_multiparameter_attributes_on_time_with_invalid_time_params
    ex = assert_raise(ActiveRecord::MultiparameterAssignmentErrors) do
      attributes = {
        "written_on(1i)" => "2004", "written_on(2i)" => "6", "written_on(3i)" => "24",
        "written_on(4i)" => "2004", "written_on(5i)" => "36", "written_on(6i)" => "64",
      }
      topic = Topic.find(1)
      topic.attributes = attributes
    end
    assert_equal("written_on", ex.errors[0].attribute)
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

  def test_multiparameter_attributes_on_time_will_raise_on_big_time_if_missing_date_parts
    ex = assert_raise(ActiveRecord::MultiparameterAssignmentErrors) do
      attributes = {
        "written_on(4i)" => "16", "written_on(5i)" => "24"
      }
      topic = Topic.find(1)
      topic.attributes = attributes
    end
    assert_equal("written_on", ex.errors[0].attribute)
  end

  def test_multiparameter_attributes_on_time_with_raise_on_small_time_if_missing_date_parts
    ex = assert_raise(ActiveRecord::MultiparameterAssignmentErrors) do
      attributes = {
        "written_on(4i)" => "16", "written_on(5i)" => "12", "written_on(6i)" => "02"
      }
      topic = Topic.find(1)
      topic.attributes = attributes
    end
    assert_equal("written_on", ex.errors[0].attribute)
  end

  def test_multiparameter_attributes_on_time_will_ignore_hour_if_missing
    attributes = {
      "written_on(1i)" => "2004", "written_on(2i)" => "12", "written_on(3i)" => "12",
      "written_on(5i)" => "12", "written_on(6i)" => "02"
    }
    topic = Topic.find(1)
    topic.attributes = attributes
    assert_equal Time.local(2004, 12, 12, 0, 12, 2), topic.written_on
  end

  def test_multiparameter_attributes_on_time_will_ignore_hour_if_blank
    attributes = {
      "written_on(1i)" => "", "written_on(2i)" => "", "written_on(3i)" => "",
      "written_on(4i)" => "", "written_on(5i)" => "12", "written_on(6i)" => "02"
    }
    topic = Topic.find(1)
    topic.attributes = attributes
    assert_nil topic.written_on
  end

  def test_multiparameter_attributes_on_time_will_ignore_date_if_empty
    attributes = {
      "written_on(1i)" => "", "written_on(2i)" => "", "written_on(3i)" => "",
      "written_on(4i)" => "16", "written_on(5i)" => "24"
    }
    topic = Topic.find(1)
    topic.attributes = attributes
    assert_nil topic.written_on
  end
  def test_multiparameter_attributes_on_time_with_seconds_will_ignore_date_if_empty
    attributes = {
      "written_on(1i)" => "", "written_on(2i)" => "", "written_on(3i)" => "",
      "written_on(4i)" => "16", "written_on(5i)" => "12", "written_on(6i)" => "02"
    }
    topic = Topic.find(1)
    topic.attributes = attributes
    assert_nil topic.written_on
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

  # Oracle, and Sybase do not have a TIME datatype.
  unless current_adapter?(:OracleAdapter, :SybaseAdapter)
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

  def test_multiparameter_assignment_of_aggregation
    customer = Customer.new
    address = Address.new("The Street", "The City", "The Country")
    attributes = { "address(1)" => address.street, "address(2)" => address.city, "address(3)" => address.country }
    customer.attributes = attributes
    assert_equal address, customer.address
  end

  def test_multiparameter_assignment_of_aggregation_out_of_order
    customer = Customer.new
    address = Address.new("The Street", "The City", "The Country")
    attributes = { "address(3)" => address.country, "address(2)" => address.city, "address(1)" => address.street }
    customer.attributes = attributes
    assert_equal address, customer.address
  end

  def test_multiparameter_assignment_of_aggregation_with_missing_values
    ex = assert_raise(ActiveRecord::MultiparameterAssignmentErrors) do
      customer = Customer.new
      address = Address.new("The Street", "The City", "The Country")
      attributes = { "address(2)" => address.city, "address(3)" => address.country }
      customer.attributes = attributes
    end
    assert_equal("address", ex.errors[0].attribute)
  end

  def test_multiparameter_assignment_of_aggregation_with_blank_values
    customer = Customer.new
    address = Address.new("The Street", "The City", "The Country")
    attributes = { "address(1)" => "", "address(2)" => address.city, "address(3)" => address.country }
    customer.attributes = attributes
    assert_equal Address.new(nil, "The City", "The Country"), customer.address
  end

  def test_multiparameter_assignment_of_aggregation_with_large_index
    ex = assert_raise(ActiveRecord::MultiparameterAssignmentErrors) do
      customer = Customer.new
      address = Address.new("The Street", "The City", "The Country")
      attributes = { "address(1)" => "The Street", "address(2)" => address.city, "address(3000)" => address.country }
      customer.attributes = attributes
    end
    assert_equal("address", ex.errors[0].attribute)
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

  def test_attributes_on_dummy_time_with_invalid_time
    # Oracle, and Sybase do not have a TIME datatype.
    return true if current_adapter?(:OracleAdapter, :SybaseAdapter)

    attributes = {
      "bonus_time" => "not a time"
    }
    topic = Topic.find(1)
    topic.attributes = attributes
    assert_nil topic.bonus_time
  end

  def test_boolean
    b_nil = Boolean.create({ "value" => nil })
    nil_id = b_nil.id
    b_false = Boolean.create({ "value" => false })
    false_id = b_false.id
    b_true = Boolean.create({ "value" => true })
    true_id = b_true.id

    b_nil = Boolean.find(nil_id)
    assert_nil b_nil.value
    b_false = Boolean.find(false_id)
    assert !b_false.value?
    b_true = Boolean.find(true_id)
    assert b_true.value?
  end

  def test_boolean_without_questionmark
    b_true = Boolean.create({ "value" => true })
    true_id = b_true.id

    subclass   = Class.new(Boolean).find true_id
    superclass = Boolean.find true_id

    assert_equal superclass.read_attribute(:has_fun), subclass.read_attribute(:has_fun)
  end

  def test_boolean_cast_from_string
    b_blank = Boolean.create({ "value" => "" })
    blank_id = b_blank.id
    b_false = Boolean.create({ "value" => "0" })
    false_id = b_false.id
    b_true = Boolean.create({ "value" => "1" })
    true_id = b_true.id

    b_blank = Boolean.find(blank_id)
    assert_nil b_blank.value
    b_false = Boolean.find(false_id)
    assert !b_false.value?
    b_true = Boolean.find(true_id)
    assert b_true.value?
  end

  def test_new_record_returns_boolean
    assert_equal false, Topic.new.persisted?
    assert_equal true, Topic.find(1).persisted?
  end

  def test_dup
    topic = Topic.find(1)
    duped_topic = nil
    assert_nothing_raised { duped_topic = topic.dup }
    assert_equal topic.title, duped_topic.title
    assert !duped_topic.persisted?

    # test if the attributes have been duped
    topic.title = "a"
    duped_topic.title = "b"
    assert_equal "a", topic.title
    assert_equal "b", duped_topic.title

    # test if the attribute values have been duped
    topic.title = {"a" => "b"}
    duped_topic = topic.dup
    duped_topic.title["a"] = "c"
    assert_equal "b", topic.title["a"]

    # test if attributes set as part of after_initialize are duped correctly
    assert_equal topic.author_email_address, duped_topic.author_email_address

    # test if saved clone object differs from original
    duped_topic.save
    assert duped_topic.persisted?
    assert_not_equal duped_topic.id, topic.id

    duped_topic.reload
    # FIXME: I think this is poor behavior, and will fix it with #5686
    assert_equal({'a' => 'c'}.to_yaml, duped_topic.title)
  end

  def test_dup_with_aggregate_of_same_name_as_attribute
    dev = DeveloperWithAggregate.find(1)
    assert_kind_of DeveloperSalary, dev.salary

    dup = nil
    assert_nothing_raised { dup = dev.dup }
    assert_kind_of DeveloperSalary, dup.salary
    assert_equal dev.salary.amount, dup.salary.amount
    assert !dup.persisted?

    # test if the attributes have been dupd
    original_amount = dup.salary.amount
    dev.salary.amount = 1
    assert_equal original_amount, dup.salary.amount

    assert dup.save
    assert dup.persisted?
    assert_not_equal dup.id, dev.id
  end

  def test_dup_does_not_copy_associations
    author = authors(:david)
    assert_not_equal [], author.posts
    author.send(:clear_association_cache)

    author_dup = author.dup
    assert_equal [], author_dup.posts
  end

  def test_clone_preserves_subtype
    clone = nil
    assert_nothing_raised { clone = Company.find(3).clone }
    assert_kind_of Client, clone
  end

  def test_clone_of_new_object_with_defaults
    developer = Developer.new
    assert !developer.name_changed?
    assert !developer.salary_changed?

    cloned_developer = developer.clone
    assert !cloned_developer.name_changed?
    assert !cloned_developer.salary_changed?
  end

  def test_clone_of_new_object_marks_attributes_as_dirty
    developer = Developer.new :name => 'Bjorn', :salary => 100000
    assert developer.name_changed?
    assert developer.salary_changed?

    cloned_developer = developer.clone
    assert cloned_developer.name_changed?
    assert cloned_developer.salary_changed?
  end

  def test_clone_of_new_object_marks_as_dirty_only_changed_attributes
    developer = Developer.new :name => 'Bjorn'
    assert developer.name_changed?            # obviously
    assert !developer.salary_changed?         # attribute has non-nil default value, so treated as not changed

    cloned_developer = developer.clone
    assert cloned_developer.name_changed?
    assert !cloned_developer.salary_changed?  # ... and cloned instance should behave same
  end

  def test_dup_of_saved_object_marks_attributes_as_dirty
    developer = Developer.create! :name => 'Bjorn', :salary => 100000
    assert !developer.name_changed?
    assert !developer.salary_changed?

    cloned_developer = developer.dup
    assert cloned_developer.name_changed?     # both attributes differ from defaults
    assert cloned_developer.salary_changed?
  end

  def test_dup_of_saved_object_marks_as_dirty_only_changed_attributes
    developer = Developer.create! :name => 'Bjorn'
    assert !developer.name_changed?           # both attributes of saved object should be treated as not changed
    assert !developer.salary_changed?

    cloned_developer = developer.dup
    assert cloned_developer.name_changed?     # ... but on cloned object should be
    assert !cloned_developer.salary_changed?  # ... BUT salary has non-nil default which should be treated as not changed on cloned instance
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
      h = ActiveRecord::IdentityMap.without { Geometric.find(g.id) }

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
      h = ActiveRecord::IdentityMap.without { Geometric.find(g.id) }

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

  def test_big_decimal_conditions
    m = NumericData.new(
      :bank_balance => 1586.43,
      :big_bank_balance => BigDecimal("1000234000567.95"),
      :world_population => 6000000000,
      :my_house_population => 3
    )
    assert m.save
    assert_equal 0, NumericData.where("bank_balance > ?", 2000.0).count
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
    assert(auto.id > 0)
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
    Topic.serialize("content", MyObject)

    myobj = MyObject.new('value1', 'value2')
    topic = Topic.create("content" => myobj)
    assert_equal(myobj, topic.content)

    topic.reload
    assert_equal(myobj, topic.content)
  end

  def test_serialized_attribute_in_base_class
    Topic.serialize("content", Hash)

    hash = { 'content1' => 'value1', 'content2' => 'value2' }
    important_topic = ImportantTopic.create("content" => hash)
    assert_equal(hash, important_topic.content)

    important_topic.reload
    assert_equal(hash, important_topic.content)
  end

  # This test was added to fix GH #4004. Obviously the value returned
  # is not really the value 'before type cast' so we should maybe think
  # about changing that in the future.
  def test_serialized_attribute_before_type_cast_returns_unserialized_value
    klass = Class.new(ActiveRecord::Base)
    klass.table_name = "topics"
    klass.serialize :content, Hash

    t = klass.new(:content => { :foo => :bar })
    assert_equal({ :foo => :bar }, t.content_before_type_cast)
    t.save!
    t.reload
    assert_equal({ :foo => :bar }, t.content_before_type_cast)
  end

  def test_serialized_attributes_before_type_cast_returns_unserialized_value
    Topic.serialize :content, Hash

    t = Topic.new(:content => { :foo => :bar })
    assert_equal({ :foo => :bar }, t.attributes_before_type_cast["content"])
    t.save!
    t.reload
    assert_equal({ :foo => :bar }, t.attributes_before_type_cast["content"])
  end

  def test_serialized_attribute_calling_dup_method
    klass = Class.new(ActiveRecord::Base)
    klass.table_name = "topics"
    klass.serialize :content, JSON

    t = klass.new(:content => { :foo => :bar }).dup
    assert_equal({ :foo => :bar }, t.content_before_type_cast)
  end

  def test_serialized_attribute_declared_in_subclass
    hash = { 'important1' => 'value1', 'important2' => 'value2' }
    important_topic = ImportantTopic.create("important" => hash)
    assert_equal(hash, important_topic.important)

    important_topic.reload
    assert_equal(hash, important_topic.important)
    assert_equal(hash, important_topic.read_attribute(:important))
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
    topic = Topic.new
    assert_nil topic.content
  end

  def test_should_raise_exception_on_serialized_attribute_with_type_mismatch
    myobj = MyObject.new('value1', 'value2')
    topic = Topic.new(:content => myobj)
    assert topic.save
    Topic.serialize(:content, Hash)
    assert_raise(ActiveRecord::SerializationTypeMismatch) { Topic.find(topic.id).reload.content }
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

  def test_serialized_default_class
    Topic.serialize(:content, Hash)
    topic = Topic.new
    assert_equal Hash, topic.content.class
    assert_equal Hash, topic.read_attribute(:content).class
    topic.content["beer"] = "MadridRb"
    assert topic.save
    topic.reload
    assert_equal Hash, topic.content.class
    assert_equal "MadridRb", topic.content["beer"]
  ensure
    Topic.serialize(:content)
  end

  def test_serialized_no_default_class_for_object
    topic = Topic.new
    assert_nil topic.content
  end

  def test_serialized_boolean_value_true
    Topic.serialize(:content)
    topic = Topic.new(:content => true)
    assert topic.save
    topic = topic.reload
    assert_equal topic.content, true
  end

  def test_serialized_boolean_value_false
    Topic.serialize(:content)
    topic = Topic.new(:content => false)
    assert topic.save
    topic = topic.reload
    assert_equal topic.content, false
  end

  def test_serialize_with_coder
    coder = Class.new {
      # Identity
      def load(thing)
        thing
      end

      # base 64
      def dump(thing)
        [thing].pack('m')
      end
    }.new

    Topic.serialize(:content, coder)
    s = 'hello world'
    topic = Topic.new(:content => s)
    assert topic.save
    topic = topic.reload
    assert_equal [s].pack('m'), topic.content
  ensure
    Topic.serialize(:content)
  end

  def test_serialize_with_bcrypt_coder
    crypt_coder = Class.new {
      def load(thing)
        return unless thing
        BCrypt::Password.new thing
      end

      def dump(thing)
        BCrypt::Password.create(thing).to_s
      end
    }.new

    Topic.serialize(:content, crypt_coder)
    password = 'password'
    topic = Topic.new(:content => password)
    assert topic.save
    topic = topic.reload
    assert_kind_of BCrypt::Password, topic.content
    assert_equal(true, topic.content == password, 'password should equal')
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

  def test_reload_with_exclusive_scope
    dev = DeveloperCalledDavid.first
    dev.update_attributes!( :name => "NotDavid" )
    assert_equal dev, dev.reload
  end

  def test_set_table_name_with_value
    k = Class.new( ActiveRecord::Base )
    k.table_name = "foo"
    assert_equal "foo", k.table_name

    assert_deprecated do
      k.set_table_name "bar"
    end
    assert_equal "bar", k.table_name
  end

  def test_switching_between_table_name
    assert_difference("GoodJoke.count") do
      Joke.table_name = "cold_jokes"
      Joke.create

      Joke.table_name = "funny_jokes"
      Joke.create
    end
  end

  def test_set_table_name_symbol_converted_to_string
    Joke.table_name = :cold_jokes
    assert_equal 'cold_jokes', Joke.table_name
  end

  def test_quoted_table_name_after_set_table_name
    klass = Class.new(ActiveRecord::Base)

    klass.table_name = "foo"
    assert_equal "foo", klass.table_name
    assert_equal klass.connection.quote_table_name("foo"), klass.quoted_table_name

    klass.table_name = "bar"
    assert_equal "bar", klass.table_name
    assert_equal klass.connection.quote_table_name("bar"), klass.quoted_table_name
  end

  def test_set_table_name_with_block
    k = Class.new( ActiveRecord::Base )
    assert_deprecated do
      k.set_table_name "foo"
      k.set_table_name do
        ActiveSupport::Deprecation.silence { original_table_name } + "ks"
      end
    end
    assert_equal "fooks", k.table_name
  end

  def test_set_table_name_with_inheritance
    k = Class.new( ActiveRecord::Base )
    def k.name; "Foo"; end
    def k.table_name; super + "ks"; end
    assert_equal "foosks", k.table_name
  end

  def test_original_table_name
    k = Class.new(ActiveRecord::Base)
    def k.name; "Foo"; end
    k.table_name = "bar"

    assert_deprecated do
      assert_equal "foos", k.original_table_name
    end

    k = Class.new(ActiveRecord::Base)
    k.table_name = "omg"
    k.table_name = "wtf"

    assert_deprecated do
      assert_equal "omg", k.original_table_name
    end
  end

  def test_set_primary_key_with_value
    k = Class.new( ActiveRecord::Base )
    k.primary_key = "foo"
    assert_equal "foo", k.primary_key

    assert_deprecated do
      k.set_primary_key "bar"
    end
    assert_equal "bar", k.primary_key
  end

  def test_set_primary_key_with_block
    k = Class.new( ActiveRecord::Base )
    k.primary_key = 'id'

    assert_deprecated do
      k.set_primary_key do
        "sys_" + ActiveSupport::Deprecation.silence { original_primary_key }
      end
    end
    assert_equal "sys_id", k.primary_key
  end

  def test_original_primary_key
    k = Class.new(ActiveRecord::Base)
    def k.name; "Foo"; end
    k.table_name = "posts"
    k.primary_key = "bar"

    assert_deprecated do
      assert_equal "id", k.original_primary_key
    end

    k = Class.new(ActiveRecord::Base)
    k.primary_key = "omg"
    k.primary_key = "wtf"

    assert_deprecated do
      assert_equal "omg", k.original_primary_key
    end
  end

  def test_set_inheritance_column_with_value
    k = Class.new( ActiveRecord::Base )
    k.inheritance_column = "foo"
    assert_equal "foo", k.inheritance_column

    assert_deprecated do
      k.set_inheritance_column "bar"
    end
    assert_equal "bar", k.inheritance_column
  end

  def test_set_inheritance_column_with_block
    k = Class.new( ActiveRecord::Base )
    assert_deprecated do
      k.set_inheritance_column do
        ActiveSupport::Deprecation.silence { original_inheritance_column } + "_id"
      end
    end
    assert_equal "type_id", k.inheritance_column
  end

  def test_original_inheritance_column
    k = Class.new(ActiveRecord::Base)
    def k.name; "Foo"; end
    k.inheritance_column = "omg"

    assert_deprecated do
      assert_equal "type", k.original_inheritance_column
    end
  end

  def test_set_sequence_name_with_value
    k = Class.new( ActiveRecord::Base )
    k.sequence_name = "foo"
    assert_equal "foo", k.sequence_name

    assert_deprecated do
      k.set_sequence_name "bar"
    end
    assert_equal "bar", k.sequence_name
  end

  def test_set_sequence_name_with_block
    k = Class.new( ActiveRecord::Base )
    k.table_name = "projects"
    orig_name = k.sequence_name
    return skip "sequences not supported by db" unless orig_name

    assert_deprecated do
      k.set_sequence_name do
        ActiveSupport::Deprecation.silence { original_sequence_name } + "_lol"
      end
    end
    assert_equal orig_name + "_lol", k.sequence_name
  end

  def test_original_sequence_name
    k = Class.new(ActiveRecord::Base)
    k.table_name = "projects"
    orig_name = k.sequence_name
    return skip "sequences not supported by db" unless orig_name

    k = Class.new(ActiveRecord::Base)
    k.table_name = "projects"
    k.sequence_name = "omg"

    assert_deprecated do
      assert_equal orig_name, k.original_sequence_name
    end

    k = Class.new(ActiveRecord::Base)
    k.table_name = "projects"
    k.sequence_name = "omg"
    k.sequence_name = "wtf"
    assert_deprecated do
      assert_equal "omg", k.original_sequence_name
    end
  end

  def test_sequence_name_with_abstract_class
    ak = Class.new(ActiveRecord::Base)
    ak.abstract_class = true
    k = Class.new(ak)
    k.table_name = "projects"
    orig_name = k.sequence_name
    return skip "sequences not supported by db" unless orig_name
    assert_equal k.reset_sequence_name, orig_name
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

  def test_scoped_find_conditions
    scoped_developers = Developer.send(:with_scope, :find => { :conditions => 'salary > 90000' }) do
      Developer.find(:all, :conditions => 'id < 5')
    end
    assert !scoped_developers.include?(developers(:david)) # David's salary is less than 90,000
    assert_equal 3, scoped_developers.size
  end

  def test_no_limit_offset
    assert_nothing_raised do
      Developer.find(:all, :offset => 2)
    end
  end

  def test_scoped_find_limit_offset
    scoped_developers = Developer.send(:with_scope, :find => { :limit => 3, :offset => 2 }) do
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
    scoped_developers = Developer.send(:with_scope, :find => { :limit => 1, :order => 'salary DESC' }) do
      Developer.find(:all)
    end
    assert_equal 'Jamis', scoped_developers.first.name
    assert scoped_developers.include?(developers(:jamis))
    # Test scope without order and order in find
    scoped_developers = Developer.send(:with_scope, :find => { :limit => 1 }) do
      Developer.find(:all, :order => 'salary DESC')
    end
    # Test scope order + find order, order has priority
    scoped_developers = Developer.send(:with_scope, :find => { :limit => 3, :order => 'id DESC' }) do
      Developer.find(:all, :order => 'salary ASC')
    end
    assert scoped_developers.include?(developers(:poor_jamis))
    assert ! scoped_developers.include?(developers(:david))
    assert ! scoped_developers.include?(developers(:jamis))
    assert_equal 3, scoped_developers.size

    # Test without scoped find conditions to ensure we get the right thing
    assert ! scoped_developers.include?(Developer.find(1))
    assert scoped_developers.include?(Developer.find(11))
  end

  def test_scoped_find_limit_offset_including_has_many_association
    topics = Topic.send(:with_scope, :find => {:limit => 1, :offset => 1, :include => :replies}) do
      Topic.find(:all, :order => "topics.id")
    end
    assert_equal 1, topics.size
    assert_equal 2, topics.first.id
  end

  def test_scoped_find_order_including_has_many_association
    developers = Developer.send(:with_scope, :find => { :order => 'developers.salary DESC', :include => :projects }) do
      Developer.find(:all)
    end
    assert developers.size >= 2
    for i in 1...developers.size
      assert developers[i-1].salary >= developers[i].salary
    end
  end

  def test_scoped_find_with_group_and_having
    developers = Developer.send(:with_scope, :find => { :group => 'developers.salary', :having => "SUM(salary) > 10000", :select => "SUM(salary) as salary" }) do
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

  def test_all
    developers = Developer.all
    assert_kind_of Array, developers
    assert_equal Developer.find(:all), developers
  end

  def test_all_with_conditions
    assert_equal Developer.find(:all, :order => 'id desc'), Developer.order('id desc').all
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

  def test_find_keeps_multiple_order_values
    combined = Developer.find(:all, :order => 'developers.name, developers.salary')
    assert_equal combined, Developer.find(:all, :order => ['developers.name', 'developers.salary'])
  end

  def test_find_keeps_multiple_group_values
    combined = Developer.find(:all, :group => 'developers.name, developers.salary, developers.id, developers.created_at, developers.updated_at')
    assert_equal combined, Developer.find(:all, :group => ['developers.name', 'developers.salary', 'developers.id', 'developers.created_at', 'developers.updated_at'])
  end

  def test_find_symbol_ordered_last
    last  = Developer.find :last, :order => :salary
    assert_equal last, Developer.find(:all, :order => :salary).last
  end

  def test_find_scoped_ordered_last
    last_developer = Developer.send(:with_scope, :find => { :order => 'developers.salary ASC' }) do
      Developer.find(:last)
    end
    assert_equal last_developer, Developer.find(:all, :order => 'developers.salary ASC').last
  end

  def test_abstract_class
    assert !ActiveRecord::Base.abstract_class?
    assert LoosePerson.abstract_class?
    assert !LooseDescendant.abstract_class?
  end

  def test_abstract_class_table_name
    assert_nil AbstractCompany.table_name
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

  def test_to_param_should_return_string
    assert_kind_of String, Client.find(:first).to_param
  end

  def test_to_param_returns_id_even_if_not_persisted
    client = Client.new
    client.id = 1
    assert_equal "1", client.to_param
  end

  def test_inspect_class
    assert_equal 'ActiveRecord::Base', ActiveRecord::Base.inspect
    assert_equal 'LoosePerson(abstract)', LoosePerson.inspect
    assert_match(/^Topic\(id: integer, title: string/, Topic.inspect)
  end

  def test_inspect_instance
    topic = topics(:first)
    assert_equal %(#<Topic id: 1, title: "The First Topic", author_name: "David", author_email_address: "david@loudthinking.com", written_on: "#{topic.written_on.to_s(:db)}", bonus_time: "#{topic.bonus_time.to_s(:db)}", last_read: "#{topic.last_read.to_s(:db)}", content: "Have a nice day", important: nil, approved: false, replies_count: 1, parent_id: nil, parent_title: nil, type: nil, group: nil, created_at: "#{topic.created_at.to_s(:db)}", updated_at: "#{topic.updated_at.to_s(:db)}">), topic.inspect
  end

  def test_inspect_new_instance
    assert_match(/Topic id: nil/, Topic.new.inspect)
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

  def test_becomes_includes_errors
    company = Company.new(:name => nil)
    assert !company.valid?
    original_errors = company.errors
    client = company.becomes(Client)
    assert_equal original_errors, client.errors
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
    ActiveRecord::Base.benchmark("Debug Topic Count", :level => :debug) { Topic.count }
    ActiveRecord::Base.benchmark("Warn Topic Count",  :level => :warn)  { Topic.count }
    ActiveRecord::Base.benchmark("Error Topic Count", :level => :error) { Topic.count }
    assert_no_match(/Debug Topic Count/, log.string)
    assert_match(/Warn Topic Count/, log.string)
    assert_match(/Error Topic Count/, log.string)
  ensure
    ActiveRecord::Base.logger = original_logger
  end

  def test_benchmark_with_use_silence
    original_logger = ActiveRecord::Base.logger
    log = StringIO.new
    ActiveRecord::Base.logger = Logger.new(log)
    ActiveRecord::Base.benchmark("Logging", :level => :debug, :silence => true) { ActiveRecord::Base.logger.debug "Loud" }
    ActiveRecord::Base.benchmark("Logging", :level => :debug, :silence => false)  { ActiveRecord::Base.logger.debug "Quiet" }
    assert_no_match(/Loud/, log.string)
    assert_match(/Quiet/, log.string)
  ensure
    ActiveRecord::Base.logger = original_logger
  end

  def test_compute_type_success
    assert_equal Author, ActiveRecord::Base.send(:compute_type, 'Author')
  end

  def test_compute_type_nonexistent_constant
    assert_raises NameError do
      ActiveRecord::Base.send :compute_type, 'NonexistentModel'
    end
  end

  def test_compute_type_no_method_error
    ActiveSupport::Dependencies.stubs(:constantize).raises(NoMethodError)
    assert_raises NoMethodError do
      ActiveRecord::Base.send :compute_type, 'InvalidModel'
    end
  end

  def test_compute_type_argument_error
    ActiveSupport::Dependencies.stubs(:constantize).raises(ArgumentError)
    assert_raises ArgumentError do
      ActiveRecord::Base.send :compute_type, 'InvalidModel'
    end
  end

  def test_clear_cache!
    # preheat cache
    c1 = Post.connection.schema_cache.columns['posts']
    ActiveRecord::Base.clear_cache!
    c2 = Post.connection.schema_cache.columns['posts']
    assert_not_equal c1, c2
  end

  def test_current_scope_is_reset
    Object.const_set :UnloadablePost, Class.new(ActiveRecord::Base)
    UnloadablePost.send(:current_scope=, UnloadablePost.scoped)

    UnloadablePost.unloadable
    assert_not_nil Thread.current[:UnloadablePost_current_scope]
    ActiveSupport::Dependencies.remove_unloadable_constants!
    assert_nil Thread.current[:UnloadablePost_current_scope]
  ensure
    Object.class_eval{ remove_const :UnloadablePost } if defined?(UnloadablePost)
  end

  def test_marshal_round_trip
    if ENV['TRAVIS'] && RUBY_VERSION == "1.8.7"
      return skip("Marshalling tests disabled for Ruby 1.8.7 on Travis CI due to what appears " \
                  "to be a Ruby bug.")
    end

    expected = posts(:welcome)
    marshalled = Marshal.dump(expected)
    actual   = Marshal.load(marshalled)

    assert_equal expected.attributes, actual.attributes
  end

  def test_marshal_new_record_round_trip
    if ENV['TRAVIS'] && RUBY_VERSION == "1.8.7"
      return skip("Marshalling tests disabled for Ruby 1.8.7 on Travis CI due to what appears " \
                  "to be a Ruby bug.")
    end

    marshalled = Marshal.dump(Post.new)
    post       = Marshal.load(marshalled)

    assert post.new_record?, "should be a new record"
  end

  def test_marshalling_with_associations
    if ENV['TRAVIS'] && RUBY_VERSION == "1.8.7"
      return skip("Marshalling tests disabled for Ruby 1.8.7 on Travis CI due to what appears " \
                  "to be a Ruby bug.")
    end

    post = Post.new
    post.comments.build

    marshalled = Marshal.dump(post)
    post       = Marshal.load(marshalled)

    assert_equal 1, post.comments.length
  end

  def test_attribute_names
    assert_equal ["id", "type", "ruby_type", "firm_id", "firm_name", "name", "client_of", "rating", "account_id"],
                 Company.attribute_names
  end

  def test_attribute_names_on_table_not_exists
    assert_equal [], NonExistentTable.attribute_names
  end

  def test_attribtue_names_on_abstract_class
    assert_equal [], AbstractCompany.attribute_names
  end

  def test_cache_key_for_existing_record_is_not_timezone_dependent
    ActiveRecord::Base.time_zone_aware_attributes = true

    Time.zone = "UTC"
    utc_key = Developer.first.cache_key

    Time.zone = "EST"
    est_key = Developer.first.cache_key

    assert_equal utc_key, est_key
  ensure
    ActiveRecord::Base.time_zone_aware_attributes = false
  end

  def test_cache_key_format_for_existing_record_with_updated_at
    dev = Developer.first
    assert_equal "developers/#{dev.id}-#{dev.updated_at.utc.to_s(:number)}", dev.cache_key
  end

  def test_cache_key_format_for_existing_record_with_nil_updated_at
    dev = Developer.first
    dev.update_attribute(:updated_at, nil)
    assert_match(/\/#{dev.id}$/, dev.cache_key)
  end

  def test_uniq_delegates_to_scoped
    scope = stub
    Bird.stubs(:scoped).returns(mock(:uniq => scope))
    assert_equal scope, Bird.uniq
  end

  def test_table_name_with_2_abstract_subclasses
    assert_equal "photos", Photo.table_name
  end
end
