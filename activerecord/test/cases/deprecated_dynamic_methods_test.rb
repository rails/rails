# This file should be deleted when activerecord-deprecated_finders is removed as
# a dependency.
#
# It is kept for now as there is some fairly nuanced behaviour in the dynamic
# finders so it is useful to keep this around to guard against regressions if
# we need to change the code.

require 'cases/helper'
require 'models/topic'
require 'models/reply'
require 'models/customer'
require 'models/post'
require 'models/company'
require 'models/author'
require 'models/category'
require 'models/comment'
require 'models/person'
require 'models/reader'

class DeprecatedDynamicMethodsTest < ActiveRecord::TestCase
  fixtures :topics, :customers, :companies, :accounts, :posts, :categories, :categories_posts, :authors, :people, :comments, :readers

  def setup
    @deprecation_behavior = ActiveSupport::Deprecation.behavior
    ActiveSupport::Deprecation.behavior = :silence
  end

  def teardown
    ActiveSupport::Deprecation.behavior = @deprecation_behavior
  end

  def test_find_all_by_one_attribute
    topics = Topic.find_all_by_content("Have a nice day")
    assert_equal 2, topics.size
    assert topics.include?(topics(:first))

    assert_equal [], Topic.find_all_by_title("The First Topic!!")
  end

  def test_find_all_by_one_attribute_which_is_a_symbol
    topics = Topic.find_all_by_content("Have a nice day".to_sym)
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
    assert_equal topics(:first), topics.last

    topics = Topic.find_all_by_content("Have a nice day", :order => "id")
    assert_equal topics(:first), topics.first
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
    assert sig38.persisted?
  end

  def test_find_or_create_from_two_attributes
    number_of_topics = Topic.count
    another = Topic.find_or_create_by_title_and_author_name("Another topic","John")
    assert_equal number_of_topics + 1, Topic.count
    assert_equal another, Topic.find_or_create_by_title_and_author_name("Another topic", "John")
    assert another.persisted?
  end

  def test_find_or_create_from_one_attribute_bang
    number_of_companies = Company.count
    assert_raises(ActiveRecord::RecordInvalid) { Company.find_or_create_by_name!("") }
    assert_equal number_of_companies, Company.count
    sig38 = Company.find_or_create_by_name!("38signals")
    assert_equal number_of_companies + 1, Company.count
    assert_equal sig38, Company.find_or_create_by_name!("38signals")
    assert sig38.persisted?
  end

  def test_find_or_create_from_two_attributes_bang
    number_of_companies = Company.count
    assert_raises(ActiveRecord::RecordInvalid) { Company.find_or_create_by_name_and_firm_id!("", 17) }
    assert_equal number_of_companies, Company.count
    sig38 = Company.find_or_create_by_name_and_firm_id!("38signals", 17)
    assert_equal number_of_companies + 1, Company.count
    assert_equal sig38, Company.find_or_create_by_name_and_firm_id!("38signals", 17)
    assert sig38.persisted?
    assert_equal "38signals", sig38.name
    assert_equal 17, sig38.firm_id
  end

  def test_find_or_create_from_two_attributes_with_one_being_an_aggregate
    number_of_customers = Customer.count
    created_customer = Customer.find_or_create_by_balance_and_name(Money.new(123), "Elizabeth")
    assert_equal number_of_customers + 1, Customer.count
    assert_equal created_customer, Customer.find_or_create_by_balance(Money.new(123), "Elizabeth")
    assert created_customer.persisted?
  end

  def test_find_or_create_from_one_attribute_and_hash
    number_of_companies = Company.count
    sig38 = Company.find_or_create_by_name({:name => "38signals", :firm_id => 17, :client_of => 23})
    assert_equal number_of_companies + 1, Company.count
    assert_equal sig38, Company.find_or_create_by_name({:name => "38signals", :firm_id => 17, :client_of => 23})
    assert sig38.persisted?
    assert_equal "38signals", sig38.name
    assert_equal 17, sig38.firm_id
    assert_equal 23, sig38.client_of
  end

  def test_find_or_create_from_two_attributes_and_hash
    number_of_companies = Company.count
    sig38 = Company.find_or_create_by_name_and_firm_id({:name => "38signals", :firm_id => 17, :client_of => 23})
    assert_equal number_of_companies + 1, Company.count
    assert_equal sig38, Company.find_or_create_by_name_and_firm_id({:name => "38signals", :firm_id => 17, :client_of => 23})
    assert sig38.persisted?
    assert_equal "38signals", sig38.name
    assert_equal 17, sig38.firm_id
    assert_equal 23, sig38.client_of
  end

  def test_find_or_create_from_one_aggregate_attribute
    number_of_customers = Customer.count
    created_customer = Customer.find_or_create_by_balance(Money.new(123))
    assert_equal number_of_customers + 1, Customer.count
    assert_equal created_customer, Customer.find_or_create_by_balance(Money.new(123))
    assert created_customer.persisted?
  end

  def test_find_or_create_from_one_aggregate_attribute_and_hash
    number_of_customers = Customer.count
    balance = Money.new(123)
    name = "Elizabeth"
    created_customer = Customer.find_or_create_by_balance({:balance => balance, :name => name})
    assert_equal number_of_customers + 1, Customer.count
    assert_equal created_customer, Customer.find_or_create_by_balance({:balance => balance, :name => name})
    assert created_customer.persisted?
    assert_equal balance, created_customer.balance
    assert_equal name, created_customer.name
  end

  def test_find_or_initialize_from_one_attribute
    sig38 = Company.find_or_initialize_by_name("38signals")
    assert_equal "38signals", sig38.name
    assert !sig38.persisted?
  end

  def test_find_or_initialize_from_one_aggregate_attribute
    new_customer = Customer.find_or_initialize_by_balance(Money.new(123))
    assert_equal 123, new_customer.balance.amount
    assert !new_customer.persisted?
  end

  def test_find_or_initialize_from_one_attribute_should_set_attribute
    c = Company.find_or_initialize_by_name_and_rating("Fortune 1000", 1000)
    assert_equal "Fortune 1000", c.name
    assert_equal 1000, c.rating
    assert c.valid?
    assert !c.persisted?
  end

  def test_find_or_create_from_one_attribute_should_set_attribute
    c = Company.find_or_create_by_name_and_rating("Fortune 1000", 1000)
    assert_equal "Fortune 1000", c.name
    assert_equal 1000, c.rating
    assert c.valid?
    assert c.persisted?
  end

  def test_find_or_initialize_from_one_attribute_should_set_attribute_even_when_set_the_hash
    c = Company.find_or_initialize_by_rating(1000, {:name => "Fortune 1000"})
    assert_equal "Fortune 1000", c.name
    assert_equal 1000, c.rating
    assert c.valid?
    assert !c.persisted?
  end

  def test_find_or_create_from_one_attribute_should_set_attribute_even_when_set_the_hash
    c = Company.find_or_create_by_rating(1000, {:name => "Fortune 1000"})
    assert_equal "Fortune 1000", c.name
    assert_equal 1000, c.rating
    assert c.valid?
    assert c.persisted?
  end

  def test_find_or_initialize_should_set_attributes_if_given_as_block
    c = Company.find_or_initialize_by_name(:name => "Fortune 1000") { |f| f.rating = 1000 }
    assert_equal "Fortune 1000", c.name
    assert_equal 1000.to_f, c.rating.to_f
    assert c.valid?
    assert !c.persisted?
  end

  def test_find_or_create_should_set_attributes_if_given_as_block
    c = Company.find_or_create_by_name(:name => "Fortune 1000") { |f| f.rating = 1000 }
    assert_equal "Fortune 1000", c.name
    assert_equal 1000.to_f, c.rating.to_f
    assert c.valid?
    assert c.persisted?
  end

  def test_find_or_create_should_work_with_block_on_first_call
	  class << Company
		undef_method(:find_or_create_by_name) if method_defined?(:find_or_create_by_name)
	  end
    c = Company.find_or_create_by_name(:name => "Fortune 1000") { |f| f.rating = 1000 }
    assert_equal "Fortune 1000", c.name
    assert_equal 1000.to_f, c.rating.to_f
    assert c.valid?
    assert c.persisted?
  end

  def test_find_or_initialize_from_two_attributes
    another = Topic.find_or_initialize_by_title_and_author_name("Another topic","John")
    assert_equal "Another topic", another.title
    assert_equal "John", another.author_name
    assert !another.persisted?
  end

  def test_find_or_initialize_from_two_attributes_but_passing_only_one
    assert_raise(ArgumentError) { Topic.find_or_initialize_by_title_and_author_name("Another topic") }
  end

  def test_find_or_initialize_from_one_aggregate_attribute_and_one_not
    new_customer = Customer.find_or_initialize_by_balance_and_name(Money.new(123), "Elizabeth")
    assert_equal 123, new_customer.balance.amount
    assert_equal "Elizabeth", new_customer.name
    assert !new_customer.persisted?
  end

  def test_find_or_initialize_from_one_attribute_and_hash
    sig38 = Company.find_or_initialize_by_name({:name => "38signals", :firm_id => 17, :client_of => 23})
    assert_equal "38signals", sig38.name
    assert_equal 17, sig38.firm_id
    assert_equal 23, sig38.client_of
    assert !sig38.persisted?
  end

  def test_find_or_initialize_from_one_aggregate_attribute_and_hash
    balance = Money.new(123)
    name = "Elizabeth"
    new_customer = Customer.find_or_initialize_by_balance({:balance => balance, :name => name})
    assert_equal balance, new_customer.balance
    assert_equal name, new_customer.name
    assert !new_customer.persisted?
  end

  def test_find_last_by_one_attribute
    assert_equal Topic.last, Topic.find_last_by_title(Topic.last.title)
    assert_nil Topic.find_last_by_title("A title with no matches")
  end

  def test_find_last_by_invalid_method_syntax
    assert_raise(NoMethodError) { Topic.fail_to_find_last_by_title("The First Topic") }
    assert_raise(NoMethodError) { Topic.find_last_by_title?("The First Topic") }
  end

  def test_find_last_by_one_attribute_with_several_options
    assert_equal accounts(:signals37), Account.order('id DESC').where('id != ?', 3).find_last_by_credit_limit(50)
  end

  def test_find_last_by_one_missing_attribute
    assert_raise(NoMethodError) { Topic.find_last_by_undertitle("The Last Topic!") }
  end

  def test_find_last_by_two_attributes
    topic = Topic.last
    assert_equal topic, Topic.find_last_by_title_and_author_name(topic.title, topic.author_name)
    assert_nil Topic.find_last_by_title_and_author_name(topic.title, "Anonymous")
  end

  def test_find_last_with_limit_gives_same_result_when_loaded_and_unloaded
    scope = Topic.limit(2)
    unloaded_last = scope.last
    loaded_last = scope.to_a.last
    assert_equal loaded_last, unloaded_last
  end

  def test_find_last_with_limit_and_offset_gives_same_result_when_loaded_and_unloaded
    scope = Topic.offset(2).limit(2)
    unloaded_last = scope.last
    loaded_last = scope.to_a.last
    assert_equal loaded_last, unloaded_last
  end

  def test_find_last_with_offset_gives_same_result_when_loaded_and_unloaded
    scope = Topic.offset(3)
    unloaded_last = scope.last
    loaded_last = scope.to_a.last
    assert_equal loaded_last, unloaded_last
  end

  def test_find_all_by_nil_attribute
    topics = Topic.find_all_by_last_read nil
    assert_equal 3, topics.size
    assert topics.collect(&:last_read).all?(&:nil?)
  end

  def test_forwarding_to_dynamic_finders
    welcome = Post.find(1)
    assert_equal 4, Category.find_all_by_type('SpecialCategory').size
    assert_equal 0, welcome.categories.find_all_by_type('SpecialCategory').size
    assert_equal 2, welcome.categories.find_all_by_type('Category').size
  end

  def test_dynamic_find_all_should_respect_association_order
    assert_equal [companies(:second_client), companies(:first_client)], companies(:first_firm).clients_sorted_desc.where("type = 'Client'").to_a
    assert_equal [companies(:second_client), companies(:first_client)], companies(:first_firm).clients_sorted_desc.find_all_by_type('Client')
  end

  def test_dynamic_find_all_should_respect_association_limit
    assert_equal 1, companies(:first_firm).limited_clients.where("type = 'Client'").to_a.length
    assert_equal 1, companies(:first_firm).limited_clients.find_all_by_type('Client').length
  end

  def test_dynamic_find_all_limit_should_override_association_limit
    assert_equal 2, companies(:first_firm).limited_clients.where("type = 'Client'").limit(9_000).to_a.length
    assert_equal 2, companies(:first_firm).limited_clients.find_all_by_type('Client', :limit => 9_000).length
  end

  def test_dynamic_find_last_without_specified_order
    assert_equal companies(:second_client), companies(:first_firm).unsorted_clients.find_last_by_type('Client')
  end

  def test_dynamic_find_or_create_from_two_attributes_using_an_association
    author = authors(:david)
    number_of_posts = Post.count
    another = author.posts.find_or_create_by_title_and_body("Another Post", "This is the Body")
    assert_equal number_of_posts + 1, Post.count
    assert_equal another, author.posts.find_or_create_by_title_and_body("Another Post", "This is the Body")
    assert another.persisted?
  end

  def test_dynamic_find_all_should_respect_association_order_for_through
    assert_equal [Comment.find(10), Comment.find(7), Comment.find(6), Comment.find(3)], authors(:david).comments_desc.where("comments.type = 'SpecialComment'").to_a
    assert_equal [Comment.find(10), Comment.find(7), Comment.find(6), Comment.find(3)], authors(:david).comments_desc.find_all_by_type('SpecialComment')
  end

  def test_dynamic_find_all_should_respect_association_limit_for_through
    assert_equal 1, authors(:david).limited_comments.where("comments.type = 'SpecialComment'").to_a.length
    assert_equal 1, authors(:david).limited_comments.find_all_by_type('SpecialComment').length
  end

  def test_dynamic_find_all_order_should_override_association_limit_for_through
    assert_equal 4, authors(:david).limited_comments.where("comments.type = 'SpecialComment'").limit(9_000).to_a.length
    assert_equal 4, authors(:david).limited_comments.find_all_by_type('SpecialComment', :limit => 9_000).length
  end

  def test_find_all_include_over_the_same_table_for_through
    assert_equal 2, people(:michael).posts.includes(:people).to_a.length
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

  def test_forwarding_to_dynamic_finders_2
    welcome = Post.find(1)
    assert_equal 4, Comment.find_all_by_type('Comment').size
    assert_equal 2, welcome.comments.find_all_by_type('Comment').size
  end

  def test_dynamic_find_all_by_attributes
    authors = Author.all

    davids = authors.find_all_by_name('David')
    assert_kind_of Array, davids
    assert_equal [authors(:david)], davids
  end

  def test_dynamic_find_or_initialize_by_attributes
    authors = Author.all

    lifo = authors.find_or_initialize_by_name('Lifo')
    assert_equal "Lifo", lifo.name
    assert !lifo.persisted?

    assert_equal authors(:david), authors.find_or_initialize_by_name(:name => 'David')
  end

  def test_dynamic_find_or_create_by_attributes
    authors = Author.all

    lifo = authors.find_or_create_by_name('Lifo')
    assert_equal "Lifo", lifo.name
    assert lifo.persisted?

    assert_equal authors(:david), authors.find_or_create_by_name(:name => 'David')
  end

  def test_dynamic_find_or_create_by_attributes_bang
    authors = Author.all

    assert_raises(ActiveRecord::RecordInvalid) { authors.find_or_create_by_name!('') }

    lifo = authors.find_or_create_by_name!('Lifo')
    assert_equal "Lifo", lifo.name
    assert lifo.persisted?

    assert_equal authors(:david), authors.find_or_create_by_name!(:name => 'David')
  end

  def test_finder_block
    t = Topic.first
    found = nil
    Topic.find_by_id(t.id) { |f| found = f }
    assert_equal t, found
  end

  def test_finder_block_nothing_found
    bad_id = Topic.maximum(:id) + 1
    assert_nil Topic.find_by_id(bad_id) { |f| raise }
  end

  def test_find_returns_block_value
    t = Topic.first
    x = Topic.find_by_id(t.id) { |f| "hi mom!" }
    assert_equal "hi mom!", x
  end

  def test_dynamic_finder_with_invalid_params
    assert_raise(ArgumentError) { Topic.find_by_title 'No Title', :join => "It should be `joins'" }
  end

  def test_find_by_one_attribute_with_order_option
    assert_equal accounts(:signals37), Account.find_by_credit_limit(50, :order => 'id')
    assert_equal accounts(:rails_core_account), Account.find_by_credit_limit(50, :order => 'id DESC')
  end

  def test_dynamic_find_by_attributes_should_yield_found_object
    david = authors(:david)
    yielded_value = nil
    Author.find_by_name(david.name) do |author|
      yielded_value = author
    end
    assert_equal david, yielded_value
  end
