require 'abstract_unit'
require 'fixtures/company'
require 'fixtures/topic'
require 'fixtures/entrant'
require 'fixtures/developer'

class FinderTest < Test::Unit::TestCase
  fixtures :companies, :topics, :entrants, :developers

  def test_find
    assert_equal(topics(:first).title, Topic.find(1).title)
  end
  
  def test_exists
    assert (Topic.exists?(1))
    assert !(Topic.exists?(45))
    assert !(Topic.exists?("foo"))
    assert !(Topic.exists?([1,2]))
  end
  
  def test_find_by_array_of_one_id
    assert_kind_of(Array, Topic.find([ 1 ]))
    assert_equal(1, Topic.find([ 1 ]).length)
  end
  
  def test_find_by_ids
    assert_equal(2, Topic.find(1, 2).length)
    assert_equal(topics(:second).title, Topic.find([ 2 ]).first.title)
  end

  def test_find_an_empty_array
    assert_equal [], Topic.find([])
  end

  def test_find_by_ids_missing_one
    assert_raises(ActiveRecord::RecordNotFound) {
      Topic.find(1, 2, 45)
    }
  end
  
  def test_find_all_with_limit
    entrants = Entrant.find(:all, :order => "id ASC", :limit => 2)
    
    assert_equal(2, entrants.size)
    assert_equal(entrants(:first).name, entrants.first.name)
  end

  def test_find_all_with_prepared_limit_and_offset
    if ActiveRecord::ConnectionAdapters.const_defined? :OracleAdapter
      if ActiveRecord::Base.connection.instance_of?(ActiveRecord::ConnectionAdapters::OracleAdapter)
        assert_raises(ArgumentError) { Entrant.find(:all, :order => 'id ASC', :limit => 2, :offset => 1) }
      end
    else
      entrants = Entrant.find(:all, :order => "id ASC", :limit => 2, :offset => 1)

      assert_equal(2, entrants.size)
      assert_equal(entrants(:second).name, entrants.first.name)

      entrants = Entrant.find(:all, :order => "id ASC", :limit => 2, :offset => 2)
      assert_equal(1, entrants.size)
      assert_equal(entrants(:third).name, entrants.first.name)
    end
  end

  def test_find_with_entire_select_statement
    topics = Topic.find_by_sql "SELECT * FROM topics WHERE author_name = 'Mary'"
    
    assert_equal(1, topics.size)
    assert_equal(topics(:second).title, topics.first.title)
  end
  
  def test_find_with_prepared_select_statement
    topics = Topic.find_by_sql ["SELECT * FROM topics WHERE author_name = ?", "Mary"]
    
    assert_equal(1, topics.size)
    assert_equal(topics(:second).title, topics.first.title)
  end
  
  def test_find_first
    first = Topic.find(:first, :conditions => "title = 'The First Topic'")
    assert_equal(topics(:first).title, first.title)
  end
  
  def test_find_first_failing
    first = Topic.find(:first, :conditions => "title = 'The First Topic!'")
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
  
  def test_condition_interpolation
    assert_kind_of Firm, Company.find(:first, :conditions => ["name = '%s'", "37signals"])
    assert_nil Company.find(:first, :conditions => ["name = '%s'", "37signals!"])
    assert_nil Company.find(:first, :conditions => ["name = '%s'", "37signals!' OR 1=1"])
    assert_kind_of Time, Topic.find(:first, :conditions => ["id = %d", 1]).written_on
  end

  def test_bind_variables
    assert_kind_of Firm, Company.find(:first, :conditions => ["name = ?", "37signals"])
    assert_nil Company.find(:first, :conditions => ["name = ?", "37signals!"])
    assert_nil Company.find(:first, :conditions => ["name = ?", "37signals!' OR 1=1"])
    assert_kind_of Time, Topic.find(:first, :conditions => ["id = ?", 1]).written_on
    assert_raises(ActiveRecord::PreparedStatementInvalid) {
      Company.find(:first, :conditions => ["id=? AND name = ?", 2])
    }
    assert_raises(ActiveRecord::PreparedStatementInvalid) {
	   Company.find(:first, :conditions => ["id=?", 2, 3, 4])
    }
  end
  
  def test_bind_variables_with_quotes
    Company.create("name" => "37signals' go'es agains")
    assert Company.find(:first, :conditions => ["name = ?", "37signals' go'es agains"])
  end

  def test_named_bind_variables_with_quotes
    Company.create("name" => "37signals' go'es agains")
    assert Company.find(:first, :conditions => ["name = :name", {:name => "37signals' go'es agains"}])
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
  
    assert_kind_of Firm, Company.find(:first, :conditions => ["name = :name", { :name => "37signals" }])
    assert_nil Company.find(:first, :conditions => ["name = :name", { :name => "37signals!" }])
    assert_nil Company.find(:first, :conditions => ["name = :name", { :name => "37signals!' OR 1=1" }])
    assert_kind_of Time, Topic.find(:first, :conditions => ["id = :id", { :id => 1 }]).written_on
    assert_raises(ActiveRecord::PreparedStatementInvalid) {
      Company.find(:first, :conditions => ["id=:id and name=:name", { :id=>3 }])
    }
    assert_raises(ActiveRecord::PreparedStatementInvalid) {
      Company.find(:first, :conditions => ["id=:id", { :id=>3, :name=>"37signals!" }])
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

  def test_bind_enumerable
    assert_equal '1,2,3', bind('?', [1, 2, 3])
    assert_equal %('a','b','c'), bind('?', %w(a b c))

    assert_equal '1,2,3', bind(':a', :a => [1, 2, 3])
    assert_equal %('a','b','c'), bind(':a', :a => %w(a b c)) # '

    require 'set'
    assert_equal '1,2,3', bind('?', Set.new([1, 2, 3]))
    assert_equal %('a','b','c'), bind('?', Set.new(%w(a b c)))

    assert_equal '1,2,3', bind(':a', :a => Set.new([1, 2, 3]))
    assert_equal %('a','b','c'), bind(':a', :a => Set.new(%w(a b c))) # '
  end

  def test_bind_string
    assert_equal "''", bind('?', '')
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
    assert_equal topics(:first), Topic.find_by_title("The First Topic")
    assert_nil Topic.find_by_title("The First Topic!")
  end

  def test_find_by_one_missing_attribute
    assert_raises(NoMethodError) { Topic.find_by_undertitle("The First Topic!") }
  end

  def test_find_by_two_attributes
    assert_equal topics(:first), Topic.find_by_title_and_author_name("The First Topic", "David")
    assert_nil Topic.find_by_title_and_author_name("The First Topic", "Mary")
  end

  def test_find_all_by_one_attribute
    topics = Topic.find_all_by_content("Have a nice day")
    assert_equal 2, topics.size
    assert topics.include?(topics(:first))

    assert_equal [], Topic.find_all_by_title("The First Topic!!")
  end
  
  def test_find_all_by_one_attribute_with_options
    topics = Topic.find_all_by_content("Have a nice day", :order => "id DESC")
    assert topics(:first), topics.last

    topics = Topic.find_all_by_content("Have a nice day", :order => "id")
    assert topics(:first), topics.first
  end

  def test_find_all_by_array_attribute
    assert_equal 2, Topic.find_all_by_title(["The First Topic", "The Second Topic's of the day"]).size
  end

  def test_find_all_by_boolean_attribute
    topics = Topic.find_all_by_approved(false)
    assert_equal 1, topics.size
    assert topics.include?(topics(:first))

    topics = Topic.find_all_by_approved(true)
    assert_equal 1, topics.size
    assert topics.include?(topics(:second))
  end
  
  def test_find_by_nil_attribute
    topic = Topic.find_by_last_read nil
    assert_not_nil topic
    assert_nil topic.last_read
  end
  
  def test_find_all_by_nil_attribute
    topics = Topic.find_all_by_last_read nil
    assert_equal 1, topics.size
    assert_nil topics[0].last_read
  end
  
  def test_find_by_nil_and_not_nil_attributes
    topic = Topic.find_by_last_read_and_author_name nil, "Mary"
    assert_equal "Mary", topic.author_name
  end

  def test_find_all_by_nil_and_not_nil_attributes
    topics = Topic.find_all_by_last_read_and_author_name nil, "Mary"
    assert_equal 1, topics.size
    assert_equal "Mary", topics[0].author_name
  end

  def test_find_with_bad_sql
    assert_raises(ActiveRecord::StatementInvalid) { Topic.find_by_sql "select 1 from badtable" }
  end

  def test_find_all_with_limit
    first_five_developers = Developer.find :all, :order => 'id ASC', :limit =>  5
    assert_equal 5, first_five_developers.length
    assert_equal 'David', first_five_developers.first.name
    assert_equal 'fixture_5', first_five_developers.last.name
    
    no_developers = Developer.find :all, :order => 'id ASC', :limit => 0
    assert_equal 0, no_developers.length
  end

  def test_find_all_with_limit_and_offset
    first_three_developers = Developer.find :all, :order => 'id ASC', :limit => 3, :offset => 0
    second_three_developers = Developer.find :all, :order => 'id ASC', :limit => 3, :offset => 3
    last_two_developers = Developer.find :all, :order => 'id ASC', :limit => 2, :offset => 8
    
    assert_equal 3, first_three_developers.length
    assert_equal 3, second_three_developers.length
    assert_equal 2, last_two_developers.length
    
    assert_equal 'David', first_three_developers.first.name
    assert_equal 'fixture_4', second_three_developers.first.name
    assert_equal 'fixture_9', last_two_developers.first.name
  end

  def test_find_all_with_join
    developers_on_project_one = Developer.find(
      :all, 
      :joins => 'LEFT JOIN developers_projects ON developers.id = developers_projects.developer_id', 
      :conditions => 'project_id=1'
    )
    assert_equal 2, developers_on_project_one.length
    developer_names = developers_on_project_one.map { |d| d.name }
    assert developer_names.include?('David')
    assert developer_names.include?('Jamis')
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
