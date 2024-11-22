# frozen_string_literal: true

require "cases/helper"
require "support/connection_helper"
require "models/admin"
require "models/admin/account"
require "models/admin/randomly_named_c1"
require "models/admin/user"
require "models/author"
require "models/binary"
require "models/book"
require "models/bulb"
require "models/category"
require "models/post"
require "models/comment"
require "models/company"
require "models/computer"
require "models/course"
require "models/developer"
require "models/dog_lover"
require "models/dog"
require "models/doubloon"
require "models/essay"
require "models/joke"
require "models/matey"
require "models/organization"
require "models/other_dog"
require "models/parrot"
require "models/pirate"
require "models/randomly_named_c1"
require "models/reply"
require "models/ship"
require "models/task"
require "models/topic"
require "models/traffic_light"
require "models/treasure"
require "models/tree"
require "models/cpk"

class FixturesTest < ActiveRecord::TestCase
  include ConnectionHelper

  self.use_instantiated_fixtures = true
  self.use_transactional_tests = false

  # other_topics fixture should not be included here
  fixtures :topics, :developers, :accounts, :tasks, :categories, :funny_jokes, :binaries, :traffic_lights, :trees

  FIXTURES = %w( accounts binaries companies customers
                 developers developers_projects entrants
                 movies projects subscribers topics tasks )
  MATCH_ATTRIBUTE_NAME = /[a-zA-Z][-\w]*/

  def setup
    Arel::Table.engine = nil # should not rely on the global Arel::Table.engine
  end

  def teardown
    Arel::Table.engine = ActiveRecord::Base
  end

  def test_clean_fixtures
    FIXTURES.each do |name|
      fixtures = nil
      assert_nothing_raised { fixtures = create_fixtures(name).first }
      assert_kind_of(ActiveRecord::FixtureSet, fixtures)
      fixtures.each { |_name, fixture|
        fixture.each { |key, value|
          assert_match(MATCH_ATTRIBUTE_NAME, key)
        }
      }
    end
  end

  class InsertQuerySubscriber
    attr_reader :events

    def initialize
      @events = []
    end

    def call(_, _, _, _, values)
      @events << values[:sql] if /INSERT/.match?(values[:sql])
    end
  end

  if current_adapter?(:Mysql2Adapter, :TrilogyAdapter, :PostgreSQLAdapter)
    def test_bulk_insert
      subscriber = InsertQuerySubscriber.new
      subscription = ActiveSupport::Notifications.subscribe("sql.active_record", subscriber)
      create_fixtures("bulbs")
      assert_equal 1, subscriber.events.size, "It takes one INSERT query to insert two fixtures"
    ensure
      ActiveSupport::Notifications.unsubscribe(subscription)
    end

    def test_bulk_insert_multiple_table_with_a_multi_statement_query
      subscriber = InsertQuerySubscriber.new
      subscription = ActiveSupport::Notifications.subscribe("sql.active_record", subscriber)

      create_fixtures("bulbs", "movies", "computers")

      expected_sql = <<~EOS.chop
        INSERT INTO #{quote_table_name("bulbs")} .*
        INSERT INTO #{quote_table_name("movies")} .*
        INSERT INTO #{quote_table_name("computers")} .*
      EOS
      assert_equal 1, subscriber.events.size
      assert_match(/#{expected_sql}/, subscriber.events.first)
    ensure
      ActiveSupport::Notifications.unsubscribe(subscription)
    end

    def test_bulk_insert_with_a_multi_statement_query_raises_an_exception_when_any_insert_fails
      require "models/aircraft"

      assert_equal false, Aircraft.columns_hash["wheels_count"].null
      fixtures = {
        "aircraft" => [
          { "name" => "working_aircrafts", "wheels_count" => 2 },
          { "name" => "broken_aircrafts", "wheels_count" => nil },
        ]
      }

      assert_no_difference "Aircraft.count" do
        assert_raises(ActiveRecord::NotNullViolation) do
          ActiveRecord::Base.lease_connection.insert_fixtures_set(fixtures)
        end
      end
    end

    def test_bulk_insert_with_a_multi_statement_query_in_a_nested_transaction
      fixtures = {
        "traffic_lights" => [
          { "location" => "US", "state" => ["NY"], "long_state" => ["a"] },
        ]
      }

      assert_difference "TrafficLight.count" do
        ActiveRecord::Base.transaction do
          conn = ActiveRecord::Base.lease_connection
          assert_equal 1, conn.open_transactions
          conn.insert_fixtures_set(fixtures)
          assert_equal 1, conn.open_transactions
        end
      end
    end
  end

  if current_adapter?(:Mysql2Adapter, :TrilogyAdapter)
    def test_bulk_insert_with_multi_statements_enabled
      adapter_name = ActiveRecord::Base.lease_connection.adapter_name
      run_without_connection do |orig_connection|
        case adapter_name
        when "Trilogy"
          ActiveRecord::Base.establish_connection(
            orig_connection.merge(multi_statement: true)
          )
        else
          ActiveRecord::Base.establish_connection(
            orig_connection.merge(flags: %w[MULTI_STATEMENTS])
          )
        end

        fixtures = {
          "traffic_lights" => [
            { "location" => "US", "state" => ["NY"], "long_state" => ["a"] },
          ]
        }

        assert_nothing_raised do
          conn = ActiveRecord::Base.lease_connection
          conn.execute("SELECT 1; SELECT 2;")
          case adapter_name
          when "Trilogy"
            conn.raw_connection.next_result while conn.raw_connection.more_results_exist?
          else
            conn.raw_connection.abandon_results!
          end
        end

        assert_difference "TrafficLight.count" do
          ActiveRecord::Base.transaction do
            conn = ActiveRecord::Base.lease_connection
            assert_equal 1, conn.open_transactions
            conn.insert_fixtures_set(fixtures)
            assert_equal 1, conn.open_transactions
          end
        end

        assert_nothing_raised do
          conn = ActiveRecord::Base.lease_connection
          conn.execute("SELECT 1; SELECT 2;")
          case adapter_name
          when "Trilogy"
            conn.raw_connection.next_result while conn.raw_connection.more_results_exist?
          else
            conn.raw_connection.abandon_results!
          end
        end
      end
    end

    def test_bulk_insert_with_multi_statements_disabled
      adapter_name = ActiveRecord::Base.lease_connection.adapter_name
      run_without_connection do |orig_connection|
        case adapter_name
        when "Trilogy"
          ActiveRecord::Base.establish_connection(
            orig_connection.merge(multi_statement: false)
          )
        else
          ActiveRecord::Base.establish_connection(
            orig_connection.merge(flags: [])
          )
        end

        fixtures = {
          "traffic_lights" => [
            { "location" => "US", "state" => ["NY"], "long_state" => ["a"] },
          ]
        }

        assert_raises(ActiveRecord::StatementInvalid) do
          conn = ActiveRecord::Base.lease_connection
          conn.execute("SELECT 1; SELECT 2;")
          case adapter_name
          when "Trilogy"
            conn.raw_connection.next_result while conn.raw_connection.more_results_exist?
          else
            conn.raw_connection.abandon_results!
          end
        end

        assert_difference "TrafficLight.count" do
          conn = ActiveRecord::Base.lease_connection
          conn.insert_fixtures_set(fixtures)
        end

        assert_raises(ActiveRecord::StatementInvalid) do
          conn = ActiveRecord::Base.lease_connection
          conn.execute("SELECT 1; SELECT 2;")
          case adapter_name
          when "Trilogy"
            conn.raw_connection.next_result while conn.raw_connection.more_results_exist?
          else
            conn.raw_connection.abandon_results!
          end
        end
      end
    end

    def test_insert_fixtures_set_raises_an_error_when_max_allowed_packet_is_smaller_than_fixtures_set_size
      conn = ActiveRecord::Base.lease_connection
      mysql_margin = 2
      packet_size = 1024
      bytes_needed_to_have_a_1024_bytes_fixture = 906
      fixtures = {
        "traffic_lights" => [
          { "location" => "US", "state" => ["NY"], "long_state" => ["a" * bytes_needed_to_have_a_1024_bytes_fixture] },
        ]
      }

      conn.stub(:max_allowed_packet, packet_size - mysql_margin) do
        error = assert_raises(ActiveRecord::ActiveRecordError) { conn.insert_fixtures_set(fixtures) }
        assert_match(/Fixtures set is too large #{packet_size}\./, error.message)
      end
    end

    def test_insert_fixture_set_when_max_allowed_packet_is_bigger_than_fixtures_set_size
      conn = ActiveRecord::Base.lease_connection
      packet_size = 1024
      fixtures = {
        "traffic_lights" => [
          { "location" => "US", "state" => ["NY"], "long_state" => ["a" * 51] },
        ]
      }

      conn.stub(:max_allowed_packet, packet_size) do
        assert_difference "TrafficLight.count" do
          conn.insert_fixtures_set(fixtures)
        end
      end
    end

    def test_insert_fixtures_set_split_the_total_sql_into_two_chunks_smaller_than_max_allowed_packet
      subscriber = InsertQuerySubscriber.new
      subscription = ActiveSupport::Notifications.subscribe("sql.active_record", subscriber)
      conn = ActiveRecord::Base.lease_connection
      packet_size = 1024
      fixtures = {
        "traffic_lights" => [
          { "location" => "US", "state" => ["NY"], "long_state" => ["a" * 450] },
        ],
        "comments" => [
          { "post_id" => 1, "body" => "a" * 450 },
        ]
      }

      conn.stub(:max_allowed_packet, packet_size) do
        conn.insert_fixtures_set(fixtures)

        assert_equal 2, subscriber.events.size
        assert_operator subscriber.events.first.bytesize, :<, packet_size
        assert_operator subscriber.events.second.bytesize, :<, packet_size
      end
    ensure
      ActiveSupport::Notifications.unsubscribe(subscription)
    end

    def test_insert_fixtures_set_concat_total_sql_into_a_single_packet_smaller_than_max_allowed_packet
      subscriber = InsertQuerySubscriber.new
      subscription = ActiveSupport::Notifications.subscribe("sql.active_record", subscriber)
      conn = ActiveRecord::Base.lease_connection
      packet_size = 1024
      fixtures = {
        "traffic_lights" => [
          { "location" => "US", "state" => ["NY"], "long_state" => ["a" * 200] },
        ],
        "comments" => [
          { "post_id" => 1, "body" => "a" * 200 },
        ]
      }

      conn.stub(:max_allowed_packet, packet_size) do
        assert_difference ["TrafficLight.count", "Comment.count"], +1 do
          conn.insert_fixtures_set(fixtures)
        end
      end
      assert_equal 1, subscriber.events.size
    ensure
      ActiveSupport::Notifications.unsubscribe(subscription)
    end
  end

  def test_auto_value_on_primary_key
    fixtures = [
      { "name" => "first", "wheels_count" => 2 },
      { "name" => "second", "wheels_count" => 3 }
    ]
    conn = ActiveRecord::Base.lease_connection
    assert_nothing_raised do
      conn.insert_fixtures_set({ "aircraft" => fixtures }, ["aircraft"])
    end
    result = conn.select_all("SELECT name, wheels_count FROM aircraft ORDER BY id")
    assert_equal fixtures, result.to_a
  end

  def test_broken_yaml_exception
    badyaml = Tempfile.new ["foo", ".yml"]
    badyaml.write "a: : "
    badyaml.flush

    dir  = File.dirname badyaml.path
    name = File.basename badyaml.path, ".yml"
    assert_raises(ActiveRecord::Fixture::FormatError) do
      ActiveRecord::FixtureSet.create_fixtures(dir, name)
    end
  ensure
    badyaml.close
    badyaml.unlink
  end

  def test_create_fixtures
    fixtures = ActiveRecord::FixtureSet.create_fixtures(FIXTURES_ROOT, "organizations")
    assert Organization.find_by_name("No Such Agency"), "'No Such Agency' is not in the database"
    assert fixtures.detect { |f| f.name == "organizations" }, "no fixtures named 'organizations' in #{fixtures.map(&:name).inspect}"
  end

  def test_multiple_clean_fixtures
    fixtures_array = nil
    assert_nothing_raised { fixtures_array = create_fixtures(*FIXTURES) }
    assert_kind_of(Array, fixtures_array)
    fixtures_array.each { |fixtures| assert_kind_of(ActiveRecord::FixtureSet, fixtures) }
  end

  def test_create_symbol_fixtures
    fixtures = ActiveRecord::FixtureSet.create_fixtures(FIXTURES_ROOT, :collections, collections: Course)

    assert Course.find_by_name("Collection"), "course is not in the database"
    assert fixtures.detect { |f| f.name == "collections" }, "no fixtures named 'collections' in #{fixtures.map(&:name).inspect}"
  end

  def test_attributes
    topics = create_fixtures("topics").first
    assert_equal("The First Topic", topics["first"]["title"])
    assert_nil(topics["second"]["author_email_address"])
  end

  def test_no_args_returns_all
    all_topics = topics
    assert_equal 5, all_topics.length
    assert_equal "The First Topic", all_topics.first["title"]
    assert_equal 5, all_topics.last.id
  end

  def test_no_args_record_returns_all_without_array
    all_binaries = binaries
    assert_kind_of(Array, all_binaries)
    assert_equal 2, binaries.length
  end

  def test_nil_raises
    assert_raise(StandardError) { topics(nil) }
    assert_raise(StandardError) { topics([nil]) }
  end

  def test_inserts
    create_fixtures("topics")
    first_row = ActiveRecord::Base.lease_connection.select_one("SELECT * FROM topics WHERE author_name = 'David'")
    assert_equal("The First Topic", first_row["title"])

    second_row = ActiveRecord::Base.lease_connection.select_one("SELECT * FROM topics WHERE author_name = 'Mary'")
    assert_nil(second_row["author_email_address"])
  end

  def test_inserts_with_pre_and_suffix
    # Reset cache to make finds on the new table work
    ActiveRecord::FixtureSet.reset_cache

    ActiveRecord::Base.lease_connection.create_table :prefix_other_topics_suffix do |t|
      t.column :title, :string
      t.column :author_name, :string
      t.column :author_email_address, :string
      t.column :written_on, :datetime
      t.column :bonus_time, :time
      t.column :last_read, :date
      t.column :content, :string
      t.column :approved, :boolean, default: true
      t.column :replies_count, :integer, default: 0
      t.column :parent_id, :integer
      t.column :type, :string, limit: 50
    end

    # Store existing prefix/suffix
    old_prefix = ActiveRecord::Base.table_name_prefix
    old_suffix = ActiveRecord::Base.table_name_suffix

    # Set a prefix/suffix we can test against
    ActiveRecord::Base.table_name_prefix = "prefix_"
    ActiveRecord::Base.table_name_suffix = "_suffix"

    other_topic_klass = Class.new(ActiveRecord::Base) do
      def self.name
        "OtherTopic"
      end
    end

    topics = [create_fixtures("other_topics")].flatten.first

    # This checks for a caching problem which causes a bug in the fixtures
    # class-level configuration helper.
    assert_not_nil topics, "Fixture data inserted, but fixture objects not returned from create"

    first_row = ActiveRecord::Base.lease_connection.select_one("SELECT * FROM prefix_other_topics_suffix WHERE author_name = 'David'")
    assert_not_nil first_row, "The prefix_other_topics_suffix table appears to be empty despite create_fixtures: the row with author_name = 'David' was not found"
    assert_equal("The First Topic", first_row["title"])

    second_row = ActiveRecord::Base.lease_connection.select_one("SELECT * FROM prefix_other_topics_suffix WHERE author_name = 'Mary'")
    assert_nil(second_row["author_email_address"])

    assert_equal :prefix_other_topics_suffix, topics.table_name.to_sym
    # This assertion should preferably be the last in the list, because calling
    # other_topic_klass.table_name sets a class-level instance variable
    assert_equal :prefix_other_topics_suffix, other_topic_klass.table_name.to_sym

  ensure
    # Restore prefix/suffix to its previous values
    ActiveRecord::Base.table_name_prefix = old_prefix
    ActiveRecord::Base.table_name_suffix = old_suffix

    ActiveRecord::Base.lease_connection.drop_table :prefix_other_topics_suffix rescue nil
  end

  def test_insert_with_datetime
    create_fixtures("tasks")
    first = Task.find(1)
    assert first
  end

  def test_logger_level_invariant
    previous_logger = ActiveRecord::Base.logger
    ActiveRecord::Base.logger = ActiveSupport::Logger.new(nil)

    level = ActiveRecord::Base.logger.level
    create_fixtures("topics")
    assert_equal level, ActiveRecord::Base.logger.level
  ensure
    ActiveRecord::Base.logger = previous_logger
  end

  def test_instantiation
    topics = create_fixtures("topics").first
    assert_kind_of Topic, topics["first"].find
  end

  def test_complete_instantiation
    assert_equal "The First Topic", @first.title
  end

  def test_fixtures_from_root_yml_with_instantiation
    assert_equal 50, @unknown.credit_limit
  end

  def test_erb_in_fixtures
    assert_equal "fixture_5", @dev_5.name
  end

  def test_empty_yaml_fixture
    assert_not_nil ActiveRecord::FixtureSet.new(nil, "accounts", Account, FIXTURES_ROOT + "/naked/yml/accounts")
  end

  def test_empty_yaml_fixture_with_a_comment_in_it
    assert_not_nil ActiveRecord::FixtureSet.new(nil, "companies", Company, FIXTURES_ROOT + "/naked/yml/companies")
  end

  def test_nonexistent_fixture_file
    nonexistent_fixture_path = FIXTURES_ROOT + "/imnothere"

    # Ensure that this file never exists
    assert_empty Dir[nonexistent_fixture_path + "*"]

    assert_raise(ArgumentError) do
      ActiveRecord::FixtureSet.new(nil, "companies", Company, nonexistent_fixture_path)
    end
  end

  def test_dirty_dirty_yaml_file
    fixture_path = FIXTURES_ROOT + "/naked/yml/courses"
    error = assert_raise(ActiveRecord::Fixture::FormatError) do
      ActiveRecord::FixtureSet.new(nil, "courses", Course, fixture_path)
    end
    assert_equal "fixture is not a hash: #{fixture_path}.yml", error.to_s
  end

  def test_yaml_file_with_one_invalid_fixture
    fixture_path = FIXTURES_ROOT + "/naked/yml/courses_with_invalid_key"
    error = assert_raise(ActiveRecord::Fixture::FormatError) do
      ActiveRecord::FixtureSet.new(nil, "courses", Course, fixture_path)
    end
    assert_equal "fixture key is not a hash: #{fixture_path}.yml, keys: [\"two\"]", error.to_s
  end

  def test_yaml_file_with_invalid_column
    e = assert_raise(ActiveRecord::Fixture::FixtureError) do
      ActiveRecord::FixtureSet.create_fixtures(FIXTURES_ROOT + "/naked/yml", "parrots")
    end

    assert_equal(%(table "parrots" has no columns named "arrr", "foobar".), e.message)
  end

  def test_yaml_file_with_symbol_columns
    ActiveRecord::FixtureSet.create_fixtures(FIXTURES_ROOT + "/naked/yml", "trees")
    root = Tree.find(1)
    assert root
  end

  def test_omap_fixtures
    assert_nothing_raised do
      fixtures = ActiveRecord::FixtureSet.new(nil, "categories", Category, FIXTURES_ROOT + "/categories_ordered")

      fixtures.each.with_index do |(name, fixture), i|
        assert_equal "fixture_no_#{i}", name
        assert_equal "Category #{i}", fixture["name"]
      end
    end
  end

  def test_yml_file_in_subdirectory
    assert_equal("A special category in a subdir file", categories(:sub_special_1).name)
    assert_equal(categories(:sub_special_1).class, SpecialCategory)
  end

  def test_subsubdir_file_with_arbitrary_name
    assert_equal("A special category in an arbitrarily named subsubdir file", categories(:sub_special_3).name)
    assert_equal(categories(:sub_special_3).class, SpecialCategory)
  end

  def test_binary_in_fixtures
    data = File.binread(ASSETS_ROOT + "/flowers.jpg")
    data.force_encoding("ASCII-8BIT")
    data.freeze
    assert_equal data, @flowers.data
    assert_equal data, @binary_helper.data
  end

  def test_serialized_fixtures
    assert_equal ["Green", "Red", "Orange"], traffic_lights(:uk).state
  end

  def test_fixtures_are_set_up_with_database_env_variable
    db_url_tmp = ENV["DATABASE_URL"]
    ENV["DATABASE_URL"] = "sqlite3::memory:"
    ActiveRecord::Base.stub(:configurations, {}) do
      test_case = Class.new(ActiveRecord::TestCase) do
        fixtures :accounts

        def test_fixtures
          assert accounts(:signals37)
        end
      end

      result = test_case.new(:test_fixtures).run

      assert_predicate result, :passed?, "Expected #{result.name} to pass:\n#{result}"
    end
  ensure
    ENV["DATABASE_URL"] = db_url_tmp
  end

  def test_fixture_method_and_private_alias
    assert_equal "The First Topic", topics(:first).title
    assert_equal "The First Topic", fixture(:topics, :first).title
    assert_equal "The First Topic", active_record_fixture(:topics, :first).title
  end

  def test_fixture_method_does_not_clash_with_a_test_case_method
    test_case = Class.new(ActiveRecord::TestCase) do
      fixtures :accounts

      def test_fixtures
        assert accounts(:signals37)
      end

      private
        def fixture
          Account.new
        end
    end

    result = test_case.new(:test_fixtures).run

    assert_predicate result, :passed?, "Expected #{result.name} to pass:\n#{result}"
  end
end

class HasManyThroughFixture < ActiveRecord::TestCase
  def make_model(name)
    Class.new(ActiveRecord::Base) { define_singleton_method(:name) { name } }
  end

  def test_has_many_through_with_join_table_name_changed_to_match_habtm_table_name
    pt = make_model "ParrotTreasure"
    parrot = make_model "Parrot"
    treasure = make_model "Treasure"

    pt.table_name = "parrots_treasures"
    pt.belongs_to :parrot, anonymous_class: parrot
    pt.belongs_to :treasure, anonymous_class: treasure

    parrot.has_many :parrot_treasures, anonymous_class: pt
    parrot.has_many :treasures, through: :parrot_treasures

    parrots = File.join FIXTURES_ROOT, "parrots"

    fs = ActiveRecord::FixtureSet.new(nil, "parrots", parrot, parrots)
    rows = fs.table_rows
    assert_equal load_has_and_belongs_to_many["parrots_treasures"], rows["parrots_treasures"]
  end

  def test_has_many_through_with_default_table_name_on_join_table
    pt = make_model "ParrotTreasure"
    parrot = make_model "Parrot"
    treasure = make_model "Treasure"

    pt.belongs_to :parrot, anonymous_class: parrot
    pt.belongs_to :treasure, anonymous_class: treasure

    parrot.has_many :parrot_treasures, anonymous_class: pt
    parrot.has_many :treasures, through: :parrot_treasures

    parrots = File.join FIXTURES_ROOT, "parrots"

    fs = ActiveRecord::FixtureSet.new(nil, "parrots", parrot, parrots)
    rows = fs.table_rows
    assert_equal load_has_and_belongs_to_many["parrots_treasures"], rows["parrot_treasures"]
  end

  def test_has_and_belongs_to_many_order
    assert_equal ["parrots", "parrots_treasures"], load_has_and_belongs_to_many.keys
  end

  def load_has_and_belongs_to_many
    parrot = make_model "Parrot"
    parrot.has_and_belongs_to_many :treasures

    parrots = File.join FIXTURES_ROOT, "parrots"

    fs = ActiveRecord::FixtureSet.new(nil, "parrots", parrot, parrots)
    fs.table_rows
  end
end

if Account.lease_connection.respond_to?(:reset_pk_sequence!)
  class FixturesResetPkSequenceTest < ActiveRecord::TestCase
    fixtures :accounts
    fixtures :companies
    self.use_transactional_tests = false

    def setup
      @instances = [Account.new(credit_limit: 50), Company.new(name: "RoR Consulting"), Course.new(name: "Test")]
      ActiveRecord::FixtureSet.reset_cache # make sure tables get reinitialized
    end

    def test_resets_to_min_pk_with_specified_pk_and_sequence
      @instances.each do |instance|
        model = instance.class
        model.delete_all
        model.lease_connection.reset_pk_sequence!(model.table_name, model.primary_key, model.sequence_name)

        instance.save!
        assert_equal 1, instance.id, "Sequence reset for #{model.table_name} failed."
      end
    end

    def test_resets_to_min_pk_with_default_pk_and_sequence
      @instances.each do |instance|
        model = instance.class
        model.delete_all
        model.lease_connection.reset_pk_sequence!(model.table_name)

        instance.save!
        assert_equal 1, instance.id, "Sequence reset for #{model.table_name} failed."
      end
    end

    def test_create_fixtures_resets_sequences_when_not_cached
      @instances.each do |instance|
        max_id = create_fixtures(instance.class.table_name).first.fixtures.inject(0) do |_max_id, (_, fixture)|
          fixture_id = fixture["id"].to_i
          fixture_id > _max_id ? fixture_id : _max_id
        end

        # Clone the last fixture to check that it gets the next greatest id.
        instance.save!
        assert_equal max_id + 1, instance.id, "Sequence reset for #{instance.class.table_name} failed."
      end
    end
  end
end

class FixturesWithoutInstantiationTest < ActiveRecord::TestCase
  self.use_instantiated_fixtures = false
  fixtures :topics, :developers, :accounts

  def test_without_complete_instantiation
    assert_not defined?(@first)
    assert_not defined?(@topics)
    assert_not defined?(@developers)
    assert_not defined?(@accounts)
  end

  def test_fixtures_from_root_yml_without_instantiation
    assert_not defined?(@unknown), "@unknown is not defined"
  end

  def test_visibility_of_accessor_method
    assert_equal false, respond_to?(:topics, false), "should be private method"
    assert_equal true, respond_to?(:topics, true), "confirm to respond surely"
  end

  def test_accessor_methods
    assert_equal "The First Topic", topics(:first).title
    assert_equal "Jamis", developers(:jamis).name
    assert_equal 50, accounts(:signals37).credit_limit
  end

  def test_accessor_methods_with_multiple_args
    assert_equal 2, topics(:first, :second).size
    assert_raise(StandardError) { topics([:first, :second]) }
  end

  def test_reloading_fixtures_through_accessor_methods
    topic = Struct.new(:title)
    assert_equal "The First Topic", topics(:first).title
    assert_called(@loaded_fixtures["topics"]["first"], :find, returns: topic.new("Fresh Topic!")) do
      assert_equal "Fresh Topic!", topics(:first, true).title
    end
  end
end

class FixturesWithoutInstanceInstantiationTest < ActiveRecord::TestCase
  self.use_instantiated_fixtures = true
  self.use_instantiated_fixtures = :no_instances

  fixtures :topics, :developers, :accounts

  def test_without_instance_instantiation
    assert_not defined?(@first), "@first is not defined"
  end
end

class TransactionalFixturesTest < ActiveRecord::TestCase
  self.use_instantiated_fixtures = true
  self.use_transactional_tests = true

  fixtures :topics

  def test_destroy
    assert_not_nil @first
    @first.destroy
  end

  def test_destroy_just_kidding
    assert_not_nil @first
  end
end

class MultipleFixturesTest < ActiveRecord::TestCase
  fixtures :topics
  fixtures :developers, :accounts

  def test_fixture_table_names
    assert_equal %w(accounts developers topics), fixture_table_names
  end
end

class SetupTest < ActiveRecord::TestCase
  # fixtures :topics

  def setup
    @first = true
  end

  def test_nothing
    pass
  end
end

class SetupSubclassTest < SetupTest
  def setup
    super
    @second = true
  end

  def test_subclassing_should_preserve_setups
    assert @first
    assert @second
  end
end

class OverlappingFixturesTest < ActiveRecord::TestCase
  fixtures :topics, :developers
  fixtures :developers, :accounts

  def test_fixture_table_names
    assert_equal %w(accounts developers topics), fixture_table_names
  end
end

class ForeignKeyFixturesTest < ActiveRecord::TestCase
  fixtures :fk_test_has_pk, :fk_test_has_fk

  # if foreign keys are implemented and fixtures
  # are not deleted in reverse order then this test
  # case will raise StatementInvalid

  def test_number1
    assert true
  end

  def test_number2
    assert true
  end
end

class FkObjectToPointTo < ActiveRecord::Base
  has_many :fk_pointing_to_non_existent_objects
end
class FkPointingToNonExistentObject < ActiveRecord::Base
  belongs_to :fk_object_to_point_to
end

class FixturesWithForeignKeyViolationsTest < ActiveRecord::TestCase
  fixtures :fk_object_to_point_to

  def setup
    # other tests in this file load the parrots fixture but not the treasure one (see `test_create_fixtures`).
    # this creates FK violations since Parrot and ParrotTreasure records are created.
    # those violations can cause false positives in these tests. since they aren't related to these tests we
    # delete the irrelevant records here (this test is transactional so it's fine).
    Parrot.all.each(&:destroy)

    @path = "/fk_pointing_to_non_existent_object.yml"
  end

  def test_raises_fk_violations
    fk_pointing_to_non_existent_object = <<~FIXTURE
    first:
      fk_object_to_point_to: one
    FIXTURE
    File.write(FIXTURES_ROOT + @path, fk_pointing_to_non_existent_object)

    with_verify_foreign_keys_for_fixtures do
      if current_adapter?(:SQLite3Adapter, :PostgreSQLAdapter)
        error = assert_raise RuntimeError do
          ActiveRecord::FixtureSet.create_fixtures(FIXTURES_ROOT, ["fk_pointing_to_non_existent_object"])
        end
        assert_includes error.message, "Foreign key violations found in your fixture data. Ensure you aren't referring to labels that don't exist on associations."
        assert_includes error.message, "fk_pointing_to_non_existent_objects"
      else
        assert_nothing_raised do
          ActiveRecord::FixtureSet.create_fixtures(FIXTURES_ROOT, ["fk_pointing_to_non_existent_object"])
        end
      end
    end

  ensure
    File.delete(FIXTURES_ROOT + @path)
    ActiveRecord::FixtureSet.reset_cache
  end

  def test_does_not_raise_if_no_fk_violations
    fk_pointing_to_valid_object = <<~FIXTURE
    first:
      fk_object_to_point_to_id: 1
    FIXTURE
    File.write(FIXTURES_ROOT + @path, fk_pointing_to_valid_object)

    with_verify_foreign_keys_for_fixtures do
      assert_nothing_raised do
        ActiveRecord::FixtureSet.create_fixtures(FIXTURES_ROOT, ["fk_pointing_to_non_existent_object"])
      end
    end

  ensure
    File.delete(FIXTURES_ROOT + @path)
    ActiveRecord::FixtureSet.reset_cache
  end

  private
    def with_verify_foreign_keys_for_fixtures
      setting_was = ActiveRecord.verify_foreign_keys_for_fixtures
      ActiveRecord.verify_foreign_keys_for_fixtures = true
      yield
    ensure
      ActiveRecord.verify_foreign_keys_for_fixtures = setting_was
    end
end

class OverRideFixtureMethodTest < ActiveRecord::TestCase
  fixtures :topics

  def topics(name)
    topic = super
    topic.title = "omg"
    topic
  end

  def test_fixture_methods_can_be_overridden
    x = topics :first
    assert_equal "omg", x.title
  end
end

class FixtureWithSetModelClassTest < ActiveRecord::TestCase
  fixtures :other_posts, :other_comments

  # Set to false to blow away fixtures cache and ensure our fixtures are loaded
  # and thus takes into account the `model_class` set in the fixture.
  self.use_transactional_tests = false

  def test_uses_fixture_class_defined_in_yaml
    assert_kind_of Post, other_posts(:second_welcome)
  end

  def test_loads_the_associations_to_fixtures_with_set_model_class
    post = other_posts(:second_welcome)
    comment = other_comments(:second_greetings)
    assert_equal [comment], post.comments
    assert_equal post, comment.post
  end
end

class SetFixtureClassPrevailsTest < ActiveRecord::TestCase
  set_fixture_class bad_posts: Post
  fixtures :bad_posts

  # Set to false to blow away fixtures cache and ensure our fixtures are loaded
  # and thus takes into account our `set_fixture_class`.
  self.use_transactional_tests = false

  def test_uses_set_fixture_class
    assert_kind_of Post, bad_posts(:bad_welcome)
  end
end

class FixtureWithSetModelClassPrevailsOverNamingConventionTest < ActiveRecord::TestCase
  def test_model_class_in_fixture_file_is_respected
    Object.const_set(:OtherPost, Class.new(ActiveRecord::Base))
    other_posts = create_fixtures("other_posts").first
    assert_kind_of Post, other_posts["second_welcome"].find
  ensure
    Object.send(:remove_const, :OtherPost)
  end
end

class CheckSetTableNameFixturesTest < ActiveRecord::TestCase
  set_fixture_class funny_jokes: Joke
  fixtures :funny_jokes
  # Set to false to blow away fixtures cache and ensure our fixtures are loaded
  # and thus takes into account our `set_fixture_class`.
  self.use_transactional_tests = false

  def test_table_method
    assert_kind_of Joke, funny_jokes(:a_joke)
  end
end

class FixtureNameIsNotTableNameFixturesTest < ActiveRecord::TestCase
  set_fixture_class items: Book
  fixtures :items
  # Set to false to blow away fixtures cache and ensure our fixtures are loaded
  # and thus takes into account our `set_fixture_class`.
  self.use_transactional_tests = false

  def test_named_accessor
    assert_kind_of Book, items(:dvd)
  end
end

class FixtureNameIsNotTableNameMultipleFixturesTest < ActiveRecord::TestCase
  set_fixture_class items: Book, funny_jokes: Joke
  fixtures :items, :funny_jokes
  # Set to false to blow away fixtures cache and ensure our fixtures are loaded
  # and thus takes into account our `set_fixture_class`.
  self.use_transactional_tests = false

  def test_named_accessor_of_differently_named_fixture
    assert_kind_of Book, items(:dvd)
  end

  def test_named_accessor_of_same_named_fixture
    assert_kind_of Joke, funny_jokes(:a_joke)
  end
end

class CustomConnectionFixturesTest < ActiveRecord::TestCase
  set_fixture_class courses: Course
  fixtures :courses
  self.use_transactional_tests = false

  def test_leaky_destroy
    assert_nothing_raised { courses(:ruby) }
    courses(:ruby).destroy
  end

  def test_it_twice_in_whatever_order_to_check_for_fixture_leakage
    test_leaky_destroy
  end
end

class TransactionalFixturesOnCustomConnectionTest < ActiveRecord::TestCase
  set_fixture_class courses: Course
  fixtures :courses
  self.use_transactional_tests = true

  def test_leaky_destroy
    assert_nothing_raised { courses(:ruby) }
    courses(:ruby).destroy
  end

  def test_it_twice_in_whatever_order_to_check_for_fixture_leakage
    test_leaky_destroy
  end
end

class TransactionalFixturesOnConnectionNotification < ActiveRecord::TestCase
  self.use_transactional_tests = true
  self.use_instantiated_fixtures = false

  def test_transaction_created_on_connection_notification
    connection = Class.new do
      attr_accessor :pool

      def transaction_open?; end
      def begin_transaction(*args); end
      def rollback_transaction(*args); end
      def connect!; end
    end.new

    pool = connection.pool = Class.new do
      attr_accessor :db_config

      def initialize(connection); @connection = connection; end
      def lease_connection; @connection; end
      def release_connection; end
      def pin_connection!(_); end
      def unpin_connection!; @connection.rollback_transaction; true; end
    end.new(connection)

    connection.pool.db_config = Class.new do
      attr_accessor :name
      def initialize(name); @name = name; end
    end.new("database_name")

    assert_called_with(pool, :pin_connection!, [true]) do
      fire_connection_notification(connection.pool)
    end
  end

  def test_notification_established_transactions_are_rolled_back
    connection = Class.new do
      attr_accessor :rollback_transaction_called
      attr_accessor :pool

      def transaction_open?; true; end
      def begin_transaction(*args); end
      def rollback_transaction(*args)
        @rollback_transaction_called = true
      end
      def lock_thread=(lock_thread); end
      def connect!; end
    end.new

    connection.pool = Class.new do
      attr_accessor :db_config

      def initialize(connection); @connection = connection; end
      def lease_connection; @connection; end
      def release_connection; end
      def pin_connection!(_); end
      def unpin_connection!; @connection.rollback_transaction; true; end
    end.new(connection)

    connection.pool.db_config = Class.new do
      attr_accessor :name
      def initialize(name); @name = name; end
    end.new("database_name")

    fire_connection_notification(connection.pool)
    teardown_fixtures

    assert(connection.rollback_transaction_called, "Expected <mock connection>#rollback_transaction to be called but was not")
  end

  def test_transaction_created_on_connection_notification_for_shard
    connection = Class.new do
      attr_accessor :pool

      def transaction_open?; end
      def begin_transaction(*args); end
      def rollback_transaction(*args); end
      def connect!; end
    end.new

    connection.pool = Class.new do
      attr_accessor :db_config

      def initialize(connection); @connection = connection; end
      def lease_connection; @connection; end
      def release_connection; end
      def pin_connection!(_); end
      def unpin_connection!; @connection.rollback_transaction; true; end
    end.new(connection)

    connection.pool.db_config = Class.new do
      attr_accessor :name
      def initialize(name); @name = name; end
    end.new("database_name")

    assert_called_with(connection.pool, :pin_connection!, [true]) do
      fire_connection_notification(connection.pool, shard: :shard_two)
    end
  end

  private
    def fire_connection_notification(pool, shard: ActiveRecord::Base.default_shard)
      assert_called_with(ActiveRecord::Base.connection_handler, :retrieve_connection_pool, ["book"], returns: pool, shard: shard) do
        message_bus = ActiveSupport::Notifications.instrumenter
        payload = {
          connection_name: "book",
          shard: shard,
          config: nil
        }

        message_bus.instrument("!connection.active_record", payload) { }
      end
    end
end

class InvalidTableNameFixturesTest < ActiveRecord::TestCase
  fixtures :funny_jokes
  # Set to false to blow away fixtures cache and ensure our fixtures are loaded
  # and thus takes into account our lack of set_fixture_class
  self.use_transactional_tests = false

  def test_raises_error
    assert_raise ActiveRecord::FixtureClassNotFound do
      funny_jokes(:a_joke)
    end
  end
end

class CheckEscapedYamlFixturesTest < ActiveRecord::TestCase
  set_fixture_class funny_jokes: Joke
  fixtures :funny_jokes
  # Set to false to blow away fixtures cache and ensure our fixtures are loaded
  # and thus takes into account our `set_fixture_class`.
  self.use_transactional_tests = false

  def test_proper_escaped_fixture
    assert_equal "The \\n Aristocrats\nAte the candy\n", funny_jokes(:another_joke).name
  end
end

class DevelopersProject; end
class ManyToManyFixturesWithClassDefined < ActiveRecord::TestCase
  fixtures :developers_projects

  def test_this_should_run_cleanly
    assert true
  end
end

class FixturesBrokenRollbackTest < ActiveRecord::TestCase
  def blank_setup
    @fixture_connection_pools = [ActiveRecord::Base.connection_pool]
  end
  alias_method :ar_setup_fixtures, :setup_fixtures
  alias_method :setup_fixtures, :blank_setup
  alias_method :setup, :blank_setup

  def blank_teardown; end
  alias_method :ar_teardown_fixtures, :teardown_fixtures
  alias_method :teardown_fixtures, :blank_teardown
  alias_method :teardown, :blank_teardown

  fixtures rand.to_s # bypass fixtures cache

  def test_no_rollback_in_teardown_unless_transaction_active
    assert_equal 0, ActiveRecord::Base.lease_connection.open_transactions
    assert_raise(RuntimeError) { ar_setup_fixtures }
    assert_equal 0, ActiveRecord::Base.lease_connection.open_transactions
    assert_nothing_raised { ar_teardown_fixtures }
    assert_equal 0, ActiveRecord::Base.lease_connection.open_transactions
  end

  private
    def load_fixtures(config)
      raise "argh"
    end
end

class LoadAllFixturesTest < ActiveRecord::TestCase
  def test_all_there
    self.class.fixture_paths = [FIXTURES_ROOT + "/all"]
    self.class.fixtures :all

    if File.symlink? FIXTURES_ROOT + "/all/admin"
      assert_equal %w(admin/accounts admin/users developers namespaced/accounts people tasks), fixture_table_names.sort
    end
  ensure
    ActiveRecord::FixtureSet.reset_cache
  end
end

class LoadAllFixturesWithArrayTest < ActiveRecord::TestCase
  def test_all_there
    self.class.fixture_paths = [FIXTURES_ROOT + "/all", FIXTURES_ROOT + "/categories"]
    self.class.fixtures :all

    if File.symlink? FIXTURES_ROOT + "/all/admin"
      assert_equal %w(admin/accounts admin/users developers namespaced/accounts people special_categories subsubdir/arbitrary_filename tasks), fixture_table_names.sort
    end
  ensure
    ActiveRecord::FixtureSet.reset_cache
  end
end

class LoadAllFixturesWithPathnameTest < ActiveRecord::TestCase
  def test_all_there
    self.class.fixture_paths = [Pathname.new(FIXTURES_ROOT).join("all")]
    self.class.fixtures :all

    if File.symlink? FIXTURES_ROOT + "/all/admin"
      assert_equal %w(admin/accounts admin/users developers namespaced/accounts people tasks), fixture_table_names.sort
    end
  ensure
    ActiveRecord::FixtureSet.reset_cache
  end
end

class FasterFixturesTest < ActiveRecord::TestCase
  self.use_transactional_tests = false
  fixtures :categories, :authors, :author_addresses

  def load_extra_fixture(name)
    fixture = create_fixtures(name).first
    assert fixture.is_a?(ActiveRecord::FixtureSet)
    @loaded_fixtures[fixture.table_name] = fixture
  end

  def test_cache
    assert ActiveRecord::FixtureSet.fixture_is_cached?(ActiveRecord::Base.connection_pool, "categories")
    assert ActiveRecord::FixtureSet.fixture_is_cached?(ActiveRecord::Base.connection_pool, "authors")

    assert_no_queries do
      create_fixtures("categories")
      create_fixtures("authors")
    end

    load_extra_fixture("posts")
    assert ActiveRecord::FixtureSet.fixture_is_cached?(ActiveRecord::Base.connection_pool, "posts")
    self.class.setup_fixture_accessors :posts
    assert_equal "Welcome to the weblog", posts(:welcome).title
  end
end

class FoxyFixturesTest < ActiveRecord::TestCase
  # Set to false to blow away fixtures cache and ensure our fixtures are loaded
  self.use_transactional_tests = false
  fixtures :parrots, :parrots_pirates, :pirates, :treasures, :mateys, :ships, :computers,
           :developers, :"admin/accounts", :"admin/users", :live_parrots, :dead_parrots, :books

  if current_adapter?(:PostgreSQLAdapter)
    require "models/uuid_parent"
    require "models/uuid_child"
    fixtures :uuid_parents, :uuid_children
  end

  def test_identifies_strings
    assert_equal(ActiveRecord::FixtureSet.identify("foo"), ActiveRecord::FixtureSet.identify("foo"))
    assert_not_equal(ActiveRecord::FixtureSet.identify("foo"), ActiveRecord::FixtureSet.identify("FOO"))
  end

  def test_identifies_symbols
    assert_equal(ActiveRecord::FixtureSet.identify(:foo), ActiveRecord::FixtureSet.identify(:foo))
  end

  def test_identifies_consistently
    assert_equal 207281424, ActiveRecord::FixtureSet.identify(:ruby)
    assert_equal 1066363776, ActiveRecord::FixtureSet.identify(:sapphire_2)

    assert_equal "f92b6bda-0d0d-5fe1-9124-502b18badded", ActiveRecord::FixtureSet.identify(:daddy, :uuid)
    assert_equal "b4b10018-ad47-595d-b42f-d8bdaa6d01bf", ActiveRecord::FixtureSet.identify(:sonny, :uuid)
  end

  TIMESTAMP_COLUMNS = %w(created_at created_on updated_at updated_on)

  def test_populates_timestamp_columns
    TIMESTAMP_COLUMNS.each do |property|
      assert_not_nil(parrots(:george).public_send(property), "should set #{property}")
    end
  end

  def test_does_not_populate_timestamp_columns_if_model_has_set_record_timestamps_to_false
    TIMESTAMP_COLUMNS.each do |property|
      assert_nil(ships(:black_pearl).public_send(property), "should not set #{property}")
    end
  end

  def test_populates_all_columns_with_the_same_time
    last = nil

    TIMESTAMP_COLUMNS.each do |property|
      current = parrots(:george).public_send(property)
      last ||= current

      assert_equal(last, current)
      last = current
    end
  end

  def test_only_populates_columns_that_exist
    assert_not_nil(pirates(:blackbeard).created_on)
    assert_not_nil(pirates(:blackbeard).updated_on)
  end

  def test_preserves_existing_fixture_data
    assert_equal(2.weeks.ago.to_date, pirates(:redbeard).created_on.to_date)
    assert_equal(2.weeks.ago.to_date, pirates(:redbeard).updated_on.to_date)
  end

  def test_generates_unique_ids
    assert_not_nil(parrots(:george).id)
    assert_not_equal(parrots(:george).id, parrots(:louis).id)
  end

  def test_automatically_sets_primary_key
    assert_not_nil(ships(:black_pearl))
  end

  def test_preserves_existing_primary_key
    assert_equal(2, ships(:interceptor).id)
  end

  def test_resolves_belongs_to_symbols
    assert_equal(parrots(:george), pirates(:blackbeard).parrot)
  end

  def test_ignores_belongs_to_symbols_if_association_and_foreign_key_are_named_the_same
    assert_equal(developers(:david), computers(:workstation).developer)
  end

  def test_supports_join_tables
    assert(pirates(:blackbeard).parrots.include?(parrots(:george)))
    assert(pirates(:blackbeard).parrots.include?(parrots(:louis)))
    assert(parrots(:george).pirates.include?(pirates(:blackbeard)))
  end

  def test_supports_timestamps_in_join_tables
    assert_not_nil developers(:david).created_at
    assert_not_nil computers(:laptop).created_at

    klass = Class.new(ActiveRecord::Base) do
      self.table_name = "computers_developers"
    end

    computers_developers = klass.find_by(developer_id: developers(:david), computer_id: computers(:laptop))
    assert_not_nil computers_developers.created_at
  end

  def test_supports_inline_habtm
    assert(parrots(:george).treasures.include?(treasures(:diamond)))
    assert(parrots(:george).treasures.include?(treasures(:sapphire)))
    assert_not(parrots(:george).treasures.include?(treasures(:ruby)))
  end

  def test_supports_inline_habtm_with_specified_id
    assert(parrots(:polly).treasures.include?(treasures(:ruby)))
    assert(parrots(:polly).treasures.include?(treasures(:sapphire)))
    assert_not(parrots(:polly).treasures.include?(treasures(:diamond)))
  end

  def test_supports_yaml_arrays
    assert(parrots(:louis).treasures.include?(treasures(:diamond)))
    assert(parrots(:louis).treasures.include?(treasures(:sapphire)))
  end

  def test_strips_DEFAULTS_key
    assert_raise(StandardError) { parrots(:DEFAULTS) }

    # this lets us do YAML defaults and not have an extra fixture entry
    %w(sapphire ruby).each { |t| assert(parrots(:davey).treasures.include?(treasures(t))) }
  end

  def test_supports_label_interpolation
    assert_equal("frederick", parrots(:frederick).name)
  end

  def test_supports_label_string_interpolation
    assert_equal("X marks the spot!", pirates(:mark).catchphrase)
  end

  def test_supports_label_interpolation_for_integer_label
    assert_equal("#1 pirate!", pirates(1).catchphrase)
  end

  def test_supports_polymorphic_belongs_to
    assert_equal(pirates(:redbeard), treasures(:sapphire).looter)
    assert_equal(parrots(:louis), treasures(:ruby).looter)
  end

  def test_only_generates_a_pk_if_necessary
    assert_nothing_raised do
      m = Matey.first
      m.pirate = pirates(:blackbeard)
      m.target = pirates(:redbeard)
    end
  end

  def test_supports_sti
    assert_kind_of DeadParrot, parrots(:polly)
    assert_equal pirates(:blackbeard), parrots(:polly).killer
  end

  def test_supports_sti_with_respective_files
    assert_kind_of LiveParrot, live_parrots(:dusty)
    assert_kind_of DeadParrot, dead_parrots(:deadbird)
    assert_equal pirates(:blackbeard), dead_parrots(:deadbird).killer
  end

  def test_resolves_enums_in_sti_subclasses
    assert_predicate parrots(:george), :australian?
    assert_predicate parrots(:louis), :african?
    assert_predicate parrots(:frederick), :african?
  end

  def test_namespaced_models
    assert_includes admin_accounts(:signals37).users, admin_users(:david)
    assert_equal 2, admin_accounts(:signals37).users.size
  end

  def test_resolves_enums
    assert_predicate books(:awdr), :published?
    assert_predicate books(:awdr), :read?
    assert_predicate books(:rfr), :proposed?
    assert_predicate books(:ddd), :published?
  end
end

class ActiveSupportSubclassWithFixturesTest < ActiveRecord::TestCase
  fixtures :organizations

  # This seemingly useless assertion catches a bug that caused the fixtures
  # setup code call nil[]
  def test_foo
    assert_equal organizations(:nsa), Organization.find_by_name("No Such Agency")
  end
end

class CustomNameForFixtureOrModelTest < ActiveRecord::TestCase
  ActiveRecord::FixtureSet.reset_cache

  set_fixture_class :randomly_named_a9 =>
                        ClassNameThatDoesNotFollowCONVENTIONS,
                    :'admin/randomly_named_a9' =>
                        Admin::ClassNameThatDoesNotFollowCONVENTIONS1,
                    "admin/randomly_named_b0"  =>
                        Admin::ClassNameThatDoesNotFollowCONVENTIONS2

  fixtures :randomly_named_a9, "admin/randomly_named_a9",
           :'admin/randomly_named_b0'

  def test_named_accessor_for_randomly_named_fixture_and_class
    assert_kind_of ClassNameThatDoesNotFollowCONVENTIONS,
                   randomly_named_a9(:first_instance)
  end

  def test_named_accessor_for_randomly_named_namespaced_fixture_and_class
    assert_kind_of Admin::ClassNameThatDoesNotFollowCONVENTIONS1,
                   admin_randomly_named_a9(:first_instance)
    assert_kind_of Admin::ClassNameThatDoesNotFollowCONVENTIONS2,
                   admin_randomly_named_b0(:second_instance)
  end

  def test_table_name_is_defined_in_the_model
    assert_equal "randomly_named_table2", ActiveRecord::FixtureSet.all_loaded_fixtures["admin/randomly_named_a9"].table_name
    assert_equal "randomly_named_table2", Admin::ClassNameThatDoesNotFollowCONVENTIONS1.table_name
  end
end

class IgnoreFixturesTest < ActiveRecord::TestCase
  fixtures :other_books, :parrots, :parrots_pirates, :pirates, :treasures

  # Set to false to blow away fixtures cache and ensure our fixtures are loaded
  # without interfering with other tests that use the same `model_class`.
  self.use_transactional_tests = false

  test "ignores books fixtures" do
    assert_raise(StandardError) { other_books(:published) }
    assert_raise(StandardError) { other_books(:published_paperback) }
    assert_raise(StandardError) { other_books(:published_ebook) }

    assert_equal 2, Book.count
    assert_equal "Agile Web Development with Rails", other_books(:awdr).name
    assert_equal "published", other_books(:awdr).status
    assert_equal "paperback", other_books(:awdr).format
    assert_equal "english", other_books(:awdr).language

    assert_equal "Ruby for Rails", other_books(:rfr).name
    assert_equal "ebook", other_books(:rfr).format
    assert_equal "published", other_books(:rfr).status
  end

  test "ignores parrots fixtures" do
    assert_raise(StandardError) { parrots(:DEFAULT) }
    assert_raise(StandardError) { parrots(:DEAD_PARROT) }

    assert_equal "DeadParrot", parrots(:polly).parrot_sti_class
  end
end

class FixturesWithDefaultScopeTest < ActiveRecord::TestCase
  fixtures :bulbs

  test "inserts fixtures excluded by a default scope" do
    assert_equal 1, Bulb.count
    assert_equal 2, Bulb.unscoped.count
  end

  test "allows access to fixtures excluded by a default scope" do
    assert_equal "special", bulbs(:special).name
  end
end

class FixturesWithAbstractBelongsTo < ActiveRecord::TestCase
  fixtures :pirates, :doubloons

  test "creates fixtures with belongs_to associations defined in abstract base classes" do
    assert_not_nil doubloons(:blackbeards_doubloon)
    assert_equal pirates(:blackbeard), doubloons(:blackbeards_doubloon).pirate
  end
end

class FixtureClassNamesTest < ActiveRecord::TestCase
  def setup
    @saved_cache = fixture_class_names.dup
  end

  def teardown
    fixture_class_names.replace(@saved_cache)
  end

  test "fixture_class_names returns nil for unregistered identifier" do
    assert_nil fixture_class_names["unregistered_identifier"]
  end
end

class SameNameDifferentDatabaseFixturesTest < ActiveRecord::TestCase
  fixtures :dogs, :other_dogs

  test "fixtures are properly loaded" do
    # Force loading the fixtures again to reproduce issue
    ActiveRecord::FixtureSet.reset_cache
    create_fixtures("dogs", "other_dogs")

    assert_kind_of Dog, dogs(:sophie)
    assert_kind_of OtherDog, other_dogs(:lassie)
  end
end

class NilFixturePathTest < ActiveRecord::TestCase
  test "raises an error when all fixtures loaded" do
    error = assert_raises(StandardError) do
      TestCase = Class.new(ActiveRecord::TestCase)
      TestCase.class_eval do
        self.fixture_paths = nil
        fixtures :all
      end
    end
    assert_equal <<~MSG.squish, error.message
      No fixture path found.
      Please set `NilFixturePathTest::TestCase.fixture_paths`.
    MSG
  end
end

class FileFixtureConflictTest < ActiveRecord::TestCase
  def self.file_fixture_path
    FIXTURES_ROOT + "/all/admin"
  end

  test "ignores file fixtures" do
    self.class.fixture_paths = [FIXTURES_ROOT + "/all"]
    self.class.fixtures :all

    assert_equal %w(developers namespaced/accounts people tasks), fixture_table_names.sort
  end
end

class PrimaryKeyErrorTest < ActiveRecord::TestCase
  test "generates the correct value" do
    e = assert_raise(ActiveRecord::FixtureSet::TableRow::PrimaryKeyError) do
      ActiveRecord::FixtureSet.create_fixtures(FIXTURES_ROOT + "/primary_key_error", "primary_key_error")
    end

    assert_includes e.message, "Unable to set"
  end
end

class MultipleFixtureConnectionsTest < ActiveRecord::TestCase
  if current_adapter?(:SQLite3Adapter) && !in_memory_db?
    include ActiveRecord::TestFixtures

    fixtures :dogs

    def setup
      @old_handler = ActiveRecord::Base.connection_handler
      @prev_configs, ActiveRecord::Base.configurations = ActiveRecord::Base.configurations, config
      db_config = ActiveRecord::DatabaseConfigurations::HashConfig.new(ENV["RAILS_ENV"], "readonly", readonly_config)

      teardown_shared_connection_pool

      handler = ActiveRecord::ConnectionAdapters::ConnectionHandler.new
      ActiveRecord::Base.connection_handler = handler
      handler.establish_connection(db_config)

      ActiveRecord::Base.connects_to(database: { writing: :default, reading: :readonly })

      setup_shared_connection_pool
    end

    def teardown
      ActiveRecord::Base.configurations = @prev_configs
      ActiveRecord::Base.connection_handler = @old_handler
      clean_up_connection_handler
    end

    def test_uses_writing_connection_for_fixtures
      ActiveRecord::Base.connected_to(role: :reading) do
        Dog.first

        assert_nothing_raised do
          ActiveRecord::Base.connected_to(role: :writing) { Dog.create! alias: "Doggo" }
        end
      end
    end

    def test_writing_and_reading_connections_are_the_same
      handler = ActiveRecord::Base.connection_handler
      rw_conn = handler.retrieve_connection_pool("ActiveRecord::Base", role: :writing).lease_connection
      ro_conn = handler.retrieve_connection_pool("ActiveRecord::Base", role: :reading).lease_connection

      assert_equal rw_conn, ro_conn

      teardown_shared_connection_pool

      rw_conn = handler.retrieve_connection_pool("ActiveRecord::Base", role: :writing).lease_connection
      ro_conn = handler.retrieve_connection_pool("ActiveRecord::Base", role: :reading).lease_connection

      assert_not_equal rw_conn, ro_conn
    end

    def test_writing_and_reading_connections_are_the_same_for_non_default_shards
      ActiveRecord::Base.connects_to shards: {
        default: { writing: :default, reading: :readonly },
        two: { writing: :default, reading: :readonly }
      }

      handler = ActiveRecord::Base.connection_handler
      rw_conn = handler.retrieve_connection_pool("ActiveRecord::Base", role: :writing, shard: :two).lease_connection
      ro_conn = handler.retrieve_connection_pool("ActiveRecord::Base", role: :reading, shard: :two).lease_connection

      assert_equal rw_conn, ro_conn

      teardown_shared_connection_pool

      rw_conn = handler.retrieve_connection_pool("ActiveRecord::Base", role: :writing, shard: :two).lease_connection
      ro_conn = handler.retrieve_connection_pool("ActiveRecord::Base", role: :reading, shard: :two).lease_connection

      assert_not_equal rw_conn, ro_conn
    end

    def test_only_existing_connections_are_replaced
      ActiveRecord::Base.connects_to shards: {
        default: { writing: :default, reading: :readonly },
        two: { writing: :default }
      }

      setup_shared_connection_pool

      assert_raises(ActiveRecord::ConnectionNotDefined) do
        ActiveRecord::Base.connected_to(role: :reading, shard: :two) do
          ActiveRecord::Base.retrieve_connection
        end
      end
    end

    def test_only_existing_connections_are_restored
      clean_up_connection_handler
      teardown_shared_connection_pool

      assert_raises(ActiveRecord::ConnectionNotDefined) do
        ActiveRecord::Base.connected_to(role: :reading) do
          ActiveRecord::Base.retrieve_connection
        end
      end
    end

    private
      def config
        { "default" => default_config, "readonly" => readonly_config }
      end

      def default_config
        { "adapter" => "sqlite3", "database" => "test/fixtures/fixture_database.sqlite3" }
      end

      def readonly_config
        default_config.merge("replica" => true)
      end
  end

  class CompositePkFixturesTest < ActiveRecord::TestCase
    fixtures :cpk_orders, :cpk_books, :cpk_authors, :cpk_reviews, :cpk_order_agreements

    def test_generates_composite_primary_key_for_partially_filled_fixtures
      alice = cpk_authors(:cpk_great_author)
      alice_cpk_book = cpk_books(:cpk_great_author_first_book)

      assert_not_empty(alice_cpk_book.id.compact)
      assert_equal alice_cpk_book.id.first, alice.id
      assert_not_nil alice_cpk_book.id.last
    end

    def test_generates_composite_primary_key_ids
      assert_not_empty(cpk_orders(:cpk_groceries_order_1).id.compact)

      cpk_books(:cpk_great_author_first_book).id.each do |id_column|
        assert_not_nil(id_column)
      end
    end

    def test_generates_composite_primary_key_with_unique_components
      assert_equal 2, cpk_orders(:cpk_groceries_order_1).id.uniq.size
    end

    def test_resolves_associations_using_composite_primary_keys
      review = cpk_reviews(:first_book_review)
      generated_book = cpk_books(:cpk_book_with_generated_pk)

      assert_equal generated_book.id, [review.author_id, review.number]
      assert_equal generated_book, review.book
    end

    def test_resolves_associations_using_composite_primary_keys_with_partially_filled_values
      review = cpk_reviews(:second_book_review_for_book_with_partial_pk_defined)
      book_with_partially_filled_cpk = cpk_books(:cpk_great_author_first_book)

      assert_equal book_with_partially_filled_cpk.id, [review.author_id, review.number]
      assert_equal book_with_partially_filled_cpk, review.book
    end

    def test_association_with_custom_primary_key
      order = cpk_orders(:cpk_groceries_order_2)
      order_agreement = cpk_order_agreements(:order_agreement_three)

      _, order_id = order.id

      assert_equal order_id, order_agreement.order_id
      assert_equal order, order_agreement.order
    end

    def test_composite_identify_resolves_to_same_values
      identify_one = ActiveRecord::FixtureSet.composite_identify("label", [:a, :b, :c])
      identify_two = ActiveRecord::FixtureSet.composite_identify("label", [:a, :b, :c])

      assert_equal identify_one, identify_two
    end

    def test_composite_identify_returns_hash_with_key_names
      id = ActiveRecord::FixtureSet.composite_identify("order", Cpk::Order.primary_key)

      assert_equal ["shop_id", "id"], id.keys
    end

    def test_composite_identify_uses_same_hashing_algorithm_as_identify_for_first_attribute
      id_hash = ActiveRecord::FixtureSet.composite_identify("order", [:first_attribute, :second_attribute])
      id = ActiveRecord::FixtureSet.identify("order")

      assert_equal id, id_hash[:first_attribute]
      assert_not_equal id, id_hash[:second_attribute]
    end

    def test_composite_identify_hashes_one_label_to_same_values_irrespective_of_column_names
      id_hash_one = ActiveRecord::FixtureSet.composite_identify("order", [:first_attribute, :second_attribute])
      id_hash_two = ActiveRecord::FixtureSet.composite_identify("order", [:shop_id, :id])

      assert_equal id_hash_one.values, id_hash_two.values
      assert_not_equal id_hash_one.keys, id_hash_two.keys
    end

    def test_composite_identify_hashes_to_same_values_based_on_position_in_key
      id = ActiveRecord::FixtureSet.identify("order")
      id_hash_two = ActiveRecord::FixtureSet.composite_identify("order", [:one, :two])
      id_hash_three = ActiveRecord::FixtureSet.composite_identify("order", [:one, :two, :three])

      assert_equal id, id_hash_two.values.first
      assert_equal id, id_hash_three.values.first
      assert_equal id_hash_two.values, id_hash_three.values.slice(0, 2)
    end
  end
end
