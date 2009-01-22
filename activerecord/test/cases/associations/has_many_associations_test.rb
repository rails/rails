require "cases/helper"
require 'models/developer'
require 'models/project'
require 'models/company'
require 'models/topic'
require 'models/reply'
require 'models/category'
require 'models/post'
require 'models/author'
require 'models/comment'
require 'models/person'
require 'models/reader'

class HasManyAssociationsTest < ActiveRecord::TestCase
  fixtures :accounts, :categories, :companies, :developers, :projects,
           :developers_projects, :topics, :authors, :comments, :author_addresses,
           :people, :posts, :readers

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

  def test_counting_with_empty_hash_conditions
    assert_equal 2, Firm.find(:first).plain_clients.count(:conditions => {})
  end

  def test_counting_with_single_conditions
    assert_equal 1, Firm.find(:first).plain_clients.count(:conditions => ['name=?', "Microsoft"])
  end

  def test_counting_with_single_hash
    assert_equal 1, Firm.find(:first).plain_clients.count(:conditions => {:name => "Microsoft"})
  end

  def test_counting_with_column_name_and_hash
    assert_equal 2, Firm.find(:first).plain_clients.count(:name)
  end

  def test_counting_with_association_limit
    firm = companies(:first_firm)
    assert_equal firm.limited_clients.length, firm.limited_clients.size
    assert_equal firm.limited_clients.length, firm.limited_clients.count
  end

  def test_finding
    assert_equal 2, Firm.find(:first).clients.length
  end

  def test_find_with_blank_conditions
    [[], {}, nil, ""].each do |blank|
      assert_equal 2, Firm.find(:first).clients.find(:all, :conditions => blank).size
    end
  end

  def test_find_many_with_merged_options
    assert_equal 1, companies(:first_firm).limited_clients.size
    assert_equal 1, companies(:first_firm).limited_clients.find(:all).size
    assert_equal 2, companies(:first_firm).limited_clients.find(:all, :limit => nil).size
  end

  def test_dynamic_find_should_respect_association_order
    assert_equal companies(:second_client), companies(:first_firm).clients_sorted_desc.find(:first, :conditions => "type = 'Client'")
    assert_equal companies(:second_client), companies(:first_firm).clients_sorted_desc.find_by_type('Client')
  end

  def test_dynamic_find_order_should_override_association_order
    assert_equal companies(:first_client), companies(:first_firm).clients_sorted_desc.find(:first, :conditions => "type = 'Client'", :order => 'id')
    assert_equal companies(:first_client), companies(:first_firm).clients_sorted_desc.find_by_type('Client', :order => 'id')
  end

  def test_dynamic_find_all_should_respect_association_order
    assert_equal [companies(:second_client), companies(:first_client)], companies(:first_firm).clients_sorted_desc.find(:all, :conditions => "type = 'Client'")
    assert_equal [companies(:second_client), companies(:first_client)], companies(:first_firm).clients_sorted_desc.find_all_by_type('Client')
  end

  def test_dynamic_find_all_order_should_override_association_order
    assert_equal [companies(:first_client), companies(:second_client)], companies(:first_firm).clients_sorted_desc.find(:all, :conditions => "type = 'Client'", :order => 'id')
    assert_equal [companies(:first_client), companies(:second_client)], companies(:first_firm).clients_sorted_desc.find_all_by_type('Client', :order => 'id')
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

  def test_cant_save_has_many_readonly_association
    authors(:david).readonly_comments.each { |c| assert_raise(ActiveRecord::ReadOnlyRecord) { c.save! } }
    authors(:david).readonly_comments.each { |c| assert c.readonly? }
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

  def test_finding_using_primary_key
    assert_equal "Summit", Firm.find(:first).clients_using_primary_key.first.name
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

  def test_find_string_ids_when_using_finder_sql
    firm = Firm.find(:first)

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

  def test_create_with_bang_on_has_many_raises_when_record_not_saved
    assert_raises(ActiveRecord::RecordInvalid) do
      firm = Firm.find(:first)
      firm.plain_clients.create!
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

  def test_invalid_adding_with_validate_false
    firm = Firm.find(:first)
    client = Client.new
    firm.unvalidated_clients_of_firm << client

    assert firm.valid?
    assert !client.valid?
    assert firm.save
    assert client.new_record?
  end

  def test_valid_adding_with_validate_false
    no_of_clients = Client.count

    firm = Firm.find(:first)
    client = Client.new("name" => "Apple")

    assert firm.valid?
    assert client.valid?
    assert client.new_record?

    firm.unvalidated_clients_of_firm << client

    assert firm.save
    assert !client.new_record?
    assert_equal no_of_clients+1, Client.count
  end

  def test_build
    company = companies(:first_firm)
    new_client = assert_no_queries { company.clients_of_firm.build("name" => "Another Client") }
    assert !company.clients_of_firm.loaded?

    assert_equal "Another Client", new_client.name
    assert new_client.new_record?
    assert_equal new_client, company.clients_of_firm.last
    company.name += '-changed'
    assert_queries(2) { assert company.save }
    assert !new_client.new_record?
    assert_equal 2, company.clients_of_firm(true).size
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
    company.name += '-changed'
    assert_queries(3) { assert company.save }
    assert_equal 3, company.clients_of_firm(true).size
  end

  def test_build_followed_by_save_does_not_load_target
    new_client = companies(:first_firm).clients_of_firm.build("name" => "Another Client")
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
    assert new_client.new_record?
    assert_equal new_client, company.clients_of_firm.last
    company.name += '-changed'
    assert_queries(2) { assert company.save }
    assert !new_client.new_record?
    assert_equal 2, company.clients_of_firm(true).size
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

    company.name += '-changed'
    assert_queries(3) { assert company.save }
    assert_equal 3, company.clients_of_firm(true).size
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

  def test_create_followed_by_save_does_not_load_target
    new_client = companies(:first_firm).clients_of_firm.create("name" => "Another Client")
    assert companies(:first_firm).save
    assert !companies(:first_firm).clients_of_firm.loaded?
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
    # no destroy-filters should have been called
    assert_equal [], Client.destroyed_client_ids[firm.id]

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


  def test_creation_respects_hash_condition
    ms_client = companies(:first_firm).clients_like_ms_with_hash_conditions.build

    assert        ms_client.save
    assert_equal  'Microsoft', ms_client.name

    another_ms_client = companies(:first_firm).clients_like_ms_with_hash_conditions.create

    assert        !another_ms_client.new_record?
    assert_equal  'Microsoft', another_ms_client.name
  end

  def test_dependent_delete_and_destroy_with_belongs_to
    author_address = author_addresses(:david_address)
    assert_equal [], AuthorAddress.destroyed_author_address_ids[authors(:david).id]

    assert_difference "AuthorAddress.count", -2 do
      authors(:david).destroy
    end

    assert_equal nil, AuthorAddress.find_by_id(authors(:david).author_address_id)
    assert_equal nil, AuthorAddress.find_by_id(authors(:david).author_address_extra_id)
  end

  def test_invalid_belongs_to_dependent_option_raises_exception
    assert_raises ArgumentError do
      Author.belongs_to :special_author_address, :dependent => :nullify
    end
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

  def test_get_ids_for_unloaded_finder_sql_associations_loads_them
    company = companies(:first_firm)
    assert !company.clients_using_sql.loaded?
    assert_equal [companies(:second_client).id], company.clients_using_sql_ids
    assert company.clients_using_sql.loaded?
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

  def test_modifying_a_through_a_has_many_should_raise
    [
      lambda { authors(:mary).comment_ids = [comments(:greetings).id, comments(:more_greetings).id] },
      lambda { authors(:mary).comments = [comments(:greetings), comments(:more_greetings)] },
      lambda { authors(:mary).comments << Comment.create!(:body => "Yay", :post_id => 424242) },
      lambda { authors(:mary).comments.delete(authors(:mary).comments.first) },
    ].each {|block| assert_raise(ActiveRecord::HasManyThroughCantAssociateThroughHasManyReflection, &block) }
  end


  def test_assign_ids_for_through_a_belongs_to
    post = Post.new(:title => "Assigning IDs works!", :body => "You heared it here first, folks!")
    post.person_ids = [people(:david).id, people(:michael).id]
    post.save
    post.reload
    assert_equal 2, post.people.length
    assert post.people.include?(people(:david))
  end

  def test_dynamic_find_should_respect_association_order_for_through
    assert_equal Comment.find(10), authors(:david).comments_desc.find(:first, :conditions => "comments.type = 'SpecialComment'")
    assert_equal Comment.find(10), authors(:david).comments_desc.find_by_type('SpecialComment')
  end

  def test_dynamic_find_order_should_override_association_order_for_through
    assert_equal Comment.find(3), authors(:david).comments_desc.find(:first, :conditions => "comments.type = 'SpecialComment'", :order => 'comments.id')
    assert_equal Comment.find(3), authors(:david).comments_desc.find_by_type('SpecialComment', :order => 'comments.id')
  end

  def test_dynamic_find_all_should_respect_association_order_for_through
    assert_equal [Comment.find(10), Comment.find(7), Comment.find(6), Comment.find(3)], authors(:david).comments_desc.find(:all, :conditions => "comments.type = 'SpecialComment'")
    assert_equal [Comment.find(10), Comment.find(7), Comment.find(6), Comment.find(3)], authors(:david).comments_desc.find_all_by_type('SpecialComment')
  end

  def test_dynamic_find_all_order_should_override_association_order_for_through
    assert_equal [Comment.find(3), Comment.find(6), Comment.find(7), Comment.find(10)], authors(:david).comments_desc.find(:all, :conditions => "comments.type = 'SpecialComment'", :order => 'comments.id')
    assert_equal [Comment.find(3), Comment.find(6), Comment.find(7), Comment.find(10)], authors(:david).comments_desc.find_all_by_type('SpecialComment', :order => 'comments.id')
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

  uses_mocha 'mocking Comment.transaction' do
    def test_association_proxy_transaction_method_starts_transaction_in_association_class
      Comment.expects(:transaction)
      Post.find(:first).comments.transaction do
        # nothing
      end
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
    firm = Firm.find(:first)
    client = firm.clients_using_primary_key.create!(:name => 'test')
    assert_equal firm.name, client.firm_name
  end
end