end

class DynamicScopeTest < ActiveRecord::TestCase
  fixtures :posts

  def setup
    @test_klass = Class.new(Post) do
      def self.name; "Post"; end
    end
    @deprecation_behavior = ActiveSupport::Deprecation.behavior
    ActiveSupport::Deprecation.behavior = :silence
  end

  def teardown
    ActiveSupport::Deprecation.behavior = @deprecation_behavior
  end

  def test_dynamic_scope
    assert_equal @test_klass.scoped_by_author_id(1).find(1), @test_klass.find(1)
    assert_equal @test_klass.scoped_by_author_id_and_title(1, "Welcome to the weblog").first, @test_klass.all.merge!(:where => { :author_id => 1, :title => "Welcome to the weblog"}).first
  end

  def test_dynamic_scope_should_create_methods_after_hitting_method_missing
    assert_blank @test_klass.methods.grep(/scoped_by_type/)
    @test_klass.scoped_by_type(nil)
    assert_present @test_klass.methods.grep(/scoped_by_type/)
  end

  def test_dynamic_scope_with_less_number_of_arguments
    assert_raise(ArgumentError){ @test_klass.scoped_by_author_id_and_title(1) }
  end
end

class DynamicScopeMatchTest < ActiveRecord::TestCase
  def test_scoped_by_no_match
    assert_nil ActiveRecord::DynamicMatchers::Method.match(nil, "not_scoped_at_all")
  end

  def test_scoped_by
    model = stub(attribute_aliases: {})
    match = ActiveRecord::DynamicMatchers::Method.match(model, "scoped_by_age_and_sex_and_location")
    assert_not_nil match
    assert_equal %w(age sex location), match.attribute_names
  end
end
