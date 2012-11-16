require "cases/helper"
require 'models/developer'
require 'models/project'
require 'models/company'
require 'models/contract'
require 'models/topic'
require 'models/reply'
require 'models/category'
require 'models/post'
require 'models/author'
require 'models/essay'
require 'models/comment'
require 'models/person'
require 'models/reader'
require 'models/tagging'
require 'models/tag'
require 'models/invoice'
require 'models/line_item'
require 'models/car'
require 'models/bulb'
require 'models/engine'

class HasManyAssociationsTestForCountWithFinderSql < ActiveRecord::TestCase
  class Invoice < ActiveRecord::Base
    has_many :custom_line_items, :class_name => 'LineItem', :finder_sql => "SELECT line_items.* from line_items"
  end
  def test_should_fail
    assert_raise(ArgumentError) do
      Invoice.create.custom_line_items.count(:conditions => {:amount => 0})
    end
  end
end

class HasManyAssociationsTestForCountWithCountSql < ActiveRecord::TestCase
  class Invoice < ActiveRecord::Base
    has_many :custom_line_items, :class_name => 'LineItem', :counter_sql => "SELECT COUNT(*) line_items.* from line_items"
  end
  def test_should_fail
    assert_raise(ArgumentError) do
      Invoice.create.custom_line_items.count(:conditions => {:amount => 0})
    end
  end
end

class HasManyAssociationsTestForCountWithVariousFinderSqls < ActiveRecord::TestCase
  class Invoice < ActiveRecord::Base
    has_many :custom_line_items, :class_name => 'LineItem', :finder_sql => "SELECT DISTINCT line_items.amount from line_items"
    has_many :custom_full_line_items, :class_name => 'LineItem', :finder_sql => "SELECT line_items.invoice_id, line_items.amount from line_items"
    has_many :custom_star_line_items, :class_name => 'LineItem', :finder_sql => "SELECT * from line_items"
    has_many :custom_qualified_star_line_items, :class_name => 'LineItem', :finder_sql => "SELECT line_items.* from line_items"
  end

  def test_should_count_distinct_results
    invoice = Invoice.new
    invoice.custom_line_items << LineItem.new(:amount => 0)
    invoice.custom_line_items << LineItem.new(:amount => 0)
    invoice.save!

    assert_equal 1, invoice.custom_line_items.count
  end

  def test_should_count_results_with_multiple_fields
    invoice = Invoice.new
    invoice.custom_full_line_items << LineItem.new(:amount => 0)
    invoice.custom_full_line_items << LineItem.new(:amount => 0)
    invoice.save!

    assert_equal 2, invoice.custom_full_line_items.count
  end

  def test_should_count_results_with_star
    invoice = Invoice.new
    invoice.custom_star_line_items << LineItem.new(:amount => 0)
    invoice.custom_star_line_items << LineItem.new(:amount => 0)
    invoice.save!

    assert_equal 2, invoice.custom_star_line_items.count
  end

  def test_should_count_results_with_qualified_star
    invoice = Invoice.new
    invoice.custom_qualified_star_line_items << LineItem.new(:amount => 0)
    invoice.custom_qualified_star_line_items << LineItem.new(:amount => 0)
    invoice.save!

    assert_equal 2, invoice.custom_qualified_star_line_items.count
  end
end

class HasManyAssociationsTestForReorderWithJoinDependency < ActiveRecord::TestCase
  fixtures :authors, :posts, :comments

  def test_should_generate_valid_sql
    author = authors(:david)
    # this can fail on adapters which require ORDER BY expressions to be included in the SELECT expression
    # if the reorder clauses are not correctly handled
    assert author.posts_with_comments_sorted_by_comment_id.where('comments.id > 0').reorder('posts.comments_count DESC', 'posts.taggings_count DESC').last
  end
end


