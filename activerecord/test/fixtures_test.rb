require 'abstract_unit'
require 'fixtures/topic'
require 'fixtures/developer'
require 'fixtures/company'

class FixturesTest < Test::Unit::TestCase
  fixtures :topics, :developers, :accounts, :developers
  
  FIXTURES = %w( accounts companies customers
                 developers developers_projects entrants
                 movies projects subscribers topics )
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

  def test_bad_format
    path = File.join(File.dirname(__FILE__), 'fixtures', 'bad_fixtures')
    Dir.entries(path).each do |file|
      next unless File.file?(file) and file !~ %r(^.|.yaml$)
      assert_raise(Fixture::FormatError) {
        Fixture.new(bad_fixtures_path, file)
      }
    end
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
end