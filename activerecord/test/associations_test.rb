require 'abstract_unit'
require 'fixtures/developer'
require 'fixtures/project'
# require File.dirname(__FILE__) + '/../dev-utils/eval_debugger'
require 'fixtures/company'
require 'fixtures/topic'
require 'fixtures/reply'

# Can't declare new classes in test case methods, so tests before that
bad_collection_keys = false
begin
  class Car < ActiveRecord::Base; has_many :wheels, :name => "wheels"; end
rescue ActiveRecord::ActiveRecordError
  bad_collection_keys = true
end
raise "ActiveRecord should have barked on bad collection keys" unless bad_collection_keys


class AssociationsTest < Test::Unit::TestCase
  def setup
    create_fixtures "accounts", "companies", "accounts", "developers", "projects", "developers_projects"  
    @signals37 = Firm.find(1)
  end
  
  def test_force_reload
    firm = Firm.new
    firm.save
    firm.clients.each {|c|} # forcing to load all clients
    assert firm.clients.empty?, "New firm shouldn't have client objects"
    assert !firm.has_clients?, "New firm shouldn't have clients"
    assert_equal 0, firm.clients.size, "New firm should have 0 clients"

    client = Client.new("firm_id" => firm.id)
    client.save

    assert firm.clients.empty?, "New firm should have cached no client objects"
    assert !firm.has_clients?, "New firm should have cached a no-clients response"
    assert_equal 0, firm.clients.size, "New firm should have cached 0 clients count"

    assert !firm.clients(true).empty?, "New firm should have reloaded client objects"
    assert_equal 1, firm.clients(true).size, "New firm should have reloaded clients count"
  end

  def test_storing_in_pstore
    store_filename = "/tmp/ar-pstore-association-test"
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

class HasOneAssociationsTest < Test::Unit::TestCase
  def setup
    create_fixtures "accounts", "companies", "accounts", "developers", "projects", "developers_projects"
    @signals37 = Firm.find(1)
  end
  
  def test_has_one
    assert_equal @signals37.account, Account.find(1)
    assert_equal Account.find(1).credit_limit, @signals37.account.credit_limit
    assert @signals37.has_account?, "37signals should have an account"
    assert Account.find(1).firm?(@signals37), "37signals account should be able to backtrack"
    assert Account.find(1).has_firm?, "37signals account should be able to backtrack"

    assert !Account.find(2).has_firm?, "Unknown isn't linked"
    assert !Account.find(2).firm?(@signals37), "Unknown isn't linked"
  end

  def test_type_mismatch
    assert_raises(ActiveRecord::AssociationTypeMismatch) { @signals37.account = 1 }
    assert_raises(ActiveRecord::AssociationTypeMismatch) { @signals37.account = Project.find(1) }
  end

  def test_natural_assignment
    apple = Firm.create("name" => "Apple")
    citibank = Account.create("credit_limit" => 10)
    apple.account = citibank
    assert_equal apple.id, citibank.firm_id
  end
  
  def test_natural_assignment_to_nil
    old_account_id = @signals37.account.id
    @signals37.account = nil
    @signals37.save
    assert_nil @signals37.account
    assert_nil Account.find(old_account_id).firm_id
  end

  def test_build
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

  def test_create
    firm = Firm.new("name" => "GlobalMegaCorp")
    firm.save
    assert_equal firm.create_account("credit_limit" => 1000), firm.account
  end
  
  def test_dependence
    firm = Firm.find(1)
    assert !firm.account.nil?
    firm.destroy
    assert_equal 1, Account.find_all.length
  end

  def test_dependence_with_missing_association
    Account.destroy_all
    firm = Firm.find(1)    
    assert !firm.has_account?
    firm.destroy
  end
end


