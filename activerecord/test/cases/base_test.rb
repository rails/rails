# frozen_string_literal: true

require "cases/helper"
require "models/post"
require "models/author"
require "models/topic"
require "models/reply"
require "models/category"
require "models/categorization"
require "models/company"
require "models/customer"
require "models/developer"
require "models/computer"
require "models/project"
require "models/default"
require "models/auto_id"
require "models/column_name"
require "models/subscriber"
require "models/comment"
require "models/minimalistic"
require "models/warehouse_thing"
require "models/parrot"
require "models/person"
require "models/edge"
require "models/joke"
require "models/bird"
require "models/car"
require "models/bulb"
require "concurrent/atomic/count_down_latch"
require "active_support/core_ext/enumerable"

class FirstAbstractClass < ActiveRecord::Base
  self.abstract_class = true
end
class SecondAbstractClass < FirstAbstractClass
  self.abstract_class = true
end
class Photo < SecondAbstractClass; end
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
class NonExistentTable < ActiveRecord::Base; end
class TestOracleDefault < ActiveRecord::Base; end

class ReadonlyTitlePost < Post
  attr_readonly :title
end

class Weird < ActiveRecord::Base; end

class LintTest < ActiveRecord::TestCase
  include ActiveModel::Lint::Tests

  class LintModel < ActiveRecord::Base; end

  def setup
    @model = LintModel.new
  end
end