class HasManyAssociationsTest < ActiveRecord::TestCase
  fixtures :accounts, :categories, :companies, :developers, :projects,
           :developers_projects, :topics, :authors, :comments,
           :people, :posts, :readers, :taggings, :cars, :essays

  def setup
    Client.destroyed_client_ids.clear
  end

  def test_create_from_association_should_respect_default_scope
    car = Car.create(:name => 'honda')
    assert_equal 'honda', car.name

    bulb = Bulb.create
    assert_equal 'defaulty', bulb.name

    bulb = car.bulbs.build
    assert_equal 'defaulty', bulb.name

    bulb = car.bulbs.create
    assert_equal 'defaulty', bulb.name

    bulb = car.bulbs.create(:name => 'exotic')
    assert_equal 'exotic', bulb.name
  end

  def test_create_from_association_with_nil_values_should_work
    car = Car.create(:name => 'honda')

    bulb = car.bulbs.new(nil)
    assert_equal 'defaulty', bulb.name

    bulb = car.bulbs.build(nil)
    assert_equal 'defaulty', bulb.name

    bulb = car.bulbs.create(nil)
    assert_equal 'defaulty', bulb.name
  end

  def test_association_keys_bypass_attribute_protection
    car = Car.create(:name => 'honda')

    bulb = car.bulbs.new
    assert_equal car.id, bulb.car_id

    bulb = car.bulbs.new :car_id => car.id + 1
    assert_equal car.id, bulb.car_id

    bulb = car.bulbs.build
    assert_equal car.id, bulb.car_id

    bulb = car.bulbs.build :car_id => car.id + 1
    assert_equal car.id, bulb.car_id

    bulb = car.bulbs.create
    assert_equal car.id, bulb.car_id

    bulb = car.bulbs.create :car_id => car.id + 1
    assert_equal car.id, bulb.car_id
  end

  def test_association_protect_foreign_key
    invoice = Invoice.create

    line_item = invoice.line_items.new
    assert_equal invoice.id, line_item.invoice_id

    line_item = invoice.line_items.new :invoice_id => invoice.id + 1
    assert_equal invoice.id, line_item.invoice_id

    line_item = invoice.line_items.build
    assert_equal invoice.id, line_item.invoice_id

    line_item = invoice.line_items.build :invoice_id => invoice.id + 1
    assert_equal invoice.id, line_item.invoice_id

    line_item = invoice.line_items.create
    assert_equal invoice.id, line_item.invoice_id

    line_item = invoice.line_items.create :invoice_id => invoice.id + 1
    assert_equal invoice.id, line_item.invoice_id
  end

  def test_association_conditions_bypass_attribute_protection
    car = Car.create(:name => 'honda')

    bulb = car.frickinawesome_bulbs.new
    assert_equal true, bulb.frickinawesome?

    bulb = car.frickinawesome_bulbs.new(:frickinawesome => false)
    assert_equal true, bulb.frickinawesome?

    bulb = car.frickinawesome_bulbs.build
    assert_equal true, bulb.frickinawesome?

    bulb = car.frickinawesome_bulbs.build(:frickinawesome => false)
    assert_equal true, bulb.frickinawesome?

    bulb = car.frickinawesome_bulbs.create
    assert_equal true, bulb.frickinawesome?

    bulb = car.frickinawesome_bulbs.create(:frickinawesome => false)
    assert_equal true, bulb.frickinawesome?
  end

  # When creating objects on the association, we must not do it within a scope (even though it
  # would be convenient), because this would cause that scope to be applied to any callbacks etc.
  def test_build_and_create_should_not_happen_within_scope
    car = cars(:honda)
    scoped_count = car.foo_bulbs.scoped.where_values.count

    bulb = car.foo_bulbs.build
    assert_not_equal scoped_count, bulb.scope_after_initialize.where_values.count

    bulb = car.foo_bulbs.create
    assert_not_equal scoped_count, bulb.scope_after_initialize.where_values.count

    bulb = car.foo_bulbs.create!
    assert_not_equal scoped_count, bulb.scope_after_initialize.where_values.count
  end

  def test_no_sql_should_be_fired_if_association_already_loaded
    Car.create(:name => 'honda')
    bulbs = Car.first.bulbs
    bulbs.inspect # to load all instances of bulbs

    assert_no_queries do
      bulbs.first()
      bulbs.first({})
    end

    assert_no_queries do
      bulbs.last()
      bulbs.last({})
    end
  end

  def test_create_resets_cached_counters
    person = Person.create!(:first_name => 'tenderlove')
    post   = Post.first

    assert_equal [], person.readers
    assert_nil person.readers.find_by_post_id(post.id)

    person.readers.create(:post_id => post.id)

    assert_equal 1, person.readers.count
    assert_equal 1, person.readers.length
    assert_equal post, person.readers.first.post
    assert_equal person, person.readers.first.person
  end

  def test_find_or_create_by_resets_cached_counters
    person = Person.create! :first_name => 'tenderlove'
    post   = Post.first

    assert_equal [], person.readers
    assert_nil person.readers.find_by_post_id(post.id)

    person.readers.find_or_create_by_post_id(post.id)

    assert_equal 1, person.readers.count
    assert_equal 1, person.readers.length
    assert_equal post, person.readers.first.post
    assert_equal person, person.readers.first.person
  end

  def force_signal37_to_load_all_clients_of_firm
    companies(:first_firm).clients_of_firm.each {|f| }
  end

  # sometimes tests on Oracle fail if ORDER BY is not provided therefore add always :order with :first
  def test_counting_with_counter_sql
    assert_equal 2, Firm.find(:first, :order => "id").clients.count
  end

  def test_counting
    assert_equal 2, Firm.find(:first, :order => "id").plain_clients.count
  end

  def test_counting_with_empty_hash_conditions
    assert_equal 2, Firm.find(:first, :order => "id").plain_clients.count(:conditions => {})
  end

  def test_counting_with_single_conditions
    assert_equal 1, Firm.find(:first, :order => "id").plain_clients.count(:conditions => ['name=?', "Microsoft"])
  end

  def test_counting_with_single_hash
    assert_equal 1, Firm.find(:first, :order => "id").plain_clients.count(:conditions => {:name => "Microsoft"})
  end

  def test_counting_with_column_name_and_hash
    assert_equal 2, Firm.find(:first, :order => "id").plain_clients.count(:name)
  end

  def test_counting_with_association_limit
    firm = companies(:first_firm)
    assert_equal firm.limited_clients.length, firm.limited_clients.size
    assert_equal firm.limited_clients.length, firm.limited_clients.count
  end

  def test_counting_should_not_fire_sql_if_parent_is_unsaved
    assert_no_queries do
      assert_equal 0, Person.new.readers.count
    end
  end

  def test_finding
    assert_equal 2, Firm.find(:first, :order => "id").clients.length
  end

  def test_finding_array_compatibility
    assert_equal 2, Firm.order(:id).find{|f| f.id > 0}.clients.length
  end

  def test_find_with_blank_conditions
    [[], {}, nil, ""].each do |blank|
      assert_equal 2, Firm.find(:first, :order => "id").clients.find(:all, :conditions => blank).size
    end
  end

  def test_find_many_with_merged_options
    assert_equal 1, companies(:first_firm).limited_clients.size
    assert_equal 1, companies(:first_firm).limited_clients.find(:all).size
    assert_equal 2, companies(:first_firm).limited_clients.find(:all, :limit => nil).size
  end

  def test_find_should_append_to_association_order
    ordered_clients =  companies(:first_firm).clients_sorted_desc.order('companies.id')
    assert_equal ['id DESC', 'companies.id'], ordered_clients.order_values
  end

  def test_dynamic_find_last_without_specified_order
    assert_equal companies(:second_client), companies(:first_firm).unsorted_clients.find_last_by_type('Client')
  end

  def test_dynamic_find_should_respect_association_order
    assert_equal companies(:second_client), companies(:first_firm).clients_sorted_desc.find(:first, :conditions => "type = 'Client'")
    assert_equal companies(:second_client), companies(:first_firm).clients_sorted_desc.find_by_type('Client')
  end

  def test_dynamic_find_all_should_respect_association_order
    assert_equal [companies(:second_client), companies(:first_client)], companies(:first_firm).clients_sorted_desc.find(:all, :conditions => "type = 'Client'")
    assert_equal [companies(:second_client), companies(:first_client)], companies(:first_firm).clients_sorted_desc.find_all_by_type('Client')
  end

  def test_dynamic_find_all_should_respect_association_limit
    assert_equal 1, companies(:first_firm).limited_clients.find(:all, :conditions => "type = 'Client'").length
    assert_equal 1, companies(:first_firm).limited_clients.find_all_by_type('Client').length
  end

  def test_dynamic_find_all_limit_should_override_association_limit
    assert_equal 2, companies(:first_firm).limited_clients.find(:all, :conditions => "type = 'Client'", :limit => 9_000).length
    assert_equal 2, companies(:first_firm).limited_clients.find_all_by_type('Client', :limit => 9_000).length
  end

  def test_dynamic_find_all_should_respect_readonly_access
    companies(:first_firm).readonly_clients.find(:all).each { |c| assert_raise(ActiveRecord::ReadOnlyRecord) { c.save!  } }
    companies(:first_firm).readonly_clients.find(:all).each { |c| assert c.readonly? }
  end

  def test_dynamic_find_or_create_from_two_attributes_using_an_association
    author = authors(:david)
    number_of_posts = Post.count
    another = author.posts.find_or_create_by_title_and_body("Another Post", "This is the Body")
    assert_equal number_of_posts + 1, Post.count
    assert_equal another, author.posts.find_or_create_by_title_and_body("Another Post", "This is the Body")
    assert another.persisted?
  end

  def test_cant_save_has_many_readonly_association
    authors(:david).readonly_comments.each { |c| assert_raise(ActiveRecord::ReadOnlyRecord) { c.save! } }
    authors(:david).readonly_comments.each { |c| assert c.readonly? }
  end

  def test_triple_equality
    # sometimes tests on Oracle fail if ORDER BY is not provided therefore add always :order with :first
    assert !(Array === Firm.find(:first, :order => "id").clients)
    assert Firm.find(:first, :order => "id").clients === Array
  end

  def test_finding_default_orders
    assert_equal "Summit", Firm.find(:first, :order => "id").clients.first.name
  end

  def test_finding_with_different_class_name_and_order
    assert_equal "Microsoft", Firm.find(:first, :order => "id").clients_sorted_desc.first.name
  end

  def test_finding_with_foreign_key
    assert_equal "Microsoft", Firm.find(:first, :order => "id").clients_of_firm.first.name
  end

  def test_finding_with_condition
    assert_equal "Microsoft", Firm.find(:first, :order => "id").clients_like_ms.first.name
  end

  def test_finding_with_condition_hash
    assert_equal "Microsoft", Firm.find(:first, :order => "id").clients_like_ms_with_hash_conditions.first.name
  end

  def test_finding_using_primary_key
    assert_equal "Summit", Firm.find(:first, :order => "id").clients_using_primary_key.first.name
  end

  def test_finding_using_sql
    firm = Firm.find(:first, :order => "id")
    first_client = firm.clients_using_sql.first
    assert_not_nil first_client
    assert_equal "Microsoft", first_client.name
    assert_equal 1, firm.clients_using_sql.size
    assert_equal 1, Firm.find(:first, :order => "id").clients_using_sql.size
  end

  def test_counting_using_sql
    assert_equal 1, Firm.find(:first, :order => "id").clients_using_counter_sql.size
    assert Firm.find(:first, :order => "id").clients_using_counter_sql.any?
    assert_equal 0, Firm.find(:first, :order => "id").clients_using_zero_counter_sql.size
    assert !Firm.find(:first, :order => "id").clients_using_zero_counter_sql.any?
  end

  def test_counting_non_existant_items_using_sql
    assert_equal 0, Firm.find(:first, :order => "id").no_clients_using_counter_sql.size
  end

  def test_counting_using_finder_sql
    assert_equal 2, Firm.find(4).clients_using_sql.count
  end

  def test_belongs_to_sanity
    c = Client.new
    assert_nil c.firm

    flunk "belongs_to failed if check" if c.firm
  end

  def test_find_ids
    firm = Firm.find(:first, :order => "id")

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

  def test_find_string_ids_when_using_finder_sql
    firm = Firm.find(:first, :order => "id")

    client = firm.clients_using_finder_sql.find("2")
    assert_kind_of Client, client

    client_ary = firm.clients_using_finder_sql.find(["2"])
    assert_kind_of Array, client_ary
    assert_equal client, client_ary.first

    client_ary = firm.clients_using_finder_sql.find("2", "3")
    assert_kind_of Array, client_ary
    assert_equal 2, client_ary.size
    assert client_ary.include?(client)
  end

  def test_find_all
    firm = Firm.find(:first, :order => "id")
    assert_equal 2, firm.clients.find(:all, :conditions => "#{QUOTED_TYPE} = 'Client'").length
    assert_equal 1, firm.clients.find(:all, :conditions => "name = 'Summit'").length
  end

  def test_find_each
    firm = companies(:first_firm)

    assert ! firm.clients.loaded?

    assert_queries(3) do
      firm.clients.find_each(:batch_size => 1) {|c| assert_equal firm.id, c.firm_id }
    end

    assert ! firm.clients.loaded?
  end

  def test_find_each_with_conditions
    firm = companies(:first_firm)

    assert_queries(2) do
      firm.clients.find_each(:batch_size => 1, :conditions => {:name => "Microsoft"}) do |c|
        assert_equal firm.id, c.firm_id
        assert_equal "Microsoft", c.name
      end
    end

    assert ! firm.clients.loaded?
  end

  def test_find_in_batches
    firm = companies(:first_firm)

    assert ! firm.clients.loaded?

    assert_queries(2) do
      firm.clients.find_in_batches(:batch_size => 2) do |clients|
        clients.each {|c| assert_equal firm.id, c.firm_id }
      end
    end

    assert ! firm.clients.loaded?
  end

  def test_find_all_sanitized
    # sometimes tests on Oracle fail if ORDER BY is not provided therefore add always :order with :first
    firm = Firm.find(:first, :order => "id")
    summit = firm.clients.find(:all, :conditions => "name = 'Summit'")
    assert_equal summit, firm.clients.find(:all, :conditions => ["name = ?", "Summit"])
    assert_equal summit, firm.clients.find(:all, :conditions => ["name = :name", { :name => "Summit" }])
  end

  def test_find_first
    firm = Firm.find(:first, :order => "id")
    client2 = Client.find(2)
    assert_equal firm.clients.first, firm.clients.find(:first, :order => "id")
    assert_equal client2, firm.clients.find(:first, :conditions => "#{QUOTED_TYPE} = 'Client'", :order => "id")
  end

  def test_find_first_sanitized
    firm = Firm.find(:first, :order => "id")
    client2 = Client.find(2)
    assert_equal client2, firm.clients.find(:first, :conditions => ["#{QUOTED_TYPE} = ?", 'Client'], :order => "id")
    assert_equal client2, firm.clients.find(:first, :conditions => ["#{QUOTED_TYPE} = :type", { :type => 'Client' }], :order => "id")
  end

  def test_find_all_with_include_and_conditions
    assert_nothing_raised do
      Developer.find(:all, :joins => :audit_logs, :conditions => {'audit_logs.message' => nil, :name => 'Smith'})
    end
  end

  def test_find_in_collection
    assert_equal Client.find(2).name, companies(:first_firm).clients.find(2).name
    assert_raise(ActiveRecord::RecordNotFound) { companies(:first_firm).clients.find(6) }
  end

  def test_find_grouped
    all_clients_of_firm1 = Client.find(:all, :conditions => "firm_id = 1")
    grouped_clients_of_firm1 = Client.find(:all, :conditions => "firm_id = 1", :group => "firm_id", :select => 'firm_id, count(id) as clients_count')
    assert_equal 2, all_clients_of_firm1.size
    assert_equal 1, grouped_clients_of_firm1.size
  end

  def test_find_scoped_grouped
    assert_equal 1, companies(:first_firm).clients_grouped_by_firm_id.size
    assert_equal 1, companies(:first_firm).clients_grouped_by_firm_id.length
    assert_equal 2, companies(:first_firm).clients_grouped_by_name.size
    assert_equal 2, companies(:first_firm).clients_grouped_by_name.length
  end

  def test_find_scoped_grouped_having
    assert_equal 1, authors(:david).popular_grouped_posts.length
    assert_equal 0, authors(:mary).popular_grouped_posts.length
  end

  def test_default_select
    assert_equal Comment.column_names.sort, posts(:welcome).comments.first.attributes.keys.sort
  end

  def test_select_query_method
    assert_equal ['id'], posts(:welcome).comments.select(:id).first.attributes.keys
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
    first_firm.plain_clients.create(:name => "Natural Company")
    assert_equal 3, first_firm.plain_clients.length
    assert_equal 3, first_firm.plain_clients.size
  end

  def test_create_with_bang_on_has_many_when_parent_is_new_raises
    assert_raise(ActiveRecord::RecordNotSaved) do
      firm = Firm.new
      firm.plain_clients.create! :name=>"Whoever"
    end
  end

  def test_regular_create_on_has_many_when_parent_is_new_raises
    assert_raise(ActiveRecord::RecordNotSaved) do
      firm = Firm.new
      firm.plain_clients.create :name=>"Whoever"
    end
  end

  def test_create_with_bang_on_has_many_raises_when_record_not_saved
    assert_raise(ActiveRecord::RecordInvalid) do
      firm = Firm.find(:first, :order => "id")
      firm.plain_clients.create!
    end
  end

  def test_create_with_bang_on_habtm_when_parent_is_new_raises
    assert_raise(ActiveRecord::RecordNotSaved) do
      Developer.new("name" => "Aredridel").projects.create!
    end
  end

  def test_adding_a_mismatch_class
    assert_raise(ActiveRecord::AssociationTypeMismatch) { companies(:first_firm).clients_of_firm << nil }
    assert_raise(ActiveRecord::AssociationTypeMismatch) { companies(:first_firm).clients_of_firm << 1 }
    assert_raise(ActiveRecord::AssociationTypeMismatch) { companies(:first_firm).clients_of_firm << Topic.find(1) }
  end

  def test_adding_a_collection
    force_signal37_to_load_all_clients_of_firm
    companies(:first_firm).clients_of_firm.concat([Client.new("name" => "Natural Company"), Client.new("name" => "Apple")])
    assert_equal 3, companies(:first_firm).clients_of_firm.size
    assert_equal 3, companies(:first_firm).clients_of_firm(true).size
  end

  def test_transactions_when_adding_to_persisted
    good = Client.new(:name => "Good")
    bad  = Client.new(:name => "Bad", :raise_on_save => true)

    begin
      companies(:first_firm).clients_of_firm.concat(good, bad)
    rescue Client::RaisedOnSave
    end

    assert !companies(:first_firm).clients_of_firm(true).include?(good)
  end

  def test_transactions_when_adding_to_new_record
    assert_no_queries do
      firm = Firm.new
      firm.clients_of_firm.concat(Client.new("name" => "Natural Company"))
    end
  end

  def test_new_aliased_to_build
    company = companies(:first_firm)
    new_client = assert_no_queries { company.clients_of_firm.new("name" => "Another Client") }
    assert !company.clients_of_firm.loaded?

    assert_equal "Another Client", new_client.name
    assert !new_client.persisted?
    assert_equal new_client, company.clients_of_firm.last
  end

  def test_build
    company = companies(:first_firm)
    new_client = assert_no_queries { company.clients_of_firm.build("name" => "Another Client") }
    assert !company.clients_of_firm.loaded?

    assert_equal "Another Client", new_client.name
    assert !new_client.persisted?
    assert_equal new_client, company.clients_of_firm.last
  end

  def test_collection_size_after_building
    company = companies(:first_firm)  # company already has one client
    company.clients_of_firm.build("name" => "Another Client")
    company.clients_of_firm.build("name" => "Yet Another Client")
    assert_equal 3, company.clients_of_firm.size
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
    new_clients = assert_no_queries { company.clients_of_firm.build([{"name" => "Another Client"}, {"name" => "Another Client II"}]) }
    assert_equal 2, new_clients.size
  end

  def test_build_followed_by_save_does_not_load_target
    companies(:first_firm).clients_of_firm.build("name" => "Another Client")
    assert companies(:first_firm).save
    assert !companies(:first_firm).clients_of_firm.loaded?
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

  def test_build_via_block
    company = companies(:first_firm)
    new_client = assert_no_queries { company.clients_of_firm.build {|client| client.name = "Another Client" } }
    assert !company.clients_of_firm.loaded?

    assert_equal "Another Client", new_client.name
    assert !new_client.persisted?
    assert_equal new_client, company.clients_of_firm.last
  end

  def test_build_many_via_block
    company = companies(:first_firm)
    new_clients = assert_no_queries do
      company.clients_of_firm.build([{"name" => "Another Client"}, {"name" => "Another Client II"}]) do |client|
        client.name = "changed"
      end
    end

    assert_equal 2, new_clients.size
    assert_equal "changed", new_clients.first.name
    assert_equal "changed", new_clients.last.name
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

  def test_create
    force_signal37_to_load_all_clients_of_firm
    new_client = companies(:first_firm).clients_of_firm.create("name" => "Another Client")
    assert new_client.persisted?
    assert_equal new_client, companies(:first_firm).clients_of_firm.last
    assert_equal new_client, companies(:first_firm).clients_of_firm(true).last
  end

  def test_create_many
    companies(:first_firm).clients_of_firm.create([{"name" => "Another Client"}, {"name" => "Another Client II"}])
    assert_equal 3, companies(:first_firm).clients_of_firm(true).size
  end

  def test_create_followed_by_save_does_not_load_target
    companies(:first_firm).clients_of_firm.create("name" => "Another Client")
    assert companies(:first_firm).save
    assert !companies(:first_firm).clients_of_firm.loaded?
  end

  def test_find_or_initialize
    the_client = companies(:first_firm).clients.find_or_initialize_by_name("Yet another client")
    assert_equal companies(:first_firm).id, the_client.firm_id
    assert_equal "Yet another client", the_client.name
    assert !the_client.persisted?
  end

  def test_find_or_create_updates_size
    number_of_clients = companies(:first_firm).clients.size
    the_client = companies(:first_firm).clients.find_or_create_by_name("Yet another client")
    assert_equal number_of_clients + 1, companies(:first_firm, :reload).clients.size
    assert_equal the_client, companies(:first_firm).clients.find_or_create_by_name("Yet another client")
    assert_equal number_of_clients + 1, companies(:first_firm, :reload).clients.size
  end

  def test_find_or_initialize_updates_collection_size
    number_of_clients = companies(:first_firm).clients_of_firm.size
    companies(:first_firm).clients_of_firm.find_or_initialize_by_name("name" => "Another Client")
    assert_equal number_of_clients + 1, companies(:first_firm).clients_of_firm.size
  end

  def test_find_or_initialize_returns_the_instantiated_object
    client = companies(:first_firm).clients_of_firm.find_or_initialize_by_name("name" => "Another Client")
    assert_equal client, companies(:first_firm).clients_of_firm[-1]
  end

  def test_find_or_initialize_only_instantiates_a_single_object
    number_of_clients = Client.count
    companies(:first_firm).clients_of_firm.find_or_initialize_by_name("name" => "Another Client").save!
    companies(:first_firm).save!
    assert_equal number_of_clients+1, Client.count
  end

  def test_find_or_create_with_hash
    post = authors(:david).posts.find_or_create_by_title(:title => 'Yet another post', :body => 'somebody')
    assert_equal post, authors(:david).posts.find_or_create_by_title(:title => 'Yet another post', :body => 'somebody')
    assert post.persisted?
  end

  def test_find_or_create_with_one_attribute_followed_by_hash
    post = authors(:david).posts.find_or_create_by_title('Yet another post', :body => 'somebody')
    assert_equal post, authors(:david).posts.find_or_create_by_title('Yet another post', :body => 'somebody')
    assert post.persisted?
  end

  def test_find_or_create_should_work_with_block
    post = authors(:david).posts.find_or_create_by_title('Yet another post') {|p| p.body = 'somebody'}
    assert_equal post, authors(:david).posts.find_or_create_by_title('Yet another post') {|p| p.body = 'somebody'}
    assert post.persisted?
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

  def test_deleting_updates_counter_cache
    topic = Topic.first(:order => "id ASC")
    assert_equal topic.replies.to_a.size, topic.replies_count

    topic.replies.delete(topic.replies.first)
    topic.reload
    assert_equal topic.replies.to_a.size, topic.replies_count
  end

  def test_deleting_updates_counter_cache_without_dependent_option
    post = posts(:welcome)

    assert_difference "post.reload.taggings_count", -1 do
      post.taggings.delete(post.taggings.first)
    end
  end

  def test_deleting_updates_counter_cache_with_dependent_delete_all
    post = posts(:welcome)
    post.update_column(:taggings_with_delete_all_count, post.taggings_count)

    assert_difference "post.reload.taggings_with_delete_all_count", -1 do
      post.taggings_with_delete_all.delete(post.taggings_with_delete_all.first)
    end
  end

  def test_deleting_updates_counter_cache_with_dependent_destroy
    post = posts(:welcome)
    post.update_column(:taggings_with_destroy_count, post.taggings_count)

    assert_difference "post.reload.taggings_with_destroy_count", -1 do
      post.taggings_with_destroy.delete(post.taggings_with_destroy.first)
    end
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
    clients = companies(:first_firm).clients_of_firm.to_a
    assert_equal 2, clients.count
    deleted = companies(:first_firm).clients_of_firm.delete_all
    assert_equal clients.sort_by(&:id), deleted.sort_by(&:id)
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

  def test_transaction_when_deleting_persisted
    good = Client.new(:name => "Good")
    bad  = Client.new(:name => "Bad", :raise_on_destroy => true)

    companies(:first_firm).clients_of_firm = [good, bad]

    begin
      companies(:first_firm).clients_of_firm.destroy(good, bad)
    rescue Client::RaisedOnDestroy
    end

    assert_equal [good, bad], companies(:first_firm).clients_of_firm(true)
  end

  def test_transaction_when_deleting_new_record
    assert_no_queries do
      firm = Firm.new
      client = Client.new("name" => "New Client")
      firm.clients_of_firm << client
      firm.clients_of_firm.destroy(client)
    end
  end

  def test_clearing_an_association_collection
    firm = companies(:first_firm)
    client_id = firm.clients_of_firm.first.id
    assert_equal 1, firm.clients_of_firm.size

    cleared = firm.clients_of_firm.clear

    assert_equal 0, firm.clients_of_firm.size
    assert_equal 0, firm.clients_of_firm(true).size
    assert_equal [], Client.destroyed_client_ids[firm.id]
    assert_equal firm.clients_of_firm.object_id, cleared.object_id

    # Should not be destroyed since the association is not dependent.
    assert_nothing_raised do
      assert_nil Client.find(client_id).firm
    end
  end

  def test_clearing_updates_counter_cache
    topic = Topic.order(:id).first

    assert_difference 'topic.reload.replies_count', -1 do
      topic.replies.clear
    end
  end

  def test_clearing_updates_counter_cache_when_inverse_counter_cache_is_a_symbol_with_dependent_destroy
    car = Car.first
    car.engines.create!

    assert_difference 'car.reload.engines_count', -1 do
      car.engines.clear
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
    assert_nil Client.find_by_id(client_id)
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
    # no destroy-filters should have been called
    assert_equal [], Client.destroyed_client_ids[firm.id]

    # Should be destroyed since the association is exclusively dependent.
    assert_nil Client.find_by_id(client_id)
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

  def test_dependent_association_respects_optional_hash_conditions_on_delete
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

  def test_delete_all_association_with_primary_key_deletes_correct_records
    firm = Firm.order(:id).first
    # break the vanilla firm_id foreign key
    assert_equal 2, firm.clients.count
    firm.clients.first.update_column(:firm_id, nil)
    assert_equal 1, firm.clients(true).count
    assert_equal 1, firm.clients_using_primary_key_with_delete_all.count
    old_record = firm.clients_using_primary_key_with_delete_all.first
    firm = Firm.order(:id).first
    firm.destroy
    assert_nil Client.find_by_id(old_record.id)
  end

  def test_creation_respects_hash_condition
    ms_client = companies(:first_firm).clients_like_ms_with_hash_conditions.build

    assert        ms_client.save
    assert_equal  'Microsoft', ms_client.name

    another_ms_client = companies(:first_firm).clients_like_ms_with_hash_conditions.create

    assert        another_ms_client.persisted?
    assert_equal  'Microsoft', another_ms_client.name
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
    assert_raise(ActiveRecord::AssociationTypeMismatch) { david.projects.delete(1) }
  end

  def test_deleting_self_type_mismatch
    david = Developer.find(1)
    david.projects.reload
    assert_raise(ActiveRecord::AssociationTypeMismatch) { david.projects.delete(Project.find(1).developers) }
  end

  def test_destroying
    force_signal37_to_load_all_clients_of_firm

    assert_difference "Client.count", -1 do
      companies(:first_firm).clients_of_firm.destroy(companies(:first_firm).clients_of_firm.first)
    end

    assert_equal 0, companies(:first_firm).reload.clients_of_firm.size
    assert_equal 0, companies(:first_firm).clients_of_firm(true).size
  end

  def test_destroying_by_fixnum_id
    force_signal37_to_load_all_clients_of_firm

    assert_difference "Client.count", -1 do
      companies(:first_firm).clients_of_firm.destroy(companies(:first_firm).clients_of_firm.first.id)
    end

    assert_equal 0, companies(:first_firm).reload.clients_of_firm.size
    assert_equal 0, companies(:first_firm).clients_of_firm(true).size
  end

  def test_destroying_by_string_id
    force_signal37_to_load_all_clients_of_firm

    assert_difference "Client.count", -1 do
      companies(:first_firm).clients_of_firm.destroy(companies(:first_firm).clients_of_firm.first.id.to_s)
    end

    assert_equal 0, companies(:first_firm).reload.clients_of_firm.size
    assert_equal 0, companies(:first_firm).clients_of_firm(true).size
  end

  def test_destroying_a_collection
    force_signal37_to_load_all_clients_of_firm
    companies(:first_firm).clients_of_firm.create("name" => "Another Client")
    assert_equal 2, companies(:first_firm).clients_of_firm.size

    assert_difference "Client.count", -2 do
      companies(:first_firm).clients_of_firm.destroy([companies(:first_firm).clients_of_firm[0], companies(:first_firm).clients_of_firm[1]])
    end

    assert_equal 0, companies(:first_firm).reload.clients_of_firm.size
    assert_equal 0, companies(:first_firm).clients_of_firm(true).size
  end

  def test_destroy_all
    force_signal37_to_load_all_clients_of_firm
    clients = companies(:first_firm).clients_of_firm.to_a
    assert !clients.empty?, "37signals has clients after load"
    destroyed = companies(:first_firm).clients_of_firm.destroy_all
    assert_equal clients.sort_by(&:id), destroyed.sort_by(&:id)
    assert destroyed.all? { |client| client.frozen? }, "destroyed clients should be frozen"
    assert companies(:first_firm).clients_of_firm.empty?, "37signals has no clients after destroy all"
    assert companies(:first_firm).clients_of_firm(true).empty?, "37signals has no clients after destroy all and refresh"
  end

  def test_dependence
    firm = companies(:first_firm)
    assert_equal 2, firm.clients.size
    firm.destroy
    assert Client.find(:all, :conditions => "firm_id=#{firm.id}").empty?
  end

  def test_dependence_for_associations_with_hash_condition
    david = authors(:david)
    assert_difference('Post.count', -1) { assert david.destroy }
  end

  def test_destroy_dependent_when_deleted_from_association
    # sometimes tests on Oracle fail if ORDER BY is not provided therefore add always :order with :first
    firm = Firm.find(:first, :order => "id")
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
    reply.replies.create "title" => "neat and simple", "content" => "ain't complaining"

    assert_nothing_raised { topic.destroy }
  end

  uses_transaction :test_dependence_with_transaction_support_on_failure
  def test_dependence_with_transaction_support_on_failure
    firm = companies(:first_firm)
    clients = firm.clients
    assert_equal 2, clients.length
    clients.last.instance_eval { def overwrite_to_raise() raise "Trigger rollback" end }

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

    core = companies(:rails_core)
    assert_equal accounts(:rails_core_account), core.account
    assert_equal companies(:leetsoft, :jadedpixel), core.companies.order(:id)
    core.destroy
    assert_nil accounts(:rails_core_account).reload.firm_id
    assert_nil companies(:leetsoft).reload.client_of
    assert_nil companies(:jadedpixel).reload.client_of

    assert_equal num_accounts, Account.count
  end

  def test_restrict
    firm = RestrictedFirm.new(:name => 'restrict')
    firm.save!
    firm.companies.create(:name => 'child')
    assert !firm.companies.empty?
    assert_raise(ActiveRecord::DeleteRestrictionError) { firm.destroy }
  end

  def test_included_in_collection
    assert companies(:first_firm).clients.include?(Client.find(2))
  end

  def test_included_in_collection_for_new_records
    client = Client.create(:name => 'Persisted')
    assert_nil client.client_of
    assert !Firm.new.clients_of_firm.include?(client),
           'includes a client that does not belong to any firm'
  end

  def test_adding_array_and_collection
    assert_nothing_raised { Firm.find(:first).clients + Firm.find(:all).last.clients }
  end

  def test_find_all_without_conditions
    firm = companies(:first_firm)
    assert_equal 2, firm.clients.find(:all).length
  end

  def test_replace_with_less
    firm = Firm.find(:first, :order => "id")
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
    firm = Firm.find(:first, :order => "id")
    firm.clients = [companies(:second_client), Client.new("name" => "New Client")]
    firm.save
    firm.reload
    assert_equal 2, firm.clients.length
    assert !firm.clients.include?(:first_client)
  end

  def test_replace_failure
    firm = companies(:first_firm)
    account = Account.new
    orig_accounts = firm.accounts.to_a

    assert !account.valid?
    assert !orig_accounts.empty?
    assert_raise ActiveRecord::RecordNotSaved do
      firm.accounts = [account]
    end
    assert_equal orig_accounts, firm.accounts
  end

  def test_transactions_when_replacing_on_persisted
    good = Client.new(:name => "Good")
    bad  = Client.new(:name => "Bad", :raise_on_save => true)

    companies(:first_firm).clients_of_firm = [good]

    begin
      companies(:first_firm).clients_of_firm = [bad]
    rescue Client::RaisedOnSave
    end

    assert_equal [good], companies(:first_firm).clients_of_firm(true)
  end

  def test_transactions_when_replacing_on_new_record
    assert_no_queries do
      firm = Firm.new
      firm.clients_of_firm = [Client.new("name" => "New Client")]
    end
  end

  def test_get_ids
    assert_equal [companies(:first_client).id, companies(:second_client).id], companies(:first_firm).client_ids
  end

  def test_get_ids_for_loaded_associations
    company = companies(:first_firm)
    company.clients(true)
    assert_queries(0) do
      company.client_ids
      company.client_ids
    end
  end

  def test_get_ids_for_unloaded_associations_does_not_load_them
    company = companies(:first_firm)
    assert !company.clients.loaded?
    assert_equal [companies(:first_client).id, companies(:second_client).id], company.client_ids
    assert !company.clients.loaded?
  end

  def test_get_ids_ignores_include_option
    assert_equal [readers(:michael_welcome).id], posts(:welcome).readers_with_person_ids
  end

  def test_get_ids_for_unloaded_finder_sql_associations_loads_them
    company = companies(:first_firm)
    assert !company.clients_using_sql.loaded?
    assert_equal [companies(:second_client).id], company.clients_using_sql_ids
    assert company.clients_using_sql.loaded?
  end

  def test_get_ids_for_ordered_association
    assert_equal [companies(:second_client).id, companies(:first_client).id], companies(:first_firm).clients_ordered_by_name_ids
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

  def test_modifying_a_through_a_has_many_should_raise
    [
      lambda { authors(:mary).comment_ids = [comments(:greetings).id, comments(:more_greetings).id] },
      lambda { authors(:mary).comments = [comments(:greetings), comments(:more_greetings)] },
      lambda { authors(:mary).comments << Comment.create!(:body => "Yay", :post_id => 424242) },
      lambda { authors(:mary).comments.delete(authors(:mary).comments.first) },
    ].each {|block| assert_raise(ActiveRecord::HasManyThroughCantAssociateThroughHasOneOrManyReflection, &block) }
  end

  def test_dynamic_find_should_respect_association_order_for_through
    assert_equal Comment.find(10), authors(:david).comments_desc.find(:first, :conditions => "comments.type = 'SpecialComment'")
    assert_equal Comment.find(10), authors(:david).comments_desc.find_by_type('SpecialComment')
  end

  def test_dynamic_find_all_should_respect_association_order_for_through
    assert_equal [Comment.find(10), Comment.find(7), Comment.find(6), Comment.find(3)], authors(:david).comments_desc.find(:all, :conditions => "comments.type = 'SpecialComment'")
    assert_equal [Comment.find(10), Comment.find(7), Comment.find(6), Comment.find(3)], authors(:david).comments_desc.find_all_by_type('SpecialComment')
  end

  def test_dynamic_find_all_should_respect_association_limit_for_through
    assert_equal 1, authors(:david).limited_comments.find(:all, :conditions => "comments.type = 'SpecialComment'").length
    assert_equal 1, authors(:david).limited_comments.find_all_by_type('SpecialComment').length
  end

  def test_dynamic_find_all_order_should_override_association_limit_for_through
    assert_equal 4, authors(:david).limited_comments.find(:all, :conditions => "comments.type = 'SpecialComment'", :limit => 9_000).length
    assert_equal 4, authors(:david).limited_comments.find_all_by_type('SpecialComment', :limit => 9_000).length
  end

  def test_find_all_include_over_the_same_table_for_through
    assert_equal 2, people(:michael).posts.find(:all, :include => :people).length
  end

  def test_has_many_through_respects_hash_conditions
    assert_equal authors(:david).hello_posts, authors(:david).hello_posts_with_hash_conditions
    assert_equal authors(:david).hello_post_comments, authors(:david).hello_post_comments_with_hash_conditions
  end

  def test_include_uses_array_include_after_loaded
    firm = companies(:first_firm)
    firm.clients.class # force load target

    client = firm.clients.first

    assert_no_queries do
      assert firm.clients.loaded?
      assert firm.clients.include?(client)
    end
  end

  def test_include_checks_if_record_exists_if_target_not_loaded
    firm = companies(:first_firm)
    client = firm.clients.first

    firm.reload
    assert ! firm.clients.loaded?
    assert_queries(1) do
      assert firm.clients.include?(client)
    end
    assert ! firm.clients.loaded?
  end

  def test_include_loads_collection_if_target_uses_finder_sql
    firm = companies(:first_firm)
    client = firm.clients_using_sql.first

    firm.reload
    assert ! firm.clients_using_sql.loaded?
    assert firm.clients_using_sql.include?(client)
    assert firm.clients_using_sql.loaded?
  end


  def test_include_returns_false_for_non_matching_record_to_verify_scoping
    firm = companies(:first_firm)
    client = Client.create!(:name => 'Not Associated')

    assert ! firm.clients.loaded?
    assert ! firm.clients.include?(client)
  end

  def test_calling_first_or_last_on_association_should_not_load_association
    firm = companies(:first_firm)
    firm.clients.first
    firm.clients.last
    assert !firm.clients.loaded?
  end

  def test_calling_first_or_last_on_loaded_association_should_not_fetch_with_query
    firm = companies(:first_firm)
    firm.clients.class # force load target
    assert firm.clients.loaded?

    assert_no_queries do
      firm.clients.first
      assert_equal 2, firm.clients.first(2).size
      firm.clients.last
      assert_equal 2, firm.clients.last(2).size
    end
  end

  def test_calling_first_or_last_on_existing_record_with_build_should_load_association
    firm = companies(:first_firm)
    firm.clients.build(:name => 'Foo')
    assert !firm.clients.loaded?

    assert_queries 1 do
      firm.clients.first
      firm.clients.last
    end

    assert firm.clients.loaded?
  end

  def test_calling_first_or_last_on_existing_record_with_create_should_not_load_association
    firm = companies(:first_firm)
    firm.clients.create(:name => 'Foo')
    assert !firm.clients.loaded?

    assert_queries 2 do
      firm.clients.first
      firm.clients.last
    end

    assert !firm.clients.loaded?
  end

  def test_calling_first_or_last_on_new_record_should_not_run_queries
    firm = Firm.new

    assert_no_queries do
      firm.clients.first
      firm.clients.last
    end
  end

  def test_custom_primary_key_on_new_record_should_fetch_with_query
    author = Author.new(:name => "David")
    assert !author.essays.loaded?

    assert_queries 1 do
      assert_equal 1, author.essays.size
    end

    assert_equal author.essays, Essay.find_all_by_writer_id("David")

  end

  def test_has_many_custom_primary_key
    david = authors(:david)
    assert_equal david.essays, Essay.find_all_by_writer_id("David")
  end

  def test_blank_custom_primary_key_on_new_record_should_not_run_queries
    author = Author.new
    assert !author.essays.loaded?

    assert_queries 0 do
      assert_equal 0, author.essays.size
    end
  end

  def test_calling_first_or_last_with_find_options_on_loaded_association_should_fetch_with_query
    firm = companies(:first_firm)
    firm.clients.class # force load target

    assert_queries 2 do
      assert firm.clients.loaded?
      firm.clients.first(:order => 'name')
      firm.clients.last(:order => 'name')
    end
  end

  def test_calling_first_or_last_with_integer_on_association_should_load_association
    firm = companies(:first_firm)

    assert_queries 1 do
      firm.clients.first(2)
      firm.clients.last(2)
    end

    assert firm.clients.loaded?
  end

  def test_calling_many_should_count_instead_of_loading_association
    firm = companies(:first_firm)
    assert_queries(1) do
      firm.clients.many?  # use count query
    end
    assert !firm.clients.loaded?
  end

  def test_calling_many_on_loaded_association_should_not_use_query
    firm = companies(:first_firm)
    firm.clients.collect  # force load
    assert_no_queries { assert firm.clients.many? }
  end

  def test_calling_many_should_defer_to_collection_if_using_a_block
    firm = companies(:first_firm)
    assert_queries(1) do
      firm.clients.expects(:size).never
      firm.clients.many? { true }
    end
    assert firm.clients.loaded?
  end

  def test_calling_many_should_return_false_if_none_or_one
    firm = companies(:another_firm)
    assert !firm.clients_like_ms.many?
    assert_equal 0, firm.clients_like_ms.size

    firm = companies(:first_firm)
    assert !firm.limited_clients.many?
    assert_equal 1, firm.limited_clients.size
  end

  def test_calling_many_should_return_true_if_more_than_one
    firm = companies(:first_firm)
    assert firm.clients.many?
    assert_equal 2, firm.clients.size
  end

  def test_joins_with_namespaced_model_should_use_correct_type
    old = ActiveRecord::Base.store_full_sti_class
    ActiveRecord::Base.store_full_sti_class = true

    firm = Namespaced::Firm.create({ :name => 'Some Company' })
    firm.clients.create({ :name => 'Some Client' })

    stats = Namespaced::Firm.find(firm.id, {
      :select => "#{Namespaced::Firm.table_name}.id, COUNT(#{Namespaced::Client.table_name}.id) AS num_clients",
      :joins  => :clients,
      :group  => "#{Namespaced::Firm.table_name}.id"
    })
    assert_equal 1, stats.num_clients.to_i

  ensure
    ActiveRecord::Base.store_full_sti_class = old
  end

  def test_association_proxy_transaction_method_starts_transaction_in_association_class
    Comment.expects(:transaction)
    Post.find(:first).comments.transaction do
      # nothing
    end
  end

  def test_sending_new_to_association_proxy_should_have_same_effect_as_calling_new
    client_association = companies(:first_firm).clients
    assert_equal client_association.new.attributes, client_association.send(:new).attributes
  end

  def test_respond_to_private_class_methods
    client_association = companies(:first_firm).clients
    assert !client_association.respond_to?(:private_method)
    assert client_association.respond_to?(:private_method, true)
  end

  def test_creating_using_primary_key
    firm = Firm.find(:first, :order => "id")
    client = firm.clients_using_primary_key.create!(:name => 'test')
    assert_equal firm.name, client.firm_name
  end

  def test_defining_has_many_association_with_delete_all_dependency_lazily_evaluates_target_class
    ActiveRecord::Reflection::AssociationReflection.any_instance.expects(:class_name).never
    class_eval <<-EOF
      class DeleteAllModel < ActiveRecord::Base
        has_many :nonentities, :dependent => :delete_all
      end
    EOF
  end

  def test_defining_has_many_association_with_nullify_dependency_lazily_evaluates_target_class
    ActiveRecord::Reflection::AssociationReflection.any_instance.expects(:class_name).never
    class_eval <<-EOF
      class NullifyModel < ActiveRecord::Base
        has_many :nonentities, :dependent => :nullify
      end
    EOF
  end

  def test_attributes_are_being_set_when_initialized_from_has_many_association_with_where_clause
    new_comment = posts(:welcome).comments.where(:body => "Some content").build
    assert_equal new_comment.body, "Some content"
  end

  def test_attributes_are_being_set_when_initialized_from_has_many_association_with_multiple_where_clauses
    new_comment = posts(:welcome).comments.where(:body => "Some content").where(:type => 'SpecialComment').build
    assert_equal new_comment.body, "Some content"
    assert_equal new_comment.type, "SpecialComment"
    assert_equal new_comment.post_id, posts(:welcome).id
  end

  def test_include_method_in_has_many_association_should_return_true_for_instance_added_with_build
    post = Post.new
    comment = post.comments.build
    assert post.comments.include?(comment)
  end

  def test_load_target_respects_protected_attributes
    topic = Topic.create!
    reply = topic.replies.create(:title => "reply 1")
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
    bulb = Bulb.new(:color => "red")
    assert_equal "RED!", bulb.color

    car = Car.create!
    car.bulbs << bulb

    assert_equal "RED!", car.bulbs.to_a.first.color
  end

  def test_new_is_called_with_attributes_and_options
    car = Car.create(:name => 'honda')

    bulb = car.bulbs.build
    assert_equal Bulb, bulb.class

    bulb = car.bulbs.build(:bulb_type => :custom)
    assert_equal Bulb, bulb.class

    bulb = car.bulbs.build({ :bulb_type => :custom }, :as => :admin)
    assert_equal CustomBulb, bulb.class
  end

  def test_abstract_class_with_polymorphic_has_many
    post = SubStiPost.create! :title => "fooo", :body => "baa"
    tagging = Tagging.create! :taggable => post
    assert_equal [tagging], post.taggings
  end

  def test_dont_call_save_callbacks_twice_on_has_many
    firm = companies(:first_firm)
    contract = firm.contracts.create!

    assert_equal 1, contract.hi_count
    assert_equal 1, contract.bye_count
  end

  def test_association_attributes_are_available_to_after_initialize
    car = Car.create(:name => 'honda')
    bulb = car.bulbs.build

    assert_equal car.id, bulb.attributes_after_initialize['car_id']
  end

  def test_replace
    car = Car.create(:name => 'honda')
    bulb1 = car.bulbs.create
    bulb2 = Bulb.create

    assert_equal [bulb1], car.bulbs
    car.bulbs.replace([bulb2])
    assert_equal [bulb2], car.bulbs
    assert_equal [bulb2], car.reload.bulbs
  end

  def test_replace_returns_target
    car = Car.create(:name => 'honda')
    bulb1 = car.bulbs.create
    bulb2 = car.bulbs.create
    bulb3 = Bulb.create

    assert_equal [bulb1, bulb2], car.bulbs
    result = car.bulbs.replace([bulb3, bulb1])
    assert_equal [bulb1, bulb3], car.bulbs
    assert_equal [bulb1, bulb3], result
  end
end
