require 'abstract_unit'
require 'fixtures/developer'
require 'fixtures/project'
require 'fixtures/company'
require 'fixtures/topic'
require 'fixtures/reply'
require 'fixtures/computer'
require 'fixtures/customer'
require 'fixtures/order'
require 'fixtures/categorization'
require 'fixtures/category'
require 'fixtures/post'
require 'fixtures/author'
require 'fixtures/comment'
require 'fixtures/tag'
require 'fixtures/tagging'

class AssociationsTest < Test::Unit::TestCase
  fixtures :accounts, :companies, :developers, :projects, :developers_projects,
           :computers

  def test_bad_collection_keys
    assert_raise(ArgumentError, 'ActiveRecord should have barked on bad collection keys') do
      Class.new(ActiveRecord::Base).has_many(:wheels, :name => 'wheels')
    end
  end

  def test_force_reload
    firm = Firm.new("name" => "A New Firm, Inc")
    firm.save
    firm.clients.each {|c|} # forcing to load all clients
    assert firm.clients.empty?, "New firm shouldn't have client objects"
    assert_equal 0, firm.clients.size, "New firm should have 0 clients"

    client = Client.new("name" => "TheClient.com", "firm_id" => firm.id)
    client.save

    assert firm.clients.empty?, "New firm should have cached no client objects"
    assert_equal 0, firm.clients.size, "New firm should have cached 0 clients count"

    assert !firm.clients(true).empty?, "New firm should have reloaded client objects"
    assert_equal 1, firm.clients(true).size, "New firm should have reloaded clients count"
  end

  def test_storing_in_pstore
    require "tmpdir"
    store_filename = File.join(Dir.tmpdir, "ar-pstore-association-test")
    File.delete(store_filename) if File.exists?(store_filename)
    require "pstore"
    apple = Firm.create("name" => "Apple")
    natural = Client.new("name" => "Natural Company")
    apple.clients << natural

    db = PStore.new(store_filename)
    db.transaction do
      db["apple"] = apple
    end

    db = PStore.new(store_filename)
    db.transaction do
      assert_equal "Natural Company", db["apple"].clients.first.name
    end
  end
end

class AssociationProxyTest < Test::Unit::TestCase
  fixtures :authors, :posts, :categorizations, :categories, :developers, :projects, :developers_projects

  def test_proxy_accessors
    welcome = posts(:welcome)
    assert_equal  welcome, welcome.author.proxy_owner
    assert_equal  welcome.class.reflect_on_association(:author), welcome.author.proxy_reflection
    welcome.author.class  # force load target
    assert_equal  welcome.author, welcome.author.proxy_target

    david = authors(:david)
    assert_equal  david, david.posts.proxy_owner
    assert_equal  david.class.reflect_on_association(:posts), david.posts.proxy_reflection
    david.posts.first   # force load target
    assert_equal  david.posts, david.posts.proxy_target

    assert_equal  david, david.posts_with_extension.testing_proxy_owner
    assert_equal  david.class.reflect_on_association(:posts_with_extension), david.posts_with_extension.testing_proxy_reflection
    david.posts_with_extension.first   # force load target
    assert_equal  david.posts_with_extension, david.posts_with_extension.testing_proxy_target
  end

  def test_push_does_not_load_target
    david = authors(:david)

    david.categories << categories(:technology)
    assert !david.categories.loaded?
    assert david.categories.include?(categories(:technology))
  end

  def test_save_on_parent_does_not_load_target
    david = developers(:david)

    assert !david.projects.loaded?
    david.update_attribute(:created_at, Time.now)
    assert !david.projects.loaded?
  end

end

class HasOneAssociationsTest < Test::Unit::TestCase
  fixtures :accounts, :companies, :developers, :projects, :developers_projects

  def setup
    Account.destroyed_account_ids.clear
  end

  def test_has_one
    assert_equal companies(:first_firm).account, Account.find(1)
    assert_equal Account.find(1).credit_limit, companies(:first_firm).account.credit_limit
  end

  def test_has_one_cache_nils
    firm = companies(:another_firm)
    assert_queries(1) { assert_nil firm.account }
    assert_queries(0) { assert_nil firm.account }

    firms = Firm.find(:all, :include => :account)
    assert_queries(0) { firms.each(&:account) }
  end

  def test_can_marshal_has_one_association_with_nil_target
    firm = Firm.new
    assert_nothing_raised do
      assert_equal firm.attributes, Marshal.load(Marshal.dump(firm)).attributes
    end

    firm.account
    assert_nothing_raised do
      assert_equal firm.attributes, Marshal.load(Marshal.dump(firm)).attributes
    end
  end

  def test_proxy_assignment
    company = companies(:first_firm)
    assert_nothing_raised { company.account = company.account }
  end

  def test_triple_equality
    assert Account === companies(:first_firm).account
    assert companies(:first_firm).account === Account
  end

  def test_type_mismatch
    assert_raises(ActiveRecord::AssociationTypeMismatch) { companies(:first_firm).account = 1 }
    assert_raises(ActiveRecord::AssociationTypeMismatch) { companies(:first_firm).account = Project.find(1) }
  end

  def test_natural_assignment
    apple = Firm.create("name" => "Apple")
    citibank = Account.create("credit_limit" => 10)
    apple.account = citibank
    assert_equal apple.id, citibank.firm_id
  end

  def test_natural_assignment_to_nil
    old_account_id = companies(:first_firm).account.id
    companies(:first_firm).account = nil
    companies(:first_firm).save
    assert_nil companies(:first_firm).account
    # account is dependent, therefore is destroyed when reference to owner is lost
    assert_raises(ActiveRecord::RecordNotFound) { Account.find(old_account_id) }
  end

  def test_assignment_without_replacement
    apple = Firm.create("name" => "Apple")
    citibank = Account.create("credit_limit" => 10)
    apple.account = citibank
    assert_equal apple.id, citibank.firm_id

    hsbc = apple.build_account({ :credit_limit => 20}, false)
    assert_equal apple.id, hsbc.firm_id
    hsbc.save
    assert_equal apple.id, citibank.firm_id

    nykredit = apple.create_account({ :credit_limit => 30}, false)
    assert_equal apple.id, nykredit.firm_id
    assert_equal apple.id, citibank.firm_id
    assert_equal apple.id, hsbc.firm_id
  end

  def test_assignment_without_replacement_on_create
    apple = Firm.create("name" => "Apple")
    citibank = Account.create("credit_limit" => 10)
    apple.account = citibank
    assert_equal apple.id, citibank.firm_id

    hsbc = apple.create_account({:credit_limit => 10}, false)
    assert_equal apple.id, hsbc.firm_id
    hsbc.save
    assert_equal apple.id, citibank.firm_id
  end

  def test_dependence
    num_accounts = Account.count

    firm = Firm.find(1)
    assert !firm.account.nil?
    account_id = firm.account.id
    assert_equal [], Account.destroyed_account_ids[firm.id]

    firm.destroy
    assert_equal num_accounts - 1, Account.count
    assert_equal [account_id], Account.destroyed_account_ids[firm.id]
  end

  def test_exclusive_dependence
    num_accounts = Account.count

    firm = ExclusivelyDependentFirm.find(9)
    assert !firm.account.nil?
    account_id = firm.account.id
    assert_equal [], Account.destroyed_account_ids[firm.id]

    firm.destroy
    assert_equal num_accounts - 1, Account.count
    assert_equal [], Account.destroyed_account_ids[firm.id]
  end

  def test_dependence_with_nil_associate
    firm = DependentFirm.new(:name => 'nullify')
    firm.save!
    assert_nothing_raised { firm.destroy }
  end

  def test_succesful_build_association
    firm = Firm.new("name" => "GlobalMegaCorp")
    firm.save

    account = firm.build_account("credit_limit" => 1000)
    assert account.save
    assert_equal account, firm.account
  end

  def test_failing_build_association
    firm = Firm.new("name" => "GlobalMegaCorp")
    firm.save

    account = firm.build_account
    assert !account.save
    assert_equal "can't be empty", account.errors.on("credit_limit")
  end

  def test_build_association_twice_without_saving_affects_nothing
    count_of_account = Account.count
    firm = Firm.find(:first)
    account1 = firm.build_account("credit_limit" => 1000)
    account2 = firm.build_account("credit_limit" => 2000)

    assert_equal count_of_account, Account.count
  end

  def test_create_association
    firm = Firm.create(:name => "GlobalMegaCorp")
    account = firm.create_account(:credit_limit => 1000)
    assert_equal account, firm.reload.account
  end

  def test_build
    firm = Firm.new("name" => "GlobalMegaCorp")
    firm.save

    firm.account = account = Account.new("credit_limit" => 1000)
    assert_equal account, firm.account
    assert account.save
    assert_equal account, firm.account
  end

  def test_build_before_child_saved
    firm = Firm.find(1)

    account = firm.account.build("credit_limit" => 1000)
    assert_equal account, firm.account
    assert account.new_record?
    assert firm.save
    assert_equal account, firm.account
    assert !account.new_record?
  end

  def test_build_before_either_saved
    firm = Firm.new("name" => "GlobalMegaCorp")

    firm.account = account = Account.new("credit_limit" => 1000)
    assert_equal account, firm.account
    assert account.new_record?
    assert firm.save
    assert_equal account, firm.account
    assert !account.new_record?
  end

  def test_failing_build_association
    firm = Firm.new("name" => "GlobalMegaCorp")
    firm.save

    firm.account = account = Account.new
    assert_equal account, firm.account
    assert !account.save
    assert_equal account, firm.account
    assert_equal "can't be empty", account.errors.on("credit_limit")
  end

  def test_create
    firm = Firm.new("name" => "GlobalMegaCorp")
    firm.save
    firm.account = account = Account.create("credit_limit" => 1000)
    assert_equal account, firm.account
  end

  def test_create_before_save
    firm = Firm.new("name" => "GlobalMegaCorp")
    firm.account = account = Account.create("credit_limit" => 1000)
    assert_equal account, firm.account
  end

  def test_dependence_with_missing_association
    Account.destroy_all
    firm = Firm.find(1)
    assert firm.account.nil?
    firm.destroy
  end

  def test_dependence_with_missing_association_and_nullify
    Account.destroy_all
    firm = DependentFirm.find(:first)
    assert firm.account.nil?
    firm.destroy
  end

  def test_assignment_before_parent_saved
    firm = Firm.new("name" => "GlobalMegaCorp")
    firm.account = a = Account.find(1)
    assert firm.new_record?
    assert_equal a, firm.account
    assert firm.save
    assert_equal a, firm.account
    assert_equal a, firm.account(true)
  end

  def test_finding_with_interpolated_condition
    firm = Firm.find(:first)
    superior = firm.clients.create(:name => 'SuperiorCo')
    superior.rating = 10
    superior.save
    assert_equal 10, firm.clients_with_interpolated_conditions.first.rating
  end

  def test_assignment_before_child_saved
    firm = Firm.find(1)
    firm.account = a = Account.new("credit_limit" => 1000)
    assert !a.new_record?
    assert_equal a, firm.account
    assert_equal a, firm.account
    assert_equal a, firm.account(true)
  end

  def test_assignment_before_either_saved
    firm = Firm.new("name" => "GlobalMegaCorp")
    firm.account = a = Account.new("credit_limit" => 1000)
    assert firm.new_record?
    assert a.new_record?
    assert_equal a, firm.account
    assert firm.save
    assert !firm.new_record?
    assert !a.new_record?
    assert_equal a, firm.account
    assert_equal a, firm.account(true)
  end

  def test_not_resaved_when_unchanged
    firm = Firm.find(:first, :include => :account)
    assert_queries(1) { firm.save! }

    firm = Firm.find(:first)
    firm.account = Account.find(:first)
    assert_queries(1) { firm.save! }

    firm = Firm.find(:first).clone
    firm.account = Account.find(:first)
    assert_queries(2) { firm.save! }

    firm = Firm.find(:first).clone
    firm.account = Account.find(:first).clone
    assert_queries(2) { firm.save! }
  end

  def test_save_still_works_after_accessing_nil_has_one
    jp = Company.new :name => 'Jaded Pixel'
    jp.dummy_account.nil?

    assert_nothing_raised do
      jp.save!
    end
  end