class BasicsTest < ActiveRecord::TestCase
  fixtures :topics, :companies, :developers, :projects, :computers, :accounts, :minimalistics, "warehouse-things", :authors, :author_addresses, :categorizations, :categories, :posts

  def test_generated_association_methods_module_name
    mod = Post.send(:generated_association_methods)
    assert_equal "Post::GeneratedAssociationMethods", mod.inspect
  end

  def test_generated_relation_methods_module_name
    mod = Post.send(:generated_relation_methods)
    assert_equal "Post::GeneratedRelationMethods", mod.inspect
  end

  def test_incomplete_schema_loading
    topic = Topic.first
    payload = { foo: 42 }
    topic.update!(content: payload)

    Topic.reset_column_information

    Topic.connection.stub(:lookup_cast_type_from_column, ->(_) { raise "Some Error" }) do
      assert_raises RuntimeError do
        Topic.first
      end
    end

    assert_equal payload, Topic.first.content
  end

  def test_column_names_are_escaped
    conn      = ActiveRecord::Base.connection
    classname = conn.class.name[/[^:]*$/]
    badchar   = {
      "SQLite3Adapter"    => '"',
      "Mysql2Adapter"     => "`",
      "PostgreSQLAdapter" => '"',
      "OracleAdapter"     => '"',
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
    pk = Subscriber.columns_hash[Subscriber.primary_key]
    assert_equal "nick", pk.name, "nick should be primary key"
  end

  def test_primary_key_with_no_id
    assert_nil Edge.primary_key
  end

  def test_primary_key_and_references_columns_should_be_identical_type
    pk = Author.columns_hash["id"]
    ref = Post.columns_hash["author_id"]

    assert_equal pk.sql_type, ref.sql_type
  end

  def test_many_mutations
    car = Car.new name: "<3<3<3"
    car.engines_count = 0
    20_000.times { car.engines_count += 1 }
    assert car.save
  end

  def test_limit_without_comma
    assert_equal 1, Topic.limit("1").to_a.length
    assert_equal 1, Topic.limit(1).to_a.length
  end

  def test_limit_should_take_value_from_latest_limit
    assert_equal 1, Topic.limit(2).limit(1).to_a.length
  end

  def test_invalid_limit
    assert_raises(ArgumentError) do
      Topic.limit("asdfadf").to_a
    end
  end

  def test_limit_should_sanitize_sql_injection_for_limit_without_commas
    assert_raises(ArgumentError) do
      Topic.limit("1 select * from schema").to_a
    end
  end

  def test_limit_should_sanitize_sql_injection_for_limit_with_commas
    assert_raises(ArgumentError) do
      Topic.limit("1, 7 procedure help()").to_a
    end
  end

  def test_select_symbol
    topic_ids = Topic.select(:id).map(&:id).sort
    assert_equal Topic.pluck(:id).sort, topic_ids
  end

  def test_table_exists
    assert_not_predicate NonExistentTable, :table_exists?
    assert_predicate Topic, :table_exists?
  end

  def test_preserving_date_objects
    # Oracle enhanced adapter allows to define Date attributes in model class (see topic.rb)
    assert_kind_of(
      Date, Topic.find(1).last_read,
      "The last_read attribute should be of the Date class"
    )
  end

  def test_previously_changed
    topic = Topic.first
    topic.title = "<3<3<3"
    assert_equal({}, topic.previous_changes)

    topic.save!
    expected = ["The First Topic", "<3<3<3"]
    assert_equal(expected, topic.previous_changes["title"])
  end

  def test_previously_changed_dup
    topic = Topic.first
    topic.title = "<3<3<3"
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
    if supports_datetime_with_precision?
      assert_equal 11, Topic.find(1).written_on.sec
      assert_equal 223300, Topic.find(1).written_on.usec
      assert_equal 9900, Topic.find(2).written_on.usec
      assert_equal 129346, Topic.find(3).written_on.usec
    end
  end

  def test_preserving_time_objects_with_local_time_conversion_to_default_timezone_utc
    with_env_tz eastern_time_zone do
      with_timezone_config default: :utc do
        time = Time.local(2000)
        topic = Topic.create("written_on" => time)
        saved_time = Topic.find(topic.id).reload.written_on
        assert_equal time, saved_time
        assert_equal [0, 0, 0, 1, 1, 2000, 6, 1, false, "EST"], time.to_a
        assert_equal [0, 0, 5, 1, 1, 2000, 6, 1, false, "UTC"], saved_time.to_a
      end
    end
  end

  def test_preserving_time_objects_with_time_with_zone_conversion_to_default_timezone_utc
    with_env_tz eastern_time_zone do
      with_timezone_config default: :utc do
        Time.use_zone "Central Time (US & Canada)" do
          time = Time.zone.local(2000)
          topic = Topic.create("written_on" => time)
          saved_time = Topic.find(topic.id).reload.written_on
          assert_equal time, saved_time
          assert_equal [0, 0, 0, 1, 1, 2000, 6, 1, false, "CST"], time.to_a
          assert_equal [0, 0, 6, 1, 1, 2000, 6, 1, false, "UTC"], saved_time.to_a
        end
      end
    end
  end

  def test_preserving_time_objects_with_utc_time_conversion_to_default_timezone_local
    with_env_tz eastern_time_zone do
      with_timezone_config default: :local do
        time = Time.utc(2000)
        topic = Topic.create("written_on" => time)
        saved_time = Topic.find(topic.id).reload.written_on
        assert_equal time, saved_time
        assert_equal [0, 0, 0, 1, 1, 2000, 6, 1, false, "UTC"], time.to_a
        assert_equal [0, 0, 19, 31, 12, 1999, 5, 365, false, "EST"], saved_time.to_a
      end
    end
  end

  def test_preserving_time_objects_with_time_with_zone_conversion_to_default_timezone_local
    with_env_tz eastern_time_zone do
      with_timezone_config default: :local do
        Time.use_zone "Central Time (US & Canada)" do
          time = Time.zone.local(2000)
          topic = Topic.create("written_on" => time)
          saved_time = Topic.find(topic.id).reload.written_on
          assert_equal time, saved_time
          assert_equal [0, 0, 0, 1, 1, 2000, 6, 1, false, "CST"], time.to_a
          assert_equal [0, 0, 1, 1, 1, 2000, 6, 1, false, "EST"], saved_time.to_a
        end
      end
    end
  end

  def eastern_time_zone
    if Gem.win_platform?
      "EST5EDT"
    else
      "America/New_York"
    end
  end

  def test_custom_mutator
    topic = Topic.find(1)
    # This mutator is protected in the class definition
    topic.send(:approved=, true)
    assert topic.instance_variable_get("@custom_approved")
  end

  def test_initialize_with_attributes
    topic = Topic.new(
      "title" => "initialized from attributes", "written_on" => "2003-12-12 23:23")

    assert_equal("initialized from attributes", topic.title)
  end

  def test_initialize_with_invalid_attribute
    ex = assert_raise(ActiveRecord::MultiparameterAssignmentErrors) do
      Topic.new("title" => "test",
        "written_on(4i)" => "16", "written_on(5i)" => "24", "written_on(6i)" => "00")
    end

    assert_equal(1, ex.errors.size)
    assert_equal("written_on", ex.errors[0].attribute)
  end

  def test_create_after_initialize_without_block
    cb = CustomBulb.create(name: "Dude")
    assert_equal("Dude", cb.name)
    assert_equal(true, cb.frickinawesome)
  end

  def test_create_after_initialize_with_block
    cb = CustomBulb.create { |c| c.name = "Dude" }
    assert_equal("Dude", cb.name)
    assert_equal(true, cb.frickinawesome)
  end

  def test_create_after_initialize_with_array_param
    cbs = CustomBulb.create([{ name: "Dude" }, { name: "Bob" }])
    assert_equal "Dude", cbs[0].name
    assert_equal "Bob", cbs[1].name
    assert cbs[0].frickinawesome
    assert_not cbs[1].frickinawesome
  end

  def test_load
    topics = Topic.all.merge!(order: "id").to_a
    assert_equal(5, topics.size)
    assert_equal(topics(:first).title, topics.first.title)
  end

  def test_load_with_condition
    topics = Topic.all.merge!(where: "author_name = 'Mary'").to_a

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

  def test_null_fields
    assert_nil Topic.find(1).parent_id
    assert_nil Topic.create("title" => "Hey you").parent_id
  end

  def test_default_values
    topic = Topic.new
    assert_predicate topic, :approved?
    assert_nil topic.written_on
    assert_nil topic.bonus_time
    assert_nil topic.last_read

    topic.save

    topic = Topic.find(topic.id)
    assert_predicate topic, :approved?
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

  # Oracle does not have a TIME datatype.
  unless current_adapter?(:OracleAdapter)
    def test_utc_as_time_zone
      with_timezone_config default: :utc do
        attributes = { "bonus_time" => "5:42:00AM" }
        topic = Topic.find(1)
        topic.attributes = attributes
        assert_equal Time.utc(2000, 1, 1, 5, 42, 0), topic.bonus_time
      end
    end

    def test_utc_as_time_zone_and_new
      with_timezone_config default: :utc do
        attributes = { "bonus_time(1i)" => "2000",
          "bonus_time(2i)" => "1",
          "bonus_time(3i)" => "1",
          "bonus_time(4i)" => "10",
          "bonus_time(5i)" => "35",
          "bonus_time(6i)" => "50" }
        topic = Topic.new(attributes)
        assert_equal Time.utc(2000, 1, 1, 10, 35, 50), topic.bonus_time
      end
    end
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
    assert_equal Topic.find(1), Topic.find(2).topic
  end

  def test_find_by_slug
    assert_equal Topic.find("1-meowmeow"), Topic.find(1)
  end

  def test_out_of_range_slugs
    assert_equal [Topic.find(1)], Topic.where(id: ["1-meowmeow", "9223372036854775808-hello"])
  end

  def test_find_by_slug_with_array
    assert_equal Topic.find([1, 2]), Topic.find(["1-meowmeow", "2-hello"])
    assert_equal "The Second Topic of the day", Topic.find(["2-hello", "1-meowmeow"]).first.title
  end

  def test_find_by_slug_with_range
    assert_equal Topic.where(id: "1-meowmeow".."2-hello"), Topic.where(id: 1..2)
  end

  def test_equality_of_new_records
    assert_not_equal Topic.new, Topic.new
    assert_equal false, Topic.new == Topic.new
  end

  def test_equality_of_destroyed_records
    topic_1 = Topic.new(title: "test_1")
    topic_1.save
    topic_2 = Topic.find(topic_1.id)
    topic_1.destroy
    assert_equal topic_1, topic_2
    assert_equal topic_2, topic_1
  end

  def test_equality_with_blank_ids
    one = Subscriber.new(id: "")
    two = Subscriber.new(id: "")
    assert_equal one, two
  end

  def test_equality_of_relation_and_collection_proxy
    car = Car.create!
    car.bulbs.build
    car.save

    assert car.bulbs == Bulb.where(car_id: car.id), "CollectionProxy should be comparable with Relation"
    assert Bulb.where(car_id: car.id) == car.bulbs, "Relation should be comparable with CollectionProxy"
  end

  def test_equality_of_relation_and_array
    car = Car.create!
    car.bulbs.build
    car.save

    assert Bulb.where(car_id: car.id) == car.bulbs.to_a, "Relation should be comparable with Array"
  end

  def test_equality_of_relation_and_association_relation
    car = Car.create!
    car.bulbs.build
    car.save

    assert_equal Bulb.where(car_id: car.id), car.bulbs.includes(:car), "Relation should be comparable with AssociationRelation"
    assert_equal car.bulbs.includes(:car), Bulb.where(car_id: car.id), "AssociationRelation should be comparable with Relation"
  end

  def test_equality_of_collection_proxy_and_association_relation
    car = Car.create!
    car.bulbs.build
    car.save

    assert_equal car.bulbs, car.bulbs.includes(:car), "CollectionProxy should be comparable with AssociationRelation"
    assert_equal car.bulbs.includes(:car), car.bulbs, "AssociationRelation should be comparable with CollectionProxy"
  end

  def test_hashing
    assert_equal [ Topic.find(1) ], [ Topic.find(2).topic ] & [ Topic.find(1) ]
  end

  def test_successful_comparison_of_like_class_records
    topic_1 = Topic.create!
    topic_2 = Topic.create!

    assert_equal [topic_2, topic_1].sort, [topic_1, topic_2]
  end

  def test_failed_comparison_of_unlike_class_records
    assert_raises ArgumentError do
      [ topics(:first), posts(:welcome) ].sort
    end
  end

  def test_create_without_prepared_statement
    topic = Topic.connection.unprepared_statement do
      Topic.create(title: "foo")
    end

    assert_equal topic, Topic.find(topic.id)
  end

  def test_destroy_without_prepared_statement
    topic = Topic.create(title: "foo")
    Topic.connection.unprepared_statement do
      Topic.find(topic.id).destroy
    end

    assert_nil Topic.find_by_id(topic.id)
  end

  def test_comparison_with_different_objects
    topic = Topic.create
    category = Category.create(name: "comparison")
    assert_nil topic <=> category
  end

  def test_comparison_with_different_objects_in_array
    topic = Topic.create
    assert_raises(ArgumentError) do
      [1, topic].sort
    end
  end

  def test_readonly_attributes
    assert_equal Set.new([ "title", "comments_count" ]), ReadonlyTitlePost.readonly_attributes

    post = ReadonlyTitlePost.create(title: "cannot change this", body: "changeable")
    post.reload
    assert_equal "cannot change this", post.title

    post.update(title: "try to change", body: "changed")
    post.reload
    assert_equal "cannot change this", post.title
    assert_equal "changed", post.body
  end

  def test_unicode_column_name
    Weird.reset_column_information
    weird = Weird.create(なまえ: "たこ焼き仮面")
    assert_equal "たこ焼き仮面", weird.なまえ
  end

  unless current_adapter?(:PostgreSQLAdapter)
    def test_respect_internal_encoding
      old_default_internal = Encoding.default_internal
      silence_warnings { Encoding.default_internal = "EUC-JP" }

      Weird.reset_column_information

      assert_equal ["EUC-JP"], Weird.columns.map { |c| c.name.encoding.name }.uniq
    ensure
      silence_warnings { Encoding.default_internal = old_default_internal }
      Weird.reset_column_information
    end
  end

  def test_non_valid_identifier_column_name
    weird = Weird.create("a$b" => "value")
    weird.reload
    assert_equal "value", weird.send("a$b")
    assert_equal "value", weird.read_attribute("a$b")

    weird.update_columns("a$b" => "value2")
    weird.reload
    assert_equal "value2", weird.send("a$b")
    assert_equal "value2", weird.read_attribute("a$b")
  end

  def test_group_weirds_by_from
    Weird.create("a$b" => "value", :from => "aaron")
    count = Weird.group(Weird.arel_table[:from]).count
    assert_equal 1, count["aaron"]
  end

  def test_attributes_on_dummy_time
    # Oracle does not have a TIME datatype.
    return true if current_adapter?(:OracleAdapter)

    with_timezone_config default: :local do
      attributes = {
        "bonus_time" => "5:42:00AM"
      }
      topic = Topic.find(1)
      topic.attributes = attributes
      assert_equal Time.local(2000, 1, 1, 5, 42, 0), topic.bonus_time

      topic.save!
      assert_equal topic, Topic.find_by(attributes)
    end
  end

  def test_attributes_on_dummy_time_with_invalid_time
    # Oracle does not have a TIME datatype.
    return true if current_adapter?(:OracleAdapter)

    attributes = {
      "bonus_time" => "not a time"
    }
    topic = Topic.find(1)
    topic.attributes = attributes
    assert_nil topic.bonus_time
  end

  def test_attributes
    category = Category.new(name: "Ruby")

    expected_attributes = category.attribute_names.index_with do |attribute_name|
      category.public_send(attribute_name)
    end

    assert_instance_of Hash, category.attributes
    assert_equal expected_attributes, category.attributes
  end

  def test_new_record_returns_boolean
    assert_equal false, Topic.new.persisted?
    assert_equal true, Topic.find(1).persisted?
  end

  def test_previously_new_record_returns_boolean
    assert_equal false, Topic.new.previously_new_record?
    assert_equal true, Topic.create.previously_new_record?
    assert_equal false, Topic.find(1).previously_new_record?
  end

  def test_dup
    topic = Topic.find(1)
    duped_topic = nil
    assert_nothing_raised { duped_topic = topic.dup }
    assert_equal topic.title, duped_topic.title
    assert_not_predicate duped_topic, :persisted?

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
    assert_predicate duped_topic, :persisted?
    assert_not_equal duped_topic.id, topic.id

    duped_topic.reload
    assert_equal("c", duped_topic.title)
  end

  DeveloperSalary = Struct.new(:amount)
  def test_dup_with_aggregate_of_same_name_as_attribute
    developer_with_aggregate = Class.new(ActiveRecord::Base) do
      self.table_name = "developers"
      composed_of :salary, class_name: "BasicsTest::DeveloperSalary", mapping: [%w(salary amount)]
    end

    dev = developer_with_aggregate.find(1)
    assert_kind_of DeveloperSalary, dev.salary

    dup = nil
    assert_nothing_raised { dup = dev.dup }
    assert_kind_of DeveloperSalary, dup.salary
    assert_equal dev.salary.amount, dup.salary.amount
    assert_not_predicate dup, :persisted?

    # test if the attributes have been duped
    original_amount = dup.salary.amount
    dev.salary.amount = 1
    assert_equal original_amount, dup.salary.amount

    assert dup.save
    assert_predicate dup, :persisted?
    assert_not_equal dup.id, dev.id
  end

  def test_dup_does_not_copy_associations
    author = authors(:david)
    assert_not_equal [], author.posts

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
    assert_not_predicate developer, :name_changed?
    assert_not_predicate developer, :salary_changed?

    cloned_developer = developer.clone
    assert_not_predicate cloned_developer, :name_changed?
    assert_not_predicate cloned_developer, :salary_changed?
  end

  def test_clone_of_new_object_marks_attributes_as_dirty
    developer = Developer.new name: "Bjorn", salary: 100000
    assert_predicate developer, :name_changed?
    assert_predicate developer, :salary_changed?

    cloned_developer = developer.clone
    assert_predicate cloned_developer, :name_changed?
    assert_predicate cloned_developer, :salary_changed?
  end

  def test_clone_of_new_object_marks_as_dirty_only_changed_attributes
    developer = Developer.new name: "Bjorn"
    assert developer.name_changed?            # obviously
    assert_not developer.salary_changed?         # attribute has non-nil default value, so treated as not changed

    cloned_developer = developer.clone
    assert_predicate cloned_developer, :name_changed?
    assert_not cloned_developer.salary_changed?  # ... and cloned instance should behave same
  end

  def test_dup_of_saved_object_marks_attributes_as_dirty
    developer = Developer.create! name: "Bjorn", salary: 100000
    assert_not_predicate developer, :name_changed?
    assert_not_predicate developer, :salary_changed?

    cloned_developer = developer.dup
    assert cloned_developer.name_changed?     # both attributes differ from defaults
    assert_predicate cloned_developer, :salary_changed?
  end

  def test_dup_of_saved_object_marks_as_dirty_only_changed_attributes
    developer = Developer.create! name: "Bjorn"
    assert_not developer.name_changed?           # both attributes of saved object should be treated as not changed
    assert_not_predicate developer, :salary_changed?

    cloned_developer = developer.dup
    assert cloned_developer.name_changed?     # ... but on cloned object should be
    assert_not cloned_developer.salary_changed?  # ... BUT salary has non-nil default which should be treated as not changed on cloned instance
  end

  def test_bignum
    company = Company.find(1)
    company.rating = 2147483648
    company.save
    company = Company.find(1)
    assert_equal 2147483648, company.rating
  end

  def test_bignum_pk
    company = Company.create!(id: 2147483648, name: "foo")
    assert_equal company, Company.find(company.id)
  end

  if current_adapter?(:PostgreSQLAdapter, :Mysql2Adapter, :SQLite3Adapter)
    def test_default
      with_timezone_config default: :local do
        default = Default.new

        # fixed dates / times
        assert_equal Date.new(2004, 1, 1), default.fixed_date
        assert_equal Time.local(2004, 1, 1, 0, 0, 0, 0), default.fixed_time

        # char types
        assert_equal "Y", default.char1
        assert_equal "a varchar field", default.char2
        # Mysql text type can't have default value
        unless current_adapter?(:Mysql2Adapter)
          assert_equal "a text field", default.char3
        end
      end
    end
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
    replies = Reply.all.merge!(where: [ "id IN (?)", topics(:first).replies.collect(&:id) ]).to_a
    assert_equal topics(:first).replies.size, replies.size

    replies = Reply.all.merge!(where: [ "id IN (?)", [] ]).to_a
    assert_equal 0, replies.size
  end

  def test_quote
    author_name = "\\ \001 ' \n \\n \""
    topic = Topic.create("author_name" => author_name)
    assert_equal author_name, Topic.find(topic.id).author_name
  end

  def test_toggle_attribute
    assert_not_predicate topics(:first), :approved?
    topics(:first).toggle!(:approved)
    assert_predicate topics(:first), :approved?
    topic = topics(:first)
    topic.toggle(:approved)
    assert_not_predicate topic, :approved?
    topic.reload
    assert_predicate topic, :approved?
  end

  def test_reload
    t1 = Topic.find(1)
    t2 = Topic.find(1)
    t1.title = "something else"
    t1.save
    t2.reload
    assert_equal t1.title, t2.title
  end

  def test_switching_between_table_name
    k = Class.new(Joke)

    assert_difference("GoodJoke.count") do
      k.table_name = "cold_jokes"
      k.create

      k.table_name = "funny_jokes"
      k.create
    end
  end

  def test_clear_cache_when_setting_table_name
    original_table_name = Joke.table_name

    Joke.table_name = "funny_jokes"
    before_columns = Joke.columns
    before_seq = Joke.sequence_name

    Joke.table_name = "cold_jokes"
    after_columns = Joke.columns
    after_seq = Joke.sequence_name

    assert_not_equal before_columns, after_columns
    assert_not_equal before_seq, after_seq unless before_seq.nil? && after_seq.nil?
  ensure
    Joke.table_name = original_table_name
  end

  def test_dont_clear_sequence_name_when_setting_explicitly
    k = Class.new(Joke)
    k.sequence_name = "black_jokes_seq"
    k.table_name = "cold_jokes"
    before_seq = k.sequence_name

    k.table_name = "funny_jokes"
    after_seq = k.sequence_name

    assert_equal before_seq, after_seq unless before_seq.nil? && after_seq.nil?
  end

  def test_dont_clear_inheritance_column_when_setting_explicitly
    k = Class.new(Joke)
    k.inheritance_column = "my_type"
    before_inherit = k.inheritance_column

    k.reset_column_information
    after_inherit = k.inheritance_column

    assert_equal before_inherit, after_inherit unless before_inherit.blank? && after_inherit.blank?
  end

  def test_set_table_name_symbol_converted_to_string
    k = Class.new(Joke)
    k.table_name = :cold_jokes
    assert_equal "cold_jokes", k.table_name
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
    k = Class.new(ActiveRecord::Base)
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
    skip "sequences not supported by db" unless orig_name
    assert_equal k.reset_sequence_name, orig_name
  end

  def test_count_with_join
    res = Post.count_by_sql "SELECT COUNT(*) FROM posts LEFT JOIN comments ON posts.id=comments.post_id WHERE posts.#{QUOTED_TYPE} = 'Post'"
    res2 = Post.where("posts.#{QUOTED_TYPE} = 'Post'").joins("LEFT JOIN comments ON posts.id=comments.post_id").count
    assert_equal res, res2

    res4 = Post.count_by_sql "SELECT COUNT(p.id) FROM posts p, comments co WHERE p.#{QUOTED_TYPE} = 'Post' AND p.id=co.post_id"
    res5 = Post.where("p.#{QUOTED_TYPE} = 'Post' AND p.id=co.post_id").joins("p, comments co").select("p.id").count
    assert_equal res4, res5

    res6 = Post.count_by_sql "SELECT COUNT(DISTINCT p.id) FROM posts p, comments co WHERE p.#{QUOTED_TYPE} = 'Post' AND p.id=co.post_id"
    res7 = Post.where("p.#{QUOTED_TYPE} = 'Post' AND p.id=co.post_id").joins("p, comments co").select("p.id").distinct.count
    assert_equal res6, res7
  end

  def test_no_limit_offset
    assert_nothing_raised do
      Developer.all.merge!(offset: 2).to_a
    end
  end

  def test_last
    assert_equal Developer.all.merge!(order: "id desc").first, Developer.last
  end

  def test_all
    developers = Developer.all
    assert_kind_of ActiveRecord::Relation, developers
    assert_equal Developer.all, developers
  end

  def test_all_with_conditions
    assert_equal Developer.all.merge!(order: "id desc").to_a, Developer.order("id desc").to_a
  end

  def test_find_ordered_last
    last = Developer.order("developers.salary ASC").last
    assert_equal last, Developer.order("developers.salary": "ASC").to_a.last
  end

  def test_find_reverse_ordered_last
    last = Developer.order("developers.salary DESC").last
    assert_equal last, Developer.order("developers.salary": "DESC").to_a.last
  end

  def test_find_multiple_ordered_last
    last = Developer.order("developers.name, developers.salary DESC").last
    assert_equal last, Developer.order(:"developers.name", "developers.salary": "DESC").to_a.last
  end

  def test_find_keeps_multiple_order_values
    combined = Developer.order("developers.name, developers.salary").to_a
    assert_equal combined, Developer.order(:"developers.name", :"developers.salary").to_a
  end

  def test_find_keeps_multiple_group_values
    combined = Developer.merge(group: "developers.name, developers.salary, developers.id, developers.legacy_created_at, developers.legacy_updated_at, developers.legacy_created_on, developers.legacy_updated_on").to_a
    assert_equal combined, Developer.merge(group: ["developers.name", "developers.salary", "developers.id", "developers.created_at", "developers.updated_at", "developers.created_on", "developers.updated_on"]).to_a
  end

  def test_find_symbol_ordered_last
    last = Developer.all.merge!(order: :salary).last
    assert_equal last, Developer.all.merge!(order: :salary).to_a.last
  end

  def test_abstract_class_table_name
    assert_nil AbstractCompany.table_name
  end

  def test_find_on_abstract_base_class_doesnt_use_type_condition
    old_class = LooseDescendant
    Object.send :remove_const, :LooseDescendant

    descendant = old_class.create! first_name: "bob"
    assert_not_nil LoosePerson.find(descendant.id), "Should have found instance of LooseDescendant when finding abstract LoosePerson: #{descendant.inspect}"
  ensure
    unless Object.const_defined?(:LooseDescendant)
      Object.const_set :LooseDescendant, old_class
    end
  end

  def test_assert_queries
    query = lambda { ActiveRecord::Base.connection.execute "select count(*) from developers" }
    assert_queries(2) { 2.times { query.call } }
    assert_queries 1, &query
    assert_no_queries { assert true }
  end

  def test_benchmark_with_log_level
    original_logger = ActiveRecord::Base.logger
    log = StringIO.new
    ActiveRecord::Base.logger = ActiveSupport::Logger.new(log)
    ActiveRecord::Base.logger.level = Logger::WARN
    ActiveRecord::Base.benchmark("Debug Topic Count", level: :debug) { Topic.count }
    ActiveRecord::Base.benchmark("Warn Topic Count",  level: :warn)  { Topic.count }
    ActiveRecord::Base.benchmark("Error Topic Count", level: :error) { Topic.count }
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
    ActiveRecord::Base.logger.level = Logger::DEBUG
    ActiveRecord::Base.benchmark("Logging", level: :debug, silence: false)  { ActiveRecord::Base.logger.debug "Quiet" }
    assert_match(/Quiet/, log.string)
  ensure
    ActiveRecord::Base.logger = original_logger
  end

  def test_clear_cache!
    # preheat cache
    c1 = Post.connection.schema_cache.columns("posts")
    assert_not_equal 0, Post.connection.schema_cache.size

    ActiveRecord::Base.clear_cache!
    assert_equal 0, Post.connection.schema_cache.size

    c2 = Post.connection.schema_cache.columns("posts")
    assert_not_equal 0, Post.connection.schema_cache.size

    assert_equal c1, c2
  end

  def test_current_scope_is_reset
    Object.const_set :UnloadablePost, Class.new(ActiveRecord::Base)
    UnloadablePost.current_scope = UnloadablePost.all

    UnloadablePost.unloadable
    klass = UnloadablePost
    assert_not_nil ActiveRecord::Scoping::ScopeRegistry.value_for(:current_scope, klass)
    ActiveSupport::Dependencies.remove_unloadable_constants!
    assert_nil ActiveRecord::Scoping::ScopeRegistry.value_for(:current_scope, klass)
  ensure
    Object.class_eval { remove_const :UnloadablePost } if defined?(UnloadablePost)
  end

  def test_marshal_round_trip
    expected = posts(:welcome)
    marshalled = Marshal.dump(expected)
    actual = Marshal.load(marshalled)

    assert_equal expected.attributes, actual.attributes
  end

  def test_marshal_inspected_round_trip
    expected = posts(:welcome)
    expected.inspect

    marshalled = Marshal.dump(expected)
    actual = Marshal.load(marshalled)

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

  if current_adapter?(:Mysql2Adapter)
    def test_marshal_load_legacy_6_0_record_mysql
      path = File.expand_path(
        "support/marshal_compatibility_fixtures/legacy_6_0_record_mysql.dump",
        TEST_ROOT
      )
      topic = Marshal.load(File.read(path))

      assert_not_predicate topic, :new_record?
      assert_equal 1, topic.id
      assert_equal "The First Topic", topic.title
      assert_equal "Have a nice day", topic.content
    end
  end

  if Process.respond_to?(:fork) && !in_memory_db?
    def test_marshal_between_processes
      # Define a new model to ensure there are no caches
      if self.class.const_defined?("Post", false)
        flunk "there should be no post constant"
      end

      self.class.const_set("Post", Class.new(ActiveRecord::Base) {
        has_many :comments
      })

      rd, wr = IO.pipe
      rd.binmode
      wr.binmode

      ActiveRecord::Base.connection_handler.clear_all_connections!

      fork do
        rd.close
        post = Post.new
        post.comments.build
        wr.write Marshal.dump(post)
        wr.close
      end

      wr.close
      assert Marshal.load rd.read
      rd.close
    ensure
      self.class.send(:remove_const, "Post") if self.class.const_defined?("Post", false)
    end
  end

  def test_marshalling_new_record_round_trip_with_associations
    post = Post.new
    post.comments.build

    post = Marshal.load(Marshal.dump(post))

    assert post.new_record?, "should be a new record"
  end

  def test_attribute_names
    expected = ["id", "type", "firm_id", "firm_name", "name", "client_of", "rating", "account_id", "description", "metadata"]
    assert_equal expected, Company.attribute_names
  end

  def test_has_attribute
    assert Company.has_attribute?("id")
    assert Company.has_attribute?("type")
    assert Company.has_attribute?("name")
    assert Company.has_attribute?("new_name")
    assert Company.has_attribute?("metadata")
    assert_not Company.has_attribute?("lastname")
    assert_not Company.has_attribute?("age")

    company = Company.new
    assert company.has_attribute?("id")
    assert company.has_attribute?("type")
    assert company.has_attribute?("name")
    assert company.has_attribute?("new_name")
    assert company.has_attribute?("metadata")
    assert_not company.has_attribute?("lastname")
    assert_not company.has_attribute?("age")
  end

  def test_has_attribute_with_symbol
    assert Company.has_attribute?(:id)
    assert Company.has_attribute?(:type)
    assert Company.has_attribute?(:name)
    assert Company.has_attribute?(:new_name)
    assert Company.has_attribute?(:metadata)
    assert_not Company.has_attribute?(:lastname)
    assert_not Company.has_attribute?(:age)

    company = Company.new
    assert company.has_attribute?(:id)
    assert company.has_attribute?(:type)
    assert company.has_attribute?(:name)
    assert company.has_attribute?(:new_name)
    assert company.has_attribute?(:metadata)
    assert_not company.has_attribute?(:lastname)
    assert_not company.has_attribute?(:age)
  end

  def test_attribute_names_on_table_not_exists
    assert_equal [], NonExistentTable.attribute_names
  end

  def test_attribute_names_on_abstract_class
    assert_equal [], AbstractCompany.attribute_names
  end

  def test_touch_should_raise_error_on_a_new_object
    company = Company.new(rating: 1, name: "37signals", firm_name: "37signals")
    assert_raises(ActiveRecord::ActiveRecordError) do
      company.touch :updated_at
    end
  end

  def test_distinct_delegates_to_scoped
    assert_equal Bird.all.distinct, Bird.distinct
  end

  def test_table_name_with_2_abstract_subclasses
    assert_equal "photos", Photo.table_name
  end

  def test_column_types_typecast
    topic = Topic.first
    assert_not_equal "t.lo", topic.author_name

    attrs = topic.attributes.dup
    attrs.delete "id"

    typecast = Class.new(ActiveRecord::Type::Value) {
      def cast(value)
        "t.lo"
      end
    }

    types = { "author_name" => typecast.new }
    topic = Topic.instantiate(attrs, types)

    assert_equal "t.lo", topic.author_name
  end

  def test_typecasting_aliases
    assert_equal 10, Topic.select("10 as tenderlove").first.tenderlove
  end

  def test_slice
    company = Company.new(rating: 1, name: "37signals", firm_name: "37signals")
    hash = company.slice(:name, :rating, "arbitrary_method")
    assert_equal hash[:name], company.name
    assert_equal hash["name"], company.name
    assert_equal hash[:rating], company.rating
    assert_equal hash["arbitrary_method"], company.arbitrary_method
    assert_equal hash[:arbitrary_method], company.arbitrary_method
    assert_nil hash[:firm_name]
    assert_nil hash["firm_name"]
  end

  def test_slice_accepts_array_argument
    attrs = {
      title: "slice",
      author_name: "@Cohen-Carlisle",
      content: "accept arrays so I don't have to splat"
    }.with_indifferent_access
    topic = Topic.new(attrs)
    assert_equal attrs, topic.slice(attrs.keys)
  end

  def test_default_values_are_deeply_dupped
    company = Company.new
    company.description << "foo"
    assert_equal "", Company.new.description
  end

  test "scoped can take a values hash" do
    klass = Class.new(ActiveRecord::Base)
    assert_equal ["foo"], klass.all.merge!(select: "foo").select_values
  end

  test "connection_handler can be overridden" do
    klass = Class.new(ActiveRecord::Base)
    orig_handler = klass.connection_handler
    new_handler = ActiveRecord::ConnectionAdapters::ConnectionHandler.new
    thread_connection_handler = nil

    t = Thread.new do
      klass.connection_handler = new_handler
      thread_connection_handler = klass.connection_handler
    end
    t.join

    assert_equal klass.connection_handler, orig_handler
    assert_equal thread_connection_handler, new_handler
  end

  test "new threads get default the default connection handler" do
    klass = Class.new(ActiveRecord::Base)
    orig_handler = klass.connection_handler
    handler = nil

    t = Thread.new do
      handler = klass.connection_handler
    end
    t.join

    assert_equal handler, orig_handler
    assert_equal klass.connection_handler, orig_handler
    assert_equal klass.default_connection_handler, orig_handler
  end

  test "changing a connection handler in a main thread does not poison the other threads" do
    klass = Class.new(ActiveRecord::Base)
    orig_handler = klass.connection_handler
    new_handler = ActiveRecord::ConnectionAdapters::ConnectionHandler.new
    after_handler = nil
    latch1 = Concurrent::CountDownLatch.new
    latch2 = Concurrent::CountDownLatch.new

    t = Thread.new do
      klass.connection_handler = new_handler
      latch1.count_down
      latch2.wait
      after_handler = klass.connection_handler
    end

    latch1.wait

    klass.connection_handler = orig_handler
    latch2.count_down
    t.join

    assert_equal after_handler, new_handler
    assert_equal orig_handler, klass.connection_handler
  end

  # Note: This is a performance optimization for Array#uniq and Hash#[] with
  # AR::Base objects. If the future has made this irrelevant, feel free to
  # delete this.
  test "records without an id have unique hashes" do
    assert_not_equal Post.new.hash, Post.new.hash
  end

  test "records of different classes have different hashes" do
    assert_not_equal Post.new(id: 1).hash, Developer.new(id: 1).hash
  end

  test "resetting column information doesn't remove attribute methods" do
    topic = topics(:first)

    assert_not_predicate topic, :id_changed?

    Topic.reset_column_information

    assert_not_predicate topic, :id_changed?
  end

  test "ignored columns are not present in columns_hash" do
    cache_columns = Developer.connection.schema_cache.columns_hash(Developer.table_name)
    assert_includes cache_columns.keys, "first_name"
    assert_not_includes Developer.columns_hash.keys, "first_name"
    assert_not_includes SubDeveloper.columns_hash.keys, "first_name"
    assert_not_includes SymbolIgnoredDeveloper.columns_hash.keys, "first_name"
  end

  test ".columns_hash raises an error if the record has an empty table name" do
    expected_message = "FirstAbstractClass has no table configured. Set one with FirstAbstractClass.table_name="
    exception = assert_raises(ActiveRecord::TableNotSpecified) do
      FirstAbstractClass.columns_hash
    end
    assert_equal expected_message, exception.message
  end

  test "ignored columns have no attribute methods" do
    assert_not_respond_to Developer.new, :first_name
    assert_not_respond_to Developer.new, :first_name=
    assert_not_respond_to Developer.new, :first_name?
    assert_not_respond_to SubDeveloper.new, :first_name
    assert_not_respond_to SubDeveloper.new, :first_name=
    assert_not_respond_to SubDeveloper.new, :first_name?
    assert_not_respond_to SymbolIgnoredDeveloper.new, :first_name
    assert_not_respond_to SymbolIgnoredDeveloper.new, :first_name=
    assert_not_respond_to SymbolIgnoredDeveloper.new, :first_name?
  end

  test "ignored columns don't prevent explicit declaration of attribute methods" do
    assert_respond_to Developer.new, :last_name
    assert_respond_to Developer.new, :last_name=
    assert_respond_to Developer.new, :last_name?
    assert_respond_to SubDeveloper.new, :last_name
    assert_respond_to SubDeveloper.new, :last_name=
    assert_respond_to SubDeveloper.new, :last_name?
    assert_respond_to SymbolIgnoredDeveloper.new, :last_name
    assert_respond_to SymbolIgnoredDeveloper.new, :last_name=
    assert_respond_to SymbolIgnoredDeveloper.new, :last_name?
  end

  test "ignored columns are stored as an array of string" do
    assert_equal(%w(first_name last_name), Developer.ignored_columns)
    assert_equal(%w(first_name last_name), SymbolIgnoredDeveloper.ignored_columns)
  end

  test "when #reload called, ignored columns' attribute methods are not defined" do
    developer = Developer.create!(name: "Developer")
    assert_not_respond_to developer, :first_name
    assert_not_respond_to developer, :first_name=

    developer.reload

    assert_not_respond_to developer, :first_name
    assert_not_respond_to developer, :first_name=
  end

  test "when ignored attribute is loaded, cast type should be preferred over DB type" do
    developer = AttributedDeveloper.create
    developer.update_column :name, "name"

    loaded_developer = AttributedDeveloper.where(id: developer.id).select("*").first
    assert_equal "Developer: name", loaded_developer.name
  end

  test "when assigning new ignored columns it invalidates cache for column names" do
    assert_not_includes ColumnNamesCachedDeveloper.column_names, "name"
  end

  test "ignored columns not included in SELECT" do
    query = Developer.all.to_sql.downcase

    # ignored column
    assert_not query.include?("first_name")

    # regular column
    assert query.include?("name")
  end

  test "column names are quoted when using #from clause and model has ignored columns" do
    assert_not_empty Developer.ignored_columns
    query = Developer.from("developers").to_sql
    quoted_id = "#{Developer.quoted_table_name}.#{Developer.quoted_primary_key}"

    assert_match(/SELECT #{Regexp.escape(quoted_id)}.* FROM developers/, query)
  end

  test "using table name qualified column names unless having SELECT list explicitly" do
    assert_equal developers(:david), Developer.from("developers").joins(:shared_computers).take
  end

  test "protected environments by default is an array with production" do
    assert_equal ["production"], ActiveRecord::Base.protected_environments
  end

  def test_protected_environments_are_stored_as_an_array_of_string
    previous_protected_environments = ActiveRecord::Base.protected_environments
    ActiveRecord::Base.protected_environments = [:staging, "production"]
    assert_equal ["staging", "production"], ActiveRecord::Base.protected_environments
  ensure
    ActiveRecord::Base.protected_environments = previous_protected_environments
  end

  test "creating a record raises if preventing writes" do
    error = assert_raises ActiveRecord::ReadOnlyError do
      ActiveRecord::Base.connection_handler.while_preventing_writes do
        Bird.create! name: "Bluejay"
      end
    end

    assert_match %r/\AWrite query attempted while in readonly mode: INSERT /, error.message
  end

  test "updating a record raises if preventing writes" do
    bird = Bird.create! name: "Bluejay"

    error = assert_raises ActiveRecord::ReadOnlyError do
      ActiveRecord::Base.connection_handler.while_preventing_writes do
        bird.update! name: "Robin"
      end
    end

    assert_match %r/\AWrite query attempted while in readonly mode: UPDATE /, error.message
  end

  test "deleting a record raises if preventing writes" do
    bird = Bird.create! name: "Bluejay"

    error = assert_raises ActiveRecord::ReadOnlyError do
      ActiveRecord::Base.connection_handler.while_preventing_writes do
        bird.destroy!
      end
    end

    assert_match %r/\AWrite query attempted while in readonly mode: DELETE /, error.message
  end

  test "selecting a record does not raise if preventing writes" do
    bird = Bird.create! name: "Bluejay"

    ActiveRecord::Base.connection_handler.while_preventing_writes do
      assert_equal bird, Bird.where(name: "Bluejay").first
    end
  end

  test "an explain query does not raise if preventing writes" do
    Bird.create!(name: "Bluejay")

    ActiveRecord::Base.connection_handler.while_preventing_writes do
      assert_queries(2) { Bird.where(name: "Bluejay").explain }
    end
  end

  test "an empty transaction does not raise if preventing writes" do
    ActiveRecord::Base.connection_handler.while_preventing_writes do
      assert_queries(2, ignore_none: true) do
        Bird.transaction do
          ActiveRecord::Base.connection.materialize_transactions
        end
      end
    end
  end

  test "cannot call connected_to on subclasses of ActiveRecord::Base" do
    error = assert_raises(NotImplementedError) do
      Bird.connected_to(role: :reading) { }
    end

    assert_equal "connected_to can only be called on ActiveRecord::Base", error.message
  end

  test "preventing writes applies to all connections on a handler" do
    conn1_error = assert_raises ActiveRecord::ReadOnlyError do
      ActiveRecord::Base.connection_handler.while_preventing_writes do
        assert_equal ActiveRecord::Base.connection, Bird.connection
        assert_not_equal ARUnit2Model.connection, Bird.connection
        Bird.create!(name: "Bluejay")
      end
    end

    assert_match %r/\AWrite query attempted while in readonly mode: INSERT /, conn1_error.message

    conn2_error = assert_raises ActiveRecord::ReadOnlyError do
      ActiveRecord::Base.connection_handler.while_preventing_writes do
        assert_not_equal ActiveRecord::Base.connection, Professor.connection
        assert_equal ARUnit2Model.connection, Professor.connection
        Professor.create!(name: "Professor Bluejay")
      end
    end

    assert_match %r/\AWrite query attempted while in readonly mode: INSERT /, conn2_error.message
  end

  unless in_memory_db?
    test "preventing writes with multiple handlers" do
      ActiveRecord::Base.connects_to(database: { writing: :arunit, reading: :arunit })

      conn1_error = assert_raises ActiveRecord::ReadOnlyError do
        ActiveRecord::Base.connected_to(role: :writing) do
          assert_equal :writing, ActiveRecord::Base.current_role

          ActiveRecord::Base.connection_handler.while_preventing_writes do
            Bird.create!(name: "Bluejay")
          end
        end
      end

      assert_match %r/\AWrite query attempted while in readonly mode: INSERT /, conn1_error.message

      conn2_error = assert_raises ActiveRecord::ReadOnlyError do
        ActiveRecord::Base.connected_to(role: :reading) do
          assert_equal :reading, ActiveRecord::Base.current_role

          ActiveRecord::Base.connection_handler.while_preventing_writes do
            Bird.create!(name: "Bluejay")
          end
        end
      end

      assert_match %r/\AWrite query attempted while in readonly mode: INSERT /, conn2_error.message
    ensure
      ActiveRecord::Base.connection_handlers = { writing: ActiveRecord::Base.default_connection_handler }
      ActiveRecord::Base.establish_connection(:arunit)
    end
  end
end
