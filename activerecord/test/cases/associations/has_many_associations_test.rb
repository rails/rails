# frozen_string_literal: true

require "cases/helper"
require "models/developer"
require "models/computer"
require "models/project"
require "models/company"
require "models/contract"
require "models/topic"
require "models/reply"
require "models/category"
require "models/image"
require "models/post"
require "models/author"
require "models/essay"
require "models/comment"
require "models/person"
require "models/reader"
require "models/tagging"
require "models/tag"
require "models/invoice"
require "models/line_item"
require "models/car"
require "models/bulb"
require "models/engine"
require "models/categorization"
require "models/minivan"
require "models/speedometer"
require "models/reference"
require "models/job"
require "models/college"
require "models/student"
require "models/pirate"
require "models/ship"
require "models/ship_part"
require "models/treasure"
require "models/parrot"
require "models/tyre"
require "models/subscriber"
require "models/subscription"
require "models/zine"
require "models/interest"

class HasManyAssociationsTestForReorderWithJoinDependency < ActiveRecord::TestCase
  fixtures :authors, :author_addresses, :posts, :comments

  def test_should_generate_valid_sql
    author = authors(:david)
    # this can fail on adapters which require ORDER BY expressions to be included in the SELECT expression
    # if the reorder clauses are not correctly handled
    assert author.posts_with_comments_sorted_by_comment_id.where("comments.id > 0").reorder("posts.comments_count DESC", "posts.tags_count DESC").last
  end
end

class HasManyAssociationsTestPrimaryKeys < ActiveRecord::TestCase
  fixtures :authors, :author_addresses, :essays, :subscribers, :subscriptions, :people

  def test_custom_primary_key_on_new_record_should_fetch_with_query
    subscriber = Subscriber.new(nick: "webster132")
    assert_not_predicate subscriber.subscriptions, :loaded?

    assert_queries 1 do
      assert_equal 2, subscriber.subscriptions.size
    end

    assert_equal Subscription.where(subscriber_id: "webster132"), subscriber.subscriptions
  end

  def test_association_primary_key_on_new_record_should_fetch_with_query
    author = Author.new(name: "David")
    assert_not_predicate author.essays, :loaded?

    assert_queries 1 do
      assert_equal 1, author.essays.size
    end

    assert_equal Essay.where(writer_id: "David"), author.essays
  end

  def test_has_many_custom_primary_key
    david = authors(:david)
    assert_equal Essay.where(writer_id: "David"), david.essays
  end

  def test_ids_on_unloaded_association_with_custom_primary_key
    david = people(:david)
    assert_equal Essay.where(writer_id: "David").pluck(:id), david.essay_ids
  end

  def test_ids_on_loaded_association_with_custom_primary_key
    david = people(:david)
    david.essays.load
    assert_equal Essay.where(writer_id: "David").pluck(:id), david.essay_ids
  end

  def test_has_many_assignment_with_custom_primary_key
    david = people(:david)

    assert_equal ["A Modest Proposal"], david.essays.map(&:name)
    david.essays = [Essay.create!(name: "Remote Work")]
    assert_equal ["Remote Work"], david.essays.map(&:name)
  end

  def test_blank_custom_primary_key_on_new_record_should_not_run_queries
    author = Author.new
    assert_not_predicate author.essays, :loaded?

    assert_queries 0 do
      assert_equal 0, author.essays.size
    end
  end
end