end


class HasManyAssociationsTest < Test::Unit::TestCase
  fixtures :accounts, :companies, :developers, :projects,
           :developers_projects, :topics, :authors, :comments

  def setup
    Client.destroyed_client_ids.clear
  end

  def force_signal37_to_load_all_clients_of_firm
    companies(:first_firm).clients_of_firm.each {|f| }
  end

  def test_counting_with_counter_sql
    assert_equal 2, Firm.find(:first).clients.count
  end

  def test_counting
    assert_equal 2, Firm.find(:first).plain_clients.count
  end

  def test_counting_with_single_conditions
    assert_equal 2, Firm.find(:first).plain_clients.count(:conditions => '1=1')
  end

  def test_counting_with_single_hash
    assert_equal 2, Firm.find(:first).plain_clients.count(:conditions => '1=1')
  end

  def test_counting_with_column_name_and_hash
    assert_equal 2, Firm.find(:first).plain_clients.count(:all, :conditions => '1=1')
  end

  def test_finding
    assert_equal 2, Firm.find(:first).clients.length
  end

  def test_find_many_with_merged_options
    assert_equal 1, companies(:first_firm).limited_clients.size
    assert_equal 1, companies(:first_firm).limited_clients.find(:all).size
    assert_equal 2, companies(:first_firm).limited_clients.find(:all, :limit => nil).size
  end

  def test_triple_equality
    assert !(Array === Firm.find(:first).clients)
    assert Firm.find(:first).clients === Array
  end

  def test_finding_default_orders
    assert_equal "Summit", Firm.find(:first).clients.first.name
  end

  def test_finding_with_different_class_name_and_order
    assert_equal "Microsoft", Firm.find(:first).clients_sorted_desc.first.name
  end

  def test_finding_with_foreign_key
    assert_equal "Microsoft", Firm.find(:first).clients_of_firm.first.name
  end

  def test_finding_with_condition
    assert_equal "Microsoft", Firm.find(:first).clients_like_ms.first.name
  end

  def test_finding_with_condition_hash
    assert_equal "Microsoft", Firm.find(:first).clients_like_ms_with_hash_conditions.first.name
  end

  def test_finding_using_sql
    firm = Firm.find(:first)
    first_client = firm.clients_using_sql.first
    assert_not_nil first_client
    assert_equal "Microsoft", first_client.name
    assert_equal 1, firm.clients_using_sql.size
    assert_equal 1, Firm.find(:first).clients_using_sql.size
  end

  def test_counting_using_sql
    assert_equal 1, Firm.find(:first).clients_using_counter_sql.size
    assert Firm.find(:first).clients_using_counter_sql.any?
    assert_equal 0, Firm.find(:first).clients_using_zero_counter_sql.size
    assert !Firm.find(:first).clients_using_zero_counter_sql.any?
  end

  def test_counting_non_existant_items_using_sql
    assert_equal 0, Firm.find(:first).no_clients_using_counter_sql.size
  end

  def test_belongs_to_sanity
    c = Client.new
    assert_nil c.firm

    if c.firm
      assert false, "belongs_to failed if check"
    end

    unless c.firm
    else
      assert false,  "belongs_to failed unless check"
    end
  end

  def test_find_ids
    firm = Firm.find(:first)

    assert_raises(ActiveRecord::RecordNotFound) { firm.clients.find }

    client = firm.clients.find(2)
    assert_kind_of Client, client

    client_ary = firm.clients.find([2])
    assert_kind_of Array, client_ary
    assert_equal client, client_ary.first

    client_ary = firm.clients.find(2, 3)
    assert_kind_of Array, client_ary
    assert_equal 2, client_ary.size
    assert_equal client, client_ary.first

    assert_raises(ActiveRecord::RecordNotFound) { firm.clients.find(2, 99) }
  end

  def test_find_all
    firm = Firm.find(:first)
    assert_equal 2, firm.clients.find(:all, :conditions => "#{QUOTED_TYPE} = 'Client'").length
    assert_equal 1, firm.clients.find(:all, :conditions => "name = 'Summit'").length
  end

  def test_find_all_sanitized
    firm = Firm.find(:first)
    summit = firm.clients.find(:all, :conditions => "name = 'Summit'")
    assert_equal summit, firm.clients.find(:all, :conditions => ["name = ?", "Summit"])
    assert_equal summit, firm.clients.find(:all, :conditions => ["name = :name", { :name => "Summit" }])
  end

  def test_find_first
    firm = Firm.find(:first)
    client2 = Client.find(2)
    assert_equal firm.clients.first, firm.clients.find(:first)
    assert_equal client2, firm.clients.find(:first, :conditions => "#{QUOTED_TYPE} = 'Client'")
  end

  def test_find_first_sanitized
    firm = Firm.find(:first)
    client2 = Client.find(2)
    assert_equal client2, firm.clients.find(:first, :conditions => ["#{QUOTED_TYPE} = ?", 'Client'])
    assert_equal client2, firm.clients.find(:first, :conditions => ["#{QUOTED_TYPE} = :type", { :type => 'Client' }])
  end

  def test_find_in_collection
    assert_equal Client.find(2).name, companies(:first_firm).clients.find(2).name
    assert_raises(ActiveRecord::RecordNotFound) { companies(:first_firm).clients.find(6) }
  end

  def test_find_grouped
    all_clients_of_firm1 = Client.find(:all, :conditions => "firm_id = 1")
    grouped_clients_of_firm1 = Client.find(:all, :conditions => "firm_id = 1", :group => "firm_id", :select => 'firm_id, count(id) as clients_count')
    assert_equal 2, all_clients_of_firm1.size
    assert_equal 1, grouped_clients_of_firm1.size
  end

  def test_adding
    force_signal37_to_load_all_clients_of_firm
    natural = Client.new("name" => "Natural Company")
    companies(:first_firm).clients_of_firm << natural
    assert_equal 2, companies(:first_firm).clients_of_firm.size # checking via the collection
    assert_equal 2, companies(:first_firm).clients_of_firm(true).size # checking using the db
    assert_equal natural, companies(:first_firm).clients_of_firm.last
  end

  def test_adding_using_create
    first_firm = companies(:first_firm)
    assert_equal 2, first_firm.plain_clients.size
    natural = first_firm.plain_clients.create(:name => "Natural Company")
    assert_equal 3, first_firm.plain_clients.length
    assert_equal 3, first_firm.plain_clients.size
  end
  
  def test_create_with_bang_on_has_many_when_parent_is_new_raises
    assert_raises(ActiveRecord::RecordNotSaved) do 
      firm = Firm.new
      firm.plain_clients.create! :name=>"Whoever"
    end
  end

  def test_regular_create_on_has_many_when_parent_is_new_raises
    assert_raises(ActiveRecord::RecordNotSaved) do 
      firm = Firm.new
      firm.plain_clients.create :name=>"Whoever"
    end
  end
  
  def test_create_with_bang_on_habtm_when_parent_is_new_raises
    assert_raises(ActiveRecord::RecordNotSaved) do 
      Developer.new("name" => "Aredridel").projects.create!    
    end
  end

  def test_adding_a_mismatch_class
    assert_raises(ActiveRecord::AssociationTypeMismatch) { companies(:first_firm).clients_of_firm << nil }
    assert_raises(ActiveRecord::AssociationTypeMismatch) { companies(:first_firm).clients_of_firm << 1 }
    assert_raises(ActiveRecord::AssociationTypeMismatch) { companies(:first_firm).clients_of_firm << Topic.find(1) }
  end

  def test_adding_a_collection
    force_signal37_to_load_all_clients_of_firm
    companies(:first_firm).clients_of_firm.concat([Client.new("name" => "Natural Company"), Client.new("name" => "Apple")])
    assert_equal 3, companies(:first_firm).clients_of_firm.size
    assert_equal 3, companies(:first_firm).clients_of_firm(true).size
  end

  def test_adding_before_save
    no_of_firms = Firm.count
    no_of_clients = Client.count

    new_firm = Firm.new("name" => "A New Firm, Inc")
    c = Client.new("name" => "Apple")

    new_firm.clients_of_firm.push Client.new("name" => "Natural Company")
    assert_equal 1, new_firm.clients_of_firm.size
    new_firm.clients_of_firm << c
    assert_equal 2, new_firm.clients_of_firm.size

    assert_equal no_of_firms, Firm.count      # Firm was not saved to database.
    assert_equal no_of_clients, Client.count  # Clients were not saved to database.
    assert new_firm.save
    assert !new_firm.new_record?
    assert !c.new_record?
    assert_equal new_firm, c.firm
    assert_equal no_of_firms+1, Firm.count      # Firm was saved to database.
    assert_equal no_of_clients+2, Client.count  # Clients were saved to database.

    assert_equal 2, new_firm.clients_of_firm.size
    assert_equal 2, new_firm.clients_of_firm(true).size
  end

  def test_invalid_adding
    firm = Firm.find(1)
    assert !(firm.clients_of_firm << c = Client.new)
    assert c.new_record?
    assert !firm.valid?
    assert !firm.save
    assert c.new_record?
  end

  def test_invalid_adding_before_save
    no_of_firms = Firm.count
    no_of_clients = Client.count
    new_firm = Firm.new("name" => "A New Firm, Inc")
    new_firm.clients_of_firm.concat([c = Client.new, Client.new("name" => "Apple")])
    assert c.new_record?
    assert !c.valid?
    assert !new_firm.valid?
    assert !new_firm.save
    assert c.new_record?
    assert new_firm.new_record?
  end

  def test_build
    new_client = companies(:first_firm).clients_of_firm.build("name" => "Another Client")
    assert_equal "Another Client", new_client.name
    assert new_client.new_record?
    assert_equal new_client, companies(:first_firm).clients_of_firm.last
    assert companies(:first_firm).save
    assert !new_client.new_record?
    assert_equal 2, companies(:first_firm).clients_of_firm(true).size
  end

  def test_build_many
    new_clients = companies(:first_firm).clients_of_firm.build([{"name" => "Another Client"}, {"name" => "Another Client II"}])
    assert_equal 2, new_clients.size

    assert companies(:first_firm).save
    assert_equal 3, companies(:first_firm).clients_of_firm(true).size
  end

  def test_build_without_loading_association
    first_topic = topics(:first)
    Reply.column_names

    assert_equal 1, first_topic.replies.length

    assert_no_queries do
      first_topic.replies.build(:title => "Not saved", :content => "Superstars")
      assert_equal 2, first_topic.replies.size
    end

    assert_equal 2, first_topic.replies.to_ary.size
  end

  def test_create_without_loading_association
    first_firm  = companies(:first_firm)
    Firm.column_names
    Client.column_names

    assert_equal 1, first_firm.clients_of_firm.size
    first_firm.clients_of_firm.reset

    assert_queries(1) do
      first_firm.clients_of_firm.create(:name => "Superstars")
    end

    assert_equal 2, first_firm.clients_of_firm.size
  end

  def test_invalid_build
    new_client = companies(:first_firm).clients_of_firm.build
    assert new_client.new_record?
    assert !new_client.valid?
    assert_equal new_client, companies(:first_firm).clients_of_firm.last
    assert !companies(:first_firm).save
    assert new_client.new_record?
    assert_equal 1, companies(:first_firm).clients_of_firm(true).size
  end

  def test_create
    force_signal37_to_load_all_clients_of_firm
    new_client = companies(:first_firm).clients_of_firm.create("name" => "Another Client")
    assert !new_client.new_record?
    assert_equal new_client, companies(:first_firm).clients_of_firm.last
    assert_equal new_client, companies(:first_firm).clients_of_firm(true).last
  end

  def test_create_many
    companies(:first_firm).clients_of_firm.create([{"name" => "Another Client"}, {"name" => "Another Client II"}])
    assert_equal 3, companies(:first_firm).clients_of_firm(true).size
  end

  def test_find_or_initialize
    the_client = companies(:first_firm).clients.find_or_initialize_by_name("Yet another client")
    assert_equal companies(:first_firm).id, the_client.firm_id
    assert_equal "Yet another client", the_client.name
    assert the_client.new_record?
  end

  def test_find_or_create
    number_of_clients = companies(:first_firm).clients.size
    the_client = companies(:first_firm).clients.find_or_create_by_name("Yet another client")
    assert_equal number_of_clients + 1, companies(:first_firm, :reload).clients.size
    assert_equal the_client, companies(:first_firm).clients.find_or_create_by_name("Yet another client")
    assert_equal number_of_clients + 1, companies(:first_firm, :reload).clients.size
  end

  def test_deleting
    force_signal37_to_load_all_clients_of_firm
    companies(:first_firm).clients_of_firm.delete(companies(:first_firm).clients_of_firm.first)
    assert_equal 0, companies(:first_firm).clients_of_firm.size
    assert_equal 0, companies(:first_firm).clients_of_firm(true).size
  end

  def test_deleting_before_save
    new_firm = Firm.new("name" => "A New Firm, Inc.")
    new_client = new_firm.clients_of_firm.build("name" => "Another Client")
    assert_equal 1, new_firm.clients_of_firm.size
    new_firm.clients_of_firm.delete(new_client)
    assert_equal 0, new_firm.clients_of_firm.size
  end

  def test_deleting_a_collection
    force_signal37_to_load_all_clients_of_firm
    companies(:first_firm).clients_of_firm.create("name" => "Another Client")
    assert_equal 2, companies(:first_firm).clients_of_firm.size
    companies(:first_firm).clients_of_firm.delete([companies(:first_firm).clients_of_firm[0], companies(:first_firm).clients_of_firm[1]])
    assert_equal 0, companies(:first_firm).clients_of_firm.size
    assert_equal 0, companies(:first_firm).clients_of_firm(true).size
  end

  def test_delete_all
    force_signal37_to_load_all_clients_of_firm
    companies(:first_firm).clients_of_firm.create("name" => "Another Client")
    assert_equal 2, companies(:first_firm).clients_of_firm.size
    companies(:first_firm).clients_of_firm.delete_all
    assert_equal 0, companies(:first_firm).clients_of_firm.size
    assert_equal 0, companies(:first_firm).clients_of_firm(true).size
  end

  def test_delete_all_with_not_yet_loaded_association_collection
    force_signal37_to_load_all_clients_of_firm
    companies(:first_firm).clients_of_firm.create("name" => "Another Client")
    assert_equal 2, companies(:first_firm).clients_of_firm.size
    companies(:first_firm).clients_of_firm.reset
    companies(:first_firm).clients_of_firm.delete_all
    assert_equal 0, companies(:first_firm).clients_of_firm.size
    assert_equal 0, companies(:first_firm).clients_of_firm(true).size
  end

  def test_clearing_an_association_collection
    firm = companies(:first_firm)
    client_id = firm.clients_of_firm.first.id
    assert_equal 1, firm.clients_of_firm.size

    firm.clients_of_firm.clear

    assert_equal 0, firm.clients_of_firm.size
    assert_equal 0, firm.clients_of_firm(true).size
    assert_equal [], Client.destroyed_client_ids[firm.id]

    # Should not be destroyed since the association is not dependent.
    assert_nothing_raised do
      assert Client.find(client_id).firm.nil?
    end
  end

  def test_clearing_a_dependent_association_collection
    firm = companies(:first_firm)
    client_id = firm.dependent_clients_of_firm.first.id
    assert_equal 1, firm.dependent_clients_of_firm.size

    # :dependent means destroy is called on each client
    firm.dependent_clients_of_firm.clear

    assert_equal 0, firm.dependent_clients_of_firm.size
    assert_equal 0, firm.dependent_clients_of_firm(true).size
    assert_equal [client_id], Client.destroyed_client_ids[firm.id]

    # Should be destroyed since the association is dependent.
    assert Client.find_by_id(client_id).nil?
  end

  def test_clearing_an_exclusively_dependent_association_collection
    firm = companies(:first_firm)
    client_id = firm.exclusively_dependent_clients_of_firm.first.id
    assert_equal 1, firm.exclusively_dependent_clients_of_firm.size

    assert_equal [], Client.destroyed_client_ids[firm.id]

    # :exclusively_dependent means each client is deleted directly from
    # the database without looping through them calling destroy.
    firm.exclusively_dependent_clients_of_firm.clear

    assert_equal 0, firm.exclusively_dependent_clients_of_firm.size
    assert_equal 0, firm.exclusively_dependent_clients_of_firm(true).size
    assert_equal [3], Client.destroyed_client_ids[firm.id]

    # Should be destroyed since the association is exclusively dependent.
    assert Client.find_by_id(client_id).nil?
  end

  def test_dependent_association_respects_optional_conditions_on_delete
    firm = companies(:odegy)
    Client.create(:client_of => firm.id, :name => "BigShot Inc.")
    Client.create(:client_of => firm.id, :name => "SmallTime Inc.")
    # only one of two clients is included in the association due to the :conditions key
    assert_equal 2, Client.find_all_by_client_of(firm.id).size
    assert_equal 1, firm.dependent_conditional_clients_of_firm.size
    firm.destroy
    # only the correctly associated client should have been deleted
    assert_equal 1, Client.find_all_by_client_of(firm.id).size
  end

  def test_dependent_association_respects_optional_sanitized_conditions_on_delete
    firm = companies(:odegy)
    Client.create(:client_of => firm.id, :name => "BigShot Inc.")
    Client.create(:client_of => firm.id, :name => "SmallTime Inc.")
    # only one of two clients is included in the association due to the :conditions key
    assert_equal 2, Client.find_all_by_client_of(firm.id).size
    assert_equal 1, firm.dependent_sanitized_conditional_clients_of_firm.size
    firm.destroy
    # only the correctly associated client should have been deleted
    assert_equal 1, Client.find_all_by_client_of(firm.id).size
  end

  def test_clearing_without_initial_access
    firm = companies(:first_firm)

    firm.clients_of_firm.clear

    assert_equal 0, firm.clients_of_firm.size
    assert_equal 0, firm.clients_of_firm(true).size
  end

  def test_deleting_a_item_which_is_not_in_the_collection
    force_signal37_to_load_all_clients_of_firm
    summit = Client.find_by_name('Summit')
    companies(:first_firm).clients_of_firm.delete(summit)
    assert_equal 1, companies(:first_firm).clients_of_firm.size
    assert_equal 1, companies(:first_firm).clients_of_firm(true).size
    assert_equal 2, summit.client_of
  end

  def test_deleting_type_mismatch
    david = Developer.find(1)
    david.projects.reload
    assert_raises(ActiveRecord::AssociationTypeMismatch) { david.projects.delete(1) }
  end

  def test_deleting_self_type_mismatch
    david = Developer.find(1)
    david.projects.reload
    assert_raises(ActiveRecord::AssociationTypeMismatch) { david.projects.delete(Project.find(1).developers) }
  end

  def test_destroy_all
    force_signal37_to_load_all_clients_of_firm
    assert !companies(:first_firm).clients_of_firm.empty?, "37signals has clients after load"
    companies(:first_firm).clients_of_firm.destroy_all
    assert companies(:first_firm).clients_of_firm.empty?, "37signals has no clients after destroy all"
    assert companies(:first_firm).clients_of_firm(true).empty?, "37signals has no clients after destroy all and refresh"
  end

  def test_dependence
    firm = companies(:first_firm)
    assert_equal 2, firm.clients.size
    firm.destroy
    assert Client.find(:all, :conditions => "firm_id=#{firm.id}").empty?
  end

  def test_destroy_dependent_when_deleted_from_association
    firm = Firm.find(:first)
    assert_equal 2, firm.clients.size

    client = firm.clients.first
    firm.clients.delete(client)

    assert_raise(ActiveRecord::RecordNotFound) { Client.find(client.id) }
    assert_raise(ActiveRecord::RecordNotFound) { firm.clients.find(client.id) }
    assert_equal 1, firm.clients.size
  end

  def test_three_levels_of_dependence
    topic = Topic.create "title" => "neat and simple"
    reply = topic.replies.create "title" => "neat and simple", "content" => "still digging it"
    silly_reply = reply.replies.create "title" => "neat and simple", "content" => "ain't complaining"

    assert_nothing_raised { topic.destroy }
  end

  uses_transaction :test_dependence_with_transaction_support_on_failure
  def test_dependence_with_transaction_support_on_failure
    firm = companies(:first_firm)
    clients = firm.clients
    assert_equal 2, clients.length
    clients.last.instance_eval { def before_destroy() raise "Trigger rollback" end }

    firm.destroy rescue "do nothing"

    assert_equal 2, Client.find(:all, :conditions => "firm_id=#{firm.id}").size
  end

  def test_dependence_on_account
    num_accounts = Account.count
    companies(:first_firm).destroy
    assert_equal num_accounts - 1, Account.count
  end

  def test_depends_and_nullify
    num_accounts = Account.count
    num_companies = Company.count

    core = companies(:rails_core)
    assert_equal accounts(:rails_core_account), core.account
    assert_equal companies(:leetsoft, :jadedpixel), core.companies
    core.destroy
    assert_nil accounts(:rails_core_account).reload.firm_id
    assert_nil companies(:leetsoft).reload.client_of
    assert_nil companies(:jadedpixel).reload.client_of


    assert_equal num_accounts, Account.count
  end

  def test_included_in_collection
    assert companies(:first_firm).clients.include?(Client.find(2))
  end

  def test_adding_array_and_collection
    assert_nothing_raised { Firm.find(:first).clients + Firm.find(:all).last.clients }
  end

  def test_find_all_without_conditions
    firm = companies(:first_firm)
    assert_equal 2, firm.clients.find(:all).length
  end

  def test_replace_with_less
    firm = Firm.find(:first)
    firm.clients = [companies(:first_client)]
    assert firm.save, "Could not save firm"
    firm.reload
    assert_equal 1, firm.clients.length
  end

  def test_replace_with_less_and_dependent_nullify
    num_companies = Company.count
    companies(:rails_core).companies = []
    assert_equal num_companies, Company.count
  end

  def test_replace_with_new
    firm = Firm.find(:first)
    firm.clients = [companies(:second_client), Client.new("name" => "New Client")]
    firm.save
    firm.reload
    assert_equal 2, firm.clients.length
    assert !firm.clients.include?(:first_client)
  end

  def test_replace_on_new_object
    firm = Firm.new("name" => "New Firm")
    firm.clients = [companies(:second_client), Client.new("name" => "New Client")]
    assert firm.save
    firm.reload
    assert_equal 2, firm.clients.length
    assert firm.clients.include?(Client.find_by_name("New Client"))
  end

  def test_get_ids
    assert_equal [companies(:first_client).id, companies(:second_client).id], companies(:first_firm).client_ids
  end

  def test_assign_ids
    firm = Firm.new("name" => "Apple")
    firm.client_ids = [companies(:first_client).id, companies(:second_client).id]
    firm.save
    firm.reload
    assert_equal 2, firm.clients.length
    assert firm.clients.include?(companies(:second_client))
  end

  def test_assign_ids_ignoring_blanks
    firm = Firm.create!(:name => 'Apple')
    firm.client_ids = [companies(:first_client).id, nil, companies(:second_client).id, '']
    firm.save!

    assert_equal 2, firm.clients(true).size
    assert firm.clients.include?(companies(:second_client))
  end

  def test_get_ids_for_through
    assert_equal [comments(:eager_other_comment1).id], authors(:mary).comment_ids
  end

  def test_assign_ids_for_through
    assert_raise(NoMethodError) { authors(:mary).comment_ids = [123] }
  end