class HasManyAssociationsTest < Test::Unit::TestCase
  def setup
    create_fixtures "accounts", "companies", "accounts", "developers", "projects", "developers_projects", "topics"
    @signals37 = Firm.find(1)
  end
  
  def force_signal37_to_load_all_clients_of_firm
    @signals37.clients_of_firm.each {|f| }
  end
  
  def test_finding
    assert_equal 2, Firm.find_first.clients.length
  end

  def test_finding_default_orders
    assert_equal "Summit", Firm.find_first.clients.first.name
  end

  def test_finding_with_different_class_name_and_order
    assert_equal "Microsoft", Firm.find_first.clients_sorted_desc.first.name
  end

  def test_finding_with_foreign_key
    assert_equal "Microsoft", Firm.find_first.clients_of_firm.first.name
  end

  def test_finding_with_condition
    assert_equal "Microsoft", Firm.find_first.clients_like_ms.first.name
  end

  def test_finding_using_sql
    firm = Firm.find_first
    firm.clients_using_sql.first
    assert_equal "Microsoft", firm.clients_using_sql.first.name
    assert_equal 1, firm.clients_using_sql.size
    assert_equal 1, Firm.find_first.clients_using_sql.size
  end

  def test_find_all
    assert_equal 2, Firm.find_first.clients.find_all("type = 'Client'").length
    assert_equal 1, Firm.find_first.clients.find_all("name = 'Summit'").length
  end

  def test_find_in_collection
    assert_equal Client.find(2).name, @signals37.clients.find(2).name
    assert_equal Client.find(2).name, @signals37.clients.find {|c| c.name == @signals37.clients.find(2).name }.name
    assert_raises(ActiveRecord::RecordNotFound) { @signals37.clients.find(6) }
  end

  def test_adding
    force_signal37_to_load_all_clients_of_firm
    natural = Client.new("name" => "Natural Company")
    @signals37.clients_of_firm << natural
    assert_equal 2, @signals37.clients_of_firm.size # checking via the collection
    assert_equal 2, @signals37.clients_of_firm(true).size # checking using the db
    assert_equal natural, @signals37.clients_of_firm.last
  end
  
  def test_adding_a_mismatch_class
    assert_raises(ActiveRecord::AssociationTypeMismatch) { @signals37.clients_of_firm << nil }
    assert_raises(ActiveRecord::AssociationTypeMismatch) { @signals37.clients_of_firm << 1 }
    assert_raises(ActiveRecord::AssociationTypeMismatch) { @signals37.clients_of_firm << Topic.find(1) }
  end
  
  def test_adding_a_collection
    force_signal37_to_load_all_clients_of_firm
    @signals37.clients_of_firm.concat(Client.new("name" => "Natural Company"), Client.new("name" => "Apple"))
    assert_equal 3, @signals37.clients_of_firm.size
    assert_equal 3, @signals37.clients_of_firm(true).size
  end

  def test_build
    new_client = @signals37.clients_of_firm.build("name" => "Another Client")
    assert_equal "Another Client", new_client.name
    assert new_client.save
    assert_equal 2, @signals37.clients_of_firm(true).size
  end
  
  def test_create
    force_signal37_to_load_all_clients_of_firm
    new_client = @signals37.clients_of_firm.create("name" => "Another Client")
    assert_equal new_client, @signals37.clients_of_firm.last
    assert_equal new_client, @signals37.clients_of_firm(true).last
  end

  def test_deleting
    force_signal37_to_load_all_clients_of_firm
    @signals37.clients_of_firm.delete(@signals37.clients_of_firm.first)
    assert_equal 0, @signals37.clients_of_firm.size
    assert_equal 0, @signals37.clients_of_firm(true).size
  end

  def test_deleting_a_collection
    force_signal37_to_load_all_clients_of_firm
    @signals37.clients_of_firm.create("name" => "Another Client")
    assert_equal 2, @signals37.clients_of_firm.size
    @signals37.clients_of_firm.delete([@signals37.clients_of_firm[0], @signals37.clients_of_firm[1]])
    assert_equal 0, @signals37.clients_of_firm.size
    assert_equal 0, @signals37.clients_of_firm(true).size
  end

  def test_deleting_a_association_collection
    force_signal37_to_load_all_clients_of_firm
    @signals37.clients_of_firm.create("name" => "Another Client")
    assert_equal 2, @signals37.clients_of_firm.size
    @signals37.clients_of_firm.delete(@signals37.clients_of_firm)
    assert_equal 0, @signals37.clients_of_firm.size
    assert_equal 0, @signals37.clients_of_firm(true).size
  end

  def test_deleting_a_item_which_is_not_in_the_collection
    force_signal37_to_load_all_clients_of_firm
    summit = Client.find_first("name = 'Summit'")
    @signals37.clients_of_firm.delete(summit)
    assert_equal 1, @signals37.clients_of_firm.size
    assert_equal 1, @signals37.clients_of_firm(true).size
    assert_equal 2, summit.client_of
  end

  def test_destroy_all
    force_signal37_to_load_all_clients_of_firm
    assert !@signals37.clients_of_firm.empty?
    @signals37.clients_of_firm.destroy_all
    assert @signals37.clients_of_firm.empty?
    assert @signals37.clients_of_firm(true).empty?
  end

  def test_dependence
    assert_equal 2, Client.find_all.length
    Firm.find_first.destroy
    assert_equal 0, Client.find_all.length
  end

  def test_dependence_with_transaction_support_on_failure
    assert_equal 2, Client.find_all.length
    firm = Firm.find_first
    clients = firm.clients
    clients.last.instance_eval { def before_destroy() raise "Trigger rollback" end }

    firm.destroy rescue "do nothing"

    assert_equal 2, Client.find_all.length
  end

  def test_dependence_on_account
    assert_equal 2, Account.find_all.length
    @signals37.destroy
    assert_equal 1, Account.find_all.length
  end

  def test_included_in_collection
    assert @signals37.clients.include?(Client.find(2))
  end
end

