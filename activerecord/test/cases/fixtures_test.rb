require "cases/helper"
require 'models/post'
require 'models/binary'
require 'models/topic'
require 'models/computer'
require 'models/developer'
require 'models/company'
require 'models/task'
require 'models/reply'
require 'models/joke'
require 'models/course'
require 'models/category'
require 'models/parrot'
require 'models/pirate'
require 'models/treasure'
require 'models/matey'
require 'models/ship'
require 'models/book'

class FixturesTest < ActiveRecord::TestCase
  self.use_instantiated_fixtures = true
  self.use_transactional_fixtures = false

  fixtures :topics, :developers, :accounts, :tasks, :categories, :funny_jokes, :binaries

  FIXTURES = %w( accounts binaries companies customers
                 developers developers_projects entrants
                 movies projects subscribers topics tasks )
  MATCH_ATTRIBUTE_NAME = /[a-zA-Z][-_\w]*/

  def test_clean_fixtures
    FIXTURES.each do |name|
      fixtures = nil
      assert_nothing_raised { fixtures = create_fixtures(name) }
      assert_kind_of(Fixtures, fixtures)
      fixtures.each { |name, fixture|
        fixture.each { |key, value|
          assert_match(MATCH_ATTRIBUTE_NAME, key)
        }
      }
    end
  end

  def test_multiple_clean_fixtures
    fixtures_array = nil
    assert_nothing_raised { fixtures_array = create_fixtures(*FIXTURES) }
    assert_kind_of(Array, fixtures_array)
    fixtures_array.each { |fixtures| assert_kind_of(Fixtures, fixtures) }
  end

  def test_attributes
    topics = create_fixtures("topics")
    assert_equal("The First Topic", topics["first"]["title"])
    assert_nil(topics["second"]["author_email_address"])
  end

  def test_inserts
    topics = create_fixtures("topics")
    first_row = ActiveRecord::Base.connection.select_one("SELECT * FROM topics WHERE author_name = 'David'")
    assert_equal("The First Topic", first_row["title"])

    second_row = ActiveRecord::Base.connection.select_one("SELECT * FROM topics WHERE author_name = 'Mary'")
    assert_nil(second_row["author_email_address"])
  end

  if ActiveRecord::Base.connection.supports_migrations?
    def test_inserts_with_pre_and_suffix
      # Reset cache to make finds on the new table work
      Fixtures.reset_cache

      ActiveRecord::Base.connection.create_table :prefix_topics_suffix do |t|
        t.column :title, :string
        t.column :author_name, :string
        t.column :author_email_address, :string
        t.column :written_on, :datetime
        t.column :bonus_time, :time
        t.column :last_read, :date
        t.column :content, :string
        t.column :approved, :boolean, :default => true
        t.column :replies_count, :integer, :default => 0
        t.column :parent_id, :integer
        t.column :type, :string, :limit => 50
      end

      # Store existing prefix/suffix
      old_prefix = ActiveRecord::Base.table_name_prefix
      old_suffix = ActiveRecord::Base.table_name_suffix

      # Set a prefix/suffix we can test against
      ActiveRecord::Base.table_name_prefix = 'prefix_'
      ActiveRecord::Base.table_name_suffix = '_suffix'

      topics = create_fixtures("topics")

      first_row = ActiveRecord::Base.connection.select_one("SELECT * FROM prefix_topics_suffix WHERE author_name = 'David'")
      assert_equal("The First Topic", first_row["title"])

      second_row = ActiveRecord::Base.connection.select_one("SELECT * FROM prefix_topics_suffix WHERE author_name = 'Mary'")
      assert_nil(second_row["author_email_address"])

      # This checks for a caching problem which causes a bug in the fixtures 
      # class-level configuration helper.
      assert_not_nil topics, "Fixture data inserted, but fixture objects not returned from create"
    ensure
      # Restore prefix/suffix to its previous values
      ActiveRecord::Base.table_name_prefix = old_prefix
      ActiveRecord::Base.table_name_suffix = old_suffix

      ActiveRecord::Base.connection.drop_table :prefix_topics_suffix rescue nil
    end
  end

  def test_insert_with_datetime
    topics = create_fixtures("tasks")
    first = Task.find(1)
    assert first
  end

  def test_logger_level_invariant
    level = ActiveRecord::Base.logger.level
    create_fixtures('topics')
    assert_equal level, ActiveRecord::Base.logger.level
  end

  def test_instantiation
    topics = create_fixtures("topics")
    assert_kind_of Topic, topics["first"].find
  end

  def test_complete_instantiation
    assert_equal 4, @topics.size
    assert_equal "The First Topic", @first.title
  end

  def test_fixtures_from_root_yml_with_instantiation
    # assert_equal 2, @accounts.size
    assert_equal 50, @unknown.credit_limit
  end

  def test_erb_in_fixtures
    assert_equal 11, @developers.size
    assert_equal "fixture_5", @dev_5.name
  end

  def test_empty_yaml_fixture
    assert_not_nil Fixtures.new( Account.connection, "accounts", 'Account', FIXTURES_ROOT + "/naked/yml/accounts")
  end

  def test_empty_yaml_fixture_with_a_comment_in_it
    assert_not_nil Fixtures.new( Account.connection, "companies", 'Company', FIXTURES_ROOT + "/naked/yml/companies")
  end

  def test_dirty_dirty_yaml_file
    assert_raise(Fixture::FormatError) do
      Fixtures.new( Account.connection, "courses", 'Course', FIXTURES_ROOT + "/naked/yml/courses")
    end
  end

  def test_empty_csv_fixtures
    assert_not_nil Fixtures.new( Account.connection, "accounts", 'Account', FIXTURES_ROOT + "/naked/csv/accounts")
  end

  def test_omap_fixtures
    assert_nothing_raised do
      fixtures = Fixtures.new(Account.connection, 'categories', 'Category', FIXTURES_ROOT + "/categories_ordered")

      i = 0
      fixtures.each do |name, fixture|
        assert_equal "fixture_no_#{i}", name
        assert_equal "Category #{i}", fixture['name']
        i += 1
      end
    end
  end

  def test_yml_file_in_subdirectory
    assert_equal(categories(:sub_special_1).name, "A special category in a subdir file")
    assert_equal(categories(:sub_special_1).class, SpecialCategory)
  end

  def test_subsubdir_file_with_arbitrary_name
    assert_equal(categories(:sub_special_3).name, "A special category in an arbitrarily named subsubdir file")
    assert_equal(categories(:sub_special_3).class, SpecialCategory)
  end

  def test_binary_in_fixtures
    assert_equal 1, @binaries.size
    data = File.open(ASSETS_ROOT + "/flowers.jpg", 'rb') { |f| f.read }
    data.force_encoding('ASCII-8BIT') if data.respond_to?(:force_encoding)
    data.freeze
    assert_equal data, @flowers.data
  end
