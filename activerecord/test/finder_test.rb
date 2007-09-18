require 'abstract_unit'
require 'fixtures/author'
require 'fixtures/comment'
require 'fixtures/company'
require 'fixtures/topic'
require 'fixtures/reply'
require 'fixtures/entrant'
require 'fixtures/developer'
require 'fixtures/post'

class FinderTest < Test::Unit::TestCase
  fixtures :companies, :topics, :entrants, :developers, :developers_projects, :posts, :comments, :accounts, :authors

  def test_find
    assert_equal(topics(:first).title, Topic.find(1).title)
  end

  # find should handle strings that come from URLs
  # (example: Category.find(params[:id]))
  def test_find_with_string
    assert_equal(Topic.find(1).title,Topic.find("1").title)
  end

  def test_exists
    assert Topic.exists?(1)
    assert Topic.exists?("1")
    assert Topic.exists?(:author_name => "David")
    assert Topic.exists?(:author_name => "Mary", :approved => true)
    assert Topic.exists?(["parent_id = ?", 1])
    assert !Topic.exists?(45)
    assert !Topic.exists?("foo")
    assert_raise(NoMethodError) { Topic.exists?([1,2]) }
  end

  def test_find_by_array_of_one_id
    assert_kind_of(Array, Topic.find([ 1 ]))
    assert_equal(1, Topic.find([ 1 ]).length)
  end

  def test_find_by_ids
    assert_equal 2, Topic.find(1, 2).size
    assert_equal topics(:second).title, Topic.find([2]).first.title
  end

  def test_find_by_ids_with_limit_and_offset
    assert_equal 2, Entrant.find([1,3,2], :limit => 2).size
    assert_equal 1, Entrant.find([1,3,2], :limit => 3, :offset => 2).size

    # Also test an edge case: If you have 11 results, and you set a
    #   limit of 3 and offset of 9, then you should find that there
    #   will be only 2 results, regardless of the limit.
    devs = Developer.find :all
    last_devs = Developer.find devs.map(&:id), :limit => 3, :offset => 9
    assert_equal 2, last_devs.size
  end

  def test_find_an_empty_array
    assert_equal [], Topic.find([])
  end

  def test_find_by_ids_missing_one
    assert_raises(ActiveRecord::RecordNotFound) { Topic.find(1, 2, 45) }
  end

  def test_find_all_with_limit
    entrants = Entrant.find(:all, :order => "id ASC", :limit => 2)

    assert_equal(2, entrants.size)
    assert_equal(entrants(:first).name, entrants.first.name)
  end

  def test_find_all_with_prepared_limit_and_offset
    entrants = Entrant.find(:all, :order => "id ASC", :limit => 2, :offset => 1)

    assert_equal(2, entrants.size)
    assert_equal(entrants(:second).name, entrants.first.name)

    entrants = Entrant.find(:all, :order => "id ASC", :limit => 2, :offset => 2)
    assert_equal(1, entrants.size)
    assert_equal(entrants(:third).name, entrants.first.name)
  end

  def test_find_all_with_limit_and_offset_and_multiple_orderings
    developers = Developer.find(:all, :order => "salary ASC, id DESC", :limit => 3, :offset => 1)
    assert_equal ["David", "fixture_10", "fixture_9"], developers.collect {|d| d.name}
  end

  def test_find_with_limit_and_condition
    developers = Developer.find(:all, :order => "id DESC", :conditions => "salary = 100000", :limit => 3, :offset =>7)
    assert_equal(1, developers.size)
    assert_equal("fixture_3", developers.first.name)
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

  def test_find_by_sql_with_sti_on_joined_table
    accounts = Account.find_by_sql("SELECT * FROM accounts INNER JOIN companies ON companies.id = accounts.firm_id")
    assert_equal [Account], accounts.collect(&:class).uniq
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

    Topic.find(2).topic
  end

  def test_find_only_some_columns
    topic = Topic.find(1, :select => "author_name")
    assert_raises(ActiveRecord::MissingAttributeError) {topic.title}
    assert_equal "David", topic.author_name
    assert !topic.attribute_present?("title")
    #assert !topic.respond_to?("title")
    assert topic.attribute_present?("author_name")
    assert topic.respond_to?("author_name")
  end
  
  def test_find_on_blank_conditions
    [nil, " ", [], {}].each do |blank|
      assert_nothing_raised { Topic.find(:first, :conditions => blank) }
    end
  end
  
  def test_find_on_blank_bind_conditions
    [ [""], ["",{}] ].each do |blank|
      assert_nothing_raised { Topic.find(:first, :conditions => blank) }
    end
  end

  def test_find_on_array_conditions
    assert Topic.find(1, :conditions => ["approved = ?", false])
    assert_raises(ActiveRecord::RecordNotFound) { Topic.find(1, :conditions => ["approved = ?", true]) }
  end

  def test_find_on_hash_conditions
    assert Topic.find(1, :conditions => { :approved => false })
    assert_raises(ActiveRecord::RecordNotFound) { Topic.find(1, :conditions => { :approved => true }) }
  end

  def test_find_on_association_proxy_conditions
    assert_equal [1, 2, 3, 5, 6, 7, 8, 9, 10], Comment.find_all_by_post_id(authors(:david).posts).map(&:id).sort
  end

  def test_find_on_hash_conditions_with_range
    assert_equal [1,2], Topic.find(:all, :conditions => { :id => 1..2 }).map(&:id).sort
    assert_raises(ActiveRecord::RecordNotFound) { Topic.find(1, :conditions => { :id => 2..3 }) }
  end

  def test_find_on_hash_conditions_with_multiple_ranges
    assert_equal [1,2,3], Comment.find(:all, :conditions => { :id => 1..3, :post_id => 1..2 }).map(&:id).sort
    assert_equal [1], Comment.find(:all, :conditions => { :id => 1..1, :post_id => 1..10 }).map(&:id).sort
  end

  def test_find_on_multiple_hash_conditions
    assert Topic.find(1, :conditions => { :author_name => "David", :title => "The First Topic", :replies_count => 1, :approved => false })
    assert_raises(ActiveRecord::RecordNotFound) { Topic.find(1, :conditions => { :author_name => "David", :title => "The First Topic", :replies_count => 1, :approved => true }) }
    assert_raises(ActiveRecord::RecordNotFound) { Topic.find(1, :conditions => { :author_name => "David", :title => "HHC", :replies_count => 1, :approved => false }) }
    assert_raises(ActiveRecord::RecordNotFound) { Topic.find(1, :conditions => { :author_name => "David", :title => "The First Topic", :replies_count => 1, :approved => true }) }
  end


  def test_condition_interpolation
    assert_kind_of Firm, Company.find(:first, :conditions => ["name = '%s'", "37signals"])
    assert_nil Company.find(:first, :conditions => ["name = '%s'", "37signals!"])
    assert_nil Company.find(:first, :conditions => ["name = '%s'", "37signals!' OR 1=1"])
    assert_kind_of Time, Topic.find(:first, :conditions => ["id = %d", 1]).written_on
  end

  def test_condition_array_interpolation
    assert_kind_of Firm, Company.find(:first, :conditions => ["name = '%s'", "37signals"])
    assert_nil Company.find(:first, :conditions => ["name = '%s'", "37signals!"])
    assert_nil Company.find(:first, :conditions => ["name = '%s'", "37signals!' OR 1=1"])
    assert_kind_of Time, Topic.find(:first, :conditions => ["id = %d", 1]).written_on
  end

  def test_condition_hash_interpolation
    assert_kind_of Firm, Company.find(:first, :conditions => { :name => "37signals"})
    assert_nil Company.find(:first, :conditions => { :name => "37signals!"})
    assert_kind_of Time, Topic.find(:first, :conditions => {:id => 1}).written_on
  end

  def test_hash_condition_find_malformed
    assert_raises(ActiveRecord::StatementInvalid) {
      Company.find(:first, :conditions => { :id => 2, :dhh => true })
    }
  end

  def test_hash_condition_find_with_escaped_characters
    Company.create("name" => "Ain't noth'n like' \#stuff")
    assert Company.find(:first, :conditions => { :name => "Ain't noth'n like' \#stuff" })
  end

  def test_hash_condition_find_with_array
    p1, p2 = Post.find(:all, :limit => 2, :order => 'id asc')
    assert_equal [p1, p2], Post.find(:all, :conditions => { :id => [p1, p2] }, :order => 'id asc')
    assert_equal [p1, p2], Post.find(:all, :conditions => { :id => [p1, p2.id] }, :order => 'id asc')
  end

  def test_hash_condition_find_with_nil
    topic = Topic.find(:first, :conditions => { :last_read => nil } )
    assert_not_nil topic
    assert_nil topic.last_read
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
  end

  def test_bind_enumerable
    quoted_abc = %(#{ActiveRecord::Base.connection.quote('a')},#{ActiveRecord::Base.connection.quote('b')},#{ActiveRecord::Base.connection.quote('c')})

    assert_equal '1,2,3', bind('?', [1, 2, 3])
    assert_equal quoted_abc, bind('?', %w(a b c))

    assert_equal '1,2,3', bind(':a', :a => [1, 2, 3])
    assert_equal quoted_abc, bind(':a', :a => %w(a b c)) # '

    require 'set'
    assert_equal '1,2,3', bind('?', Set.new([1, 2, 3]))
    assert_equal quoted_abc, bind('?', Set.new(%w(a b c)))

    assert_equal '1,2,3', bind(':a', :a => Set.new([1, 2, 3]))
    assert_equal quoted_abc, bind(':a', :a => Set.new(%w(a b c))) # '
  end

  def test_bind_empty_enumerable
    quoted_nil = ActiveRecord::Base.connection.quote(nil)
    assert_equal quoted_nil, bind('?', [])
    assert_equal " in (#{quoted_nil})", bind(' in (?)', [])
    assert_equal "foo in (#{quoted_nil})", bind('foo in (?)', [])
  end

  def test_bind_string
    assert_equal ActiveRecord::Base.connection.quote(''), bind('?', '')
  end

  def test_bind_record
    o = Struct.new(:quoted_id).new(1)
    assert_equal '1', bind('?', o)

    os = [o] * 3
    assert_equal '1,1,1', bind('?', os)
  end

  def test_string_sanitation
    assert_not_equal "#{ActiveRecord::Base.connection.quoted_string_prefix}'something ' 1=1'", ActiveRecord::Base.sanitize("something ' 1=1")
    assert_equal "#{ActiveRecord::Base.connection.quoted_string_prefix}'something; select table'", ActiveRecord::Base.sanitize("something; select table")
  end

  def test_count
    assert_equal(0, Entrant.count(:conditions => "id > 3"))
    assert_equal(1, Entrant.count(:conditions => ["id > ?", 2]))
    assert_equal(2, Entrant.count(:conditions => ["id > ?", 1]))
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
  
  def test_find_by_one_attribute_caches_dynamic_finder
    # ensure this test can run independently of order
    class << Topic; self; end.send(:remove_method, :find_by_title) if Topic.respond_to?(:find_by_title)
    assert !Topic.respond_to?(:find_by_title)
    t = Topic.find_by_title("The First Topic")
    assert Topic.respond_to?(:find_by_title)
  end

  def test_dynamic_finder_returns_same_results_after_caching
    # ensure this test can run independently of order
    class << Topic; self; end.send(:remove_method, :find_by_title) if Topic.respond_to?(:find_by_title)
    t = Topic.find_by_title("The First Topic")
    assert_equal t, Topic.find_by_title("The First Topic") # find_by_title has been cached
  end

  def test_find_by_one_attribute_with_order_option
    assert_equal accounts(:signals37), Account.find_by_credit_limit(50, :order => 'id')
    assert_equal accounts(:rails_core_account), Account.find_by_credit_limit(50, :order => 'id DESC')
  end

  def test_find_by_one_attribute_with_conditions
    assert_equal accounts(:rails_core_account), Account.find_by_credit_limit(50, :conditions => ['firm_id = ?', 6])
  end

  def test_dynamic_finder_on_one_attribute_with_conditions_caches_method
    # ensure this test can run independently of order
    class << Account; self; end.send(:remove_method, :find_by_credit_limit) if Account.respond_to?(:find_by_credit_limit)
    assert !Account.respond_to?(:find_by_credit_limit)
    a = Account.find_by_credit_limit(50, :conditions => ['firm_id = ?', 6])
    assert Account.respond_to?(:find_by_credit_limit)
  end

  def test_dynamic_finder_on_one_attribute_with_conditions_returns_same_results_after_caching
    # ensure this test can run independently of order
    class << Account; self; end.send(:remove_method, :find_by_credit_limit) if Account.respond_to?(:find_by_credit_limit)
    a = Account.find_by_credit_limit(50, :conditions => ['firm_id = ?', 6])
    assert_equal a, Account.find_by_credit_limit(50, :conditions => ['firm_id = ?', 6]) # find_by_credit_limit has been cached
  end

  def test_find_by_one_attribute_with_several_options
    assert_equal accounts(:unknown), Account.find_by_credit_limit(50, :order => 'id DESC', :conditions => ['id != ?', 3])
  end

  def test_find_by_one_missing_attribute
    assert_raises(NoMethodError) { Topic.find_by_undertitle("The First Topic!") }
  end

  def test_find_by_invalid_method_syntax
    assert_raises(NoMethodError) { Topic.fail_to_find_by_title("The First Topic") }
    assert_raises(NoMethodError) { Topic.find_by_title?("The First Topic") }
    assert_raises(NoMethodError) { Topic.fail_to_find_or_create_by_title("Nonexistent Title") }
    assert_raises(NoMethodError) { Topic.find_or_create_by_title?("Nonexistent Title") }
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

  def test_find_or_create_from_one_attribute
    number_of_companies = Company.count
    sig38 = Company.find_or_create_by_name("38signals")
    assert_equal number_of_companies + 1, Company.count
    assert_equal sig38, Company.find_or_create_by_name("38signals")
    assert !sig38.new_record?
  end

  def test_find_or_create_from_two_attributes
    number_of_topics = Topic.count
    another = Topic.find_or_create_by_title_and_author_name("Another topic","John")
    assert_equal number_of_topics + 1, Topic.count
    assert_equal another, Topic.find_or_create_by_title_and_author_name("Another topic", "John")
    assert !another.new_record?
  end

  def test_find_or_create_from_one_attribute_and_hash
    number_of_companies = Company.count
    sig38 = Company.find_or_create_by_name({:name => "38signals", :firm_id => 17, :client_of => 23})
    assert_equal number_of_companies + 1, Company.count
    assert_equal sig38, Company.find_or_create_by_name({:name => "38signals", :firm_id => 17, :client_of => 23})
    assert !sig38.new_record?
    assert_equal "38signals", sig38.name
    assert_equal 17, sig38.firm_id
    assert_equal 23, sig38.client_of
  end

  def test_find_or_initialize_from_one_attribute
    sig38 = Company.find_or_initialize_by_name("38signals")
    assert_equal "38signals", sig38.name
    assert sig38.new_record?
  end

  def test_dynamic_find_or_initialize_from_one_attribute_caches_method
    class << Company; self; end.send(:remove_method, :find_or_initialize_by_name) if Company.respond_to?(:find_or_initialize_by_name)    
    assert !Company.respond_to?(:find_or_initialize_by_name)
    sig38 = Company.find_or_initialize_by_name("38signals")
    assert Company.respond_to?(:find_or_initialize_by_name)
  end

  def test_find_or_initialize_from_two_attributes
    another = Topic.find_or_initialize_by_title_and_author_name("Another topic","John")
    assert_equal "Another topic", another.title
    assert_equal "John", another.author_name
    assert another.new_record?
  end

  def test_find_or_initialize_from_one_attribute_and_hash
    sig38 = Company.find_or_initialize_by_name({:name => "38signals", :firm_id => 17, :client_of => 23})
    assert_equal "38signals", sig38.name
    assert_equal 17, sig38.firm_id
    assert_equal 23, sig38.client_of
    assert sig38.new_record?
  end

  def test_find_with_bad_sql
    assert_raises(ActiveRecord::StatementInvalid) { Topic.find_by_sql "select 1 from badtable" }
  end

  def test_find_with_invalid_params
    assert_raises(ArgumentError) { Topic.find :first, :join => "It should be `joins'" }
    assert_raises(ArgumentError) { Topic.find :first, :conditions => '1 = 1', :join => "It should be `joins'" }
  end

  def test_dynamic_finder_with_invalid_params
    assert_raises(ArgumentError) { Topic.find_by_title 'No Title', :join => "It should be `joins'" }
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

  def test_find_all_with_limit_and_offset_and_multiple_order_clauses
    first_three_posts = Post.find :all, :order => 'author_id, id', :limit => 3, :offset => 0
    second_three_posts = Post.find :all, :order => ' author_id,id ', :limit => 3, :offset => 3
    last_posts = Post.find :all, :order => ' author_id, id  ', :limit => 3, :offset => 6

    assert_equal [[0,3],[1,1],[1,2]], first_three_posts.map { |p| [p.author_id, p.id] }
    assert_equal [[1,4],[1,5],[1,6]], second_three_posts.map { |p| [p.author_id, p.id] }
    assert_equal [[2,7]], last_posts.map { |p| [p.author_id, p.id] }
  end

  def test_find_all_with_join
    developers_on_project_one = Developer.find(
      :all,
      :joins => 'LEFT JOIN developers_projects ON developers.id = developers_projects.developer_id',
      :conditions => 'project_id=1'
    )
    assert_equal 3, developers_on_project_one.length
    developer_names = developers_on_project_one.map { |d| d.name }
    assert developer_names.include?('David')
    assert developer_names.include?('Jamis')
  end

  def test_joins_dont_clobber_id
    first = Firm.find(
      :first,
      :joins => 'INNER JOIN companies AS clients ON clients.firm_id = companies.id',
      :conditions => 'companies.id = 1'
    )
    assert_equal 1, first.id
  end

  def test_find_by_id_with_conditions_with_or
    assert_nothing_raised do
      Post.find([1,2,3],
        :conditions => "posts.id <= 3 OR posts.#{QUOTED_TYPE} = 'Post'")
    end
  end

  # http://dev.rubyonrails.org/ticket/6778
  def test_find_ignores_previously_inserted_record
    post = Post.create!(:title => 'test', :body => 'it out')
    assert_equal [], Post.find_all_by_id(nil)
  end

  def test_find_by_empty_ids
    assert_equal [], Post.find([])
  end

  def test_find_by_empty_in_condition
    assert_equal [], Post.find(:all, :conditions => ['id in (?)', []])
  end

  def test_find_by_records
    p1, p2 = Post.find(:all, :limit => 2, :order => 'id asc')
    assert_equal [p1, p2], Post.find(:all, :conditions => ['id in (?)', [p1, p2]], :order => 'id asc')
    assert_equal [p1, p2], Post.find(:all, :conditions => ['id in (?)', [p1, p2.id]], :order => 'id asc')
  end

  def test_select_value
    assert_equal "37signals", Company.connection.select_value("SELECT name FROM companies WHERE id = 1")
    assert_nil Company.connection.select_value("SELECT name FROM companies WHERE id = -1")
    # make sure we didn't break count...
    assert_equal 0, Company.count_by_sql("SELECT COUNT(*) FROM companies WHERE name = 'Halliburton'")
    assert_equal 1, Company.count_by_sql("SELECT COUNT(*) FROM companies WHERE name = '37signals'")
  end

  def test_select_values
    assert_equal ["1","2","3","4","5","6","7","8","9"], Company.connection.select_values("SELECT id FROM companies ORDER BY id").map! { |i| i.to_s }
    assert_equal ["37signals","Summit","Microsoft", "Flamboyant Software", "Ex Nihilo", "RailsCore", "Leetsoft", "Jadedpixel", "Odegy"], Company.connection.select_values("SELECT name FROM companies ORDER BY id")
  end

  def test_select_rows
    assert_equal(
      [["1", nil, nil, "37signals"],
       ["2", "1", "2", "Summit"],
       ["3", "1", "1", "Microsoft"]],
      Company.connection.select_rows("SELECT id, firm_id, client_of, name FROM companies ORDER BY id LIMIT 3"))
    assert_equal [["1", "37signals"], ["2", "Summit"], ["3", "Microsoft"]],
      Company.connection.select_rows("SELECT id, name FROM companies ORDER BY id LIMIT 3")
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
