require 'abstract_unit'
require 'fixtures/topic'
require 'fixtures/developer'
require 'fixtures/company'
require 'fixtures/task'
require 'fixtures/reply'

class FixturesTest < Test::Unit::TestCase
  self.use_instantiated_fixtures = true
  self.use_transactional_fixtures = false

  fixtures :topics, :developers, :accounts, :tasks

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
      Fixtures.new(nil, 'bad_extension', File.join(File.dirname(__FILE__), 'fixtures'))
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
    assert_equal 10, @developers.size
    assert_equal "fixture_5", @dev_5.name
  end

  def test_empty_yaml_fixture
    assert_not_nil Fixtures.new( Account.connection, "accounts", File.dirname(__FILE__) + "/fixtures/naked/yml/accounts")
  end

  def test_empty_yaml_fixture_with_a_comment_in_it
    assert_not_nil Fixtures.new( Account.connection, "companies", File.dirname(__FILE__) + "/fixtures/naked/yml/companies")
  end

  def test_dirty_dirty_yaml_file
    assert_raises(Fixture::FormatError) do
      Fixtures.new( Account.connection, "courses", File.dirname(__FILE__) + "/fixtures/naked/yml/courses")
    end
  end

  def test_empty_csv_fixtures
    assert_not_nil Fixtures.new( Account.connection, "accounts", File.dirname(__FILE__) + "/fixtures/naked/csv/accounts")
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
    assert_equal([:topics, :developers, :accounts], fixture_table_names)
  end
end


class OverlappingFixturesTest < Test::Unit::TestCase
  fixtures :topics, :developers
  fixtures :developers, :accounts

  def test_fixture_table_names
    assert_equal([:topics, :developers, :accounts], fixture_table_names)
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