end

if Account.connection.respond_to?(:reset_pk_sequence!)
  class FixturesResetPkSequenceTest < ActiveRecord::TestCase
    fixtures :accounts
    fixtures :companies

    def setup
      @instances = [Account.new(:credit_limit => 50), Company.new(:name => 'RoR Consulting')]
      Fixtures.reset_cache # make sure tables get reinitialized
    end

    def test_resets_to_min_pk_with_specified_pk_and_sequence
      @instances.each do |instance|
        model = instance.class
        model.delete_all
        model.connection.reset_pk_sequence!(model.table_name, model.primary_key, model.sequence_name)

        instance.save!
        assert_equal 1, instance.id, "Sequence reset for #{model.table_name} failed."
      end
    end

    def test_resets_to_min_pk_with_default_pk_and_sequence
      @instances.each do |instance|
        model = instance.class
        model.delete_all
        model.connection.reset_pk_sequence!(model.table_name)

        instance.save!
        assert_equal 1, instance.id, "Sequence reset for #{model.table_name} failed."
      end
    end

    def test_create_fixtures_resets_sequences_when_not_cached
      @instances.each do |instance|
        max_id = create_fixtures(instance.class.table_name).inject(0) do |max_id, (name, fixture)|
          fixture_id = fixture['id'].to_i
          fixture_id > max_id ? fixture_id : max_id
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
    assert_nil @first
    assert_nil @topics
    assert_nil @developers
    assert_nil @accounts
  end

  def test_fixtures_from_root_yml_without_instantiation
    assert_nil @unknown
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
    assert_equal "The First Topic", topics(:first).title
    @loaded_fixtures['topics']['first'].expects(:find).returns(stub(:title => "Fresh Topic!"))
    assert_equal "Fresh Topic!", topics(:first, true).title
  end
end

