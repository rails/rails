require "cases/helper"
require 'models/post'
require 'models/author'
require 'models/categorization'
require 'models/comment'
require 'models/company'
require 'models/topic'
require 'models/reply'
require 'models/entrant'
require 'models/developer'
require 'models/customer'
require 'models/job'
require 'models/categorization'

class DynamicFinderMatchTest < ActiveRecord::TestCase
  def test_find_no_match
    assert_nil ActiveRecord::DynamicFinderMatch.match("not_a_finder")
  end

  def test_find_by
    match = ActiveRecord::DynamicFinderMatch.match("find_by_age_and_sex_and_location")
    assert_not_nil match
    assert match.finder?
    assert_equal :first, match.finder
    assert_equal %w(age sex location), match.attribute_names
  end

  def find_by_bang
    match = ActiveRecord::DynamicFinderMatch.match("find_by_age_and_sex_and_location!")
    assert_not_nil match
    assert match.finder?
    assert match.bang?
    assert_equal :first, match.finder
    assert_equal %w(age sex location), match.attribute_names
  end

  def test_find_all_by
    match = ActiveRecord::DynamicFinderMatch.match("find_all_by_age_and_sex_and_location")
    assert_not_nil match
    assert match.finder?
    assert_equal :all, match.finder
    assert_equal %w(age sex location), match.attribute_names
  end

  def test_find_or_initialize_by
    match = ActiveRecord::DynamicFinderMatch.match("find_or_initialize_by_age_and_sex_and_location")
    assert_not_nil match
    assert !match.finder?
    assert match.instantiator?
    assert_equal :first, match.finder
    assert_equal :new, match.instantiator
    assert_equal %w(age sex location), match.attribute_names
  end

  def test_find_or_create_by
    match = ActiveRecord::DynamicFinderMatch.match("find_or_create_by_age_and_sex_and_location")
    assert_not_nil match
    assert !match.finder?
    assert match.instantiator?
    assert_equal :first, match.finder
    assert_equal :create, match.instantiator
    assert_equal %w(age sex location), match.attribute_names
  end
end