end

class BelongsToAssociationsTest < Test::Unit::TestCase
  fixtures :accounts, :companies, :developers, :projects, :topics,
           :developers_projects, :computers, :authors, :posts, :tags, :taggings

  def test_belongs_to
    Client.find(3).firm.name
    assert_equal companies(:first_firm).name, Client.find(3).firm.name
    assert !Client.find(3).firm.nil?, "Microsoft should have a firm"
  end

  def test_proxy_assignment
    account = Account.find(1)
    assert_nothing_raised { account.firm = account.firm }
  end

  def test_triple_equality
    assert Client.find(3).firm === Firm
    assert Firm === Client.find(3).firm
  end

  def test_type_mismatch
    assert_raise(ActiveRecord::AssociationTypeMismatch) { Account.find(1).firm = 1 }
    assert_raise(ActiveRecord::AssociationTypeMismatch) { Account.find(1).firm = Project.find(1) }
  end

  def test_natural_assignment
    apple = Firm.create("name" => "Apple")
    citibank = Account.create("credit_limit" => 10)
    citibank.firm = apple
    assert_equal apple.id, citibank.firm_id
  end

  def test_no_unexpected_aliasing
    first_firm = companies(:first_firm)
    another_firm = companies(:another_firm)

    citibank = Account.create("credit_limit" => 10)
    citibank.firm = first_firm
    original_proxy = citibank.firm
    citibank.firm = another_firm

    assert_equal first_firm.object_id, original_proxy.object_id
    assert_equal another_firm.object_id, citibank.firm.object_id
  end

  def test_creating_the_belonging_object
    citibank = Account.create("credit_limit" => 10)
    apple    = citibank.create_firm("name" => "Apple")
    assert_equal apple, citibank.firm
    citibank.save
    citibank.reload
    assert_equal apple, citibank.firm
  end

  def test_building_the_belonging_object
    citibank = Account.create("credit_limit" => 10)
    apple    = citibank.build_firm("name" => "Apple")
    citibank.save
    assert_equal apple.id, citibank.firm_id
  end

  def test_natural_assignment_to_nil
    client = Client.find(3)
    client.firm = nil
    client.save
    assert_nil client.firm(true)
    assert_nil client.client_of
  end

  def test_with_different_class_name
    assert_equal Company.find(1).name, Company.find(3).firm_with_other_name.name
    assert_not_nil Company.find(3).firm_with_other_name, "Microsoft should have a firm"
  end

  def test_with_condition
    assert_equal Company.find(1).name, Company.find(3).firm_with_condition.name
    assert_not_nil Company.find(3).firm_with_condition, "Microsoft should have a firm"
  end

  def test_belongs_to_counter
    debate = Topic.create("title" => "debate")
    assert_equal 0, debate.send(:read_attribute, "replies_count"), "No replies yet"

    trash = debate.replies.create("title" => "blah!", "content" => "world around!")
    assert_equal 1, Topic.find(debate.id).send(:read_attribute, "replies_count"), "First reply created"

    trash.destroy
    assert_equal 0, Topic.find(debate.id).send(:read_attribute, "replies_count"), "First reply deleted"
  end

  def test_belongs_to_counter_with_reassigning
    t1 = Topic.create("title" => "t1")
    t2 = Topic.create("title" => "t2")
    r1 = Reply.new("title" => "r1", "content" => "r1")
    r1.topic = t1

    assert r1.save
    assert_equal 1, Topic.find(t1.id).replies.size
    assert_equal 0, Topic.find(t2.id).replies.size

    r1.topic = Topic.find(t2.id)

    assert r1.save
    assert_equal 0, Topic.find(t1.id).replies.size
    assert_equal 1, Topic.find(t2.id).replies.size

    r1.topic = nil

    assert_equal 0, Topic.find(t1.id).replies.size
    assert_equal 0, Topic.find(t2.id).replies.size

    r1.topic = t1

    assert_equal 1, Topic.find(t1.id).replies.size
    assert_equal 0, Topic.find(t2.id).replies.size

    r1.destroy

    assert_equal 0, Topic.find(t1.id).replies.size
    assert_equal 0, Topic.find(t2.id).replies.size
  end

  def test_belongs_to_counter_after_save
    topic = Topic.create!(:title => "monday night")
    topic.replies.create!(:title => "re: monday night", :content => "football")
    assert_equal 1, Topic.find(topic.id)[:replies_count]

    topic.save!
    assert_equal 1, Topic.find(topic.id)[:replies_count]
  end

  def test_belongs_to_counter_after_update_attributes
    topic = Topic.create!(:title => "37s")
    topic.replies.create!(:title => "re: 37s", :content => "rails")
    assert_equal 1, Topic.find(topic.id)[:replies_count]

    topic.update_attributes(:title => "37signals")
    assert_equal 1, Topic.find(topic.id)[:replies_count]
  end
  
  def test_belongs_to_counter_after_save
    topic = Topic.create("title" => "monday night")
    topic.replies.create("title" => "re: monday night", "content" => "football")
    assert_equal 1, Topic.find(topic.id).send(:read_attribute, "replies_count")

    topic.save
    assert_equal 1, Topic.find(topic.id).send(:read_attribute, "replies_count")
  end

  def test_belongs_to_counter_after_update_attributes
    topic = Topic.create("title" => "37s")
    topic.replies.create("title" => "re: 37s", "content" => "rails")
    assert_equal 1, Topic.find(topic.id).send(:read_attribute, "replies_count")

    topic.update_attributes("title" => "37signals")
    assert_equal 1, Topic.find(topic.id).send(:read_attribute, "replies_count")
  end

  def test_assignment_before_parent_saved
    client = Client.find(:first)
    apple = Firm.new("name" => "Apple")
    client.firm = apple
    assert_equal apple, client.firm
    assert apple.new_record?
    assert client.save
    assert apple.save
    assert !apple.new_record?
    assert_equal apple, client.firm
    assert_equal apple, client.firm(true)
  end

  def test_assignment_before_child_saved
    final_cut = Client.new("name" => "Final Cut")
    firm = Firm.find(1)
    final_cut.firm = firm
    assert final_cut.new_record?
    assert final_cut.save
    assert !final_cut.new_record?
    assert !firm.new_record?
    assert_equal firm, final_cut.firm
    assert_equal firm, final_cut.firm(true)
  end

  def test_assignment_before_either_saved
    final_cut = Client.new("name" => "Final Cut")
    apple = Firm.new("name" => "Apple")
    final_cut.firm = apple
    assert final_cut.new_record?
    assert apple.new_record?
    assert final_cut.save
    assert !final_cut.new_record?
    assert !apple.new_record?
    assert_equal apple, final_cut.firm
    assert_equal apple, final_cut.firm(true)
  end

  def test_new_record_with_foreign_key_but_no_object
    c = Client.new("firm_id" => 1)
    assert_equal Firm.find(:first), c.firm_with_basic_id
  end

  def test_forgetting_the_load_when_foreign_key_enters_late
    c = Client.new
    assert_nil c.firm_with_basic_id

    c.firm_id = 1
    assert_equal Firm.find(:first), c.firm_with_basic_id
  end

  def test_field_name_same_as_foreign_key
    computer = Computer.find(1)
    assert_not_nil computer.developer, ":foreign key == attribute didn't lock up" # '
  end

  def test_counter_cache
    topic = Topic.create :title => "Zoom-zoom-zoom"
    assert_equal 0, topic[:replies_count]

    reply = Reply.create(:title => "re: zoom", :content => "speedy quick!")
    reply.topic = topic

    assert_equal 1, topic.reload[:replies_count]
    assert_equal 1, topic.replies.size

    topic[:replies_count] = 15
    assert_equal 15, topic.replies.size
  end

  def test_custom_counter_cache
    reply = Reply.create(:title => "re: zoom", :content => "speedy quick!")
    assert_equal 0, reply[:replies_count]

    silly = SillyReply.create(:title => "gaga", :content => "boo-boo")
    silly.reply = reply

    assert_equal 1, reply.reload[:replies_count]
    assert_equal 1, reply.replies.size

    reply[:replies_count] = 17
    assert_equal 17, reply.replies.size
  end

  def test_store_two_association_with_one_save
    num_orders = Order.count
    num_customers = Customer.count
    order = Order.new

    customer1 = order.billing = Customer.new
    customer2 = order.shipping = Customer.new
    assert order.save
    assert_equal customer1, order.billing
    assert_equal customer2, order.shipping

    order.reload

    assert_equal customer1, order.billing
    assert_equal customer2, order.shipping

    assert_equal num_orders +1, Order.count
    assert_equal num_customers +2, Customer.count
  end


  def test_store_association_in_two_relations_with_one_save
    num_orders = Order.count
    num_customers = Customer.count
    order = Order.new

    customer = order.billing = order.shipping = Customer.new
    assert order.save
    assert_equal customer, order.billing
    assert_equal customer, order.shipping

    order.reload

    assert_equal customer, order.billing
    assert_equal customer, order.shipping

    assert_equal num_orders +1, Order.count
    assert_equal num_customers +1, Customer.count
  end

  def test_store_association_in_two_relations_with_one_save_in_existing_object
    num_orders = Order.count
    num_customers = Customer.count
    order = Order.create

    customer = order.billing = order.shipping = Customer.new
    assert order.save
    assert_equal customer, order.billing
    assert_equal customer, order.shipping

    order.reload

    assert_equal customer, order.billing
    assert_equal customer, order.shipping

    assert_equal num_orders +1, Order.count
    assert_equal num_customers +1, Customer.count
  end

  def test_store_association_in_two_relations_with_one_save_in_existing_object_with_values
    num_orders = Order.count
    num_customers = Customer.count
    order = Order.create

    customer = order.billing = order.shipping = Customer.new
    assert order.save
    assert_equal customer, order.billing
    assert_equal customer, order.shipping

    order.reload

    customer = order.billing = order.shipping = Customer.new

    assert order.save
    order.reload

    assert_equal customer, order.billing
    assert_equal customer, order.shipping

    assert_equal num_orders +1, Order.count
    assert_equal num_customers +2, Customer.count
  end


  def test_association_assignment_sticks
    post = Post.find(:first)

    author1, author2 = Author.find(:all, :limit => 2)
    assert_not_nil author1
    assert_not_nil author2

    # make sure the association is loaded
    post.author

    # set the association by id, directly
    post.author_id = author2.id

    # save and reload
    post.save!
    post.reload

    # the author id of the post should be the id we set
    assert_equal post.author_id, author2.id
  end

