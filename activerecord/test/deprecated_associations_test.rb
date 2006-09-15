require 'abstract_unit'
require 'fixtures/developer'
require 'fixtures/project'
require 'fixtures/company'
require 'fixtures/topic'
require 'fixtures/reply'

# Can't declare new classes in test case methods, so tests before that
bad_collection_keys = false
begin
  class Car < ActiveRecord::Base; has_many :wheels, :name => "wheels"; end
rescue ArgumentError
  bad_collection_keys = true
end
raise "ActiveRecord should have barked on bad collection keys" unless bad_collection_keys


class DeprecatedAssociationWarningsTest < Test::Unit::TestCase
  def test_deprecation_warnings
    assert_deprecated('find_first') { Firm.find_first }
    assert_deprecated('find_all') { Firm.find_all }
    assert_deprecated('has_account?') { Firm.find(:first).has_account? }
    assert_deprecated('has_clients?') { Firm.find(:first).has_clients? }
  end
end

class DeprecatedAssociationsTest < Test::Unit::TestCase
  fixtures :accounts, :companies, :developers, :projects, :topics,
           :developers_projects

  def setup
    @firm = companies(:first_firm)
  end

  def test_has_many_find
    assert_equal 2, @firm.clients.length
  end

  def test_has_many_orders
    assert_equal "Summit", @firm.clients.first.name
  end

  def test_has_many_class_name
    assert_equal "Microsoft", @firm.clients_sorted_desc.first.name
  end

  def test_has_many_foreign_key
    assert_equal "Microsoft", @firm.clients_of_firm.first.name
  end

  def test_has_many_conditions
    assert_equal "Microsoft", @firm.clients_like_ms.first.name
  end

  def test_has_many_sql
    assert_equal "Microsoft", @firm.clients_using_sql.first.name
    assert_equal 1, @firm.clients_using_sql.count
    assert_equal 1, @firm.clients_using_sql.count
  end

  def test_has_many_counter_sql
    assert_equal 1, @firm.clients_using_counter_sql.count
  end

  def test_has_many_queries
    assert !@firm.clients.loaded?
    assert_deprecated 'has_clients?' do
      assert_queries(1) { assert @firm.has_clients? }
    end
    assert !@firm.clients.loaded?
    assert_deprecated 'clients_count' do
      assert_queries(1) { assert_equal 2, @firm.clients_count }
    end
    assert !@firm.clients.loaded?
    assert_queries(1) { @firm.clients.size }
    assert !@firm.clients.loaded?
    assert_queries(0) { @firm.clients }
    assert !@firm.clients.loaded?
    assert_queries(1) { @firm.clients.reload }
    assert @firm.clients.loaded?
    assert_queries(0) { @firm.clients.size }
    assert_queries(1) { @firm.clients.count }
  end

  def test_has_many_dependence
    count = Client.count
    Firm.find(:first).destroy
    assert_equal count - 2, Client.count
  end

  uses_transaction :test_has_many_dependence_with_transaction_support_on_failure
  def test_has_many_dependence_with_transaction_support_on_failure
    count = Client.count

    clients = @firm.clients
    clients.last.instance_eval { def before_destroy() raise "Trigger rollback" end }

    @firm.destroy rescue "do nothing"

    assert_equal count, Client.count
  end

  def test_has_one_dependence
    num_accounts = Account.count
    assert_not_nil @firm.account
    @firm.destroy
    assert_equal num_accounts - 1, Account.count
  end

  def test_has_one_dependence_with_missing_association
    Account.destroy_all
    assert_nil @firm.account
    @firm.destroy
  end

  def test_belongs_to
    client = companies(:second_client)
    assert_deprecated('has_firm?') do
      assert companies(:second_client).has_firm?, "Microsoft should have a firm"
    end
    assert_equal companies(:first_firm), client.firm, "Microsoft should have a firm"
  end

  def test_belongs_to_with_different_class_name
    assert_equal @firm, companies(:second_client).firm_with_other_name
  end

  def test_belongs_to_with_condition
    assert_equal @firm, companies(:second_client).firm_with_condition
  end

  def test_belongs_to_equality
    assert_equal @firm, companies(:second_client).firm, 'Microsoft should have 37signals as firm'
  end

  def test_has_one
    assert_equal accounts(:signals37), @firm.account
    assert_deprecated 'has_account?' do
      assert @firm.has_account?, "37signals should have an account"
    end
    assert_deprecated 'firm?' do
      assert accounts(:signals37).firm?(@firm), "37signals account should be able to backtrack"
    end
    assert_deprecated 'has_firm?' do
      assert accounts(:signals37).has_firm?, "37signals account should be able to backtrack"
    end

    assert_nil accounts(:unknown).firm, "Unknown isn't linked"
  end

  def test_has_many_dependence_on_account
    num_accounts = Account.count
    @firm.destroy
    assert_equal num_accounts - 1, Account.count
  end

  def test_find_in
    assert_deprecated 'find_in_clients' do
      assert_equal companies(:first_client), @firm.find_in_clients(2)
      assert_raises(ActiveRecord::RecordNotFound) { @firm.find_in_clients(6) }
    end
  end

  def test_force_reload
    ActiveSupport::Deprecation.silence do
      firm = Firm.new("name" => "A New Firm, Inc")
      firm.save
      firm.clients.each {|c|} # forcing to load all clients
      assert firm.clients.empty?, "New firm shouldn't have client objects"
      assert !firm.has_clients?, "New firm shouldn't have clients"
      assert_equal 0, firm.clients_count, "New firm should have 0 clients"

      client = Client.new("name" => "TheClient.com", "firm_id" => firm.id)
      client.save

      assert firm.clients.empty?, "New firm should have cached no client objects"
      assert !firm.has_clients?, "New firm should have cached a no-clients response"
      assert_equal 0, firm.clients_count, "New firm should have cached 0 clients count"

      assert !firm.clients(true).empty?, "New firm should have reloaded client objects"
      assert firm.has_clients?(true), "New firm should have reloaded with a have-clients response"
      assert_equal 1, firm.clients_count(true), "New firm should have reloaded clients count"
    end
  end

  def test_included_in_collection
    assert @firm.clients.include?(Client.find(2))
  end

  def test_build_to_collection
    count = @firm.clients_of_firm.count
    new_client = nil
    assert_deprecated 'build_to_clients_of_firm' do
      new_client = @firm.build_to_clients_of_firm("name" => "Another Client")
    end
    assert_equal "Another Client", new_client.name
    assert new_client.save

    assert_equal @firm, new_client.firm
    assert_equal count + 1, @firm.clients_of_firm.count
  end

  def test_create_in_collection
    assert_deprecated 'create_in_clients_of_firm' do
      assert_equal @firm.create_in_clients_of_firm("name" => "Another Client"), @firm.clients_of_firm(true).last
    end
  end

  def test_has_and_belongs_to_many
    david = Developer.find(1)
    assert_deprecated 'has_projects?' do
      assert david.has_projects?
    end
    assert_deprecated 'projects_count' do
      assert_equal 2, david.projects_count
    end

    active_record = Project.find(1)
    assert_deprecated 'has_developers?' do
      assert active_record.has_developers?
    end
    assert_deprecated 'developers_count' do
      assert_equal 3, active_record.developers_count
    end
    assert active_record.developers.include?(david)
  end

  def test_has_and_belongs_to_many_removing
    david = Developer.find(1)
    active_record = Project.find(1)

    assert_deprecated do
      david.remove_projects(active_record)
      assert_equal 1, david.projects_count
      assert_equal 2, active_record.developers_count
    end
  end

  def test_has_and_belongs_to_many_zero
    david = Developer.find(1)
    assert_deprecated do
      david.remove_projects Project.find_all
      assert_equal 0, david.projects_count
      assert !david.has_projects?
    end
  end

  def test_has_and_belongs_to_many_adding
    jamis = Developer.find(2)
    action_controller = Project.find(2)

    assert_deprecated do
      jamis.add_projects(action_controller)
      assert_equal 2, jamis.projects_count
      assert_equal 2, action_controller.developers_count
    end
  end

  def test_has_and_belongs_to_many_adding_from_the_project
    jamis = Developer.find(2)
    action_controller = Project.find(2)

    assert_deprecated do
      action_controller.add_developers(jamis)
      assert_equal 2, jamis.projects_count
      assert_equal 2, action_controller.developers_count
    end
  end

  def test_has_and_belongs_to_many_adding_a_collection
    aredridel = Developer.new("name" => "Aredridel")
    aredridel.save

    assert_deprecated do
      aredridel.add_projects([ Project.find(1), Project.find(2) ])
      assert_equal 2, aredridel.projects_count
    end
  end

  def test_belongs_to_counter
    topic = Topic.create("title" => "Apple", "content" => "hello world")
    assert_equal 0, topic.send(:read_attribute, "replies_count"), "No replies yet"

    reply = assert_deprecated { topic.create_in_replies("title" => "I'm saying no!", "content" => "over here") }
    assert_equal 1, Topic.find(topic.id).send(:read_attribute, "replies_count"), "First reply created"

    reply.destroy
    assert_equal 0, Topic.find(topic.id).send(:read_attribute, "replies_count"), "First reply deleted"
  end

  def test_natural_assignment_of_has_one
    apple = Firm.create("name" => "Apple")
    citibank = Account.create("credit_limit" => 10)
    apple.account = citibank
    assert_equal apple.id, citibank.firm_id
  end

  def test_natural_assignment_of_belongs_to
    apple = Firm.create("name" => "Apple")
    citibank = Account.create("credit_limit" => 10)
    citibank.firm = apple
    assert_equal apple.id, citibank.firm_id
  end

  def test_natural_assignment_of_has_many
    apple = Firm.create("name" => "Apple")
    natural = Client.create("name" => "Natural Company")
    apple.clients << natural
    assert_equal apple.id, natural.firm_id
    assert_equal Client.find(natural.id), Firm.find(apple.id).clients.find(natural.id)
    apple.clients.delete natural
    assert_raises(ActiveRecord::RecordNotFound) {
      Firm.find(apple.id).clients.find(natural.id)
    }
  end

  def test_natural_adding_of_has_and_belongs_to_many
    rails = Project.create("name" => "Rails")
    ap = Project.create("name" => "Action Pack")
    john = Developer.create("name" => "John")
    mike = Developer.create("name" => "Mike")
    rails.developers << john
    rails.developers << mike

    assert_equal Developer.find(john.id), Project.find(rails.id).developers.find(john.id)
    assert_equal Developer.find(mike.id), Project.find(rails.id).developers.find(mike.id)
    assert_equal Project.find(rails.id), Developer.find(mike.id).projects.find(rails.id)
    assert_equal Project.find(rails.id), Developer.find(john.id).projects.find(rails.id)
    ap.developers << john
    assert_equal Developer.find(john.id), Project.find(ap.id).developers.find(john.id)
    assert_equal Project.find(ap.id), Developer.find(john.id).projects.find(ap.id)

    ap.developers.delete john
    assert_raises(ActiveRecord::RecordNotFound) {
      Project.find(ap.id).developers.find(john.id)
    }
    assert_raises(ActiveRecord::RecordNotFound) {
      Developer.find(john.id).projects.find(ap.id)
    }
  end

  def test_storing_in_pstore
    require "pstore"
    require "tmpdir"
    apple = Firm.create("name" => "Apple")
    natural = Client.new("name" => "Natural Company")
    apple.clients << natural

    db = PStore.new(File.join(Dir.tmpdir, "ar-pstore-association-test"))
    db.transaction do
      db["apple"] = apple
    end

    db = PStore.new(File.join(Dir.tmpdir, "ar-pstore-association-test"))
    db.transaction do
      assert_equal "Natural Company", db["apple"].clients.first.name
    end
  end

  def test_has_many_find_all
    assert_deprecated 'find_all_in_clients' do
      assert_equal 2, @firm.find_all_in_clients("#{QUOTED_TYPE} = 'Client'").length
      assert_equal 1, @firm.find_all_in_clients("name = 'Summit'").length
    end
  end

  def test_has_one
    assert_equal Account.find(1), @firm.account, "37signals should have an account"
    assert_equal @firm, Account.find(1).firm, "37signals account should be able to backtrack"
    assert_nil Account.find(2).firm, "Unknown isn't linked"
  end

  def test_has_one_build
    firm = Firm.new("name" => "GlobalMegaCorp")
    assert firm.save

    account = firm.build_account(:credit_limit => 1000)
    assert account.save
    assert_equal account, firm.account
  end

  def test_has_one_failing_build_association
    firm = Firm.new("name" => "GlobalMegaCorp")
    firm.save

    account = firm.build_account
    assert !account.save
    assert_equal "can't be empty", account.errors.on("credit_limit")
  end

  def test_has_one_create
    firm = Firm.new("name" => "GlobalMegaCorp")
    firm.save
    assert_equal firm.create_account("credit_limit" => 1000), firm.account
  end
end