class BelongsToAssociationsTest < Test::Unit::TestCase
  def setup
    create_fixtures "accounts", "companies", "accounts", "developers", "projects", "developers_projects", "topics"
    @signals37 = Firm.find(1)
  end

  def test_belongs_to
    Client.find(3).firm.name
    assert_equal @signals37.name, Client.find(3).firm.name
    assert !Client.find(3).firm.nil?, "Microsoft should have a firm"   
  end

  def test_type_mismatch
    assert_raises(ActiveRecord::AssociationTypeMismatch) { Account.find(1).firm = 1 }
    assert_raises(ActiveRecord::AssociationTypeMismatch) { Account.find(1).firm = Project.find(1) }
  end

  def test_natural_assignment
    apple = Firm.create("name" => "Apple")
    citibank = Account.create("credit_limit" => 10)
    citibank.firm = apple
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
    assert !Company.find(3).firm_with_other_name.empty?, "Microsoft should have a firm"
  end

  def test_with_condition
    assert_equal Company.find(1).name, Company.find(3).firm_with_condition.name
    assert !Company.find(3).firm_with_condition.empty?, "Microsoft should have a firm"
  end
  
  def test_belongs_to_counter
    debate = Topic.create("title" => "debate")
    assert_equal 0, debate.send(:read_attribute, "replies_count"), "No replies yet"

    trash = debate.replies.create("title" => "blah!", "content" => "world around!")
    assert_equal 1, Topic.find(debate.id).send(:read_attribute, "replies_count"), "First reply created"

    trash.destroy
    assert_equal 0, Topic.find(debate.id).send(:read_attribute, "replies_count"), "First reply deleted"
  end

  def xtest_counter_cache
    apple = Firm.create("name" => "Apple")
    final_cut = apple.clients.create("name" => "Final Cut")

    apple.clients.to_s
    assert_equal 1, apple.clients.size, "Created one client"
    
    apple.companies_count = 2
    apple.save

    apple = Firm.find_first("name = 'Apple'")
    assert_equal 2, apple.clients.size, "Should use the new cached number"

    apple.clients.to_s 
    assert_equal 1, apple.clients.size, "Should not use the cached number, but go to the database"
  end
end


class HasAndBelongsToManyAssociationsTest < Test::Unit::TestCase
  def setup
    create_fixtures "accounts"
    create_fixtures "companies"
    create_fixtures "accounts"
    create_fixtures "developers"
    create_fixtures "projects"
    create_fixtures "developers_projects"  
    @signals37 = Firm.find(1)
  end
  
  def test_has_and_belongs_to_many
    david = Developer.find(1)

    assert !david.projects.empty?
    assert_equal 2, david.projects.size

    active_record = Project.find(1)
    assert !active_record.developers.empty?
    assert_equal 2, active_record.developers.size
    assert_equal david.name, active_record.developers.first.name
  end
  
  def test_addings
    jamis = Developer.find(2)
    jamis.projects.id # causing the collection to load 
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
    assert_raises(ActiveRecord::AssociationTypeMismatch) { jamis.projects << nil }
    assert_raises(ActiveRecord::AssociationTypeMismatch) { jamis.projects << 1 }
  end

  def test_adding_from_the_project
    jamis = Developer.find(2)
    action_controller = Project.find(2)
    action_controller.developers.id
    assert_equal 1, jamis.projects.size
    assert_equal 1, action_controller.developers.size

    action_controller.developers << jamis 
    
    assert_equal 2, jamis.projects(true).size
    assert_equal 2, action_controller.developers.size
    assert_equal 2, action_controller.developers(true).size
  end

  def test_adding_a_collection
    aridridel = Developer.new("name" => "Aridridel")
    aridridel.save
    aridridel.projects.id
    aridridel.projects.concat([ Project.find(1), Project.find(2) ])
    assert_equal 2, aridridel.projects.size
    assert_equal 2, aridridel.projects(true).size
  end
  
  def test_deleting
    david = Developer.find(1)
    active_record = Project.find(1)
    david.projects.id
    assert_equal 2, david.projects.size
    assert_equal 2, active_record.developers.size

    david.projects.delete(active_record)
    
    assert_equal 1, david.projects.size
    assert_equal 1, david.projects(true).size
    assert_equal 1, active_record.developers(true).size
  end

  def test_deleting_a_collection
    david = Developer.find(1)
    david.projects.id
    david.projects.delete(Project.find_all)
    assert_equal 0, david.projects.size
    assert_equal 0, david.projects(true).size
  end
  
  def test_deleting_a_association_collection
    david = Developer.find(1)
    david.projects.id
    david.projects.delete(david.projects)
    assert_equal 0, david.projects.size
    assert_equal 0, david.projects(true).size
  end

  def test_removing_associations_on_destroy
    Developer.find(1).destroy
    assert Developer.connection.select_all("SELECT * FROM developers_projects WHERE developer_id = '1'").empty?
  end
  
  def test_destroy_all
    david = Developer.find(1)
    david.projects.id
    assert !david.projects.empty?
    david.projects.destroy_all
    assert david.projects.empty?
    assert david.projects(true).empty?
  end
end