class HasManyAssociationsTest < ActiveRecord::TestCase
  fixtures :accounts, :categories, :companies, :developers, :projects,
           :developers_projects, :topics, :authors, :author_addresses, :comments,
           :posts, :readers, :taggings, :cars, :jobs, :tags,
           :categorizations, :zines, :interests

  def setup
    Client.destroyed_client_ids.clear
  end

  def test_sti_subselect_count
    tag = Tag.first
    len = Post.tagged_with(tag.id).limit(10).size
    assert_operator len, :>, 0
  end

  def test_anonymous_has_many
    developer = Class.new(ActiveRecord::Base) {
      self.table_name = "developers"
      dev = self

      developer_project = Class.new(ActiveRecord::Base) {
        self.table_name = "developers_projects"
        belongs_to :developer, anonymous_class: dev
      }
      has_many :developer_projects, anonymous_class: developer_project, foreign_key: "developer_id"
    }
    dev = developer.first
    named = Developer.find(dev.id)
    assert_operator dev.developer_projects.count, :>, 0
    assert_equal named.projects.map(&:id).sort,
                 dev.developer_projects.map(&:project_id).sort
  end

  def test_default_scope_on_relations_is_not_cached
    counter = 0
    posts = Class.new(ActiveRecord::Base) {
      self.table_name = "posts"
      self.inheritance_column = "not_there"
      post = self

      comments = Class.new(ActiveRecord::Base) {
        self.table_name = "comments"
        self.inheritance_column = "not_there"
        belongs_to :post, anonymous_class: post
        default_scope -> {
          counter += 1
          where("id = :inc", inc: counter)
        }
      }
      has_many :comments, anonymous_class: comments, foreign_key: "post_id"
    }
    assert_equal 0, counter
    post = posts.first
    assert_equal 0, counter
    sql = capture_sql { post.comments.to_a }
    post.comments.reset
    assert_not_equal sql, capture_sql { post.comments.to_a }
  end

  def test_has_many_build_with_options
    college = College.create(name: "UFMT")
    Student.create(active: true, college_id: college.id, name: "Sarah")

    assert_equal college.students, Student.where(active: true, college_id: college.id)
  end

  def test_add_record_to_collection_should_change_its_updated_at
    ship = Ship.create(name: "dauntless")
    part = ShipPart.create(name: "cockpit")
    updated_at = part.updated_at

    travel(1.second) do
      ship.parts << part
    end

    assert_equal part.ship, ship
    assert_not_equal part.updated_at, updated_at
  end

  def test_clear_collection_should_not_change_updated_at
    # GH#17161: .clear calls delete_all (and returns the association),
    # which is intended to not touch associated objects's updated_at field
    ship = Ship.create(name: "dauntless")
    part = ShipPart.create(name: "cockpit", ship_id: ship.id)

    ship.parts.clear
    part.reload

    assert_nil part.ship
    assert_not_predicate part, :updated_at_changed?
  end

  def test_create_from_association_should_respect_default_scope
    car = Car.create(name: "honda")
    assert_equal "honda", car.name

    bulb = Bulb.create
    assert_equal "defaulty", bulb.name

    bulb = car.bulbs.build
    assert_equal "defaulty", bulb.name

    bulb = car.bulbs.create
    assert_equal "defaulty", bulb.name
  end

  def test_build_and_create_from_association_should_respect_passed_attributes_over_default_scope
    car = Car.create(name: "honda")

    bulb = car.bulbs.build(name: "exotic")
    assert_equal "exotic", bulb.name

    bulb = car.bulbs.create(name: "exotic")
    assert_equal "exotic", bulb.name

    bulb = car.awesome_bulbs.build(frickinawesome: false)
    assert_equal false, bulb.frickinawesome

    bulb = car.awesome_bulbs.create(frickinawesome: false)
    assert_equal false, bulb.frickinawesome
  end

  def test_build_from_association_should_respect_scope
    author = Author.new

    post = author.thinking_posts.build
    assert_equal "So I was thinking", post.title
  end

  def test_create_from_association_with_nil_values_should_work
    car = Car.create(name: "honda")

    bulb = car.bulbs.new(nil)
    assert_equal "defaulty", bulb.name

    bulb = car.bulbs.build(nil)
    assert_equal "defaulty", bulb.name

    bulb = car.bulbs.create(nil)
    assert_equal "defaulty", bulb.name
  end

  def test_build_from_association_sets_inverse_instance
    car = Car.new(name: "honda")

    bulb = car.bulbs.build
    assert_equal car, bulb.car
  end

  def test_do_not_call_callbacks_for_delete_all
    car = Car.create(name: "honda")
    car.funky_bulbs.create!
    assert_equal 1, car.funky_bulbs.count
    assert_nothing_raised { car.reload.funky_bulbs.delete_all }
    assert_equal 0, car.funky_bulbs.count, "bulbs should have been deleted using :delete_all strategy"
  end

  def test_delete_all_on_association_is_the_same_as_not_loaded
    author = authors :david
    author.thinking_posts.create!(body: "test")
    author.reload
    expected_sql = capture_sql { author.thinking_posts.delete_all }

    author.thinking_posts.create!(body: "test")
    author.reload
    author.thinking_posts.inspect
    loaded_sql = capture_sql { author.thinking_posts.delete_all }
    assert_equal(expected_sql, loaded_sql)
  end

  def test_delete_all_on_association_with_nil_dependency_is_the_same_as_not_loaded
    author = authors :david
    author.posts.create!(title: "test", body: "body")
    author.reload
    expected_sql = capture_sql { author.posts.delete_all }

    author.posts.create!(title: "test", body: "body")
    author.reload
    author.posts.to_a
    loaded_sql = capture_sql { author.posts.delete_all }
    assert_equal(expected_sql, loaded_sql)
  end

  def test_building_the_associated_object_with_implicit_sti_base_class
    firm = DependentFirm.new
    company = firm.companies.build
    assert_kind_of Company, company, "Expected #{company.class} to be a Company"
  end

  def test_building_the_associated_object_with_explicit_sti_base_class
    firm = DependentFirm.new
    company = firm.companies.build(type: "Company")
    assert_kind_of Company, company, "Expected #{company.class} to be a Company"
  end

  def test_building_the_associated_object_with_sti_subclass
    firm = DependentFirm.new
    company = firm.companies.build(type: "Client")
    assert_kind_of Client, company, "Expected #{company.class} to be a Client"
  end

  def test_building_the_associated_object_with_an_invalid_type
    firm = DependentFirm.new
    assert_raise(ActiveRecord::SubclassNotFound) { firm.companies.build(type: "Invalid") }
  end

  def test_building_the_associated_object_with_an_unrelated_type
    firm = DependentFirm.new
    assert_raise(ActiveRecord::SubclassNotFound) { firm.companies.build(type: "Account") }
  end

  test "building the association with an array" do
    speedometer = Speedometer.new(speedometer_id: "a")
    data = [{ name: "first" }, { name: "second" }]
    speedometer.minivans.build(data)

    assert_equal 2, speedometer.minivans.size
    assert speedometer.save
    assert_equal ["first", "second"], speedometer.reload.minivans.map(&:name)
  end

  def test_association_keys_bypass_attribute_protection
    car = Car.create(name: "honda")

    bulb = car.bulbs.new
    assert_equal car.id, bulb.car_id

    bulb = car.bulbs.new car_id: car.id + 1
    assert_equal car.id, bulb.car_id

    bulb = car.bulbs.build
    assert_equal car.id, bulb.car_id

    bulb = car.bulbs.build car_id: car.id + 1
    assert_equal car.id, bulb.car_id

    bulb = car.bulbs.create
    assert_equal car.id, bulb.car_id

    bulb = car.bulbs.create car_id: car.id + 1
    assert_equal car.id, bulb.car_id
  end

  def test_association_protect_foreign_key
    invoice = Invoice.create

    line_item = invoice.line_items.new
    assert_equal invoice.id, line_item.invoice_id

    line_item = invoice.line_items.new invoice_id: invoice.id + 1
    assert_equal invoice.id, line_item.invoice_id

    line_item = invoice.line_items.build
    assert_equal invoice.id, line_item.invoice_id

    line_item = invoice.line_items.build invoice_id: invoice.id + 1
    assert_equal invoice.id, line_item.invoice_id

    line_item = invoice.line_items.create
    assert_equal invoice.id, line_item.invoice_id

    line_item = invoice.line_items.create invoice_id: invoice.id + 1
    assert_equal invoice.id, line_item.invoice_id
  end

  # When creating objects on the association, we must not do it within a scope (even though it
  # would be convenient), because this would cause that scope to be applied to any callbacks etc.
  def test_build_and_create_should_not_happen_within_scope
    car = cars(:honda)
    scope = car.foo_bulbs.where_values_hash

    bulb = car.foo_bulbs.build
    assert_not_equal scope, bulb.scope_after_initialize.where_values_hash

    bulb = car.foo_bulbs.create
    assert_not_equal scope, bulb.scope_after_initialize.where_values_hash

    bulb = car.foo_bulbs.create!
    assert_not_equal scope, bulb.scope_after_initialize.where_values_hash
  end

  def test_no_sql_should_be_fired_if_association_already_loaded
    Car.create(name: "honda")
    bulbs = Car.first.bulbs
    bulbs.to_a # to load all instances of bulbs

    assert_no_queries do
      bulbs.first()
    end

    assert_no_queries do
      bulbs.second()
    end

    assert_no_queries do
      bulbs.third()
    end

    assert_no_queries do
      bulbs.fourth()
    end

    assert_no_queries do
      bulbs.fifth()
    end

    assert_no_queries do
      bulbs.forty_two()
    end

    assert_no_queries do
      bulbs.third_to_last()
    end

    assert_no_queries do
      bulbs.second_to_last()
    end

    assert_no_queries do
      bulbs.last()
    end
  end

  def test_finder_method_with_dirty_target
    company = companies(:first_firm)
    new_clients = []
    assert_no_queries(ignore_none: false) do
      new_clients << company.clients_of_firm.build(name: "Another Client")
      new_clients << company.clients_of_firm.build(name: "Another Client II")
      new_clients << company.clients_of_firm.build(name: "Another Client III")
    end

    assert_not_predicate company.clients_of_firm, :loaded?
    assert_queries(1) do
      assert_same new_clients[0], company.clients_of_firm.third
      assert_same new_clients[1], company.clients_of_firm.fourth
      assert_same new_clients[2], company.clients_of_firm.fifth
      assert_same new_clients[0], company.clients_of_firm.third_to_last
      assert_same new_clients[1], company.clients_of_firm.second_to_last
      assert_same new_clients[2], company.clients_of_firm.last
    end
  end

  def test_finder_bang_method_with_dirty_target
    company = companies(:first_firm)
    new_clients = []
    assert_no_queries(ignore_none: false) do
      new_clients << company.clients_of_firm.build(name: "Another Client")
      new_clients << company.clients_of_firm.build(name: "Another Client II")
      new_clients << company.clients_of_firm.build(name: "Another Client III")
    end

    assert_not_predicate company.clients_of_firm, :loaded?
    assert_queries(1) do
      assert_same new_clients[0], company.clients_of_firm.third!
      assert_same new_clients[1], company.clients_of_firm.fourth!
      assert_same new_clients[2], company.clients_of_firm.fifth!
      assert_same new_clients[0], company.clients_of_firm.third_to_last!
      assert_same new_clients[1], company.clients_of_firm.second_to_last!
      assert_same new_clients[2], company.clients_of_firm.last!
    end
  end

  def test_create_resets_cached_counters
    Reader.delete_all

    person = Person.create!(first_name: "tenderlove")

    post   = Post.first

    assert_equal [], person.readers
    assert_nil person.readers.find_by_post_id(post.id)

    person.readers.create(post_id: post.id)

    assert_equal 1, person.readers.count
    assert_equal 1, person.readers.length
    assert_equal post, person.readers.first.post
    assert_equal person, person.readers.first.person
  end

  def test_update_all_respects_association_scope
    person = Person.new
    person.first_name = "Naruto"
    person.references << Reference.new
    person.id = 10
    person.references
    person.save!
    assert_equal 1, person.references.update_all(favourite: true)
  end

  def test_exists_respects_association_scope
    person = Person.new
    person.first_name = "Sasuke"
    person.references << Reference.new
    person.id = 10
    person.references
    person.save!
    assert_predicate person.references, :exists?
  end

  def test_counting_with_counter_sql
    assert_equal 3, Firm.first.clients.count
  end

  def test_counting
    assert_equal 3, Firm.first.plain_clients.count
  end

  def test_counting_with_single_hash
    assert_equal 1, Firm.first.plain_clients.where(name: "Microsoft").count
  end

  def test_counting_with_column_name_and_hash
    assert_equal 3, Firm.first.plain_clients.count(:name)
  end

  def test_counting_with_association_limit
    firm = companies(:first_firm)
    assert_equal firm.limited_clients.length, firm.limited_clients.size
    assert_equal firm.limited_clients.length, firm.limited_clients.count
  end

  def test_finding
    assert_equal 3, Firm.first.clients.length
  end

  def test_finding_array_compatibility
    assert_equal 3, Firm.order(:id).find { |f| f.id > 0 }.clients.length
  end

  def test_find_many_with_merged_options
    assert_equal 1, companies(:first_firm).limited_clients.size
    assert_equal 1, companies(:first_firm).limited_clients.to_a.size
    assert_equal 3, companies(:first_firm).limited_clients.limit(nil).to_a.size
  end

  def test_find_should_append_to_association_order
    ordered_clients = companies(:first_firm).clients_sorted_desc.order("companies.id")
    assert_equal ["id DESC", "companies.id"], ordered_clients.order_values
  end

  def test_dynamic_find_should_respect_association_order
    assert_equal companies(:another_first_firm_client), companies(:first_firm).clients_sorted_desc.where("type = 'Client'").first
    assert_equal companies(:another_first_firm_client), companies(:first_firm).clients_sorted_desc.find_by_type("Client")
  end

  def test_taking
    posts(:other_by_bob).destroy
    assert_equal posts(:misc_by_bob), authors(:bob).posts.take
    assert_equal posts(:misc_by_bob), authors(:bob).posts.take!
    authors(:bob).posts.to_a
    assert_equal posts(:misc_by_bob), authors(:bob).posts.take
    assert_equal posts(:misc_by_bob), authors(:bob).posts.take!
  end

  def test_taking_not_found
    authors(:bob).posts.delete_all
    assert_raise(ActiveRecord::RecordNotFound) { authors(:bob).posts.take! }
    authors(:bob).posts.to_a
    assert_raise(ActiveRecord::RecordNotFound) { authors(:bob).posts.take! }
  end

  def test_taking_with_a_number
    klass = Class.new(Author) do
      has_many :posts, -> { order(:id) }

      def self.name
        "Author"
      end
    end

    # taking from unloaded Relation
    bob = klass.find(authors(:bob).id)
    new_post = bob.posts.build
    assert_not_predicate bob.posts, :loaded?
    assert_equal [posts(:misc_by_bob)], bob.posts.take(1)
    assert_equal [posts(:misc_by_bob), posts(:other_by_bob)], bob.posts.take(2)
    assert_equal [posts(:misc_by_bob), posts(:other_by_bob), new_post], bob.posts.take(3)

    # taking from loaded Relation
    bob.posts.load
    assert_predicate bob.posts, :loaded?
    assert_equal [posts(:misc_by_bob)], bob.posts.take(1)
    assert_equal [posts(:misc_by_bob), posts(:other_by_bob)], bob.posts.take(2)
    assert_equal [posts(:misc_by_bob), posts(:other_by_bob), new_post], bob.posts.take(3)
  end

  def test_taking_with_inverse_of
    interests(:woodsmanship).destroy
    interests(:survival).destroy

    zine = zines(:going_out)
    interest = zine.interests.take
    assert_equal interests(:hunting), interest
    assert_same zine, interest.zine
  end

  def test_cant_save_has_many_readonly_association
    authors(:david).readonly_comments.each { |c| assert_raise(ActiveRecord::ReadOnlyRecord) { c.save! } }
    authors(:david).readonly_comments.each { |c| assert c.readonly? }
  end

  def test_finding_default_orders
    assert_equal "Summit", Firm.first.clients.first.name
  end

  def test_finding_with_different_class_name_and_order
    assert_equal "Apex", Firm.first.clients_sorted_desc.first.name
  end

  def test_finding_with_foreign_key
    assert_equal "Microsoft", Firm.first.clients_of_firm.first.name
  end

  def test_finding_with_condition
    assert_equal "Microsoft", Firm.first.clients_like_ms.first.name
  end

  def test_finding_with_condition_hash
    assert_equal "Microsoft", Firm.first.clients_like_ms_with_hash_conditions.first.name
  end

  def test_finding_using_primary_key
    assert_equal "Summit", Firm.first.clients_using_primary_key.first.name
  end

  def test_update_all_on_association_accessed_before_save
    firm = Firm.new(name: "Firm")
    firm.clients << Client.first
    firm.save!
    assert_equal firm.clients.count, firm.clients.update_all(description: "Great!")
  end

  def test_update_all_on_association_accessed_before_save_with_explicit_foreign_key
    firm = Firm.new(name: "Firm", id: 100)
    firm.clients << Client.first
    firm.save!
    assert_equal firm.clients.count, firm.clients.update_all(description: "Great!")
  end

  def test_belongs_to_sanity
    c = Client.new
    assert_nil c.firm, "belongs_to failed sanity check on new object"
  end

  def test_find_ids
    firm = Firm.first

    assert_raise(ActiveRecord::RecordNotFound) { firm.clients.find }

    client = firm.clients.find(2)
    assert_kind_of Client, client

    client_ary = firm.clients.find([2])
    assert_kind_of Array, client_ary
    assert_equal client, client_ary.first

    client_ary = firm.clients.find(2, 3)
    assert_kind_of Array, client_ary
    assert_equal 2, client_ary.size
    assert_equal client, client_ary.first

    assert_raise(ActiveRecord::RecordNotFound) { firm.clients.find(2, 99) }
  end

  def test_find_one_message_on_primary_key
    firm = Firm.first

    e = assert_raises(ActiveRecord::RecordNotFound) do
      firm.clients.find(0)
    end
    assert_equal 0, e.id
    assert_equal "id", e.primary_key
    assert_equal "Client", e.model
    assert_match (/\ACouldn't find Client with 'id'=0/), e.message
  end

  def test_find_ids_and_inverse_of
    force_signal37_to_load_all_clients_of_firm

    assert_predicate companies(:first_firm).clients_of_firm, :loaded?

    firm = companies(:first_firm)
    client = firm.clients_of_firm.find(3)
    assert_kind_of Client, client

    client_ary = firm.clients_of_firm.find([3])
    assert_kind_of Array, client_ary
    assert_equal client, client_ary.first
  end

  def test_find_all
    firm = Firm.first
    assert_equal 3, firm.clients.where("#{QUOTED_TYPE} = 'Client'").to_a.length
    assert_equal 1, firm.clients.where("name = 'Summit'").to_a.length
  end

  def test_find_each
    firm = companies(:first_firm)

    assert_not_predicate firm.clients, :loaded?

    assert_queries(4) do
      firm.clients.find_each(batch_size: 1) { |c| assert_equal firm.id, c.firm_id }
    end

    assert_not_predicate firm.clients, :loaded?
  end

  def test_find_each_with_conditions
    firm = companies(:first_firm)

    assert_queries(2) do
      firm.clients.where(name: "Microsoft").find_each(batch_size: 1) do |c|
        assert_equal firm.id, c.firm_id
        assert_equal "Microsoft", c.name
      end
    end

    assert_not_predicate firm.clients, :loaded?
  end

  def test_find_in_batches
    firm = companies(:first_firm)

    assert_not_predicate firm.clients, :loaded?

    assert_queries(2) do
      firm.clients.find_in_batches(batch_size: 2) do |clients|
        clients.each { |c| assert_equal firm.id, c.firm_id }
      end
    end

    assert_not_predicate firm.clients, :loaded?
  end

  def test_find_all_sanitized
    firm = Firm.first
    summit = firm.clients.where("name = 'Summit'").to_a
    assert_equal summit, firm.clients.where("name = ?", "Summit").to_a
    assert_equal summit, firm.clients.where("name = :name", name: "Summit").to_a
  end

  def test_find_first
    firm = Firm.first
    client2 = Client.find(2)
    assert_equal firm.clients.first, firm.clients.order("id").first
    assert_equal client2, firm.clients.where("#{QUOTED_TYPE} = 'Client'").order("id").first
  end

  def test_find_first_sanitized
    firm = Firm.first
    client2 = Client.find(2)
    assert_equal client2, firm.clients.where("#{QUOTED_TYPE} = ?", "Client").first
    assert_equal client2, firm.clients.where("#{QUOTED_TYPE} = :type", type: "Client").first
  end

  def test_find_first_after_reset_scope
    firm = Firm.first
    collection = firm.clients

    original_object = collection.first
    assert_same original_object, collection.first, "Expected second call to #first to cache the same object"

    # It should return a different object, since the association has been reloaded
    assert_not_same original_object, firm.clients.first, "Expected #first to return a new object"
  end

  def test_find_first_after_reset
    firm = Firm.first
    collection = firm.clients

    original_object = collection.first
    assert_same original_object, collection.first, "Expected second call to #first to cache the same object"
    collection.reset

    # It should return a different object, since the association has been reloaded
    assert_not_same original_object, collection.first, "Expected #first after #reset to return a new object"
  end

  def test_find_first_after_reload
    firm = Firm.first
    collection = firm.clients

    original_object = collection.first
    assert_same original_object, collection.first, "Expected second call to #first to cache the same object"
    collection.reload

    # It should return a different object, since the association has been reloaded
    assert_not_same original_object, collection.first, "Expected #first after #reload to return a new object"
  end

  def test_find_all_with_include_and_conditions
    assert_nothing_raised do
      Developer.all.merge!(joins: :audit_logs, where: { "audit_logs.message" => nil, :name => "Smith" }).to_a
    end
  end

  def test_find_in_collection
    assert_equal Client.find(2).name, companies(:first_firm).clients.find(2).name
    assert_raise(ActiveRecord::RecordNotFound) { companies(:first_firm).clients.find(6) }
  end

  def test_find_grouped
    all_clients_of_firm1 = Client.all.merge!(where: "firm_id = 1").to_a
    grouped_clients_of_firm1 = Client.all.merge!(where: "firm_id = 1", group: "firm_id", select: "firm_id, count(id) as clients_count").to_a
    assert_equal 3, all_clients_of_firm1.size
    assert_equal 1, grouped_clients_of_firm1.size
  end

  def test_find_scoped_grouped
    assert_equal 1, companies(:first_firm).clients_grouped_by_firm_id.size
    assert_equal 1, companies(:first_firm).clients_grouped_by_firm_id.length
    assert_equal 3, companies(:first_firm).clients_grouped_by_name.size
    assert_equal 3, companies(:first_firm).clients_grouped_by_name.length
  end

  def test_find_scoped_grouped_having
    assert_equal 2, authors(:david).popular_grouped_posts.length
    assert_equal 0, authors(:mary).popular_grouped_posts.length
  end

  def test_default_select
    assert_equal Comment.column_names.sort, posts(:welcome).comments.first.attributes.keys.sort
  end

  def test_select_query_method
    assert_equal ["id", "body"], posts(:welcome).comments.select(:id, :body).first.attributes.keys
  end

  def test_select_with_block
    assert_equal [1], posts(:welcome).comments.select { |c| c.id == 1 }.map(&:id)
  end

  def test_select_with_block_and_dirty_target
    assert_equal 2, posts(:welcome).comments.select { true }.size
    posts(:welcome).comments.build
    assert_equal 3, posts(:welcome).comments.select { true }.size
  end

  def test_select_without_foreign_key
    assert_equal companies(:first_firm).accounts.first.credit_limit, companies(:first_firm).accounts.select(:credit_limit).first.credit_limit
  end

  def test_adding
    force_signal37_to_load_all_clients_of_firm

    assert_predicate companies(:first_firm).clients_of_firm, :loaded?

    natural = Client.new("name" => "Natural Company")
    companies(:first_firm).clients_of_firm << natural
    assert_equal 3, companies(:first_firm).clients_of_firm.size # checking via the collection
    assert_equal 3, companies(:first_firm).clients_of_firm.reload.size # checking using the db
    assert_equal natural, companies(:first_firm).clients_of_firm.last
  end

  def test_adding_using_create
    first_firm = companies(:first_firm)
    assert_equal 3, first_firm.plain_clients.size
    first_firm.plain_clients.create(name: "Natural Company")
    assert_equal 4, first_firm.plain_clients.length
    assert_equal 4, first_firm.plain_clients.size
  end

  def test_create_with_bang_on_has_many_when_parent_is_new_raises
    error = assert_raise(ActiveRecord::RecordNotSaved) do
      firm = Firm.new
      firm.plain_clients.create! name: "Whoever"
    end

    assert_equal "You cannot call create unless the parent is saved", error.message
  end

  def test_regular_create_on_has_many_when_parent_is_new_raises
    error = assert_raise(ActiveRecord::RecordNotSaved) do
      firm = Firm.new
      firm.plain_clients.create name: "Whoever"
    end

    assert_equal "You cannot call create unless the parent is saved", error.message
  end

  def test_create_with_bang_on_has_many_raises_when_record_not_saved
    assert_raise(ActiveRecord::RecordInvalid) do
      firm = Firm.first
      firm.plain_clients.create!
    end
  end

  def test_create_with_bang_on_habtm_when_parent_is_new_raises
    error = assert_raise(ActiveRecord::RecordNotSaved) do
      Developer.new("name" => "Aredridel").projects.create!
    end

    assert_equal "You cannot call create unless the parent is saved", error.message
  end

  def test_adding_a_mismatch_class
    assert_raise(ActiveRecord::AssociationTypeMismatch) { companies(:first_firm).clients_of_firm << nil }
    assert_raise(ActiveRecord::AssociationTypeMismatch) { companies(:first_firm).clients_of_firm << 1 }
    assert_raise(ActiveRecord::AssociationTypeMismatch) { companies(:first_firm).clients_of_firm << Topic.find(1) }
  end

  def test_adding_a_collection
    force_signal37_to_load_all_clients_of_firm

    assert_predicate companies(:first_firm).clients_of_firm, :loaded?

    companies(:first_firm).clients_of_firm.concat([Client.new("name" => "Natural Company"), Client.new("name" => "Apple")])
    assert_equal 4, companies(:first_firm).clients_of_firm.size
    assert_equal 4, companies(:first_firm).clients_of_firm.reload.size
  end

  def test_transactions_when_adding_to_persisted
    good = Client.new(name: "Good")
    bad  = Client.new(name: "Bad", raise_on_save: true)

    begin
      companies(:first_firm).clients_of_firm.concat(good, bad)
    rescue Client::RaisedOnSave
    end

    assert_not_includes companies(:first_firm).clients_of_firm.reload, good
  end

  def test_transactions_when_adding_to_new_record
    assert_no_queries(ignore_none: false) do
      firm = Firm.new
      firm.clients_of_firm.concat(Client.new("name" => "Natural Company"))
    end
  end

  def test_inverse_on_before_validate
    firm = companies(:first_firm)
    assert_queries(1) do
      firm.clients_of_firm << Client.new("name" => "Natural Company")
    end
  end

  def test_new_aliased_to_build
    company = companies(:first_firm)
    new_client = assert_no_queries(ignore_none: false) { company.clients_of_firm.new("name" => "Another Client") }
    assert_not_predicate company.clients_of_firm, :loaded?

    assert_equal "Another Client", new_client.name
    assert_not_predicate new_client, :persisted?
    assert_equal new_client, company.clients_of_firm.last
  end

  def test_build
    company = companies(:first_firm)
    new_client = assert_no_queries(ignore_none: false) { company.clients_of_firm.build("name" => "Another Client") }
    assert_not_predicate company.clients_of_firm, :loaded?

    assert_equal "Another Client", new_client.name
    assert_not_predicate new_client, :persisted?
    assert_equal new_client, company.clients_of_firm.last
  end

  def test_collection_size_after_building
    company = companies(:first_firm)  # company already has one client
    company.clients_of_firm.build("name" => "Another Client")
    company.clients_of_firm.build("name" => "Yet Another Client")
    assert_equal 4, company.clients_of_firm.size
    assert_equal 4, company.clients_of_firm.uniq.size
  end

  def test_collection_not_empty_after_building
    company = companies(:first_firm)
    assert_empty company.contracts
    company.contracts.build
    assert_not_empty company.contracts
  end

  def test_collection_size_twice_for_regressions
    post = posts(:thinking)
    assert_equal 0, post.readers.size
    # This test needs a post that has no readers, we assert it to ensure it holds,
    # but need to reload the post because the very call to #size hides the bug.
    post.reload
    post.readers.build
    size1 = post.readers.size
    size2 = post.readers.size
    assert_equal size1, size2
  end

  def test_build_many
    company = companies(:first_firm)
    new_clients = assert_no_queries(ignore_none: false) { company.clients_of_firm.build([{ "name" => "Another Client" }, { "name" => "Another Client II" }]) }
    assert_equal 2, new_clients.size
  end

  def test_build_followed_by_save_does_not_load_target
    companies(:first_firm).clients_of_firm.build("name" => "Another Client")
    assert companies(:first_firm).save
    assert_not_predicate companies(:first_firm).clients_of_firm, :loaded?
  end

  def test_build_without_loading_association
    first_topic = topics(:first)
    Reply.column_names

    assert_equal 1, first_topic.replies.length

    assert_no_queries do
      first_topic.replies.build(title: "Not saved", content: "Superstars")
      assert_equal 2, first_topic.replies.size
    end

    assert_equal 2, first_topic.replies.to_ary.size
  end

  def test_build_via_block
    company = companies(:first_firm)
    new_client = assert_no_queries(ignore_none: false) { company.clients_of_firm.build { |client| client.name = "Another Client" } }
    assert_not_predicate company.clients_of_firm, :loaded?

    assert_equal "Another Client", new_client.name
    assert_not_predicate new_client, :persisted?
    assert_equal new_client, company.clients_of_firm.last
  end

  def test_build_many_via_block
    company = companies(:first_firm)
    new_clients = assert_no_queries(ignore_none: false) do
      company.clients_of_firm.build([{ "name" => "Another Client" }, { "name" => "Another Client II" }]) do |client|
        client.name = "changed"
      end
    end

    assert_equal 2, new_clients.size
    assert_equal "changed", new_clients.first.name
    assert_equal "changed", new_clients.last.name
  end

  def test_create_without_loading_association
    first_firm = companies(:first_firm)
    Firm.column_names
    Client.column_names

    assert_equal 2, first_firm.clients_of_firm.size
    first_firm.clients_of_firm.reset

    assert_queries(1) do
      first_firm.clients_of_firm.create(name: "Superstars")
    end

    assert_equal 3, first_firm.clients_of_firm.size
  end

  def test_create
    force_signal37_to_load_all_clients_of_firm

    assert_predicate companies(:first_firm).clients_of_firm, :loaded?

    new_client = companies(:first_firm).clients_of_firm.create("name" => "Another Client")
    assert_predicate new_client, :persisted?
    assert_equal new_client, companies(:first_firm).clients_of_firm.last
    assert_equal new_client, companies(:first_firm).clients_of_firm.reload.last
  end

  def test_create_many
    companies(:first_firm).clients_of_firm.create([{ "name" => "Another Client" }, { "name" => "Another Client II" }])
    assert_equal 4, companies(:first_firm).clients_of_firm.reload.size
  end

  def test_create_followed_by_save_does_not_load_target
    companies(:first_firm).clients_of_firm.create("name" => "Another Client")
    assert companies(:first_firm).save
    assert_not_predicate companies(:first_firm).clients_of_firm, :loaded?
  end

  def test_deleting
    force_signal37_to_load_all_clients_of_firm

    assert_predicate companies(:first_firm).clients_of_firm, :loaded?

    companies(:first_firm).clients_of_firm.delete(companies(:first_firm).clients_of_firm.first)
    assert_equal 1, companies(:first_firm).clients_of_firm.size
    assert_equal 1, companies(:first_firm).clients_of_firm.reload.size
  end

  def test_deleting_before_save
    new_firm = Firm.new("name" => "A New Firm, Inc.")
    new_client = new_firm.clients_of_firm.build("name" => "Another Client")
    assert_equal 1, new_firm.clients_of_firm.size
    new_firm.clients_of_firm.delete(new_client)
    assert_equal 0, new_firm.clients_of_firm.size
  end

  def test_has_many_without_counter_cache_option
    # Ship has a conventionally named `treasures_count` column, but the counter_cache
    # option is not given on the association.
    ship = Ship.create(name: "Countless", treasures_count: 10)

    assert_not_predicate Ship.reflect_on_association(:treasures), :has_cached_counter?

    # Count should come from sql count() of treasures rather than treasures_count attribute
    assert_equal ship.treasures.size, 0

    assert_no_difference lambda { ship.reload.treasures_count }, "treasures_count should not be changed" do
      ship.treasures.create(name: "Gold")
    end

    assert_no_difference lambda { ship.reload.treasures_count }, "treasures_count should not be changed" do
      ship.treasures.destroy_all
    end
  end

  def test_deleting_updates_counter_cache
    topic = Topic.order("id ASC").first
    assert_equal topic.replies.to_a.size, topic.replies_count

    topic.replies.delete(topic.replies.first)
    topic.reload
    assert_equal topic.replies.to_a.size, topic.replies_count
  end

  def test_counter_cache_updates_in_memory_after_concat
    topic = Topic.create title: "Zoom-zoom-zoom"

    topic.replies << Reply.create(title: "re: zoom", content: "speedy quick!")
    assert_equal 1, topic.replies_count
    assert_equal 1, topic.replies.size
    assert_equal 1, topic.reload.replies.size
  end

  def test_counter_cache_updates_in_memory_after_create
    topic = Topic.create title: "Zoom-zoom-zoom"

    topic.replies.create!(title: "re: zoom", content: "speedy quick!")
    assert_equal 1, topic.replies_count
    assert_equal 1, topic.replies.size
    assert_equal 1, topic.reload.replies.size
  end

  def test_counter_cache_updates_in_memory_after_create_with_array
    topic = Topic.create title: "Zoom-zoom-zoom"

    topic.replies.create!([
      { title: "re: zoom", content: "speedy quick!" },
      { title: "re: zoom 2", content: "OMG lol!" },
    ])
    assert_equal 2, topic.replies_count
    assert_equal 2, topic.replies.size
    assert_equal 2, topic.reload.replies.size
  end

  def test_pushing_association_updates_counter_cache
    topic = Topic.order("id ASC").first
    reply = Reply.create!

    assert_difference "topic.reload.replies_count", 1 do
      topic.replies << reply
    end
  end

  def test_deleting_updates_counter_cache_without_dependent_option
    post = posts(:welcome)

    assert_difference "post.reload.tags_count", -1 do
      post.taggings.delete(post.taggings.first)
    end
  end

  def test_deleting_updates_counter_cache_with_dependent_delete_all
    post = posts(:welcome)
    post.update_columns(taggings_with_delete_all_count: post.tags_count)

    assert_difference "post.reload.taggings_with_delete_all_count", -1 do
      post.taggings_with_delete_all.delete(post.taggings_with_delete_all.first)
    end
  end

  def test_deleting_updates_counter_cache_with_dependent_destroy
    post = posts(:welcome)
    post.update_columns(taggings_with_destroy_count: post.tags_count)

    assert_difference "post.reload.taggings_with_destroy_count", -1 do
      post.taggings_with_destroy.delete(post.taggings_with_destroy.first)
    end
  end

  def test_calling_empty_with_counter_cache
    post = posts(:welcome)
    assert_queries(0) do
      assert_not_empty post.comments
    end
  end

  def test_custom_named_counter_cache
    topic = topics(:first)

    assert_difference "topic.reload.replies_count", -1 do
      topic.approved_replies.clear
    end
  end

  def test_calling_update_attributes_on_id_changes_the_counter_cache
    topic = Topic.order("id ASC").first
    original_count = topic.replies.to_a.size
    assert_equal original_count, topic.replies_count

    first_reply = topic.replies.first
    first_reply.update_attributes(parent_id: nil)
    assert_equal original_count - 1, topic.reload.replies_count

    first_reply.update_attributes(parent_id: topic.id)
    assert_equal original_count, topic.reload.replies_count
  end

  def test_calling_update_attributes_changing_ids_doesnt_change_counter_cache
    topic1 = Topic.find(1)
    topic2 = Topic.find(3)
    original_count1 = topic1.replies.to_a.size
    original_count2 = topic2.replies.to_a.size

    reply1 = topic1.replies.first
    reply2 = topic2.replies.first

    reply1.update_attributes(parent_id: topic2.id)
    assert_equal original_count1 - 1, topic1.reload.replies_count
    assert_equal original_count2 + 1, topic2.reload.replies_count

    reply2.update_attributes(parent_id: topic1.id)
    assert_equal original_count1, topic1.reload.replies_count
    assert_equal original_count2, topic2.reload.replies_count
  end

  def test_deleting_a_collection
    force_signal37_to_load_all_clients_of_firm

    assert_predicate companies(:first_firm).clients_of_firm, :loaded?

    companies(:first_firm).clients_of_firm.create("name" => "Another Client")
    assert_equal 3, companies(:first_firm).clients_of_firm.size
    companies(:first_firm).clients_of_firm.delete([companies(:first_firm).clients_of_firm[0], companies(:first_firm).clients_of_firm[1], companies(:first_firm).clients_of_firm[2]])
    assert_equal 0, companies(:first_firm).clients_of_firm.size
    assert_equal 0, companies(:first_firm).clients_of_firm.reload.size
  end

  def test_delete_all
    force_signal37_to_load_all_clients_of_firm

    assert_predicate companies(:first_firm).clients_of_firm, :loaded?

    companies(:first_firm).dependent_clients_of_firm.create("name" => "Another Client")
    clients = companies(:first_firm).dependent_clients_of_firm.to_a
    assert_equal 3, clients.count

    assert_difference "Client.count", -(clients.count) do
      companies(:first_firm).dependent_clients_of_firm.delete_all
    end
  end

  def test_delete_all_with_not_yet_loaded_association_collection
    force_signal37_to_load_all_clients_of_firm

    assert_predicate companies(:first_firm).clients_of_firm, :loaded?

    companies(:first_firm).clients_of_firm.create("name" => "Another Client")
    assert_equal 3, companies(:first_firm).clients_of_firm.size
    companies(:first_firm).clients_of_firm.reset
    companies(:first_firm).clients_of_firm.delete_all
    assert_equal 0, companies(:first_firm).clients_of_firm.size
    assert_equal 0, companies(:first_firm).clients_of_firm.reload.size
  end

  def test_transaction_when_deleting_persisted
    good = Client.new(name: "Good")
    bad  = Client.new(name: "Bad", raise_on_destroy: true)

    companies(:first_firm).clients_of_firm = [good, bad]

    begin
      companies(:first_firm).clients_of_firm.destroy(good, bad)
    rescue Client::RaisedOnDestroy
    end

    assert_equal [good, bad], companies(:first_firm).clients_of_firm.reload
  end

  def test_transaction_when_deleting_new_record
    assert_no_queries(ignore_none: false) do
      firm = Firm.new
      client = Client.new("name" => "New Client")
      firm.clients_of_firm << client
      firm.clients_of_firm.destroy(client)
    end
  end

  def test_clearing_an_association_collection
    firm = companies(:first_firm)
    client_id = firm.clients_of_firm.first.id
    assert_equal 2, firm.clients_of_firm.size

    firm.clients_of_firm.clear

    assert_equal 0, firm.clients_of_firm.size
    assert_equal 0, firm.clients_of_firm.reload.size
    assert_equal [], Client.destroyed_client_ids[firm.id]

    # Should not be destroyed since the association is not dependent.
    assert_nothing_raised do
      assert_nil Client.find(client_id).firm
    end
  end

  def test_clearing_updates_counter_cache
    topic = Topic.first

    assert_difference "topic.reload.replies_count", -1 do
      topic.replies.clear
    end
  end

  def test_clearing_updates_counter_cache_when_inverse_counter_cache_is_a_symbol_with_dependent_destroy
    car = Car.first
    car.engines.create!

    assert_difference "car.reload.engines_count", -1 do
      car.engines.clear
    end
  end

  def test_clearing_a_dependent_association_collection
    firm = companies(:first_firm)
    client_id = firm.dependent_clients_of_firm.first.id
    assert_equal 2, firm.dependent_clients_of_firm.size
    assert_equal 1, Client.find_by_id(client_id).client_of

    # :delete_all is called on each client since the dependent options is :destroy
    firm.dependent_clients_of_firm.clear

    assert_equal 0, firm.dependent_clients_of_firm.size
    assert_equal 0, firm.dependent_clients_of_firm.reload.size
    assert_equal [], Client.destroyed_client_ids[firm.id]

    # Should be destroyed since the association is dependent.
    assert_nil Client.find_by_id(client_id)
  end

  def test_delete_all_with_option_delete_all
    firm = companies(:first_firm)
    client_id = firm.dependent_clients_of_firm.first.id
    firm.dependent_clients_of_firm.delete_all(:delete_all)
    assert_nil Client.find_by_id(client_id)
  end

  def test_delete_all_accepts_limited_parameters
    firm = companies(:first_firm)
    assert_raise(ArgumentError) do
      firm.dependent_clients_of_firm.delete_all(:destroy)
    end
  end

  def test_clearing_an_exclusively_dependent_association_collection
    firm = companies(:first_firm)
    client_id = firm.exclusively_dependent_clients_of_firm.first.id
    assert_equal 2, firm.exclusively_dependent_clients_of_firm.size

    assert_equal [], Client.destroyed_client_ids[firm.id]

    # :exclusively_dependent means each client is deleted directly from
    # the database without looping through them calling destroy.
    firm.exclusively_dependent_clients_of_firm.clear

    assert_equal 0, firm.exclusively_dependent_clients_of_firm.size
    assert_equal 0, firm.exclusively_dependent_clients_of_firm.reload.size
    # no destroy-filters should have been called
    assert_equal [], Client.destroyed_client_ids[firm.id]

    # Should be destroyed since the association is exclusively dependent.
    assert_nil Client.find_by_id(client_id)
  end

  def test_dependent_association_respects_optional_conditions_on_delete
    firm = companies(:odegy)
    Client.create(client_of: firm.id, name: "BigShot Inc.")
    Client.create(client_of: firm.id, name: "SmallTime Inc.")
    # only one of two clients is included in the association due to the :conditions key
    assert_equal 2, Client.where(client_of: firm.id).size
    assert_equal 1, firm.dependent_conditional_clients_of_firm.size
    firm.destroy
    # only the correctly associated client should have been deleted
    assert_equal 1, Client.where(client_of: firm.id).size
  end

  def test_dependent_association_respects_optional_sanitized_conditions_on_delete
    firm = companies(:odegy)
    Client.create(client_of: firm.id, name: "BigShot Inc.")
    Client.create(client_of: firm.id, name: "SmallTime Inc.")
    # only one of two clients is included in the association due to the :conditions key
    assert_equal 2, Client.where(client_of: firm.id).size
    assert_equal 1, firm.dependent_sanitized_conditional_clients_of_firm.size
    firm.destroy
    # only the correctly associated client should have been deleted
    assert_equal 1, Client.where(client_of: firm.id).size
  end

  def test_dependent_association_respects_optional_hash_conditions_on_delete
    firm = companies(:odegy)
    Client.create(client_of: firm.id, name: "BigShot Inc.")
    Client.create(client_of: firm.id, name: "SmallTime Inc.")
    # only one of two clients is included in the association due to the :conditions key
    assert_equal 2, Client.where(client_of: firm.id).size
    assert_equal 1, firm.dependent_hash_conditional_clients_of_firm.size
    firm.destroy
    # only the correctly associated client should have been deleted
    assert_equal 1, Client.where(client_of: firm.id).size
  end

  def test_delete_all_association_with_primary_key_deletes_correct_records
    firm = Firm.first
    # break the vanilla firm_id foreign key
    assert_equal 3, firm.clients.count
    firm.clients.first.update_columns(firm_id: nil)
    assert_equal 2, firm.clients.reload.count
    assert_equal 2, firm.clients_using_primary_key_with_delete_all.count
    old_record = firm.clients_using_primary_key_with_delete_all.first
    firm = Firm.first
    firm.destroy
    assert_nil Client.find_by_id(old_record.id)
  end

  def test_creation_respects_hash_condition
    ms_client = companies(:first_firm).clients_like_ms_with_hash_conditions.build

    assert ms_client.save
    assert_equal "Microsoft", ms_client.name

    another_ms_client = companies(:first_firm).clients_like_ms_with_hash_conditions.create

    assert_predicate another_ms_client, :persisted?
    assert_equal "Microsoft", another_ms_client.name
  end

  def test_clearing_without_initial_access
    firm = companies(:first_firm)

    firm.clients_of_firm.clear

    assert_equal 0, firm.clients_of_firm.size
    assert_equal 0, firm.clients_of_firm.reload.size
  end

  def test_deleting_a_item_which_is_not_in_the_collection
    force_signal37_to_load_all_clients_of_firm

    assert_predicate companies(:first_firm).clients_of_firm, :loaded?

    summit = Client.find_by_name("Summit")
    companies(:first_firm).clients_of_firm.delete(summit)
    assert_equal 2, companies(:first_firm).clients_of_firm.size
    assert_equal 2, companies(:first_firm).clients_of_firm.reload.size
    assert_equal 2, summit.client_of
  end

  def test_deleting_by_integer_id
    david = Developer.find(1)

    assert_difference "david.projects.count", -1 do
      assert_equal 1, david.projects.delete(1).size
    end

    assert_equal 1, david.projects.size
  end

  def test_deleting_by_string_id
    david = Developer.find(1)

    assert_difference "david.projects.count", -1 do
      assert_equal 1, david.projects.delete("1").size
    end

    assert_equal 1, david.projects.size
  end

  def test_deleting_self_type_mismatch
    david = Developer.find(1)
    david.projects.reload
    assert_raise(ActiveRecord::AssociationTypeMismatch) { david.projects.delete(Project.find(1).developers) }
  end

  def test_destroying
    force_signal37_to_load_all_clients_of_firm

    assert_predicate companies(:first_firm).clients_of_firm, :loaded?

    assert_difference "Client.count", -1 do
      companies(:first_firm).clients_of_firm.destroy(companies(:first_firm).clients_of_firm.first)
    end

    assert_equal 1, companies(:first_firm).reload.clients_of_firm.size
    assert_equal 1, companies(:first_firm).clients_of_firm.reload.size
  end

  def test_destroying_by_integer_id
    force_signal37_to_load_all_clients_of_firm

    assert_predicate companies(:first_firm).clients_of_firm, :loaded?

    assert_difference "Client.count", -1 do
      companies(:first_firm).clients_of_firm.destroy(companies(:first_firm).clients_of_firm.first.id)
    end

    assert_equal 1, companies(:first_firm).reload.clients_of_firm.size
    assert_equal 1, companies(:first_firm).clients_of_firm.reload.size
  end

  def test_destroying_by_string_id
    force_signal37_to_load_all_clients_of_firm

    assert_predicate companies(:first_firm).clients_of_firm, :loaded?

    assert_difference "Client.count", -1 do
      companies(:first_firm).clients_of_firm.destroy(companies(:first_firm).clients_of_firm.first.id.to_s)
    end

    assert_equal 1, companies(:first_firm).reload.clients_of_firm.size
    assert_equal 1, companies(:first_firm).clients_of_firm.reload.size
  end

  def test_destroying_a_collection
    force_signal37_to_load_all_clients_of_firm

    assert_predicate companies(:first_firm).clients_of_firm, :loaded?

    companies(:first_firm).clients_of_firm.create("name" => "Another Client")
    assert_equal 3, companies(:first_firm).clients_of_firm.size

    assert_difference "Client.count", -2 do
      companies(:first_firm).clients_of_firm.destroy([companies(:first_firm).clients_of_firm[0], companies(:first_firm).clients_of_firm[1]])
    end

    assert_equal 1, companies(:first_firm).reload.clients_of_firm.size
    assert_equal 1, companies(:first_firm).clients_of_firm.reload.size
  end

  def test_destroy_all
    force_signal37_to_load_all_clients_of_firm

    assert_predicate companies(:first_firm).clients_of_firm, :loaded?

    clients = companies(:first_firm).clients_of_firm.to_a
    assert !clients.empty?, "37signals has clients after load"
    destroyed = companies(:first_firm).clients_of_firm.destroy_all
    assert_equal clients.sort_by(&:id), destroyed.sort_by(&:id)
    assert destroyed.all?(&:frozen?), "destroyed clients should be frozen"
    assert companies(:first_firm).clients_of_firm.empty?, "37signals has no clients after destroy all"
    assert companies(:first_firm).clients_of_firm.reload.empty?, "37signals has no clients after destroy all and refresh"
  end

  def test_dependence
    firm = companies(:first_firm)
    assert_equal 3, firm.clients.size
    firm.destroy
    assert_empty Client.all.merge!(where: "firm_id=#{firm.id}").to_a
  end

  def test_dependence_for_associations_with_hash_condition
    david = authors(:david)
    assert_difference("Post.count", -1) { assert david.destroy }
  end

  def test_destroy_dependent_when_deleted_from_association
    firm = Firm.first
    assert_equal 3, firm.clients.size

    client = firm.clients.first
    firm.clients.delete(client)

    assert_raise(ActiveRecord::RecordNotFound) { Client.find(client.id) }
    assert_raise(ActiveRecord::RecordNotFound) { firm.clients.find(client.id) }
    assert_equal 2, firm.clients.size
  end

  def test_three_levels_of_dependence
    topic = Topic.create "title" => "neat and simple"
    reply = topic.replies.create "title" => "neat and simple", "content" => "still digging it"
    reply.replies.create "title" => "neat and simple", "content" => "ain't complaining"

    assert_nothing_raised { topic.destroy }
  end

  def test_dependence_with_transaction_support_on_failure
    firm = companies(:first_firm)
    clients = firm.clients
    assert_equal 3, clients.length
    clients.last.instance_eval { def overwrite_to_raise() raise "Trigger rollback" end }

    firm.destroy rescue "do nothing"

    assert_equal 3, Client.all.merge!(where: "firm_id=#{firm.id}").to_a.size
  end

  def test_dependence_on_account
    num_accounts = Account.count
    companies(:first_firm).destroy
    assert_equal num_accounts - 1, Account.count
  end

  def test_depends_and_nullify
    num_accounts = Account.count

    core = companies(:rails_core)
    assert_equal accounts(:rails_core_account), core.account
    assert_equal companies(:leetsoft, :jadedpixel), core.companies
    core.destroy
    assert_nil accounts(:rails_core_account).reload.firm_id
    assert_nil companies(:leetsoft).reload.client_of
    assert_nil companies(:jadedpixel).reload.client_of

    assert_equal num_accounts, Account.count
  end

  def test_restrict_with_exception
    firm = RestrictedWithExceptionFirm.create!(name: "restrict")
    firm.companies.create(name: "child")

    assert_not_empty firm.companies
    assert_raise(ActiveRecord::DeleteRestrictionError) { firm.destroy }
    assert RestrictedWithExceptionFirm.exists?(name: "restrict")
    assert firm.companies.exists?(name: "child")
  end

  def test_restrict_with_error
    firm = RestrictedWithErrorFirm.create!(name: "restrict")
    firm.companies.create(name: "child")

    assert_not_empty firm.companies

    firm.destroy

    assert_not_empty firm.errors

    assert_equal "Cannot delete record because dependent companies exist", firm.errors[:base].first
    assert RestrictedWithErrorFirm.exists?(name: "restrict")
    assert firm.companies.exists?(name: "child")
  end

  def test_restrict_with_error_with_locale
    I18n.backend = I18n::Backend::Simple.new
    I18n.backend.store_translations "en", activerecord: { attributes: { restricted_with_error_firm: { companies: "client companies" } } }
    firm = RestrictedWithErrorFirm.create!(name: "restrict")
    firm.companies.create(name: "child")

    assert_not_empty firm.companies

    firm.destroy

    assert_not_empty firm.errors

    assert_equal "Cannot delete record because dependent client companies exist", firm.errors[:base].first
    assert RestrictedWithErrorFirm.exists?(name: "restrict")
    assert firm.companies.exists?(name: "child")
  ensure
    I18n.backend.reload!
  end

  def test_included_in_collection
    assert_equal true, companies(:first_firm).clients.include?(Client.find(2))
  end

  def test_included_in_collection_for_new_records
    client = Client.create(name: "Persisted")
    assert_nil client.client_of
    assert_equal false, Firm.new.clients_of_firm.include?(client),
     "includes a client that does not belong to any firm"
  end

  def test_adding_array_and_collection
    assert_nothing_raised { Firm.first.clients + Firm.all.last.clients }
  end

  def test_replace_with_less
    firm = Firm.first
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
    firm = Firm.first
    firm.clients = [companies(:second_client), Client.new("name" => "New Client")]
    firm.save
    firm.reload
    assert_equal 2, firm.clients.length
    assert_equal false, firm.clients.include?(:first_client)
  end

  def test_replace_failure
    firm = companies(:first_firm)
    account = Account.new
    orig_accounts = firm.accounts.to_a

    assert_not_predicate account, :valid?
    assert_not_empty orig_accounts
    error = assert_raise ActiveRecord::RecordNotSaved do
      firm.accounts = [account]
    end

    assert_equal orig_accounts, firm.accounts
    assert_equal "Failed to replace accounts because one or more of the " \
                 "new records could not be saved.", error.message
  end

  def test_replace_with_same_content
    firm = Firm.first
    firm.clients = []
    firm.save

    assert_queries(0, ignore_none: true) do
      firm.clients = []
    end

    assert_equal [], firm.send("clients=", [])
  end

  def test_transactions_when_replacing_on_persisted
    good = Client.new(name: "Good")
    bad  = Client.new(name: "Bad", raise_on_save: true)

    companies(:first_firm).clients_of_firm = [good]

    begin
      companies(:first_firm).clients_of_firm = [bad]
    rescue Client::RaisedOnSave
    end

    assert_equal [good], companies(:first_firm).clients_of_firm.reload
  end

  def test_transactions_when_replacing_on_new_record
    assert_no_queries(ignore_none: false) do
      firm = Firm.new
      firm.clients_of_firm = [Client.new("name" => "New Client")]
    end
  end

  def test_get_ids
    assert_equal [companies(:first_client).id, companies(:second_client).id, companies(:another_first_firm_client).id], companies(:first_firm).client_ids
  end

  def test_get_ids_for_loaded_associations
    company = companies(:first_firm)
    company.clients.reload
    assert_queries(0) do
      company.client_ids
      company.client_ids
    end
  end

  def test_get_ids_for_unloaded_associations_does_not_load_them
    company = companies(:first_firm)
    assert_not_predicate company.clients, :loaded?
    assert_equal [companies(:first_client).id, companies(:second_client).id, companies(:another_first_firm_client).id], company.client_ids
    assert_not_predicate company.clients, :loaded?
  end

  def test_counter_cache_on_unloaded_association
    car = Car.create(name: "My AppliCar")
    assert_equal car.engines.size, 0
  end

  def test_get_ids_ignores_include_option
    assert_equal [readers(:michael_welcome).id], posts(:welcome).readers_with_person_ids
  end

  def test_get_ids_for_ordered_association
    assert_equal [companies(:another_first_firm_client).id, companies(:second_client).id, companies(:first_client).id], companies(:first_firm).clients_ordered_by_name_ids
  end

  def test_get_ids_for_association_on_new_record_does_not_try_to_find_records
    Company.columns  # Load schema information so we don't query below
    Contract.columns # if running just this test.

    company = Company.new
    assert_queries(0) do
      company.contract_ids
    end

    assert_equal [], company.contract_ids
  end

  def test_set_ids_for_association_on_new_record_applies_association_correctly
    contract_a = Contract.create!
    contract_b = Contract.create!
    Contract.create! # another contract
    company = Company.new(name: "Some Company")

    company.contract_ids = [contract_a.id, contract_b.id]
    assert_equal [contract_a.id, contract_b.id], company.contract_ids
    assert_equal [contract_a, contract_b], company.contracts

    company.save!
    assert_equal company, contract_a.reload.company
    assert_equal company, contract_b.reload.company
  end

  def test_assign_ids_ignoring_blanks
    firm = Firm.create!(name: "Apple")
    firm.client_ids = [companies(:first_client).id, nil, companies(:second_client).id, ""]
    firm.save!

    assert_equal 2, firm.clients.reload.size
    assert_equal true, firm.clients.include?(companies(:second_client))
  end

  def test_get_ids_for_through
    assert_equal [comments(:eager_other_comment1).id], authors(:mary).comment_ids
  end

  def test_modifying_a_through_a_has_many_should_raise
    [
      lambda { authors(:mary).comment_ids = [comments(:greetings).id, comments(:more_greetings).id] },
      lambda { authors(:mary).comments = [comments(:greetings), comments(:more_greetings)] },
      lambda { authors(:mary).comments << Comment.create!(body: "Yay", post_id: 424242) },
      lambda { authors(:mary).comments.delete(authors(:mary).comments.first) },
    ].each { |block| assert_raise(ActiveRecord::HasManyThroughCantAssociateThroughHasOneOrManyReflection, &block) }
  end

  def test_associations_order_should_be_priority_over_throughs_order
    david = authors(:david)
    expected = [12, 10, 9, 8, 7, 6, 5, 3, 2, 1]
    assert_equal expected, david.comments_desc.map(&:id)
    assert_equal expected, Author.includes(:comments_desc).find(david.id).comments_desc.map(&:id)
  end

  def test_dynamic_find_should_respect_association_order_for_through
    assert_equal Comment.find(10), authors(:david).comments_desc.where("comments.type = 'SpecialComment'").first
    assert_equal Comment.find(10), authors(:david).comments_desc.find_by_type("SpecialComment")
  end

  def test_has_many_through_respects_hash_conditions
    assert_equal authors(:david).hello_posts, authors(:david).hello_posts_with_hash_conditions
    assert_equal authors(:david).hello_post_comments, authors(:david).hello_post_comments_with_hash_conditions
  end

  def test_include_uses_array_include_after_loaded
    firm = companies(:first_firm)
    firm.clients.load_target

    client = firm.clients.first

    assert_no_queries do
      assert_predicate firm.clients, :loaded?
      assert_equal true, firm.clients.include?(client)
    end
  end

  def test_include_checks_if_record_exists_if_target_not_loaded
    firm = companies(:first_firm)
    client = firm.clients.first

    firm.reload
    assert_not_predicate firm.clients, :loaded?
    assert_queries(1) do
      assert_equal true, firm.clients.include?(client)
    end
    assert_not_predicate firm.clients, :loaded?
  end

  def test_include_returns_false_for_non_matching_record_to_verify_scoping
    firm = companies(:first_firm)
    client = Client.create!(name: "Not Associated")

    assert_not_predicate firm.clients, :loaded?
    assert_equal false, firm.clients.include?(client)
  end

  def test_calling_first_nth_or_last_on_association_should_not_load_association
    firm = companies(:first_firm)
    firm.clients.first
    firm.clients.second
    firm.clients.last
    assert_not_predicate firm.clients, :loaded?
  end

  def test_calling_first_or_last_on_loaded_association_should_not_fetch_with_query
    firm = companies(:first_firm)
    firm.clients.load_target
    assert_predicate firm.clients, :loaded?

    assert_no_queries(ignore_none: false) do
      firm.clients.first
      assert_equal 2, firm.clients.first(2).size
      firm.clients.last
      assert_equal 2, firm.clients.last(2).size
    end
  end

  def test_calling_first_or_last_on_existing_record_with_build_should_load_association
    firm = companies(:first_firm)
    firm.clients.build(name: "Foo")
    assert_not_predicate firm.clients, :loaded?

    assert_queries 1 do
      firm.clients.first
      firm.clients.second
      firm.clients.last
    end

    assert_predicate firm.clients, :loaded?
  end

  def test_calling_first_nth_or_last_on_existing_record_with_create_should_not_load_association
    firm = companies(:first_firm)
    firm.clients.create(name: "Foo")
    assert_not_predicate firm.clients, :loaded?

    assert_queries 3 do
      firm.clients.first
      firm.clients.second
      firm.clients.last
    end

    assert_not_predicate firm.clients, :loaded?
  end

  def test_calling_first_nth_or_last_on_new_record_should_not_run_queries
    firm = Firm.new

    assert_no_queries do
      firm.clients.first
      firm.clients.second
      firm.clients.last
    end
  end

  def test_calling_first_or_last_with_integer_on_association_should_not_load_association
    firm = companies(:first_firm)
    firm.clients.create(name: "Foo")
    assert_not_predicate firm.clients, :loaded?

    assert_queries 2 do
      firm.clients.first(2)
      firm.clients.last(2)
    end

    assert_not_predicate firm.clients, :loaded?
  end

  def test_calling_many_should_count_instead_of_loading_association
    firm = companies(:first_firm)
    assert_queries(1) do
      firm.clients.many?  # use count query
    end
    assert_not_predicate firm.clients, :loaded?
  end

  def test_calling_many_on_loaded_association_should_not_use_query
    firm = companies(:first_firm)
    firm.clients.load  # force load
    assert_no_queries { assert firm.clients.many? }
  end

  def test_calling_many_should_defer_to_collection_if_using_a_block
    firm = companies(:first_firm)
    assert_queries(1) do
      firm.clients.expects(:size).never
      firm.clients.many? { true }
    end
    assert_predicate firm.clients, :loaded?
  end

  def test_calling_many_should_return_false_if_none_or_one
    firm = companies(:another_firm)
    assert_not_predicate firm.clients_like_ms, :many?
    assert_equal 0, firm.clients_like_ms.size

    firm = companies(:first_firm)
    assert_not_predicate firm.limited_clients, :many?
    assert_equal 1, firm.limited_clients.size
  end

  def test_calling_many_should_return_true_if_more_than_one
    firm = companies(:first_firm)
    assert_predicate firm.clients, :many?
    assert_equal 3, firm.clients.size
  end

  def test_calling_none_should_count_instead_of_loading_association
    firm = companies(:first_firm)
    assert_queries(1) do
      firm.clients.none?  # use count query
    end
    assert_not_predicate firm.clients, :loaded?
  end

  def test_calling_none_on_loaded_association_should_not_use_query
    firm = companies(:first_firm)
    firm.clients.load  # force load
    assert_no_queries { assert ! firm.clients.none? }
  end

  def test_calling_none_should_defer_to_collection_if_using_a_block
    firm = companies(:first_firm)
    assert_queries(1) do
      firm.clients.expects(:size).never
      firm.clients.none? { true }
    end
    assert_predicate firm.clients, :loaded?
  end

  def test_calling_none_should_return_true_if_none
    firm = companies(:another_firm)
    assert_predicate firm.clients_like_ms, :none?
    assert_equal 0, firm.clients_like_ms.size
  end

  def test_calling_none_should_return_false_if_any
    firm = companies(:first_firm)
    assert_not_predicate firm.limited_clients, :none?
    assert_equal 1, firm.limited_clients.size
  end

  def test_calling_one_should_count_instead_of_loading_association
    firm = companies(:first_firm)
    assert_queries(1) do
      firm.clients.one?  # use count query
    end
    assert_not_predicate firm.clients, :loaded?
  end

  def test_calling_one_on_loaded_association_should_not_use_query
    firm = companies(:first_firm)
    firm.clients.load  # force load
    assert_no_queries { assert ! firm.clients.one? }
  end

  def test_calling_one_should_defer_to_collection_if_using_a_block
    firm = companies(:first_firm)
    assert_queries(1) do
      firm.clients.expects(:size).never
      firm.clients.one? { true }
    end
    assert_predicate firm.clients, :loaded?
  end

  def test_calling_one_should_return_false_if_zero
    firm = companies(:another_firm)
    assert_not_predicate firm.clients_like_ms, :one?
    assert_equal 0, firm.clients_like_ms.size
  end

  def test_calling_one_should_return_true_if_one
    firm = companies(:first_firm)
    assert_predicate firm.limited_clients, :one?
    assert_equal 1, firm.limited_clients.size
  end

  def test_calling_one_should_return_false_if_more_than_one
    firm = companies(:first_firm)
    assert_not_predicate firm.clients, :one?
    assert_equal 3, firm.clients.size
  end

  def test_joins_with_namespaced_model_should_use_correct_type
    old = ActiveRecord::Base.store_full_sti_class
    ActiveRecord::Base.store_full_sti_class = true

    firm = Namespaced::Firm.create(name: "Some Company")
    firm.clients.create(name: "Some Client")

    stats = Namespaced::Firm.all.merge!(
      select: "#{Namespaced::Firm.table_name}.id, COUNT(#{Namespaced::Client.table_name}.id) AS num_clients",
      joins: :clients,
      group: "#{Namespaced::Firm.table_name}.id"
    ).find firm.id
    assert_equal 1, stats.num_clients.to_i
  ensure
    ActiveRecord::Base.store_full_sti_class = old
  end

  def test_association_proxy_transaction_method_starts_transaction_in_association_class
    Comment.expects(:transaction)
    Post.first.comments.transaction do
      # nothing
    end
  end

  def test_sending_new_to_association_proxy_should_have_same_effect_as_calling_new
    client_association = companies(:first_firm).clients
    assert_equal client_association.new.attributes, client_association.send(:new).attributes
  end

  def test_creating_using_primary_key
    firm = Firm.first
    client = firm.clients_using_primary_key.create!(name: "test")
    assert_equal firm.name, client.firm_name
  end

  def test_defining_has_many_association_with_delete_all_dependency_lazily_evaluates_target_class
    ActiveRecord::Reflection::AssociationReflection.any_instance.expects(:class_name).never
    class_eval(<<-EOF, __FILE__, __LINE__ + 1)
      class DeleteAllModel < ActiveRecord::Base
        has_many :nonentities, :dependent => :delete_all
      end
    EOF
  end

  def test_defining_has_many_association_with_nullify_dependency_lazily_evaluates_target_class
    ActiveRecord::Reflection::AssociationReflection.any_instance.expects(:class_name).never
    class_eval(<<-EOF, __FILE__, __LINE__ + 1)
      class NullifyModel < ActiveRecord::Base
        has_many :nonentities, :dependent => :nullify
      end
    EOF
  end

  def test_attributes_are_being_set_when_initialized_from_has_many_association_with_where_clause
    new_comment = posts(:welcome).comments.where(body: "Some content").build
    assert_equal new_comment.body, "Some content"
  end

  def test_attributes_are_being_set_when_initialized_from_has_many_association_with_multiple_where_clauses
    new_comment = posts(:welcome).comments.where(body: "Some content").where(type: "SpecialComment").build
    assert_equal new_comment.body, "Some content"
    assert_equal new_comment.type, "SpecialComment"
    assert_equal new_comment.post_id, posts(:welcome).id
  end

  def test_include_method_in_has_many_association_should_return_true_for_instance_added_with_build
    post = Post.new
    comment = post.comments.build
    assert_equal true, post.comments.include?(comment)
  end

  def test_load_target_respects_protected_attributes
    topic = Topic.create!
    reply = topic.replies.create(title: "reply 1")
    reply.approved = false
    reply.save!

    # Save with a different object instance, so the instance that's still held
    # in topic.relies doesn't know about the changed attribute.
    reply2 = Reply.find(reply.id)
    reply2.approved = true
    reply2.save!

    # Force loading the collection from the db. This will merge the existing
    # object (reply) with what gets loaded from the db (which includes the
    # changed approved attribute). approved is a protected attribute, so if mass
    # assignment is used, it won't get updated and will still be false.
    first = topic.replies.to_a.first
    assert_equal reply.id, first.id
    assert_equal true, first.approved?
  end

  def test_to_a_should_dup_target
    ary    = topics(:first).replies.to_a
    target = topics(:first).replies.target

    assert_not_equal target.object_id, ary.object_id
  end

  def test_merging_with_custom_attribute_writer
    bulb = Bulb.new(color: "red")
    assert_equal "RED!", bulb.color

    car = Car.create!
    car.bulbs << bulb

    assert_equal "RED!", car.bulbs.to_a.first.color
  end

  def test_abstract_class_with_polymorphic_has_many
    post = SubStiPost.create! title: "fooo", body: "baa"
    tagging = Tagging.create! taggable: post
    assert_equal [tagging], post.taggings
  end

  def test_with_polymorphic_has_many_with_custom_columns_name
    post = Post.create! title: "foo", body: "bar"
    image = Image.create!

    post.images << image

    assert_equal [image], post.images
  end

  def test_build_with_polymorphic_has_many_does_not_allow_to_override_type_and_id
    welcome = posts(:welcome)
    tagging = welcome.taggings.build(taggable_id: 99, taggable_type: "ShouldNotChange")

    assert_equal welcome.id, tagging.taggable_id
    assert_equal "Post", tagging.taggable_type
  end

  def test_build_from_polymorphic_association_sets_inverse_instance
    post = Post.new
    tagging = post.taggings.build

    assert_equal post, tagging.taggable
  end

  def test_dont_call_save_callbacks_twice_on_has_many
    firm = companies(:first_firm)
    contract = firm.contracts.create!

    assert_equal 1, contract.hi_count
    assert_equal 1, contract.bye_count
  end

  def test_association_attributes_are_available_to_after_initialize
    car = Car.create(name: "honda")
    bulb = car.bulbs.build

    assert_equal car.id, bulb.attributes_after_initialize["car_id"]
  end

  def test_attributes_are_set_when_initialized_from_has_many_null_relationship
    car  = Car.new name: "honda"
    bulb = car.bulbs.where(name: "headlight").first_or_initialize
    assert_equal "headlight", bulb.name
  end

  def test_attributes_are_set_when_initialized_from_polymorphic_has_many_null_relationship
    post    = Post.new title: "title", body: "bar"
    tag     = Tag.create!(name: "foo")

    tagging = post.taggings.where(tag: tag).first_or_initialize

    assert_equal tag.id, tagging.tag_id
    assert_equal "Post", tagging.taggable_type
  end

  def test_replace
    car = Car.create(name: "honda")
    bulb1 = car.bulbs.create
    bulb2 = Bulb.create

    assert_equal [bulb1], car.bulbs
    car.bulbs.replace([bulb2])
    assert_equal [bulb2], car.bulbs
    assert_equal [bulb2], car.reload.bulbs
  end

  def test_replace_returns_target
    car = Car.create(name: "honda")
    bulb1 = car.bulbs.create
    bulb2 = car.bulbs.create
    bulb3 = Bulb.create

    assert_equal [bulb1, bulb2], car.bulbs
    result = car.bulbs.replace([bulb3, bulb1])
    assert_equal [bulb1, bulb3], car.bulbs
    assert_equal [bulb1, bulb3], result
  end

  def test_collection_association_with_private_kernel_method
    firm = companies(:first_firm)
    assert_equal [accounts(:signals37)], firm.accounts.open
  end

  test "first_or_initialize adds the record to the association" do
    firm = Firm.create! name: "omg"
    client = firm.clients_of_firm.first_or_initialize
    assert_equal [client], firm.clients_of_firm
  end

  test "first_or_create adds the record to the association" do
    firm = Firm.create! name: "omg"
    firm.clients_of_firm.load_target
    client = firm.clients_of_firm.first_or_create name: "lol"
    assert_equal [client], firm.clients_of_firm
    assert_equal [client], firm.reload.clients_of_firm
  end

  test "delete_all, when not loaded, doesn't load the records" do
    post = posts(:welcome)

    assert post.taggings_with_delete_all.count > 0
    assert_not_predicate post.taggings_with_delete_all, :loaded?

    # 2 queries: one DELETE and another to update the counter cache
    assert_queries(2) do
      post.taggings_with_delete_all.delete_all
    end
  end

  test "has many associations on new records use null relations" do
    post = Post.new

    assert_no_queries(ignore_none: false) do
      assert_equal [], post.comments
      assert_equal [], post.comments.where(body: "omg")
      assert_equal [], post.comments.pluck(:body)
      assert_equal 0,  post.comments.sum(:id)
      assert_equal 0,  post.comments.count
    end
  end

  test "collection proxy respects default scope" do
    author = authors(:mary)
    assert_not_predicate author.first_posts, :exists?
  end

  test "association with extend option" do
    post = posts(:welcome)
    assert_equal "lifo",  post.comments_with_extend.author
    assert_equal "hello", post.comments_with_extend.greeting
  end

  test "association with extend option with multiple extensions" do
    post = posts(:welcome)
    assert_equal "lifo",  post.comments_with_extend_2.author
    assert_equal "hullo", post.comments_with_extend_2.greeting
  end

  test "extend option affects per association" do
    post = posts(:welcome)
    assert_equal "lifo",  post.comments_with_extend.author
    assert_equal "lifo",  post.comments_with_extend_2.author
    assert_equal "hello", post.comments_with_extend.greeting
    assert_equal "hullo", post.comments_with_extend_2.greeting
  end

  test "delete record with complex joins" do
    david = authors(:david)

    post = david.posts.first
    post.type = "PostWithSpecialCategorization"
    post.save

    categorization = post.categorizations.first
    categorization.special = true
    categorization.save

    assert_not_equal [], david.posts_with_special_categorizations
    david.posts_with_special_categorizations = []
    assert_equal [], david.posts_with_special_categorizations
  end

  test "does not duplicate associations when used with natural primary keys" do
    speedometer = Speedometer.create!(id: "4")
    speedometer.minivans.create!(minivan_id: "a-van-red", name: "a van", color: "red")

    assert_equal 1, speedometer.minivans.to_a.size, "Only one association should be present:\n#{speedometer.minivans.to_a}"
    assert_equal 1, speedometer.reload.minivans.to_a.size
  end

  test "can unscope the default scope of the associated model" do
    car = Car.create!
    bulb1 = Bulb.create! name: "defaulty", car: car
    bulb2 = Bulb.create! name: "other",    car: car

    assert_equal [bulb1], car.bulbs
    assert_equal [bulb1, bulb2], car.all_bulbs.sort_by(&:id)
  end

  test "can unscope and where the default scope of the associated model" do
    Car.has_many :other_bulbs, -> { unscope(where: [:name]).where(name: "other") }, class_name: "Bulb"
    car = Car.create!
    bulb1 = Bulb.create! name: "defaulty", car: car
    bulb2 = Bulb.create! name: "other",    car: car

    assert_equal [bulb1], car.bulbs
    assert_equal [bulb2], car.other_bulbs
  end

  test "can rewhere the default scope of the associated model" do
    Car.has_many :old_bulbs, -> { rewhere(name: "old") }, class_name: "Bulb"
    car = Car.create!
    bulb1 = Bulb.create! name: "defaulty", car: car
    bulb2 = Bulb.create! name: "old",      car: car

    assert_equal [bulb1], car.bulbs
    assert_equal [bulb2], car.old_bulbs
  end

  test "unscopes the default scope of associated model when used with include" do
    car = Car.create!
    bulb = Bulb.create! name: "other", car: car

    assert_equal [bulb], Car.find(car.id).all_bulbs
    assert_equal [bulb], Car.includes(:all_bulbs).find(car.id).all_bulbs
    assert_equal [bulb], Car.eager_load(:all_bulbs).find(car.id).all_bulbs
  end

  test "raises RecordNotDestroyed when replaced child can't be destroyed" do
    car = Car.create!
    original_child = FailedBulb.create!(car: car)

    error = assert_raise(ActiveRecord::RecordNotDestroyed) do
      car.failed_bulbs = [FailedBulb.create!]
    end

    assert_equal [original_child], car.reload.failed_bulbs
    assert_equal "Failed to destroy the record", error.message
  end

  test "updates counter cache when default scope is given" do
    topic = DefaultRejectedTopic.create approved: true

    assert_difference "topic.reload.replies_count", 1 do
      topic.approved_replies.create!
    end
  end

  test "dangerous association name raises ArgumentError" do
    [:errors, "errors", :save, "save"].each do |name|
      assert_raises(ArgumentError, "Association #{name} should not be allowed") do
        Class.new(ActiveRecord::Base) do
          has_many name
        end
      end
    end
  end

  test "passes custom context validation to validate children" do
    pirate = FamousPirate.new
    pirate.famous_ships << ship = FamousShip.new

    assert_predicate pirate, :valid?
    assert_not pirate.valid?(:conference)
    assert_equal "can't be blank", ship.errors[:name].first
  end

  test "association with instance dependent scope" do
    bob = authors(:bob)
    Post.create!(title: "signed post by bob", body: "stuff", author: authors(:bob))
    Post.create!(title: "anonymous post", body: "more stuff", author: authors(:bob))
    assert_equal ["misc post by bob", "other post by bob",
                  "signed post by bob"], bob.posts_with_signature.map(&:title).sort

    assert_equal [], authors(:david).posts_with_signature.map(&:title)
  end

  test "associations autosaves when object is already persisted" do
    bulb = Bulb.create!
    tyre = Tyre.create!

    car = Car.create! do |c|
      c.bulbs << bulb
      c.tyres << tyre
    end

    assert_equal 1, car.bulbs.count
    assert_equal 1, car.tyres.count
  end

  test "associations replace in memory when records have the same id" do
    bulb = Bulb.create!
    car = Car.create!(bulbs: [bulb])

    new_bulb = Bulb.find(bulb.id)
    new_bulb.name = "foo"
    car.bulbs = [new_bulb]

    assert_equal "foo", car.bulbs.first.name
  end

  test "in memory replacement executes no queries" do
    bulb = Bulb.create!
    car = Car.create!(bulbs: [bulb])

    new_bulb = Bulb.find(bulb.id)

    assert_no_queries do
      car.bulbs = [new_bulb]
    end
  end

  test "in memory replacements do not execute callbacks" do
    raise_after_add = false
    klass = Class.new(ActiveRecord::Base) do
      self.table_name = :cars
      has_many :bulbs, after_add: proc { raise if raise_after_add }

      def self.name
        "Car"
      end
    end
    bulb = Bulb.create!
    car = klass.create!(bulbs: [bulb])

    new_bulb = Bulb.find(bulb.id)
    raise_after_add = true

    assert_nothing_raised do
      car.bulbs = [new_bulb]
    end
  end

  test "in memory replacements sets inverse instance" do
    bulb = Bulb.create!
    car = Car.create!(bulbs: [bulb])

    new_bulb = Bulb.find(bulb.id)
    car.bulbs = [new_bulb]

    assert_same car, new_bulb.car
  end

  test "reattach to new objects replaces inverse association and foreign key" do
    bulb = Bulb.create!(car: Car.create!)
    assert bulb.car_id
    car = Car.new
    car.bulbs << bulb
    assert_equal car, bulb.car
    assert_nil bulb.car_id
  end

  test "in memory replacement maintains order" do
    first_bulb = Bulb.create!
    second_bulb = Bulb.create!
    car = Car.create!(bulbs: [first_bulb, second_bulb])

    same_bulb = Bulb.find(first_bulb.id)
    car.bulbs = [second_bulb, same_bulb]

    assert_equal [first_bulb, second_bulb], car.bulbs
  end

  test "association size calculation works with default scoped selects when not previously fetched" do
    firm = Firm.create!(name: "Firm")
    5.times { firm.developers_with_select << Developer.create!(name: "Developer") }

    same_firm = Firm.find(firm.id)
    assert_equal 5, same_firm.developers_with_select.size
  end

  test "prevent double insertion of new object when the parent association loaded in the after save callback" do
    reset_callbacks(:save, Bulb) do
      Bulb.after_save { |record| record.car.bulbs.load }

      car = Car.create!
      car.bulbs << Bulb.new

      assert_equal 1, car.bulbs.size
    end
  end

  test "prevent double firing the before save callback of new object when the parent association saved in the callback" do
    reset_callbacks(:save, Bulb) do
      count = 0
      Bulb.before_save { |record| record.car.save && count += 1 }

      car = Car.create!
      car.bulbs.create!

      assert_equal 1, count
    end
  end

  class AuthorWithErrorDestroyingAssociation < ActiveRecord::Base
    self.table_name = "authors"
    has_many :posts_with_error_destroying,
      class_name: "PostWithErrorDestroying",
      foreign_key: :author_id,
      dependent: :destroy
  end

  class PostWithErrorDestroying < ActiveRecord::Base
    self.table_name = "posts"
    self.inheritance_column = nil
    before_destroy -> { throw :abort }
  end

  def test_destroy_does_not_raise_when_association_errors_on_destroy
    assert_no_difference "AuthorWithErrorDestroyingAssociation.count" do
      author = AuthorWithErrorDestroyingAssociation.first

      assert_not author.destroy
    end
  end

  def test_destroy_with_bang_bubbles_errors_from_associations
    error = assert_raises ActiveRecord::RecordNotDestroyed do
      AuthorWithErrorDestroyingAssociation.first.destroy!
    end

    assert_instance_of PostWithErrorDestroying, error.record
  end

  def test_ids_reader_memoization
    car = Car.create!(name: "Tofaş")
    bulb = Bulb.create!(car: car)

    assert_equal [bulb.id], car.bulb_ids
    assert_no_queries { car.bulb_ids }

    bulb2 = car.bulbs.create!

    assert_equal [bulb.id, bulb2.id], car.bulb_ids
    assert_no_queries { car.bulb_ids }
  end

  def test_loading_association_in_validate_callback_doesnt_affect_persistence
    reset_callbacks(:validation, Bulb) do
      Bulb.after_validation { |record| record.car.bulbs.load }

      car = Car.create!(name: "Car")
      bulb = car.bulbs.create!

      assert_equal [bulb], car.bulbs
    end
  end

  def test_create_children_could_be_rolled_back_by_after_save
    firm = Firm.create!(name: "A New Firm, Inc")
    assert_no_difference "Client.count" do
      client = firm.clients.create(name: "New Client") do |cli|
        cli.rollback_on_save = true
        assert_not cli.rollback_on_create_called
      end
      assert client.rollback_on_create_called
    end
  end

  private

    def force_signal37_to_load_all_clients_of_firm
      companies(:first_firm).clients_of_firm.load_target
    end

    def reset_callbacks(kind, klass)
      old_callbacks = {}
      old_callbacks[klass] = klass.send("_#{kind}_callbacks").dup
      klass.subclasses.each do |subclass|
        old_callbacks[subclass] = subclass.send("_#{kind}_callbacks").dup
      end
      yield
    ensure
      klass.send("_#{kind}_callbacks=", old_callbacks[klass])
      klass.subclasses.each do |subclass|
        subclass.send("_#{kind}_callbacks=", old_callbacks[subclass])
      end
    end
end
