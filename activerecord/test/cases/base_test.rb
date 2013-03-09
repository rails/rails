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
require 'models/car'
require 'models/bulb'
require 'rexml/document'

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

  def setup
    ActiveRecord::Base.time_zone_aware_attributes = false
    ActiveRecord::Base.default_timezone = :local
    Time.zone = nil
  end

  def test_generated_methods_modules
    modules = Computer.ancestors
    assert modules.include?(Computer::GeneratedFeatureMethods)
    assert_equal(Computer::GeneratedFeatureMethods, Computer.generated_feature_methods)
    assert(modules.index(Computer.generated_attribute_methods) > modules.index(Computer.generated_feature_methods),
           "generated_attribute_methods must be higher in inheritance hierarchy than generated_feature_methods")
    assert_not_equal Computer.generated_feature_methods, Post.generated_feature_methods
    assert(modules.index(Computer.generated_attribute_methods) < modules.index(ActiveRecord::Base.ancestors[1]))
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

  unless current_adapter?(:PostgreSQLAdapter, :OracleAdapter, :SQLServerAdapter)
    def test_limit_with_comma
      assert Topic.limit("1,2").to_a
    end
  end

  def test_limit_without_comma
    assert_equal 1, Topic.limit("1").to_a.length
    assert_equal 1, Topic.limit(1).to_a.length
  end

  def test_invalid_limit
    assert_raises(ArgumentError) do
      Topic.limit("asdfadf").to_a
    end
  end

  def test_limit_should_sanitize_sql_injection_for_limit_without_comas
    assert_raises(ArgumentError) do
      Topic.limit("1 select * from schema").to_a
    end
  end

  def test_limit_should_sanitize_sql_injection_for_limit_with_comas
    assert_raises(ArgumentError) do
      Topic.limit("1, 7 procedure help()").to_a
    end
  end

  unless current_adapter?(:MysqlAdapter, :Mysql2Adapter)
    def test_limit_should_allow_sql_literal
      assert_equal 1, Topic.limit(Arel.sql('2-1')).to_a.length
    end
  end

  def test_select_symbol
    topic_ids = Topic.select(:id).map(&:id).sort
    assert_equal Topic.pluck(:id).sort, topic_ids
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

  def test_previously_changed
    topic = Topic.first
    topic.title = '<3<3<3'
    assert_equal({}, topic.previous_changes)

    topic.save!
    expected = ["The First Topic", "<3<3<3"]
    assert_equal(expected, topic.previous_changes['title'])
  end

  def test_previously_changed_dup
    topic = Topic.first
    topic.title = '<3<3<3'
    topic.save!

    t2 = topic.dup

    assert_equal(topic.previous_changes, t2.previous_changes)

    topic.title = "lolwut"
    topic.save!

    assert_not_equal(topic.previous_changes, t2.previous_changes)
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
    if current_adapter?(:PostgreSQLAdapter, :SQLite3Adapter)
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
    Topic.new({ "title" => "test",
      "last_read(1i)" => "2005", "last_read(2i)" => "2", "last_read(3i)" => "31"})
  rescue ActiveRecord::MultiparameterAssignmentErrors => ex
    assert_equal(1, ex.errors.size)
    assert_equal("last_read", ex.errors[0].attribute)
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

  def test_create_after_initialize_with_array_param
    cbs = CustomBulb.create([{ name: 'Dude' }, { name: 'Bob' }])
    assert_equal 'Dude', cbs[0].name
    assert_equal 'Bob', cbs[1].name
    assert cbs[0].frickinawesome
    assert !cbs[1].frickinawesome
  end

  def test_load
    topics = Topic.all.merge!(:order => 'id').to_a
    assert_equal(4, topics.size)
    assert_equal(topics(:first).title, topics.first.title)
  end

  def test_load_with_condition
    topics = Topic.all.merge!(:where => "author_name = 'Mary'").to_a

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
    Post.pluralize_table_names = false
    Post.reset_table_name
    assert_equal "post", Post.table_name
    assert_equal "categories", Category.table_name
  ensure
    Post.pluralize_table_names = true
    Post.reset_table_name
  end

  if current_adapter?(:MysqlAdapter, :Mysql2Adapter)
    def test_update_all_with_order_and_limit
      assert_equal 1, Topic.limit(1).order('id DESC').update_all(:content => 'bulk updated!')
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

    post.update(title: "try to change", body: "changed")
    post.reload
    assert_equal "cannot change this", post.title
    assert_equal "changed", post.body
  end

  def test_attr_readonly_is_class_level_setting
    post = ReadonlyTitlePost.new
    assert_raise(NoMethodError) { post._attr_readonly = [:title] }
    assert_deprecated { post._attr_readonly }
  end

  def test_non_valid_identifier_column_name
    weird = Weird.create('a$b' => 'value')
    weird.reload
    assert_equal 'value', weird.send('a$b')
    assert_equal 'value', weird.read_attribute('a$b')

    weird.update_columns('a$b' => 'value2')
    weird.reload
    assert_equal 'value2', weird.send('a$b')
    assert_equal 'value2', weird.read_attribute('a$b')
  end

  def test_group_weirds_by_from
    Weird.create('a$b' => 'value', :from => 'aaron')
    count = Weird.group(Weird.arel_table[:from]).count
    assert_equal 1, count['aaron']
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
    duped_topic = topic.dup
    duped_topic.title.replace "c"
    assert_equal "a", topic.title

    # test if attributes set as part of after_initialize are duped correctly
    assert_equal topic.author_email_address, duped_topic.author_email_address

    # test if saved clone object differs from original
    duped_topic.save
    assert duped_topic.persisted?
    assert_not_equal duped_topic.id, topic.id

    duped_topic.reload
    assert_equal("c", duped_topic.title)
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
      tz = Default.default_timezone
      Default.default_timezone = :local
      default = Default.new
      Default.default_timezone = tz

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

      assert_equal true, objs[0].isopen

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

      assert_equal true, objs[0].isclosed
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
    replies = Reply.all.merge!(:where => [ "id IN (?)", topics(:first).replies.collect(&:id) ]).to_a
    assert_equal topics(:first).replies.size, replies.size

    replies = Reply.all.merge!(:where => [ "id IN (?)", [] ]).to_a
    assert_equal 0, replies.size
  end

  def test_quote
    author_name = "\\ \001 ' \n \\n \""
    topic = Topic.create('author_name' => author_name)
    assert_equal author_name, Topic.find(topic.id).author_name
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
    dev.update!(name: "NotDavid" )
    assert_equal dev, dev.reload
  end

  def test_switching_between_table_name
    assert_difference("GoodJoke.count") do
      Joke.table_name = "cold_jokes"
      Joke.create

      Joke.table_name = "funny_jokes"
      Joke.create
    end
  end

  def test_clear_cash_when_setting_table_name
    Joke.table_name = "cold_jokes"
    before_columns = Joke.columns
    before_seq     = Joke.sequence_name

    Joke.table_name = "funny_jokes"
    after_columns = Joke.columns
    after_seq     = Joke.sequence_name

    assert_not_equal before_columns, after_columns
    assert_not_equal before_seq, after_seq unless before_seq.nil? && after_seq.nil?
  end

  def test_dont_clear_sequence_name_when_setting_explicitly
    Joke.sequence_name = "black_jokes_seq"
    Joke.table_name    = "cold_jokes"
    before_seq         = Joke.sequence_name

    Joke.table_name    = "funny_jokes"
    after_seq          = Joke.sequence_name

    assert_equal before_seq, after_seq unless before_seq.nil? && after_seq.nil?
  ensure
    Joke.reset_sequence_name
  end

  def test_dont_clear_inheritnce_column_when_setting_explicitly
    Joke.inheritance_column = "my_type"
    before_inherit = Joke.inheritance_column

    Joke.reset_column_information
    after_inherit = Joke.inheritance_column

    assert_equal before_inherit, after_inherit unless before_inherit.blank? && after_inherit.blank?
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

  def test_set_table_name_with_inheritance
    k = Class.new( ActiveRecord::Base )
    def k.name; "Foo"; end
    def k.table_name; super + "ks"; end
    assert_equal "foosks", k.table_name
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

    res2 = Post.where("posts.#{QUOTED_TYPE} = 'Post'").joins("LEFT JOIN comments ON posts.id=comments.post_id").count
    assert_equal res, res2

    res3 = nil
    assert_nothing_raised do
      res3 = Post.where("posts.#{QUOTED_TYPE} = 'Post'").joins("LEFT JOIN comments ON posts.id=comments.post_id").count
    end
    assert_equal res, res3

    res4 = Post.count_by_sql "SELECT COUNT(p.id) FROM posts p, comments co WHERE p.#{QUOTED_TYPE} = 'Post' AND p.id=co.post_id"
    res5 = nil
    assert_nothing_raised do
      res5 = Post.where("p.#{QUOTED_TYPE} = 'Post' AND p.id=co.post_id").joins("p, comments co").select("p.id").count
    end

    assert_equal res4, res5

    res6 = Post.count_by_sql "SELECT COUNT(DISTINCT p.id) FROM posts p, comments co WHERE p.#{QUOTED_TYPE} = 'Post' AND p.id=co.post_id"
    res7 = nil
    assert_nothing_raised do
      res7 = Post.where("p.#{QUOTED_TYPE} = 'Post' AND p.id=co.post_id").joins("p, comments co").select("p.id").count(distinct: true)
    end
    assert_equal res6, res7
  end

  def test_no_limit_offset
    assert_nothing_raised do
      Developer.all.merge!(:offset => 2).to_a
    end
  end

  def test_find_last
    last  = Developer.last
    assert_equal last, Developer.all.merge!(:order => 'id desc').first
  end

  def test_last
    assert_equal Developer.all.merge!(:order => 'id desc').first, Developer.last
  end

  def test_all
    developers = Developer.all
    assert_kind_of ActiveRecord::Relation, developers
    assert_equal Developer.all, developers
  end

  def test_all_with_conditions
    assert_equal Developer.all.merge!(:order => 'id desc').to_a, Developer.order('id desc').to_a
  end

  def test_find_ordered_last
    last  = Developer.all.merge!(:order => 'developers.salary ASC').last
    assert_equal last, Developer.all.merge!(:order => 'developers.salary ASC').to_a.last
  end

  def test_find_reverse_ordered_last
    last  = Developer.all.merge!(:order => 'developers.salary DESC').last
    assert_equal last, Developer.all.merge!(:order => 'developers.salary DESC').to_a.last
  end

  def test_find_multiple_ordered_last
    last  = Developer.all.merge!(:order => 'developers.name, developers.salary DESC').last
    assert_equal last, Developer.all.merge!(:order => 'developers.name, developers.salary DESC').to_a.last
  end

  def test_find_keeps_multiple_order_values
    combined = Developer.all.merge!(:order => 'developers.name, developers.salary').to_a
    assert_equal combined, Developer.all.merge!(:order => ['developers.name', 'developers.salary']).to_a
  end

  def test_find_keeps_multiple_group_values
    combined = Developer.all.merge!(:group => 'developers.name, developers.salary, developers.id, developers.created_at, developers.updated_at').to_a
    assert_equal combined, Developer.all.merge!(:group => ['developers.name', 'developers.salary', 'developers.id', 'developers.created_at', 'developers.updated_at']).to_a
  end

  def test_find_symbol_ordered_last
    last  = Developer.all.merge!(:order => :salary).last
    assert_equal last, Developer.all.merge!(:order => :salary).to_a.last
  end

  def test_abstract_class
    assert !ActiveRecord::Base.abstract_class?
    assert LoosePerson.abstract_class?
    assert !LooseDescendant.abstract_class?
  end

  def test_abstract_class_table_name
    assert_nil AbstractCompany.table_name
  end

  def test_descends_from_active_record
    assert !ActiveRecord::Base.descends_from_active_record?

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
    assert_kind_of String, Client.first.to_param
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
    assert_equal %(#<Topic id: 1>), Topic.all.merge!(:select => 'id', :where => 'id = 1').first.inspect
    assert_equal %(#<Topic id: 1, title: "The First Topic">), Topic.all.merge!(:select => 'id, title', :where => 'id = 1').first.inspect
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

    assert_deprecated do
      log = StringIO.new
      ActiveRecord::Base.logger = ActiveSupport::Logger.new(log)
      ActiveRecord::Base.logger.level = Logger::DEBUG
      ActiveRecord::Base.silence do
        ActiveRecord::Base.logger.warn "warn"
        ActiveRecord::Base.logger.error "error"
      end
      assert_equal "error\n", log.string
    end
  ensure
    ActiveRecord::Base.logger = original_logger
  end

  def test_silence_sets_log_level_back_to_level_before_yield
    original_logger = ActiveRecord::Base.logger

    assert_deprecated do
      log = StringIO.new
      ActiveRecord::Base.logger = ActiveSupport::Logger.new(log)
      ActiveRecord::Base.logger.level = Logger::WARN
      ActiveRecord::Base.silence do
      end
      assert_equal Logger::WARN, ActiveRecord::Base.logger.level
    end
  ensure
    ActiveRecord::Base.logger = original_logger
  end

  def test_benchmark_with_log_level
    original_logger = ActiveRecord::Base.logger
    log = StringIO.new
    ActiveRecord::Base.logger = ActiveSupport::Logger.new(log)
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
    ActiveRecord::Base.logger = ActiveSupport::Logger.new(log)
    ActiveRecord::Base.benchmark("Logging", :level => :debug, :silence => false)  { ActiveRecord::Base.logger.debug "Quiet" }
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
    UnloadablePost.send(:current_scope=, UnloadablePost.all)

    UnloadablePost.unloadable
    assert_not_nil Thread.current[:UnloadablePost_current_scope]
    ActiveSupport::Dependencies.remove_unloadable_constants!
    assert_nil Thread.current[:UnloadablePost_current_scope]
  ensure
    Object.class_eval{ remove_const :UnloadablePost } if defined?(UnloadablePost)
  end

  def test_marshal_round_trip
    expected = posts(:welcome)
    marshalled = Marshal.dump(expected)
    actual   = Marshal.load(marshalled)

    assert_equal expected.attributes, actual.attributes
  end

  def test_marshal_new_record_round_trip
    marshalled = Marshal.dump(Post.new)
    post       = Marshal.load(marshalled)

    assert post.new_record?, "should be a new record"
  end

  def test_marshalling_with_associations
    post = Post.new
    post.comments.build

    marshalled = Marshal.dump(post)
    post       = Marshal.load(marshalled)

    assert_equal 1, post.comments.length
  end

  def test_marshalling_new_record_round_trip_with_associations
    post = Post.new
    post.comments.build

    post = Marshal.load(Marshal.dump(post))

    assert post.new_record?, "should be a new record"
  end

  def test_attribute_names
    assert_equal ["id", "type", "firm_id", "firm_name", "name", "client_of", "rating", "account_id", "description"],
                 Company.attribute_names
  end

  def test_attribute_names_on_table_not_exists
    assert_equal [], NonExistentTable.attribute_names
  end

  def test_attribute_names_on_abstract_class
    assert_equal [], AbstractCompany.attribute_names
  end

  def test_cache_key_for_existing_record_is_not_timezone_dependent
    ActiveRecord::Base.time_zone_aware_attributes = true

    Time.zone = "UTC"
    utc_key = Developer.first.cache_key

    Time.zone = "EST"
    est_key = Developer.first.cache_key

    assert_equal utc_key, est_key
  end

  def test_cache_key_format_for_existing_record_with_updated_at
    dev = Developer.first
    assert_equal "developers/#{dev.id}-#{dev.updated_at.utc.to_s(:nsec)}", dev.cache_key
  end

  def test_cache_key_format_for_existing_record_with_updated_at_and_custom_cache_timestamp_format
    dev = CachedDeveloper.first
    assert_equal "cached_developers/#{dev.id}-#{dev.updated_at.utc.to_s(:number)}", dev.cache_key
  end

  def test_cache_key_changes_when_child_touched
    car = Car.create
    Bulb.create(car: car)

    key = car.cache_key
    car.bulb.touch
    car.reload
    assert_not_equal key, car.cache_key
  end

  def test_cache_key_format_for_existing_record_with_nil_updated_at
    dev = Developer.first
    dev.update_columns(updated_at: nil)
    assert_match(/\/#{dev.id}$/, dev.cache_key)
  end

  def test_cache_key_format_is_precise_enough
    dev = Developer.first
    key = dev.cache_key
    dev.touch
    assert_not_equal key, dev.cache_key
  end

  def test_uniq_delegates_to_scoped
    scope = stub
    Bird.stubs(:all).returns(mock(:uniq => scope))
    assert_equal scope, Bird.uniq
  end

  def test_table_name_with_2_abstract_subclasses
    assert_equal "photos", Photo.table_name
  end

  def test_column_types_typecast
    topic = Topic.first
    assert_not_equal 't.lo', topic.author_name

    attrs = topic.attributes.dup
    attrs.delete 'id'

    typecast = Class.new {
      def type_cast value
        "t.lo"
      end
    }

    types = { 'author_name' => typecast.new }
    topic = Topic.allocate.init_with 'attributes' => attrs,
                                     'column_types' => types

    assert_equal 't.lo', topic.author_name
  end

  def test_typecasting_aliases
    assert_equal 10, Topic.select('10 as tenderlove').first.tenderlove
  end

  def test_slice
    company = Company.new(:rating => 1, :name => "37signals", :firm_name => "37signals")
    hash = company.slice(:name, :rating, "arbitrary_method")
    assert_equal hash[:name], company.name
    assert_equal hash['name'], company.name
    assert_equal hash[:rating], company.rating
    assert_equal hash['arbitrary_method'], company.arbitrary_method
    assert_equal hash[:arbitrary_method], company.arbitrary_method
    assert_nil hash[:firm_name]
    assert_nil hash['firm_name']
  end

  def test_default_values_are_deeply_dupped
    company = Company.new
    company.description << "foo"
    assert_equal "", Company.new.description
  end

  ["find_by", "find_by!"].each do |meth|
    test "#{meth} delegates to scoped" do
      record = stub

      scope = mock
      scope.expects(meth).with(:foo, :bar).returns(record)

      klass = Class.new(ActiveRecord::Base)
      klass.stubs(:all => scope)

      assert_equal record, klass.public_send(meth, :foo, :bar)
    end
  end

  test "scoped can take a values hash" do
    klass = Class.new(ActiveRecord::Base)
    assert_equal ['foo'], klass.all.merge!(select: 'foo').select_values
  end
end
