require "cases/helper"
require 'models/developer'
require 'models/project'
require 'models/company'
require 'models/topic'
require 'models/reply'
require 'models/computer'
require 'models/customer'
require 'models/order'
require 'models/categorization'
require 'models/category'
require 'models/post'
require 'models/author'
require 'models/comment'
require 'models/tag'
require 'models/tagging'
require 'models/person'
require 'models/reader'
require 'models/parrot'
require 'models/pirate'
require 'models/treasure'
require 'models/price_estimate'
require 'models/club'
require 'models/member'
require 'models/membership'
require 'models/sponsor'

class AssociationsTest < ActiveRecord::TestCase
  fixtures :accounts, :companies, :developers, :projects, :developers_projects,
           :computers

  def test_include_with_order_works
    assert_nothing_raised {Account.find(:first, :order => 'id', :include => :firm)}
    assert_nothing_raised {Account.find(:first, :order => :id, :include => :firm)}
  end

  def test_bad_collection_keys
    assert_raise(ArgumentError, 'ActiveRecord should have barked on bad collection keys') do
      Class.new(ActiveRecord::Base).has_many(:wheels, :name => 'wheels')
    end
  end

  def test_should_construct_new_finder_sql_after_create
    person = Person.new :first_name => 'clark'
    assert_equal [], person.readers.find(:all)
    person.save!
    reader = Reader.create! :person => person, :post => Post.new(:title => "foo", :body => "bar")
    assert_equal [reader], person.readers.find(:all)
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
    File.delete(store_filename) if File.exist?(store_filename)
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

class AssociationProxyTest < ActiveRecord::TestCase
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
    david.posts.class   # force load target
    assert_equal  david.posts, david.posts.proxy_target

    assert_equal  david, david.posts_with_extension.testing_proxy_owner
    assert_equal  david.class.reflect_on_association(:posts_with_extension), david.posts_with_extension.testing_proxy_reflection
    david.posts_with_extension.class   # force load target
    assert_equal  david.posts_with_extension, david.posts_with_extension.testing_proxy_target
  end

  def test_push_does_not_load_target
    david = authors(:david)

    david.posts << (post = Post.new(:title => "New on Edge", :body => "More cool stuff!"))
    assert !david.posts.loaded?
    assert david.posts.include?(post)
  end

  def test_push_has_many_through_does_not_load_target
    david = authors(:david)

    david.categories << categories(:technology)
    assert !david.categories.loaded?
    assert david.categories.include?(categories(:technology))
  end

  def test_push_followed_by_save_does_not_load_target
    david = authors(:david)

    david.posts << (post = Post.new(:title => "New on Edge", :body => "More cool stuff!"))
    assert !david.posts.loaded?
    david.save
    assert !david.posts.loaded?
    assert david.posts.include?(post)
  end

  def test_push_does_not_lose_additions_to_new_record
    josh = Author.new(:name => "Josh")
    josh.posts << Post.new(:title => "New on Edge", :body => "More cool stuff!")
    assert josh.posts.loaded?
    assert_equal 1, josh.posts.size
  end

  def test_save_on_parent_does_not_load_target
    david = developers(:david)

    assert !david.projects.loaded?
    david.update_attribute(:created_at, Time.now)
    assert !david.projects.loaded?
  end

  def test_inspect_does_not_reload_a_not_yet_loaded_target
    andreas = Developer.new :name => 'Andreas', :log => 'new developer added'
    assert !andreas.audit_logs.loaded?
    assert_match(/message: "new developer added"/, andreas.audit_logs.inspect)
  end

  def test_save_on_parent_saves_children
    developer = Developer.create :name => "Bryan", :salary => 50_000
    assert_equal 1, developer.reload.audit_logs.size
  end

  def test_create_via_association_with_block
    post = authors(:david).posts.create(:title => "New on Edge") {|p| p.body = "More cool stuff!"}
    assert_equal post.title, "New on Edge"
    assert_equal post.body, "More cool stuff!"
  end

  def test_create_with_bang_via_association_with_block
    post = authors(:david).posts.create!(:title => "New on Edge") {|p| p.body = "More cool stuff!"}
    assert_equal post.title, "New on Edge"
    assert_equal post.body, "More cool stuff!"
  end

  def test_failed_reload_returns_nil
    p = setup_dangling_association
    assert_nil p.author.reload
  end

  def test_failed_reset_returns_nil
    p = setup_dangling_association
    assert_nil p.author.reset
  end

  def test_reload_returns_assocition
    david = developers(:david)
    assert_nothing_raised do
      assert_equal david.projects, david.projects.reload.reload
    end
  end

  def setup_dangling_association
    josh = Author.create(:name => "Josh")
    p = Post.create(:title => "New on Edge", :body => "More cool stuff!", :author => josh)
    josh.destroy
    p
  end
end

class OverridingAssociationsTest < ActiveRecord::TestCase
  class Person < ActiveRecord::Base; end
  class DifferentPerson < ActiveRecord::Base; end

  class PeopleList < ActiveRecord::Base
    has_and_belongs_to_many :has_and_belongs_to_many, :before_add => :enlist
    has_many :has_many, :before_add => :enlist
    belongs_to :belongs_to
    has_one :has_one
  end

  class DifferentPeopleList < PeopleList
    # Different association with the same name, callbacks should be omitted here.
    has_and_belongs_to_many :has_and_belongs_to_many, :class_name => 'DifferentPerson'
    has_many :has_many, :class_name => 'DifferentPerson'
    belongs_to :belongs_to, :class_name => 'DifferentPerson'
    has_one :has_one, :class_name => 'DifferentPerson'
  end

  def test_habtm_association_redefinition_callbacks_should_differ_and_not_inherited
    # redeclared association on AR descendant should not inherit callbacks from superclass
    callbacks = PeopleList.read_inheritable_attribute(:before_add_for_has_and_belongs_to_many)
    assert_equal([:enlist], callbacks)
    callbacks = DifferentPeopleList.read_inheritable_attribute(:before_add_for_has_and_belongs_to_many)
    assert_equal([], callbacks)
  end

  def test_has_many_association_redefinition_callbacks_should_differ_and_not_inherited
    # redeclared association on AR descendant should not inherit callbacks from superclass
    callbacks = PeopleList.read_inheritable_attribute(:before_add_for_has_many)
    assert_equal([:enlist], callbacks)
    callbacks = DifferentPeopleList.read_inheritable_attribute(:before_add_for_has_many)
    assert_equal([], callbacks)
  end

  def test_habtm_association_redefinition_reflections_should_differ_and_not_inherited
    assert_not_equal(
      PeopleList.reflect_on_association(:has_and_belongs_to_many),
      DifferentPeopleList.reflect_on_association(:has_and_belongs_to_many)
    )
  end

  def test_has_many_association_redefinition_reflections_should_differ_and_not_inherited
    assert_not_equal(
      PeopleList.reflect_on_association(:has_many),
      DifferentPeopleList.reflect_on_association(:has_many)
    )
  end

  def test_belongs_to_association_redefinition_reflections_should_differ_and_not_inherited
    assert_not_equal(
      PeopleList.reflect_on_association(:belongs_to),
      DifferentPeopleList.reflect_on_association(:belongs_to)
    )
  end

  def test_has_one_association_redefinition_reflections_should_differ_and_not_inherited
    assert_not_equal(
      PeopleList.reflect_on_association(:has_one),
      DifferentPeopleList.reflect_on_association(:has_one)
    )
  end
end
