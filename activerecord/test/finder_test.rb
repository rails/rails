require 'abstract_unit'
require 'fixtures/company'
require 'fixtures/topic'
require 'fixtures/entrant'

class FinderTest < Test::Unit::TestCase
  fixtures :companies, :topics, :entrants
  
  def test_find
    assert_equal(@topics["first"]["title"], Topic.find(1).title)
  end
  
  def test_find_by_array_of_one_id
    assert_kind_of(Array, Topic.find([ 1 ]))
       assert_equal(1, Topic.find([ 1 ]).length)
  end
  
  def test_find_by_ids
    assert_equal(2, Topic.find(1, 2).length)
    assert_equal(@topics["second"]["title"], Topic.find([ 2 ]).first.title)
  end

  def test_find_by_ids_missing_one
    assert_raises(ActiveRecord::RecordNotFound) {
      Topic.find(1, 2, 45)
    }
  end
  
  def test_find_all_with_limit
    entrants = Entrant.find_all nil, "id ASC", 2
    
    assert_equal(2, entrants.size)
    assert_equal(@entrants["first"]["name"], entrants.first.name)
  end

  def test_find_all_with_prepared_limit_and_offset
    entrants = Entrant.find_all nil, "id ASC", ["? OFFSET ?", 2, 1]
    
    assert_equal(2, entrants.size)
    assert_equal(@entrants["second"]["name"], entrants.first.name)
  end

  def test_find_with_entire_select_statement
    topics = Topic.find_by_sql "SELECT * FROM topics WHERE author_name = 'Mary'"
    
    assert_equal(1, topics.size)
    assert_equal(@topics["second"]["title"], topics.first.title)
  end
  
  def test_find_with_prepared_select_statement
    topics = Topic.find_by_sql ["SELECT * FROM topics WHERE author_name = ?", "Mary"]
    
    assert_equal(1, topics.size)
    assert_equal(@topics["second"]["title"], topics.first.title)
  end
  
  def test_find_first
    first = Topic.find_first "title = 'The First Topic'"
    assert_equal(@topics["first"]["title"], first.title)
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
    assert Topic.find(1, :conditions => "approved = 0")
    assert_raises(ActiveRecord::RecordNotFound) { Topic.find(1, :conditions => "approved = 1") }
  end
  
  def test_deprecated_find_on_conditions
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
    assert_raises(ActiveRecord::PreparedStatementInvalid) {
      Company.find_first(["id=? AND name = ?", 2])
    }
    assert_raises(ActiveRecord::PreparedStatementInvalid) {
	   Company.find_first(["id=?", 2, 3, 4])
    }
  end
  
  def test_bind_variables_with_quotes
    Company.create("name" => "37signals' go'es agains")
    assert Company.find_first(["name = ?", "37signals' go'es agains"])
  end

  def test_named_bind_variables_with_quotes
    Company.create("name" => "37signals' go'es agains")
    assert Company.find_first(["name = :name", {:name => "37signals' go'es agains"}])
  end

  def test_bind_arity
    assert_nothing_raised                                 { bind '' }
    assert_raises(ActiveRecord::PreparedStatementInvalid) { bind '', 1 }
  
    assert_raises(ActiveRecord::PreparedStatementInvalid) { bind '?' }
    assert_nothing_raised                                 { bind '?', 1 }
    assert_raises(ActiveRecord::PreparedStatementInvalid) { bind '?', 1, 1  }
  end
  
  def test_named_bind_variables
    assert_equal '1', bind(':a', :a => 1) # ' ruby-mode
    assert_equal '1 1', bind(':a :a', :a => 1)  # ' ruby-mode
  
    assert_kind_of Firm, Company.find_first(["name = :name", { :name => "37signals" }])
    assert_nil Company.find_first(["name = :name", { :name => "37signals!" }])
    assert_nil Company.find_first(["name = :name", { :name => "37signals!' OR 1=1" }])
    assert_kind_of Time, Topic.find_first(["id = :id", { :id => 1 }]).written_on
    assert_raises(ActiveRecord::PreparedStatementInvalid) {
      Company.find_first(["id=:id and name=:name", { :id=>3 }])
    }
    assert_raises(ActiveRecord::PreparedStatementInvalid) {
      Company.find_first(["id=:id", { :id=>3, :name=>"37signals!" }])
    }
  end

  def test_named_bind_arity
    assert_nothing_raised { bind '', {} }
    assert_raises(ActiveRecord::PreparedStatementInvalid) { bind '', :a => 1 }
    assert_raises(ActiveRecord::PreparedStatementInvalid) { bind ':a', {} } # ' ruby-mode
    assert_nothing_raised { bind ':a', :a => 1 } # ' ruby-mode
    assert_raises(ActiveRecord::PreparedStatementInvalid) { bind ':a', :a => 1, :b => 2 } # ' ruby-mode
    assert_nothing_raised { bind ':a :a', :a => 1 } # ' ruby-mode
    assert_raises(ActiveRecord::PreparedStatementInvalid) { bind ':a :a', :a => 1, :b => 2 } # ' ruby-mode
  end
	
  def test_string_sanitation
    assert_not_equal "'something ' 1=1'", ActiveRecord::Base.sanitize("something ' 1=1")
    assert_equal "'something; select table'", ActiveRecord::Base.sanitize("something; select table")
  end

  def test_count
    assert_equal(0, Entrant.count("id > 3"))
    assert_equal(1, Entrant.count(["id > ?", 2]))
    assert_equal(2, Entrant.count(["id > ?", 1]))
  end

  def test_count_by_sql
    assert_equal(0, Entrant.count_by_sql("SELECT COUNT(*) FROM entrants WHERE id > 3"))
    assert_equal(1, Entrant.count_by_sql(["SELECT COUNT(*) FROM entrants WHERE id > ?", 2]))
    assert_equal(2, Entrant.count_by_sql(["SELECT COUNT(*) FROM entrants WHERE id > ?", 1]))
  end

  def test_find_by_one_attribute
    assert_equal @topics["first"].find, Topic.find_by_title("The First Topic")
    assert_nil Topic.find_by_title("The First Topic!")
  end

  def test_find_by_one_missing_attribute
    assert_raises(NoMethodError) { Topic.find_by_undertitle("The First Topic!") }
  end

  def test_find_by_two_attributes
    assert_equal @topics["first"].find, Topic.find_by_title_and_author_name("The First Topic", "David")
    assert_nil Topic.find_by_title_and_author_name("The First Topic", "Mary")
  end

  protected
    def bind(statement, *vars)
      if vars.first.is_a?(Hash)
        ActiveRecord::Base.send(:replace_named_bind_variables, statement, vars.first)
      else
        ActiveRecord::Base.send(:replace_bind_variables, statement, vars)
      end
    end
end
