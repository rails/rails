require 'abstract_unit'
require 'fixtures/company'
require 'fixtures/topic'

class FinderTest < Test::Unit::TestCase
  def setup
    @company_fixtures = create_fixtures("companies")
    @topic_fixtures   = create_fixtures("topics")
  end
  
  def test_find
    assert_equal(@topic_fixtures["first"]["title"], Topic.find(1).title)
  end
  
  def test_find_by_ids
    assert_equal(2, Topic.find(1, 2).length)
    assert_equal(@topic_fixtures["second"]["title"], Topic.find([ 2 ]).title)
  end

  def test_find_by_ids_missing_one
    assert_raises(ActiveRecord::RecordNotFound) {
      Topic.find(1, 2, 45)
    }
  end
  
  def test_find_with_entire_select_statement
    topics = Topic.find_by_sql "SELECT * FROM topics WHERE author_name = 'Mary'"
    
    assert_equal(1, topics.size)
    assert_equal(@topic_fixtures["second"]["title"], topics.first.title)
  end
  
  def test_find_first
    first = Topic.find_first "title = 'The First Topic'"
    assert_equal(@topic_fixtures["first"]["title"], first.title)
  end
  
  def test_find_first_failing
    first = Topic.find_first "title = 'The First Topic!'"
    assert_nil(first)
  end

  def test_unexisting_record_exception_handling
    assert_raises(ActiveRecord::RecordNotFound) {
      Topic.find(1).parent
    }
    
    Topic.find(2).parent
  end

  def test_find_on_conditions
    assert Topic.find_on_conditions(1, "approved = 0")
    assert_raises(ActiveRecord::RecordNotFound) { Topic.find_on_conditions(1, "approved = 1") }
  end
  
  def test_condition_interpolation
    assert_kind_of Firm, Company.find_first(["name = '%s'", "37signals"])
    assert_nil Company.find_first(["name = '%s'", "37signals!"])
    assert_nil Company.find_first(["name = '%s'", "37signals!' OR 1=1"])
    assert_kind_of Time, Topic.find_first(["id = %d", 1]).written_on
  end

  def test_bind_variables
    assert_kind_of Firm, Company.find_first(["name = ?", "37signals"])
    assert_nil Company.find_first(["name = ?", "37signals!"])
    assert_nil Company.find_first(["name = ?", "37signals!' OR 1=1"])
    assert_kind_of Time, Topic.find_first(["id = ?", 1]).written_on
  end
	
  def test_string_sanitation
    assert_not_equal "'something ' 1=1'", ActiveRecord::Base.sanitize("something ' 1=1")
    assert_equal "'something; select table'", ActiveRecord::Base.sanitize("something; select table")
  end
end