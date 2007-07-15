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

  def test_has_many
    assert !@firm.clients.loaded?
    assert_deprecated 'has_clients?' do
      assert_queries(1) { assert @firm.has_clients? }
    end
    assert !@firm.clients.loaded?
    assert_deprecated 'clients_count' do
      assert_queries(1) { assert_equal 2, @firm.clients_count }
    end
  end

  def test_belongs_to
    client = companies(:second_client)
    assert_deprecated('has_firm?') do
      assert companies(:second_client).has_firm?, "Microsoft should have a firm"
    end
    assert_equal companies(:first_firm), client.firm, "Microsoft should have a firm"
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

  def test_find_in
    assert_deprecated 'find_in_clients' do
      assert_equal companies(:first_client), @firm.find_in_clients(2)
      assert_raises(ActiveRecord::RecordNotFound) { @firm.find_in_clients(6) }
    end
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
      david.remove_projects Project.find(:all)
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
  
end
