require 'abstract_unit'
require 'fixtures/topic'
require 'fixtures/developer'
require 'fixtures/company'
require 'fixtures/task'
require 'fixtures/reply'
require 'fixtures/joke'
require 'fixtures/course'
require 'fixtures/category'

class FixturesTest < Test::Unit::TestCase
  self.use_instantiated_fixtures = true
  self.use_transactional_fixtures = false

  fixtures :topics, :developers, :accounts, :tasks, :categories, :funny_jokes

  FIXTURES = %w( accounts companies customers
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
    firstRow = ActiveRecord::Base.connection.select_one("SELECT * FROM topics WHERE author_name = 'David'")
    assert_equal("The First Topic", firstRow["title"])

    secondRow = ActiveRecord::Base.connection.select_one("SELECT * FROM topics WHERE author_name = 'Mary'")
    assert_nil(secondRow["author_email_address"])
  end

  if ActiveRecord::Base.connection.supports_migrations?
    def test_inserts_with_pre_and_suffix
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

      firstRow = ActiveRecord::Base.connection.select_one("SELECT * FROM prefix_topics_suffix WHERE author_name = 'David'")
      assert_equal("The First Topic", firstRow["title"])

      secondRow = ActiveRecord::Base.connection.select_one("SELECT * FROM prefix_topics_suffix WHERE author_name = 'Mary'")
      assert_nil(secondRow["author_email_address"])        
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


  def test_bad_format
    path = File.join(File.dirname(__FILE__), 'fixtures', 'bad_fixtures')
    Dir.entries(path).each do |file|
      next unless File.file?(file) and file !~ Fixtures::DEFAULT_FILTER_RE
      assert_raise(Fixture::FormatError) {
        Fixture.new(bad_fixtures_path, file)
      }
    end
  end

  def test_deprecated_yaml_extension
    assert_raise(Fixture::FormatError) {
      Fixtures.new(nil, 'bad_extension', 'BadExtension', File.join(File.dirname(__FILE__), 'fixtures'))
    }
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
    assert_equal 2, @topics.size
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
    assert_not_nil Fixtures.new( Account.connection, "accounts", 'Account', File.dirname(__FILE__) + "/fixtures/naked/yml/accounts")
  end

  def test_empty_yaml_fixture_with_a_comment_in_it
    assert_not_nil Fixtures.new( Account.connection, "companies", 'Company', File.dirname(__FILE__) + "/fixtures/naked/yml/companies")
  end

  def test_dirty_dirty_yaml_file
    assert_raises(Fixture::FormatError) do
      Fixtures.new( Account.connection, "courses", 'Course', File.dirname(__FILE__) + "/fixtures/naked/yml/courses")
    end
  end

  def test_empty_csv_fixtures
    assert_not_nil Fixtures.new( Account.connection, "accounts", 'Account', File.dirname(__FILE__) + "/fixtures/naked/csv/accounts")
  end

  def test_omap_fixtures
    assert_nothing_raised do
      fixtures = Fixtures.new(Account.connection, 'categories', 'Category', File.dirname(__FILE__) + '/fixtures/categories_ordered')

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


end

if Account.connection.respond_to?(:reset_pk_sequence!)
  class FixturesResetPkSequenceTest < Test::Unit::TestCase
    fixtures :accounts
    fixtures :companies

    def setup
      @instances = [Account.new(:credit_limit => 50), Company.new(:name => 'RoR Consulting')]
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

    def test_create_fixtures_resets_sequences
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


class FixturesWithoutInstantiationTest < Test::Unit::TestCase
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

  def test_accessor_methods
    assert_equal "The First Topic", topics(:first).title
    assert_equal "Jamis", developers(:jamis).name
    assert_equal 50, accounts(:signals37).credit_limit
  end
end


class FixturesWithoutInstanceInstantiationTest < Test::Unit::TestCase
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


class TransactionalFixturesTest < Test::Unit::TestCase
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


class MultipleFixturesTest < Test::Unit::TestCase
  fixtures :topics
  fixtures :developers, :accounts

  def test_fixture_table_names
    assert_equal %w(topics developers accounts), fixture_table_names
  end
end


class OverlappingFixturesTest < Test::Unit::TestCase
  fixtures :topics, :developers
  fixtures :developers, :accounts

  def test_fixture_table_names
    assert_equal %w(topics developers accounts), fixture_table_names
  end
end


class ForeignKeyFixturesTest < Test::Unit::TestCase
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

class SetTableNameFixturesTest < Test::Unit::TestCase
  set_fixture_class :funny_jokes => 'Joke'
  fixtures :funny_jokes
  
  def test_table_method
    assert_kind_of Joke, funny_jokes(:a_joke)
  end
end

class CustomConnectionFixturesTest < Test::Unit::TestCase
  set_fixture_class :courses => Course
  fixtures :courses
  
  def test_connection
    assert_kind_of Course, courses(:ruby)
    assert_equal Course.connection, courses(:ruby).connection
  end
end

class InvalidTableNameFixturesTest < Test::Unit::TestCase
  fixtures :funny_jokes

  def test_raises_error
    assert_raises FixtureClassNotFound do
      funny_jokes(:a_joke)
    end
  end
end

class CheckEscapedYamlFixturesTest < Test::Unit::TestCase
  set_fixture_class :funny_jokes => 'Joke'
  fixtures :funny_jokes

  def test_proper_escaped_fixture
    assert_equal "The \\n Aristocrats\nAte the candy\n", funny_jokes(:another_joke).name
  end
end

class DevelopersProject; end;

class ManyToManyFixturesWithClassDefined < Test::Unit::TestCase
  fixtures :developers_projects
  
  def test_this_should_run_cleanly
    assert true
  end
end


class FixturesBrokenRollbackTest < Test::Unit::TestCase
  def blank_setup; end
  alias_method :ar_setup_with_fixtures, :setup_with_fixtures
  alias_method :setup_with_fixtures, :blank_setup
  alias_method :setup, :blank_setup

  def blank_teardown; end
  alias_method :ar_teardown_with_fixtures, :teardown_with_fixtures
  alias_method :teardown_with_fixtures, :blank_teardown
  alias_method :teardown, :blank_teardown

  def test_no_rollback_in_teardown_unless_transaction_active
    assert_equal 0, Thread.current['open_transactions']
    assert_raise(RuntimeError) { ar_setup_with_fixtures }
    assert_equal 0, Thread.current['open_transactions']
    assert_nothing_raised { ar_teardown_with_fixtures }
    assert_equal 0, Thread.current['open_transactions']
  end

  private
    def load_fixtures
      raise 'argh'
    end
end