class FinderTest < ActiveRecord::TestCase
  fixtures :companies, :topics, :entrants, :developers, :developers_projects, :posts, :comments, :accounts, :authors, :customers

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

    begin
      assert !Topic.exists?("foo")
    rescue ActiveRecord::StatementInvalid
      # PostgreSQL complains about string comparison with integer field
    rescue Exception
      flunk
    end

    assert_raise(NoMethodError) { Topic.exists?([1,2]) }
  end

  def test_exists_returns_true_with_one_record_and_no_args
    assert Topic.exists?
  end

  def test_does_not_exist_with_empty_table_and_no_args_given
    Topic.delete_all
    assert !Topic.exists?
  end

  def test_exists_with_aggregate_having_three_mappings
    existing_address = customers(:david).address
    assert Customer.exists?(:address => existing_address)
  end

  def test_exists_with_aggregate_having_three_mappings_with_one_difference
    existing_address = customers(:david).address
    assert !Customer.exists?(:address =>
      Address.new(existing_address.street, existing_address.city, existing_address.country + "1"))
    assert !Customer.exists?(:address =>
      Address.new(existing_address.street, existing_address.city + "1", existing_address.country))
    assert !Customer.exists?(:address =>
      Address.new(existing_address.street + "1", existing_address.city, existing_address.country))
  end

  def test_exists_with_scoped_include
    Developer.with_scope(:find => { :include => :projects, :order => "projects.name" }) do
      assert Developer.exists?
    end
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
    assert_raise(ActiveRecord::RecordNotFound) { Topic.find(1, 2, 45) }
  end

  def test_find_all_with_limit
    assert_equal(2, Entrant.find(:all, :limit => 2).size)
    assert_equal(0, Entrant.find(:all, :limit => 0).size)
  end

  def test_find_all_with_prepared_limit_and_offset
    entrants = Entrant.find(:all, :order => "id ASC", :limit => 2, :offset => 1)

    assert_equal(2, entrants.size)
    assert_equal(entrants(:second).name, entrants.first.name)

    assert_equal 3, Entrant.count
    entrants = Entrant.find(:all, :order => "id ASC", :limit => 2, :offset => 2)
    assert_equal(1, entrants.size)
    assert_equal(entrants(:third).name, entrants.first.name)
  end

  def test_find_all_with_limit_and_offset_and_multiple_order_clauses
    first_three_posts = Post.find :all, :order => 'author_id, id', :limit => 3, :offset => 0
    second_three_posts = Post.find :all, :order => ' author_id,id ', :limit => 3, :offset => 3
    last_posts = Post.find :all, :order => ' author_id, id  ', :limit => 3, :offset => 6

    assert_equal [[0,3],[1,1],[1,2]], first_three_posts.map { |p| [p.author_id, p.id] }
    assert_equal [[1,4],[1,5],[1,6]], second_three_posts.map { |p| [p.author_id, p.id] }
    assert_equal [[2,7]], last_posts.map { |p| [p.author_id, p.id] }
  end


  def test_find_with_group
    developers =  Developer.find(:all, :group => "salary", :select => "salary")
    assert_equal 4, developers.size
    assert_equal 4, developers.map(&:salary).uniq.size
  end

  def test_find_with_group_and_having
    developers =  Developer.find(:all, :group => "salary", :having => "sum(salary) >  10000", :select => "salary")
    assert_equal 3, developers.size
    assert_equal 3, developers.map(&:salary).uniq.size
    assert developers.all? { |developer|  developer.salary > 10000 }
  end

  def test_find_with_group_and_sanitized_having
    developers =  Developer.find(:all, :group => "salary", :having => ["sum(salary) > ?", 10000], :select => "salary")
    assert_equal 3, developers.size
    assert_equal 3, developers.map(&:salary).uniq.size
    assert developers.all? { |developer|  developer.salary > 10000 }
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

  def test_first
    assert_equal topics(:second).title, Topic.first(:conditions => "title = 'The Second Topic of the day'").title
  end

  def test_first_failing
    assert_nil Topic.first(:conditions => "title = 'The Second Topic of the day!'")
  end

  def test_unexisting_record_exception_handling
    assert_raise(ActiveRecord::RecordNotFound) {
      Topic.find(1).parent
    }

    Topic.find(2).topic
  end

  def test_find_only_some_columns
    topic = Topic.find(1, :select => "author_name")
    assert_raise(ActiveRecord::MissingAttributeError) {topic.title}
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
    assert_raise(ActiveRecord::RecordNotFound) { Topic.find(1, :conditions => ["approved = ?", true]) }
  end

  def test_find_on_hash_conditions
    assert Topic.find(1, :conditions => { :approved => false })
    assert_raise(ActiveRecord::RecordNotFound) { Topic.find(1, :conditions => { :approved => true }) }
  end

  def test_find_on_hash_conditions_with_explicit_table_name
    assert Topic.find(1, :conditions => { 'topics.approved' => false })
    assert_raise(ActiveRecord::RecordNotFound) { Topic.find(1, :conditions => { 'topics.approved' => true }) }
  end

  def test_find_on_hash_conditions_with_hashed_table_name
    assert Topic.find(1, :conditions => {:topics => { :approved => false }})
    assert_raise(ActiveRecord::RecordNotFound) { Topic.find(1, :conditions => {:topics => { :approved => true }}) }
  end

  def test_find_with_hash_conditions_on_joined_table
    firms = Firm.all :joins => :account, :conditions => {:accounts => { :credit_limit => 50 }}
    assert_equal 1, firms.size
    assert_equal companies(:first_firm), firms.first
  end

  def test_find_with_hash_conditions_on_joined_table_and_with_range
    firms = DependentFirm.all :joins => :account, :conditions => {:name => 'RailsCore', :accounts => { :credit_limit => 55..60 }}
    assert_equal 1, firms.size
    assert_equal companies(:rails_core), firms.first
  end

  def test_find_on_hash_conditions_with_explicit_table_name_and_aggregate
    david = customers(:david)
    assert Customer.find(david.id, :conditions => { 'customers.name' => david.name, :address => david.address })
    assert_raise(ActiveRecord::RecordNotFound) {
      Customer.find(david.id, :conditions => { 'customers.name' => david.name + "1", :address => david.address })
    }
  end

  def test_find_on_association_proxy_conditions
    assert_equal [1, 2, 3, 5, 6, 7, 8, 9, 10], Comment.find_all_by_post_id(authors(:david).posts).map(&:id).sort
  end

  def test_find_on_hash_conditions_with_range
    assert_equal [1,2], Topic.find(:all, :conditions => { :id => 1..2 }).map(&:id).sort
    assert_raise(ActiveRecord::RecordNotFound) { Topic.find(1, :conditions => { :id => 2..3 }) }
  end

  def test_find_on_hash_conditions_with_end_exclusive_range
    assert_equal [1,2,3], Topic.find(:all, :conditions => { :id => 1..3 }).map(&:id).sort
    assert_equal [1,2], Topic.find(:all, :conditions => { :id => 1...3 }).map(&:id).sort
    assert_raise(ActiveRecord::RecordNotFound) { Topic.find(3, :conditions => { :id => 2...3 }) }
  end

  def test_find_on_hash_conditions_with_multiple_ranges
    assert_equal [1,2,3], Comment.find(:all, :conditions => { :id => 1..3, :post_id => 1..2 }).map(&:id).sort
    assert_equal [1], Comment.find(:all, :conditions => { :id => 1..1, :post_id => 1..10 }).map(&:id).sort
  end

  def test_find_on_multiple_hash_conditions
    assert Topic.find(1, :conditions => { :author_name => "David", :title => "The First Topic", :replies_count => 1, :approved => false })
    assert_raise(ActiveRecord::RecordNotFound) { Topic.find(1, :conditions => { :author_name => "David", :title => "The First Topic", :replies_count => 1, :approved => true }) }
    assert_raise(ActiveRecord::RecordNotFound) { Topic.find(1, :conditions => { :author_name => "David", :title => "HHC", :replies_count => 1, :approved => false }) }
    assert_raise(ActiveRecord::RecordNotFound) { Topic.find(1, :conditions => { :author_name => "David", :title => "The First Topic", :replies_count => 1, :approved => true }) }
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
    assert_raise(ActiveRecord::StatementInvalid) {
      Company.find(:first, :conditions => { :id => 2, :dhh => true })
    }
  end

  def test_hash_condition_find_with_improper_nested_hashes
    assert_raise(ActiveRecord::StatementInvalid) {
      Company.find(:first, :conditions => { :name => { :companies => { :id  => 1 }}})
    }
  end

  def test_hash_condition_find_with_dot_in_nested_column_name
    assert_raise(ActiveRecord::StatementInvalid) {
      Company.find(:first, :conditions => { :name => { "companies.id" => 1 }})
    }
  end

  def test_hash_condition_find_with_dot_in_column_name_okay
    assert Company.find(:first, :conditions => { "companies.id" => 1 })
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

  def test_hash_condition_find_with_aggregate_having_one_mapping
    balance = customers(:david).balance
    assert_kind_of Money, balance
    found_customer = Customer.find(:first, :conditions => {:balance => balance})
    assert_equal customers(:david), found_customer
  end

  def test_hash_condition_find_with_aggregate_attribute_having_same_name_as_field_and_key_value_being_aggregate
    gps_location = customers(:david).gps_location
    assert_kind_of GpsLocation, gps_location
    found_customer = Customer.find(:first, :conditions => {:gps_location => gps_location})
    assert_equal customers(:david), found_customer
  end

  def test_hash_condition_find_with_aggregate_having_one_mapping_and_key_value_being_attribute_value
    balance = customers(:david).balance
    assert_kind_of Money, balance
    found_customer = Customer.find(:first, :conditions => {:balance => balance.amount})
    assert_equal customers(:david), found_customer
  end

  def test_hash_condition_find_with_aggregate_attribute_having_same_name_as_field_and_key_value_being_attribute_value
    gps_location = customers(:david).gps_location
    assert_kind_of GpsLocation, gps_location
    found_customer = Customer.find(:first, :conditions => {:gps_location => gps_location.gps_location})
    assert_equal customers(:david), found_customer
  end

  def test_hash_condition_find_with_aggregate_having_three_mappings
    address = customers(:david).address
    assert_kind_of Address, address
    found_customer = Customer.find(:first, :conditions => {:address => address})
    assert_equal customers(:david), found_customer
  end

  def test_hash_condition_find_with_one_condition_being_aggregate_and_another_not
    address = customers(:david).address
    assert_kind_of Address, address
    found_customer = Customer.find(:first, :conditions => {:address => address, :name => customers(:david).name})
    assert_equal customers(:david), found_customer
  end

  def test_bind_variables
    assert_kind_of Firm, Company.find(:first, :conditions => ["name = ?", "37signals"])
    assert_nil Company.find(:first, :conditions => ["name = ?", "37signals!"])
    assert_nil Company.find(:first, :conditions => ["name = ?", "37signals!' OR 1=1"])
    assert_kind_of Time, Topic.find(:first, :conditions => ["id = ?", 1]).written_on
    assert_raise(ActiveRecord::PreparedStatementInvalid) {
      Company.find(:first, :conditions => ["id=? AND name = ?", 2])
    }
    assert_raise(ActiveRecord::PreparedStatementInvalid) {
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
    assert_raise(ActiveRecord::PreparedStatementInvalid) { bind '', 1 }

    assert_raise(ActiveRecord::PreparedStatementInvalid) { bind '?' }
    assert_nothing_raised                                 { bind '?', 1 }
    assert_raise(ActiveRecord::PreparedStatementInvalid) { bind '?', 1, 1  }
  end

  def test_named_bind_variables
    assert_equal '1', bind(':a', :a => 1) # ' ruby-mode
    assert_equal '1 1', bind(':a :a', :a => 1)  # ' ruby-mode

    assert_nothing_raised { bind("'+00:00'", :foo => "bar") }

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

  def test_bind_chars
    quoted_bambi = ActiveRecord::Base.connection.quote("Bambi")
    quoted_bambi_and_thumper = ActiveRecord::Base.connection.quote("Bambi\nand\nThumper")
    assert_equal "name=#{quoted_bambi}", bind('name=?', "Bambi")
    assert_equal "name=#{quoted_bambi_and_thumper}", bind('name=?', "Bambi\nand\nThumper")
    assert_equal "name=#{quoted_bambi}", bind('name=?', "Bambi".mb_chars)
    assert_equal "name=#{quoted_bambi_and_thumper}", bind('name=?', "Bambi\nand\nThumper".mb_chars)
  end

  def test_bind_record
    o = Struct.new(:quoted_id).new(1)
    assert_equal '1', bind('?', o)

    os = [o] * 3
    assert_equal '1,1,1', bind('?', os)
  end

  def test_named_bind_with_postgresql_type_casts
    l = Proc.new { bind(":a::integer '2009-01-01'::date", :a => '10') }
    assert_nothing_raised(&l)
    assert_equal "#{ActiveRecord::Base.quote_value('10')}::integer '2009-01-01'::date", l.call
  end

  def test_string_sanitation
    assert_not_equal "'something ' 1=1'", ActiveRecord::Base.sanitize("something ' 1=1")
    assert_equal "'something; select table'", ActiveRecord::Base.sanitize("something; select table")
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

  def test_dynamic_finders_should_go_through_the_find_class_method
    Topic.expects(:find).with(:first, :conditions => { :title => 'The First Topic!' })
    Topic.find_by_title("The First Topic!")

    Topic.expects(:find).with(:last, :conditions => { :title => 'The Last Topic!' })
    Topic.find_last_by_title("The Last Topic!")

    Topic.expects(:find).with(:all, :conditions => { :title => 'A Topic.' })
    Topic.find_all_by_title("A Topic.")

    Topic.expects(:find).with(:first, :conditions => { :title => 'Does not exist yet for sure!' }).times(2)
    Topic.find_or_initialize_by_title('Does not exist yet for sure!')
    Topic.find_or_create_by_title('Does not exist yet for sure!')
  end

  def test_find_by_one_attribute
    assert_equal topics(:first), Topic.find_by_title("The First Topic")
    assert_nil Topic.find_by_title("The First Topic!")
  end

  def test_find_by_one_attribute_bang
    assert_equal topics(:first), Topic.find_by_title!("The First Topic")
    assert_raise(ActiveRecord::RecordNotFound) { Topic.find_by_title!("The First Topic!") }
  end

  def test_find_by_one_attribute_caches_dynamic_finder
    # ensure this test can run independently of order
    class << Topic; self; end.send(:remove_method, :find_by_title) if Topic.public_methods.any? { |m| m.to_s == 'find_by_title' }
    assert !Topic.public_methods.any? { |m| m.to_s == 'find_by_title' }
    t = Topic.find_by_title("The First Topic")
    assert Topic.public_methods.any? { |m| m.to_s == 'find_by_title' }
  end

  def test_dynamic_finder_returns_same_results_after_caching
    # ensure this test can run independently of order
    class << Topic; self; end.send(:remove_method, :find_by_title) if Topic.public_method_defined?(:find_by_title)
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

  def test_find_by_one_attribute_that_is_an_aggregate
    address = customers(:david).address
    assert_kind_of Address, address
    found_customer = Customer.find_by_address(address)
    assert_equal customers(:david), found_customer
  end

  def test_find_by_one_attribute_that_is_an_aggregate_with_one_attribute_difference
    address = customers(:david).address
    assert_kind_of Address, address
    missing_address = Address.new(address.street, address.city, address.country + "1")
    assert_nil Customer.find_by_address(missing_address)
    missing_address = Address.new(address.street, address.city + "1", address.country)
    assert_nil Customer.find_by_address(missing_address)
    missing_address = Address.new(address.street + "1", address.city, address.country)
    assert_nil Customer.find_by_address(missing_address)
  end

  def test_find_by_two_attributes_that_are_both_aggregates
    balance = customers(:david).balance
    address = customers(:david).address
    assert_kind_of Money, balance
    assert_kind_of Address, address
    found_customer = Customer.find_by_balance_and_address(balance, address)
    assert_equal customers(:david), found_customer
  end

  def test_find_by_two_attributes_with_one_being_an_aggregate
    balance = customers(:david).balance
    assert_kind_of Money, balance
    found_customer = Customer.find_by_balance_and_name(balance, customers(:david).name)
    assert_equal customers(:david), found_customer
  end

  def test_dynamic_finder_on_one_attribute_with_conditions_caches_method
    # ensure this test can run independently of order
    class << Account; self; end.send(:remove_method, :find_by_credit_limit) if Account.public_methods.any? { |m| m.to_s == 'find_by_credit_limit' }
    assert !Account.public_methods.any? { |m| m.to_s == 'find_by_credit_limit' }
    a = Account.find_by_credit_limit(50, :conditions => ['firm_id = ?', 6])
    assert Account.public_methods.any? { |m| m.to_s == 'find_by_credit_limit' }
  end

  def test_dynamic_finder_on_one_attribute_with_conditions_returns_same_results_after_caching
    # ensure this test can run independently of order
    class << Account; self; end.send(:remove_method, :find_by_credit_limit) if Account.public_methods.any? { |m| m.to_s == 'find_by_credit_limit' }
    a = Account.find_by_credit_limit(50, :conditions => ['firm_id = ?', 6])
    assert_equal a, Account.find_by_credit_limit(50, :conditions => ['firm_id = ?', 6]) # find_by_credit_limit has been cached
  end

  def test_find_by_one_attribute_with_several_options
    assert_equal accounts(:unknown), Account.find_by_credit_limit(50, :order => 'id DESC', :conditions => ['id != ?', 3])
  end

  def test_find_by_one_missing_attribute
    assert_raise(NoMethodError) { Topic.find_by_undertitle("The First Topic!") }
  end

  def test_find_by_invalid_method_syntax
    assert_raise(NoMethodError) { Topic.fail_to_find_by_title("The First Topic") }
    assert_raise(NoMethodError) { Topic.find_by_title?("The First Topic") }
    assert_raise(NoMethodError) { Topic.fail_to_find_or_create_by_title("Nonexistent Title") }
    assert_raise(NoMethodError) { Topic.find_or_create_by_title?("Nonexistent Title") }
  end

  def test_find_by_two_attributes
    assert_equal topics(:first), Topic.find_by_title_and_author_name("The First Topic", "David")
    assert_nil Topic.find_by_title_and_author_name("The First Topic", "Mary")
  end

  def test_find_last_by_one_attribute
    assert_equal Topic.last, Topic.find_last_by_title(Topic.last.title)
    assert_nil Topic.find_last_by_title("A title with no matches")
  end

  def test_find_last_by_one_attribute_caches_dynamic_finder
    # ensure this test can run independently of order
    class << Topic; self; end.send(:remove_method, :find_last_by_title) if Topic.public_methods.any? { |m| m.to_s == 'find_last_by_title' }
    assert !Topic.public_methods.any? { |m| m.to_s == 'find_last_by_title' }
    t = Topic.find_last_by_title(Topic.last.title)
    assert Topic.public_methods.any? { |m| m.to_s == 'find_last_by_title' }
  end

  def test_find_last_by_invalid_method_syntax
    assert_raise(NoMethodError) { Topic.fail_to_find_last_by_title("The First Topic") }
    assert_raise(NoMethodError) { Topic.find_last_by_title?("The First Topic") }
  end

  def test_find_last_by_one_attribute_with_several_options
    assert_equal accounts(:signals37), Account.find_last_by_credit_limit(50, :order => 'id DESC', :conditions => ['id != ?', 3])
  end

  def test_find_last_by_one_missing_attribute
    assert_raise(NoMethodError) { Topic.find_last_by_undertitle("The Last Topic!") }
  end

  def test_find_last_by_two_attributes
    topic = Topic.last
    assert_equal topic, Topic.find_last_by_title_and_author_name(topic.title, topic.author_name)
    assert_nil Topic.find_last_by_title_and_author_name(topic.title, "Anonymous")
  end

  def test_find_all_by_one_attribute
    topics = Topic.find_all_by_content("Have a nice day")
    assert_equal 2, topics.size
    assert topics.include?(topics(:first))

    assert_equal [], Topic.find_all_by_title("The First Topic!!")
  end

  def test_find_all_by_one_attribute_that_is_an_aggregate
    balance = customers(:david).balance
    assert_kind_of Money, balance
    found_customers = Customer.find_all_by_balance(balance)
    assert_equal 1, found_customers.size
    assert_equal customers(:david), found_customers.first
  end

  def test_find_all_by_two_attributes_that_are_both_aggregates
    balance = customers(:david).balance
    address = customers(:david).address
    assert_kind_of Money, balance
    assert_kind_of Address, address
    found_customers = Customer.find_all_by_balance_and_address(balance, address)
    assert_equal 1, found_customers.size
    assert_equal customers(:david), found_customers.first
  end

  def test_find_all_by_two_attributes_with_one_being_an_aggregate
    balance = customers(:david).balance
    assert_kind_of Money, balance
    found_customers = Customer.find_all_by_balance_and_name(balance, customers(:david).name)
    assert_equal 1, found_customers.size
    assert_equal customers(:david), found_customers.first
  end

  def test_find_all_by_one_attribute_with_options
    topics = Topic.find_all_by_content("Have a nice day", :order => "id DESC")
    assert topics(:first), topics.last

    topics = Topic.find_all_by_content("Have a nice day", :order => "id")
    assert topics(:first), topics.first
  end

  def test_find_all_by_array_attribute
    assert_equal 2, Topic.find_all_by_title(["The First Topic", "The Second Topic of the day"]).size
  end

  def test_find_all_by_boolean_attribute
    topics = Topic.find_all_by_approved(false)
    assert_equal 1, topics.size
    assert topics.include?(topics(:first))

    topics = Topic.find_all_by_approved(true)
    assert_equal 3, topics.size
    assert topics.include?(topics(:second))
  end

  def test_find_by_nil_attribute
    topic = Topic.find_by_last_read nil
    assert_not_nil topic
    assert_nil topic.last_read
  end

  def test_find_all_by_nil_attribute
    topics = Topic.find_all_by_last_read nil
    assert_equal 3, topics.size
    assert topics.collect(&:last_read).all?(&:nil?)
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

  def test_find_or_create_from_two_attributes_with_one_being_an_aggregate
    number_of_customers = Customer.count
    created_customer = Customer.find_or_create_by_balance_and_name(Money.new(123), "Elizabeth")
    assert_equal number_of_customers + 1, Customer.count
    assert_equal created_customer, Customer.find_or_create_by_balance(Money.new(123), "Elizabeth")
    assert !created_customer.new_record?
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

  def test_find_or_create_from_one_aggregate_attribute
    number_of_customers = Customer.count
    created_customer = Customer.find_or_create_by_balance(Money.new(123))
    assert_equal number_of_customers + 1, Customer.count
    assert_equal created_customer, Customer.find_or_create_by_balance(Money.new(123))
    assert !created_customer.new_record?
  end

  def test_find_or_create_from_one_aggregate_attribute_and_hash
    number_of_customers = Customer.count
    balance = Money.new(123)
    name = "Elizabeth"
    created_customer = Customer.find_or_create_by_balance({:balance => balance, :name => name})
    assert_equal number_of_customers + 1, Customer.count
    assert_equal created_customer, Customer.find_or_create_by_balance({:balance => balance, :name => name})
    assert !created_customer.new_record?
    assert_equal balance, created_customer.balance
    assert_equal name, created_customer.name
  end

  def test_find_or_initialize_from_one_attribute
    sig38 = Company.find_or_initialize_by_name("38signals")
    assert_equal "38signals", sig38.name
    assert sig38.new_record?
  end

  def test_find_or_initialize_from_one_aggregate_attribute
    new_customer = Customer.find_or_initialize_by_balance(Money.new(123))
    assert_equal 123, new_customer.balance.amount
    assert new_customer.new_record?
  end

  def test_find_or_initialize_from_one_attribute_should_not_set_attribute_even_when_protected
    c = Company.find_or_initialize_by_name({:name => "Fortune 1000", :rating => 1000})
    assert_equal "Fortune 1000", c.name
    assert_not_equal 1000, c.rating
    assert c.valid?
    assert c.new_record?
  end

  def test_find_or_create_from_one_attribute_should_not_set_attribute_even_when_protected
    c = Company.find_or_create_by_name({:name => "Fortune 1000", :rating => 1000})
    assert_equal "Fortune 1000", c.name
    assert_not_equal 1000, c.rating
    assert c.valid?
    assert !c.new_record?
  end

  def test_find_or_initialize_from_one_attribute_should_set_attribute_even_when_protected_and_also_set_the_hash
    c = Company.find_or_initialize_by_rating(1000, {:name => "Fortune 1000"})
    assert_equal "Fortune 1000", c.name
    assert_equal 1000, c.rating
    assert c.valid?
    assert c.new_record?
  end

  def test_find_or_create_from_one_attribute_should_set_attribute_even_when_protected_and_also_set_the_hash
    c = Company.find_or_create_by_rating(1000, {:name => "Fortune 1000"})
    assert_equal "Fortune 1000", c.name
    assert_equal 1000, c.rating
    assert c.valid?
    assert !c.new_record?
  end

  def test_find_or_initialize_from_one_attribute_should_set_attribute_even_when_protected
    c = Company.find_or_initialize_by_name_and_rating("Fortune 1000", 1000)
    assert_equal "Fortune 1000", c.name
    assert_equal 1000, c.rating
    assert c.valid?
    assert c.new_record?
  end

  def test_find_or_create_from_one_attribute_should_set_attribute_even_when_protected
    c = Company.find_or_create_by_name_and_rating("Fortune 1000", 1000)
    assert_equal "Fortune 1000", c.name
    assert_equal 1000, c.rating
    assert c.valid?
    assert !c.new_record?
  end

  def test_find_or_initialize_should_set_protected_attributes_if_given_as_block
    c = Company.find_or_initialize_by_name(:name => "Fortune 1000") { |f| f.rating = 1000 }
    assert_equal "Fortune 1000", c.name
    assert_equal 1000.to_f, c.rating.to_f
    assert c.valid?
    assert c.new_record?
  end

  def test_find_or_create_should_set_protected_attributes_if_given_as_block
    c = Company.find_or_create_by_name(:name => "Fortune 1000") { |f| f.rating = 1000 }
    assert_equal "Fortune 1000", c.name
    assert_equal 1000.to_f, c.rating.to_f
    assert c.valid?
    assert !c.new_record?
  end

  def test_find_or_create_should_work_with_block_on_first_call
	  class << Company
		undef_method(:find_or_create_by_name) if method_defined?(:find_or_create_by_name)
	  end
    c = Company.find_or_create_by_name(:name => "Fortune 1000") { |f| f.rating = 1000 }
    assert_equal "Fortune 1000", c.name
    assert_equal 1000.to_f, c.rating.to_f
    assert c.valid?
    assert !c.new_record?
  end

  def test_dynamic_find_or_initialize_from_one_attribute_caches_method
    class << Company; self; end.send(:remove_method, :find_or_initialize_by_name) if Company.public_methods.any? { |m| m.to_s == 'find_or_initialize_by_name' }
    assert !Company.public_methods.any? { |m| m.to_s == 'find_or_initialize_by_name' }
    sig38 = Company.find_or_initialize_by_name("38signals")
    assert Company.public_methods.any? { |m| m.to_s == 'find_or_initialize_by_name' }
  end

  def test_find_or_initialize_from_two_attributes
    another = Topic.find_or_initialize_by_title_and_author_name("Another topic","John")
    assert_equal "Another topic", another.title
    assert_equal "John", another.author_name
    assert another.new_record?
  end

  def test_find_or_initialize_from_one_aggregate_attribute_and_one_not
    new_customer = Customer.find_or_initialize_by_balance_and_name(Money.new(123), "Elizabeth")
    assert_equal 123, new_customer.balance.amount
    assert_equal "Elizabeth", new_customer.name
    assert new_customer.new_record?
  end

  def test_find_or_initialize_from_one_attribute_and_hash
    sig38 = Company.find_or_initialize_by_name({:name => "38signals", :firm_id => 17, :client_of => 23})
    assert_equal "38signals", sig38.name
    assert_equal 17, sig38.firm_id
    assert_equal 23, sig38.client_of
    assert sig38.new_record?
  end

  def test_find_or_initialize_from_one_aggregate_attribute_and_hash
    balance = Money.new(123)
    name = "Elizabeth"
    new_customer = Customer.find_or_initialize_by_balance({:balance => balance, :name => name})
    assert_equal balance, new_customer.balance
    assert_equal name, new_customer.name
    assert new_customer.new_record?
  end

  def test_find_with_bad_sql
    assert_raise(ActiveRecord::StatementInvalid) { Topic.find_by_sql "select 1 from badtable" }
  end

  def test_find_with_invalid_params
    assert_raise(ArgumentError) { Topic.find :first, :join => "It should be `joins'" }
    assert_raise(ArgumentError) { Topic.find :first, :conditions => '1 = 1', :join => "It should be `joins'" }
  end

  def test_dynamic_finder_with_invalid_params
    assert_raise(ArgumentError) { Topic.find_by_title 'No Title', :join => "It should be `joins'" }
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

  def test_joins_with_string_array
    person_with_reader_and_post = Post.find(
      :all,
      :joins => [
        "INNER JOIN categorizations ON categorizations.post_id = posts.id",
        "INNER JOIN categories ON categories.id = categorizations.category_id AND categories.type = 'SpecialCategory'"
      ]
    )
    assert_equal 1, person_with_reader_and_post.size
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
      Company.connection.select_rows("SELECT id, firm_id, client_of, name FROM companies WHERE id IN (1,2,3) ORDER BY id").map! {|i| i.map! {|j| j.to_s unless j.nil?}})
    assert_equal [["1", "37signals"], ["2", "Summit"], ["3", "Microsoft"]],
      Company.connection.select_rows("SELECT id, name FROM companies WHERE id IN (1,2,3) ORDER BY id").map! {|i| i.map! {|j| j.to_s unless j.nil?}}
  end

  def test_find_with_order_on_included_associations_with_construct_finder_sql_for_association_limiting_and_is_distinct
    assert_equal 2, Post.find(:all, :include => { :authors => :author_address }, :order => ' author_addresses.id DESC ', :limit => 2).size

    assert_equal 3, Post.find(:all, :include => { :author => :author_address, :authors => :author_address},
                              :order => ' author_addresses_authors.id DESC ', :limit => 3).size
  end

  def test_with_limiting_with_custom_select
    posts = Post.find(:all, :include => :author, :select => ' posts.*, authors.id as "author_id"', :limit => 3, :order => 'posts.id')
    assert_equal 3, posts.size
    assert_equal [0, 1, 1], posts.map(&:author_id).sort
  end

  def test_finder_with_scoped_from
    all_topics = Topic.all

    Topic.with_scope(:find => { :from => 'fake_topics' }) do
      assert_equal all_topics, Topic.all(:from => 'topics')
    end
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