class FixturesWithoutInstanceInstantiationTest < ActiveRecord::TestCase
  self.use_instantiated_fixtures = true
  self.use_instantiated_fixtures = :no_instances

  fixtures :topics, :developers, :accounts

  def test_without_instance_instantiation
    assert_nil @first
    assert_not_nil @topics
    assert_not_nil @developers
    assert_not_nil @accounts
  end
end

class TransactionalFixturesTest < ActiveRecord::TestCase
  self.use_instantiated_fixtures = true
  self.use_transactional_fixtures = true

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
    assert_equal %w(topics developers accounts), fixture_table_names
  end
end

class SetupTest < ActiveRecord::TestCase
  # fixtures :topics

  def setup
    @first = true
  end

  def test_nothing
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
    assert_equal %w(topics developers accounts), fixture_table_names
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

class CheckSetTableNameFixturesTest < ActiveRecord::TestCase
  set_fixture_class :funny_jokes => 'Joke'
  fixtures :funny_jokes
  # Set to false to blow away fixtures cache and ensure our fixtures are loaded 
  # and thus takes into account our set_fixture_class
  self.use_transactional_fixtures = false

  def test_table_method
    assert_kind_of Joke, funny_jokes(:a_joke)
  end
end

class FixtureNameIsNotTableNameFixturesTest < ActiveRecord::TestCase
  set_fixture_class :items => Book
  fixtures :items
  # Set to false to blow away fixtures cache and ensure our fixtures are loaded 
  # and thus takes into account our set_fixture_class
  self.use_transactional_fixtures = false

  def test_named_accessor
    assert_kind_of Book, items(:dvd)
  end
end

class FixtureNameIsNotTableNameMultipleFixturesTest < ActiveRecord::TestCase
  set_fixture_class :items => Book, :funny_jokes => Joke
  fixtures :items, :funny_jokes
  # Set to false to blow away fixtures cache and ensure our fixtures are loaded 
  # and thus takes into account our set_fixture_class
  self.use_transactional_fixtures = false

  def test_named_accessor_of_differently_named_fixture
    assert_kind_of Book, items(:dvd)
  end

  def test_named_accessor_of_same_named_fixture
    assert_kind_of Joke, funny_jokes(:a_joke)
  end
end

class CustomConnectionFixturesTest < ActiveRecord::TestCase
  set_fixture_class :courses => Course
  fixtures :courses
  # Set to false to blow away fixtures cache and ensure our fixtures are loaded 
  # and thus takes into account our set_fixture_class
  self.use_transactional_fixtures = false

  def test_connection
    assert_kind_of Course, courses(:ruby)
    assert_equal Course.connection, courses(:ruby).connection
  end
end

class InvalidTableNameFixturesTest < ActiveRecord::TestCase
  fixtures :funny_jokes
  # Set to false to blow away fixtures cache and ensure our fixtures are loaded 
  # and thus takes into account our lack of set_fixture_class
  self.use_transactional_fixtures = false

  def test_raises_error
    assert_raise FixtureClassNotFound do
      funny_jokes(:a_joke)
    end
  end
end

class CheckEscapedYamlFixturesTest < ActiveRecord::TestCase
  set_fixture_class :funny_jokes => 'Joke'
  fixtures :funny_jokes
  # Set to false to blow away fixtures cache and ensure our fixtures are loaded 
  # and thus takes into account our set_fixture_class
  self.use_transactional_fixtures = false

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
  def blank_setup; end
  alias_method :ar_setup_fixtures, :setup_fixtures
  alias_method :setup_fixtures, :blank_setup
  alias_method :setup, :blank_setup

  def blank_teardown; end
  alias_method :ar_teardown_fixtures, :teardown_fixtures
  alias_method :teardown_fixtures, :blank_teardown
  alias_method :teardown, :blank_teardown

  def test_no_rollback_in_teardown_unless_transaction_active
    assert_equal 0, ActiveRecord::Base.connection.open_transactions
    assert_raise(RuntimeError) { ar_setup_fixtures }
    assert_equal 0, ActiveRecord::Base.connection.open_transactions
    assert_nothing_raised { ar_teardown_fixtures }
    assert_equal 0, ActiveRecord::Base.connection.open_transactions
  end

  private
    def load_fixtures
      raise 'argh'
    end
end

class LoadAllFixturesTest < ActiveRecord::TestCase
  self.fixture_path = FIXTURES_ROOT + "/all"
  fixtures :all

  def test_all_there
    assert_equal %w(developers people tasks), fixture_table_names.sort
  end