end


class ProjectWithAfterCreateHook < ActiveRecord::Base
  set_table_name 'projects'
  has_and_belongs_to_many :developers,
    :class_name => "DeveloperForProjectWithAfterCreateHook",
    :join_table => "developers_projects",
    :foreign_key => "project_id",
    :association_foreign_key => "developer_id"

  after_create :add_david

  def add_david
    david = DeveloperForProjectWithAfterCreateHook.find_by_name('David')
    david.projects << self
  end
end

class DeveloperForProjectWithAfterCreateHook < ActiveRecord::Base
  set_table_name 'developers'
  has_and_belongs_to_many :projects,
    :class_name => "ProjectWithAfterCreateHook",
    :join_table => "developers_projects",
    :association_foreign_key => "project_id",
    :foreign_key => "developer_id"
end


class HasAndBelongsToManyAssociationsTest < Test::Unit::TestCase
  fixtures :accounts, :companies, :categories, :posts, :categories_posts, :developers, :projects, :developers_projects

  def test_has_and_belongs_to_many
    david = Developer.find(1)

    assert !david.projects.empty?
    assert_equal 2, david.projects.size

    active_record = Project.find(1)
    assert !active_record.developers.empty?
    assert_equal 3, active_record.developers.size
    assert active_record.developers.include?(david)
  end

  def test_triple_equality
    assert !(Array === Developer.find(1).projects)
    assert Developer.find(1).projects === Array
  end

  def test_adding_single
    jamis = Developer.find(2)
    jamis.projects.reload # causing the collection to load
    action_controller = Project.find(2)
    assert_equal 1, jamis.projects.size
    assert_equal 1, action_controller.developers.size

    jamis.projects << action_controller

    assert_equal 2, jamis.projects.size
    assert_equal 2, jamis.projects(true).size
    assert_equal 2, action_controller.developers(true).size
  end

  def test_adding_type_mismatch
    jamis = Developer.find(2)
    assert_raise(ActiveRecord::AssociationTypeMismatch) { jamis.projects << nil }
    assert_raise(ActiveRecord::AssociationTypeMismatch) { jamis.projects << 1 }
  end

  def test_adding_from_the_project
    jamis = Developer.find(2)
    action_controller = Project.find(2)
    action_controller.developers.reload
    assert_equal 1, jamis.projects.size
    assert_equal 1, action_controller.developers.size

    action_controller.developers << jamis

    assert_equal 2, jamis.projects(true).size
    assert_equal 2, action_controller.developers.size
    assert_equal 2, action_controller.developers(true).size
  end

  def test_adding_from_the_project_fixed_timestamp
    jamis = Developer.find(2)
    action_controller = Project.find(2)
    action_controller.developers.reload
    assert_equal 1, jamis.projects.size
    assert_equal 1, action_controller.developers.size
    updated_at = jamis.updated_at

    action_controller.developers << jamis

    assert_equal updated_at, jamis.updated_at
    assert_equal 2, jamis.projects(true).size
    assert_equal 2, action_controller.developers.size
    assert_equal 2, action_controller.developers(true).size
  end

  def test_adding_multiple
    aredridel = Developer.new("name" => "Aredridel")
    aredridel.save
    aredridel.projects.reload
    aredridel.projects.push(Project.find(1), Project.find(2))
    assert_equal 2, aredridel.projects.size
    assert_equal 2, aredridel.projects(true).size
  end

  def test_adding_a_collection
    aredridel = Developer.new("name" => "Aredridel")
    aredridel.save
    aredridel.projects.reload
    aredridel.projects.concat([Project.find(1), Project.find(2)])
    assert_equal 2, aredridel.projects.size
    assert_equal 2, aredridel.projects(true).size
  end

  def test_adding_uses_default_values_on_join_table
    ac = projects(:action_controller)
    assert !developers(:jamis).projects.include?(ac)
    developers(:jamis).projects << ac

    assert developers(:jamis, :reload).projects.include?(ac)
    project = developers(:jamis).projects.detect { |p| p == ac }
    assert_equal 1, project.access_level.to_i
  end

  def test_habtm_attribute_access_and_respond_to
    project = developers(:jamis).projects[0]
    assert project.has_attribute?("name")
    assert project.has_attribute?("joined_on")
    assert project.has_attribute?("access_level")
    assert project.respond_to?("name")
    assert project.respond_to?("name=")
    assert project.respond_to?("name?")
    assert project.respond_to?("joined_on")
    # given that the 'join attribute' won't be persisted, I don't
    # think we should define the mutators
    #assert project.respond_to?("joined_on=")
    assert project.respond_to?("joined_on?")
    assert project.respond_to?("access_level")
    #assert project.respond_to?("access_level=")
    assert project.respond_to?("access_level?")
  end

  def test_habtm_adding_before_save
    no_of_devels = Developer.count
    no_of_projects = Project.count
    aredridel = Developer.new("name" => "Aredridel")
    aredridel.projects.concat([Project.find(1), p = Project.new("name" => "Projekt")])
    assert aredridel.new_record?
    assert p.new_record?
    assert aredridel.save
    assert !aredridel.new_record?
    assert_equal no_of_devels+1, Developer.count
    assert_equal no_of_projects+1, Project.count
    assert_equal 2, aredridel.projects.size
    assert_equal 2, aredridel.projects(true).size
  end

  def test_habtm_saving_multiple_relationships
    new_project = Project.new("name" => "Grimetime")
    amount_of_developers = 4
    developers = (0...amount_of_developers).collect {|i| Developer.create(:name => "JME #{i}") }.reverse

    new_project.developer_ids = [developers[0].id, developers[1].id]
    new_project.developers_with_callback_ids = [developers[2].id, developers[3].id]
    assert new_project.save

    new_project.reload
    assert_equal amount_of_developers, new_project.developers.size
    assert_equal developers, new_project.developers
  end

  def test_habtm_unique_order_preserved
    assert_equal developers(:poor_jamis, :jamis, :david), projects(:active_record).non_unique_developers
    assert_equal developers(:poor_jamis, :jamis, :david), projects(:active_record).developers
  end

  def test_build
    devel = Developer.find(1)
    proj = devel.projects.build("name" => "Projekt")
    assert_equal devel.projects.last, proj
    assert proj.new_record?
    devel.save
    assert !proj.new_record?
    assert_equal devel.projects.last, proj
    assert_equal Developer.find(1).projects.sort_by(&:id).last, proj  # prove join table is updated
  end

  def test_build_by_new_record
    devel = Developer.new(:name => "Marcel", :salary => 75000)
    proj1 = devel.projects.build(:name => "Make bed")
    proj2 = devel.projects.build(:name => "Lie in it")
    assert_equal devel.projects.last, proj2
    assert proj2.new_record?
    devel.save
    assert !devel.new_record?
    assert !proj2.new_record?
    assert_equal devel.projects.last, proj2
    assert_equal Developer.find_by_name("Marcel").projects.last, proj2  # prove join table is updated
  end

  def test_create
    devel = Developer.find(1)
    proj = devel.projects.create("name" => "Projekt")
    assert_equal devel.projects.last, proj
    assert !proj.new_record?
    assert_equal Developer.find(1).projects.sort_by(&:id).last, proj  # prove join table is updated
  end

  def test_create_by_new_record
    devel = Developer.new(:name => "Marcel", :salary => 75000)
    proj1 = devel.projects.build(:name => "Make bed")
    proj2 = devel.projects.build(:name => "Lie in it")
    assert_equal devel.projects.last, proj2
    assert proj2.new_record?
    devel.save
    assert !devel.new_record?
    assert !proj2.new_record?
    assert_equal devel.projects.last, proj2
    assert_equal Developer.find_by_name("Marcel").projects.last, proj2  # prove join table is updated
  end

  def test_uniq_after_the_fact
    developers(:jamis).projects << projects(:active_record)
    developers(:jamis).projects << projects(:active_record)
    assert_equal 3, developers(:jamis).projects.size
    assert_equal 1, developers(:jamis).projects.uniq.size
  end

  def test_uniq_before_the_fact
    projects(:active_record).developers << developers(:jamis)
    projects(:active_record).developers << developers(:david)
    assert_equal 3, projects(:active_record, :reload).developers.size
  end

  def test_deleting
    david = Developer.find(1)
    active_record = Project.find(1)
    david.projects.reload
    assert_equal 2, david.projects.size
    assert_equal 3, active_record.developers.size

    david.projects.delete(active_record)

    assert_equal 1, david.projects.size
    assert_equal 1, david.projects(true).size
    assert_equal 2, active_record.developers(true).size
  end

  def test_deleting_array
    david = Developer.find(1)
    david.projects.reload
    david.projects.delete(Project.find(:all))
    assert_equal 0, david.projects.size
    assert_equal 0, david.projects(true).size
  end

  def test_deleting_with_sql
    david = Developer.find(1)
    active_record = Project.find(1)
    active_record.developers.reload
    assert_equal 3, active_record.developers_by_sql.size

    active_record.developers_by_sql.delete(david)
    assert_equal 2, active_record.developers_by_sql(true).size
  end

  def test_deleting_array_with_sql
    active_record = Project.find(1)
    active_record.developers.reload
    assert_equal 3, active_record.developers_by_sql.size

    active_record.developers_by_sql.delete(Developer.find(:all))
    assert_equal 0, active_record.developers_by_sql(true).size
  end

  def test_deleting_all
    david = Developer.find(1)
    david.projects.reload
    david.projects.clear
    assert_equal 0, david.projects.size
    assert_equal 0, david.projects(true).size
  end

  def test_removing_associations_on_destroy
    david = DeveloperWithBeforeDestroyRaise.find(1)
    assert !david.projects.empty?
    assert_nothing_raised { david.destroy }
    assert david.projects.empty?
    assert DeveloperWithBeforeDestroyRaise.connection.select_all("SELECT * FROM developers_projects WHERE developer_id = 1").empty?
  end

  def test_additional_columns_from_join_table
    assert_date_from_db Date.new(2004, 10, 10), Developer.find(1).projects.first.joined_on.to_date
  end

  def test_destroy_all
    david = Developer.find(1)
    david.projects.reload
    assert !david.projects.empty?
    david.projects.destroy_all
    assert david.projects.empty?
    assert david.projects(true).empty?
  end

  def test_deprecated_push_with_attributes_was_removed
    jamis = developers(:jamis)
    assert_raise(NoMethodError) do
      jamis.projects.push_with_attributes(projects(:action_controller), :joined_on => Date.today)
    end
  end

  def test_associations_with_conditions
    assert_equal 3, projects(:active_record).developers.size
    assert_equal 1, projects(:active_record).developers_named_david.size
    assert_equal 1, projects(:active_record).developers_named_david_with_hash_conditions.size

    assert_equal developers(:david), projects(:active_record).developers_named_david.find(developers(:david).id)
    assert_equal developers(:david), projects(:active_record).developers_named_david_with_hash_conditions.find(developers(:david).id)
    assert_equal developers(:david), projects(:active_record).salaried_developers.find(developers(:david).id)

    projects(:active_record).developers_named_david.clear
    assert_equal 2, projects(:active_record, :reload).developers.size
  end

  def test_find_in_association
    # Using sql
    assert_equal developers(:david), projects(:active_record).developers.find(developers(:david).id), "SQL find"

    # Using ruby
    active_record = projects(:active_record)
    active_record.developers.reload
    assert_equal developers(:david), active_record.developers.find(developers(:david).id), "Ruby find"
  end

  def test_find_in_association_with_custom_finder_sql
    assert_equal developers(:david), projects(:active_record).developers_with_finder_sql.find(developers(:david).id), "SQL find"

    active_record = projects(:active_record)
    active_record.developers_with_finder_sql.reload
    assert_equal developers(:david), active_record.developers_with_finder_sql.find(developers(:david).id), "Ruby find"
  end

  def test_find_in_association_with_custom_finder_sql_and_string_id
    assert_equal developers(:david), projects(:active_record).developers_with_finder_sql.find(developers(:david).id.to_s), "SQL find"
  end

  def test_find_with_merged_options
    assert_equal 1, projects(:active_record).limited_developers.size
    assert_equal 1, projects(:active_record).limited_developers.find(:all).size
    assert_equal 3, projects(:active_record).limited_developers.find(:all, :limit => nil).size
  end

  def test_new_with_values_in_collection
    jamis = DeveloperForProjectWithAfterCreateHook.find_by_name('Jamis')
    david = DeveloperForProjectWithAfterCreateHook.find_by_name('David')
    project = ProjectWithAfterCreateHook.new(:name => "Cooking with Bertie")
    project.developers << jamis
    project.save!
    project.reload

    assert project.developers.include?(jamis)
    assert project.developers.include?(david)
  end

  def test_find_in_association_with_options
    developers = projects(:active_record).developers.find(:all)
    assert_equal 3, developers.size

    assert_equal developers(:poor_jamis), projects(:active_record).developers.find(:first, :conditions => "salary < 10000")
    assert_equal developers(:jamis),      projects(:active_record).developers.find(:first, :order => "salary DESC")
  end

  def test_replace_with_less
    david = developers(:david)
    david.projects = [projects(:action_controller)]
    assert david.save
    assert_equal 1, david.projects.length
  end

  def test_replace_with_new
    david = developers(:david)
    david.projects = [projects(:action_controller), Project.new("name" => "ActionWebSearch")]
    david.save
    assert_equal 2, david.projects.length
    assert !david.projects.include?(projects(:active_record))
  end

  def test_replace_on_new_object
    new_developer = Developer.new("name" => "Matz")
    new_developer.projects = [projects(:action_controller), Project.new("name" => "ActionWebSearch")]
    new_developer.save
    assert_equal 2, new_developer.projects.length
  end

  def test_consider_type
    developer = Developer.find(:first)
    special_project = SpecialProject.create("name" => "Special Project")

    other_project = developer.projects.first
    developer.special_projects << special_project
    developer.reload

    assert developer.projects.include?(special_project)
    assert developer.special_projects.include?(special_project)
    assert !developer.special_projects.include?(other_project)
  end

  def test_update_attributes_after_push_without_duplicate_join_table_rows
    developer = Developer.new("name" => "Kano")
    project = SpecialProject.create("name" => "Special Project")
    assert developer.save
    developer.projects << project
    developer.update_attribute("name", "Bruza")
    assert_equal 1, Developer.connection.select_value(<<-end_sql).to_i
      SELECT count(*) FROM developers_projects
      WHERE project_id = #{project.id}
      AND developer_id = #{developer.id}
    end_sql
  end

  def test_updating_attributes_on_non_rich_associations
    welcome = categories(:technology).posts.first
    welcome.title = "Something else"
    assert welcome.save!
  end

  def test_habtm_respects_select
    categories(:technology).select_testing_posts(true).each do |o|
      assert_respond_to o, :correctness_marker
    end
    assert_respond_to categories(:technology).select_testing_posts.find(:first), :correctness_marker
  end

  def test_updating_attributes_on_rich_associations
    david = projects(:action_controller).developers.first
    david.name = "DHH"
    assert_raises(ActiveRecord::ReadOnlyRecord) { david.save! }
  end


  def test_updating_attributes_on_rich_associations_with_limited_find
    david = projects(:action_controller).developers.find(:all, :select => "developers.*").first
    david.name = "DHH"
    assert david.save!
  end

  def test_join_table_alias
    assert_equal 3, Developer.find(:all, :include => {:projects => :developers}, :conditions => 'developers_projects_join.joined_on IS NOT NULL').size
  end

  def test_join_with_group
    group = Developer.columns.inject([]) do |g, c|
      g << "developers.#{c.name}"
      g << "developers_projects_2.#{c.name}"
    end
    Project.columns.each { |c| group << "projects.#{c.name}" }

    assert_equal 3, Developer.find(:all, :include => {:projects => :developers}, :conditions => 'developers_projects_join.joined_on IS NOT NULL', :group => group.join(",")).size
  end

  def test_get_ids
    assert_equal projects(:active_record, :action_controller).map(&:id), developers(:david).project_ids
    assert_equal [projects(:active_record).id], developers(:jamis).project_ids
  end

  def test_assign_ids
    developer = Developer.new("name" => "Joe")
    developer.project_ids = projects(:active_record, :action_controller).map(&:id)
    developer.save
    developer.reload
    assert_equal 2, developer.projects.length
    assert_equal projects(:active_record), developer.projects[0]
    assert_equal projects(:action_controller), developer.projects[1]
  end

  def test_assign_ids_ignoring_blanks
    developer = Developer.new("name" => "Joe")
    developer.project_ids = [projects(:active_record).id, nil, projects(:action_controller).id, '']
    developer.save
    developer.reload
    assert_equal 2, developer.projects.length
    assert_equal projects(:active_record), developer.projects[0]
    assert_equal projects(:action_controller), developer.projects[1]
  end

  def test_select_limited_ids_list
    # Set timestamps
    Developer.transaction do
      Developer.find(:all, :order => 'id').each_with_index do |record, i|
        record.update_attributes(:created_at => 5.years.ago + (i * 5.minutes))
      end
    end

    join_base = ActiveRecord::Associations::ClassMethods::JoinDependency::JoinBase.new(Project)
    join_dep  = ActiveRecord::Associations::ClassMethods::JoinDependency.new(join_base, :developers, nil)
    projects  = Project.send(:select_limited_ids_list, {:order => 'developers.created_at'}, join_dep)
    assert !projects.include?("'"), projects
    assert_equal %w(1 2), projects.scan(/\d/).sort
  end

  def test_scoped_find_on_through_association_doesnt_return_read_only_records
    tag = Post.find(1).tags.find_by_name("General")

    assert_nothing_raised do
      tag.save!
    end
  end
end