end

class FasterFixturesTest < ActiveRecord::TestCase
  fixtures :categories, :authors

  def load_extra_fixture(name)
    fixture = create_fixtures(name)
    assert fixture.is_a?(Fixtures)
    @loaded_fixtures[fixture.table_name] = fixture
  end

  def test_cache
    assert Fixtures.fixture_is_cached?(ActiveRecord::Base.connection, 'categories')
    assert Fixtures.fixture_is_cached?(ActiveRecord::Base.connection, 'authors')

    assert_no_queries do
      create_fixtures('categories')
      create_fixtures('authors')
    end

    load_extra_fixture('posts')
    assert Fixtures.fixture_is_cached?(ActiveRecord::Base.connection, 'posts')
    self.class.setup_fixture_accessors('posts')
    assert_equal 'Welcome to the weblog', posts(:welcome).title
  end
end

class FoxyFixturesTest < ActiveRecord::TestCase
  fixtures :parrots, :parrots_pirates, :pirates, :treasures, :mateys, :ships, :computers, :developers

  def test_identifies_strings
    assert_equal(Fixtures.identify("foo"), Fixtures.identify("foo"))
    assert_not_equal(Fixtures.identify("foo"), Fixtures.identify("FOO"))
  end

  def test_identifies_symbols
    assert_equal(Fixtures.identify(:foo), Fixtures.identify(:foo))
  end

  def test_identifies_consistently
    assert_equal 207281424, Fixtures.identify(:ruby)
    assert_equal 1066363776, Fixtures.identify(:sapphire_2)
  end

  TIMESTAMP_COLUMNS = %w(created_at created_on updated_at updated_on)

  def test_populates_timestamp_columns
    TIMESTAMP_COLUMNS.each do |property|
      assert_not_nil(parrots(:george).send(property), "should set #{property}")
    end
  end

  def test_does_not_populate_timestamp_columns_if_model_has_set_record_timestamps_to_false
    TIMESTAMP_COLUMNS.each do |property|
      assert_nil(ships(:black_pearl).send(property), "should not set #{property}")
    end
  end

  def test_populates_all_columns_with_the_same_time
    last = nil

    TIMESTAMP_COLUMNS.each do |property|
      current = parrots(:george).send(property)
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

  def test_supports_inline_habtm
    assert(parrots(:george).treasures.include?(treasures(:diamond)))
    assert(parrots(:george).treasures.include?(treasures(:sapphire)))
    assert(!parrots(:george).treasures.include?(treasures(:ruby)))
  end

  def test_supports_inline_habtm_with_specified_id
    assert(parrots(:polly).treasures.include?(treasures(:ruby)))
    assert(parrots(:polly).treasures.include?(treasures(:sapphire)))
    assert(!parrots(:polly).treasures.include?(treasures(:diamond)))
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

  def test_supports_polymorphic_belongs_to
    assert_equal(pirates(:redbeard), treasures(:sapphire).looter)
    assert_equal(parrots(:louis), treasures(:ruby).looter)
  end

  def test_only_generates_a_pk_if_necessary
    m = Matey.find(:first)
    m.pirate = pirates(:blackbeard)
    m.target = pirates(:redbeard)
  end

  def test_supports_sti
    assert_kind_of DeadParrot, parrots(:polly)
    assert_equal pirates(:blackbeard), parrots(:polly).killer
  end
end

class ActiveSupportSubclassWithFixturesTest < ActiveRecord::TestCase
  fixtures :parrots

  # This seemingly useless assertion catches a bug that caused the fixtures
  # setup code call nil[]
  def test_foo
    assert_equal parrots(:louis), Parrot.find_by_name("King Louis")
  end
end

class FixtureLoadingTest < ActiveRecord::TestCase
  def test_logs_message_for_failed_dependency_load
    ActiveRecord::TestCase.expects(:require_dependency).with(:does_not_exist).raises(LoadError)
    ActiveRecord::Base.logger.expects(:warn)
    ActiveRecord::TestCase.try_to_load_dependency(:does_not_exist)
  end

  def test_does_not_logs_message_for_successful_dependency_load
    ActiveRecord::TestCase.expects(:require_dependency).with(:works_out_fine)
    ActiveRecord::Base.logger.expects(:warn).never
    ActiveRecord::TestCase.try_to_load_dependency(:works_out_fine)
  end
end
