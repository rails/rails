require "cases/helper"
require 'models/developer'
require 'models/project'
require 'models/company'
require 'models/topic'
require 'models/reply'
require 'models/computer'
require 'models/post'
require 'models/author'
require 'models/tag'
require 'models/tagging'
require 'models/comment'
require 'models/sponsor'
require 'models/member'
require 'models/essay'
require 'models/toy'

class BelongsToAssociationsTest < ActiveRecord::TestCase
  fixtures :accounts, :companies, :developers, :projects, :topics,
           :developers_projects, :computers, :authors, :author_addresses,
           :posts, :tags, :taggings, :comments, :sponsors, :members

  def test_belongs_to
    Client.find(3).firm.name
    assert_equal companies(:first_firm).name, Client.find(3).firm.name
    assert_not_nil Client.find(3).firm, "Microsoft should have a firm"
  end

  def test_belongs_to_with_primary_key
    client = Client.create(:name => "Primary key client", :firm_name => companies(:first_firm).name)
    assert_equal companies(:first_firm).name, client.firm_with_primary_key.name
  end

  def test_belongs_to_with_primary_key_joins_on_correct_column
    sql = Client.joins(:firm_with_primary_key).to_sql
    if current_adapter?(:MysqlAdapter) or current_adapter?(:Mysql2Adapter)
      assert_no_match(/`firm_with_primary_keys_companies`\.`id`/, sql)
      assert_match(/`firm_with_primary_keys_companies`\.`name`/, sql)
    elsif current_adapter?(:OracleAdapter)
      # on Oracle aliases are truncated to 30 characters and are quoted in uppercase
      assert_no_match(/"firm_with_primary_keys_compani"\."id"/i, sql)
      assert_match(/"firm_with_primary_keys_compani"\."name"/i, sql)
    else
      assert_no_match(/"firm_with_primary_keys_companies"\."id"/, sql)
      assert_match(/"firm_with_primary_keys_companies"\."name"/, sql)
    end
  end

  def test_proxy_assignment
    account = Account.find(1)
    assert_nothing_raised { account.firm = account.firm }
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

  def test_id_assignment
    apple = Firm.create("name" => "Apple")
    citibank = Account.create("credit_limit" => 10)
    assert_raise(NoMethodError) { citibank.firm_id = apple }
  end

  def test_natural_assignment_with_primary_key
    apple = Firm.create("name" => "Apple")
    citibank = Client.create("name" => "Primary key client")
    citibank.firm_with_primary_key = apple
    assert_equal apple.name, citibank.firm_name
  end

  def test_eager_loading_with_primary_key
    Firm.create("name" => "Apple")
    Client.create("name" => "Citibank", :firm_name => "Apple")
    citibank_result = Client.find(:first, :conditions => {:name => "Citibank"}, :include => :firm_with_primary_key)
    assert citibank_result.association_cache.key?(:firm_with_primary_key)
  end

  def test_eager_loading_with_primary_key_as_symbol
    Firm.create("name" => "Apple")
    Client.create("name" => "Citibank", :firm_name => "Apple")
    citibank_result = Client.find(:first, :conditions => {:name => "Citibank"}, :include => :firm_with_primary_key_symbols)
    assert citibank_result.association_cache.key?(:firm_with_primary_key_symbols)
  end

  def test_creating_the_belonging_object
    citibank = Account.create("credit_limit" => 10)
    apple    = citibank.create_firm("name" => "Apple")
    assert_equal apple, citibank.firm
    citibank.save
    citibank.reload
    assert_equal apple, citibank.firm
  end

  def test_creating_the_belonging_object_with_primary_key
    client = Client.create(:name => "Primary key client")
    apple  = client.create_firm_with_primary_key("name" => "Apple")
    assert_equal apple, client.firm_with_primary_key
    client.save
    client.reload
    assert_equal apple, client.firm_with_primary_key
  end

  def test_building_the_belonging_object
    citibank = Account.create("credit_limit" => 10)
    apple    = citibank.build_firm("name" => "Apple")
    citibank.save
    assert_equal apple.id, citibank.firm_id
  end

  def test_building_the_belonging_object_with_primary_key
    client = Client.create(:name => "Primary key client")
    apple  = client.build_firm_with_primary_key("name" => "Apple")
    client.save
    assert_equal apple.name, client.firm_name
  end

  def test_create!
    client  = Client.create!(:name => "Jimmy")
    account = client.create_account!(:credit_limit => 10)
    assert_equal account, client.account
    assert account.persisted?
    client.save
    client.reload
    assert_equal account, client.account
  end

  def test_failing_create!
    client  = Client.create!(:name => "Jimmy")
    assert_raise(ActiveRecord::RecordInvalid) { client.create_account! }
    assert_not_nil client.account
    assert client.account.new_record?
  end

  def test_natural_assignment_to_nil
    client = Client.find(3)
    client.firm = nil
    client.save
    assert_nil client.firm(true)
    assert_nil client.client_of
  end

  def test_natural_assignment_to_nil_with_primary_key
    client = Client.create(:name => "Primary key client", :firm_name => companies(:first_firm).name)
    client.firm_with_primary_key = nil
    client.save
    assert_nil client.firm_with_primary_key(true)
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

  def test_polymorphic_association_class
    sponsor = Sponsor.new
    assert_nil sponsor.association(:sponsorable).send(:klass)

    sponsor.sponsorable_type = '' # the column doesn't have to be declared NOT NULL
    assert_nil sponsor.association(:sponsorable).send(:klass)

    sponsor.sponsorable = Member.new :name => "Bert"
    assert_equal Member, sponsor.association(:sponsorable).send(:klass)
  end

  def test_with_polymorphic_and_condition
    sponsor = Sponsor.create
    member = Member.create :name => "Bert"
    sponsor.sponsorable = member

    assert_equal member, sponsor.sponsorable
    assert_nil sponsor.sponsorable_with_conditions
  end

  def test_with_select
    assert_equal Company.find(2).firm_with_select.attributes.size, 1
    assert_equal Company.find(2, :include => :firm_with_select ).firm_with_select.attributes.size, 1
  end

  def test_belongs_to_counter
    debate = Topic.create("title" => "debate")
    assert_equal 0, debate.send(:read_attribute, "replies_count"), "No replies yet"

    trash = debate.replies.create("title" => "blah!", "content" => "world around!")
    assert_equal 1, Topic.find(debate.id).send(:read_attribute, "replies_count"), "First reply created"

    trash.destroy
    assert_equal 0, Topic.find(debate.id).send(:read_attribute, "replies_count"), "First reply deleted"
  end

  def test_belongs_to_counter_with_assigning_nil
    p = Post.find(1)
    c = Comment.find(1)

    assert_equal p.id, c.post_id
    assert_equal 2, Post.find(p.id).comments.size

    c.post = nil

    assert_equal 1, Post.find(p.id).comments.size
  end

  def test_belongs_to_with_primary_key_counter
    debate  = Topic.create("title" => "debate")
    debate2 = Topic.create("title" => "debate2")
    reply   = Reply.create("title" => "blah!", "content" => "world around!", "parent_title" => "debate")

    assert_equal 1, debate.reload.replies_count
    assert_equal 0, debate2.reload.replies_count

    reply.topic_with_primary_key = debate2

    assert_equal 0, debate.reload.replies_count
    assert_equal 1, debate2.reload.replies_count

    reply.topic_with_primary_key = nil

    assert_equal 0, debate.reload.replies_count
    assert_equal 0, debate2.reload.replies_count
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

    assert_no_queries do
      r1.topic = t2
    end

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

  def test_belongs_to_reassign_with_namespaced_models_and_counters
    t1 = Web::Topic.create("title" => "t1")
    t2 = Web::Topic.create("title" => "t2")
    r1 = Web::Reply.new("title" => "r1", "content" => "r1")
    r1.topic = t1

    assert r1.save
    assert_equal 1, Web::Topic.find(t1.id).replies.size
    assert_equal 0, Web::Topic.find(t2.id).replies.size

    r1.topic = Web::Topic.find(t2.id)

    assert r1.save
    assert_equal 0, Web::Topic.find(t1.id).replies.size
    assert_equal 1, Web::Topic.find(t2.id).replies.size
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

  def test_belongs_to_counter_when_update_column
    topic = Topic.create!(:title => "37s")
    topic.replies.create!(:title => "re: 37s", :content => "rails")
    assert_equal 1, Topic.find(topic.id)[:replies_count]

    topic.update_column(:content, "rails is wonderfull")
    assert_equal 1, Topic.find(topic.id)[:replies_count]
  end

  def test_assignment_before_child_saved
    final_cut = Client.new("name" => "Final Cut")
    firm = Firm.find(1)
    final_cut.firm = firm
    assert !final_cut.persisted?
    assert final_cut.save
    assert final_cut.persisted?
    assert firm.persisted?
    assert_equal firm, final_cut.firm
    assert_equal firm, final_cut.firm(true)
  end

  def test_assignment_before_child_saved_with_primary_key
    final_cut = Client.new("name" => "Final Cut")
    firm = Firm.find(1)
    final_cut.firm_with_primary_key = firm
    assert !final_cut.persisted?
    assert final_cut.save
    assert final_cut.persisted?
    assert firm.persisted?
    assert_equal firm, final_cut.firm_with_primary_key
    assert_equal firm, final_cut.firm_with_primary_key(true)
  end

  def test_new_record_with_foreign_key_but_no_object
    c = Client.new("firm_id" => 1)
    # sometimes tests on Oracle fail if ORDER BY is not provided therefore add always :order with :first
    assert_equal Firm.find(:first, :order => "id"), c.firm_with_basic_id
  end

  def test_setting_foreign_key_after_nil_target_loaded
    client = Client.new
    client.firm_with_basic_id
    client.firm_id = 1

    assert_equal companies(:first_firm), client.firm_with_basic_id
  end

  def test_polymorphic_setting_foreign_key_after_nil_target_loaded
    sponsor = Sponsor.new
    sponsor.sponsorable
    sponsor.sponsorable_id = 1
    sponsor.sponsorable_type = "Member"

    assert_equal members(:groucho), sponsor.sponsorable
  end

  def test_dont_find_target_when_foreign_key_is_null
    tagging = taggings(:thinking_general)
    queries = assert_sql { tagging.super_tag }
    assert_equal 0, queries.length
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

  def test_cant_save_readonly_association
    assert_raise(ActiveRecord::ReadOnlyRecord) { companies(:first_client).readonly_firm.save! }
    assert companies(:first_client).readonly_firm.readonly?
  end

  def test_polymorphic_assignment_foreign_type_field_updating
    # should update when assigning a saved record
    sponsor = Sponsor.new
    member = Member.create
    sponsor.sponsorable = member
    assert_equal "Member", sponsor.sponsorable_type

    # should update when assigning a new record
    sponsor = Sponsor.new
    member = Member.new
    sponsor.sponsorable = member
    assert_equal "Member", sponsor.sponsorable_type
  end

  def test_polymorphic_assignment_with_primary_key_foreign_type_field_updating
    # should update when assigning a saved record
    essay = Essay.new
    writer = Author.create(:name => "David")
    essay.writer = writer
    assert_equal "Author", essay.writer_type

    # should update when assigning a new record
    essay = Essay.new
    writer = Author.new
    essay.writer = writer
    assert_equal "Author", essay.writer_type
  end

  def test_polymorphic_assignment_updates_foreign_id_field_for_new_and_saved_records
    sponsor = Sponsor.new
    saved_member = Member.create
    new_member = Member.new

    sponsor.sponsorable = saved_member
    assert_equal saved_member.id, sponsor.sponsorable_id

    sponsor.sponsorable = new_member
    assert_nil sponsor.sponsorable_id
  end

  def test_assignment_updates_foreign_id_field_for_new_and_saved_records
    client = Client.new
    saved_firm = Firm.create :name => "Saved"
    new_firm = Firm.new

    client.firm = saved_firm
    assert_equal saved_firm.id, client.client_of

    client.firm = new_firm
    assert_nil client.client_of
  end

  def test_polymorphic_assignment_with_primary_key_updates_foreign_id_field_for_new_and_saved_records
    essay = Essay.new
    saved_writer = Author.create(:name => "David")
    new_writer = Author.new

    essay.writer = saved_writer
    assert_equal saved_writer.name, essay.writer_id

    essay.writer = new_writer
    assert_nil essay.writer_id
  end

  def test_belongs_to_proxy_should_not_respond_to_private_methods
    assert_raise(NoMethodError) { companies(:first_firm).private_method }
    assert_raise(NoMethodError) { companies(:second_client).firm.private_method }
  end

  def test_belongs_to_proxy_should_respond_to_private_methods_via_send
    companies(:first_firm).send(:private_method)
    companies(:second_client).firm.send(:private_method)
  end

  def test_save_of_record_with_loaded_belongs_to
    @account = companies(:first_firm).account

    assert_nothing_raised do
      Account.find(@account.id).save!
      Account.find(@account.id, :include => :firm).save!
    end

    @account.firm.delete

    assert_nothing_raised do
      Account.find(@account.id).save!
      Account.find(@account.id, :include => :firm).save!
    end
  end

  def test_dependent_delete_and_destroy_with_belongs_to
    author_address = author_addresses(:david_address)
    author_address_extra = author_addresses(:david_address_extra)
    assert_equal [], AuthorAddress.destroyed_author_address_ids

    assert_difference "AuthorAddress.count", -2 do
      authors(:david).destroy
    end

    assert_equal [], AuthorAddress.find_all_by_id([author_address.id, author_address_extra.id])
    assert_equal [author_address.id], AuthorAddress.destroyed_author_address_ids
  end

  def test_invalid_belongs_to_dependent_option_nullify_raises_exception
    assert_raise ArgumentError do
      Author.belongs_to :special_author_address, :dependent => :nullify
    end
  end

  def test_invalid_belongs_to_dependent_option_restrict_raises_exception
    assert_raise ArgumentError do
      Author.belongs_to :special_author_address, :dependent => :restrict
    end
  end

  def test_attributes_are_being_set_when_initialized_from_belongs_to_association_with_where_clause
    new_firm = accounts(:signals37).build_firm(:name => 'Apple')
    assert_equal new_firm.name, "Apple"
  end

  def test_reassigning_the_parent_id_updates_the_object
    client = companies(:second_client)

    client.firm
    client.firm_with_condition
    firm_proxy                = client.send(:association_instance_get, :firm)
    firm_with_condition_proxy = client.send(:association_instance_get, :firm_with_condition)

    assert !firm_proxy.stale_target?
    assert !firm_with_condition_proxy.stale_target?
    assert_equal companies(:first_firm), client.firm
    assert_equal companies(:first_firm), client.firm_with_condition

    client.client_of = companies(:another_firm).id

    assert firm_proxy.stale_target?
    assert firm_with_condition_proxy.stale_target?
    assert_equal companies(:another_firm), client.firm
    assert_equal companies(:another_firm), client.firm_with_condition
  end

  def test_polymorphic_reassignment_of_associated_id_updates_the_object
    sponsor = sponsors(:moustache_club_sponsor_for_groucho)

    sponsor.sponsorable
    proxy = sponsor.send(:association_instance_get, :sponsorable)

    assert !proxy.stale_target?
    assert_equal members(:groucho), sponsor.sponsorable

    sponsor.sponsorable_id = members(:some_other_guy).id

    assert proxy.stale_target?
    assert_equal members(:some_other_guy), sponsor.sponsorable
  end

  def test_polymorphic_reassignment_of_associated_type_updates_the_object
    sponsor = sponsors(:moustache_club_sponsor_for_groucho)

    sponsor.sponsorable
    proxy = sponsor.send(:association_instance_get, :sponsorable)

    assert !proxy.stale_target?
    assert_equal members(:groucho), sponsor.sponsorable

    sponsor.sponsorable_type = 'Firm'

    assert proxy.stale_target?
    assert_equal companies(:first_firm), sponsor.sponsorable
  end

  def test_reloading_association_with_key_change
    client = companies(:second_client)
    firm = client.association(:firm)

    client.firm = companies(:another_firm)
    firm.reload
    assert_equal companies(:another_firm), firm.target

    client.client_of = companies(:first_firm).id
    firm.reload
    assert_equal companies(:first_firm), firm.target
  end

  def test_polymorphic_counter_cache
    tagging = taggings(:welcome_general)
    post    = posts(:welcome)
    comment = comments(:greetings)

    assert_difference lambda { post.reload.taggings_count }, -1 do
      assert_difference 'comment.reload.taggings_count', +1 do
        tagging.taggable = comment
      end
    end
  end

  def test_polymorphic_with_custom_foreign_type
    sponsor = sponsors(:moustache_club_sponsor_for_groucho)
    groucho = members(:groucho)
    other   = members(:some_other_guy)

    assert_equal groucho, sponsor.sponsorable
    assert_equal groucho, sponsor.thing

    sponsor.thing = other

    assert_equal other, sponsor.sponsorable
    assert_equal other, sponsor.thing

    sponsor.sponsorable = groucho

    assert_equal groucho, sponsor.sponsorable
    assert_equal groucho, sponsor.thing
  end

  def test_build_with_conditions
    client = companies(:second_client)
    firm   = client.build_bob_firm

    assert_equal "Bob", firm.name
  end

  def test_create_with_conditions
    client = companies(:second_client)
    firm   = client.create_bob_firm

    assert_equal "Bob", firm.name
  end

  def test_create_bang_with_conditions
    client = companies(:second_client)
    firm   = client.create_bob_firm!

    assert_equal "Bob", firm.name
  end

  def test_build_with_block
    client = Client.create(:name => 'Client Company')

    firm = client.build_firm{ |f| f.name = 'Agency Company' }
    assert_equal 'Agency Company', firm.name
  end

  def test_create_with_block
    client = Client.create(:name => 'Client Company')

    firm = client.create_firm{ |f| f.name = 'Agency Company' }
    assert_equal 'Agency Company', firm.name
  end

  def test_create_bang_with_block
    client = Client.create(:name => 'Client Company')

    firm = client.create_firm!{ |f| f.name = 'Agency Company' }
    assert_equal 'Agency Company', firm.name
  end

  def test_should_set_foreign_key_on_create_association
    client = Client.create! :name => "fuu"

    firm = client.create_firm :name => "baa"
    assert_equal firm.id, client.client_of
  end

  def test_should_set_foreign_key_on_create_association!
    client = Client.create! :name => "fuu"

    firm = client.create_firm! :name => "baa"
    assert_equal firm.id, client.client_of
  end

  def test_self_referential_belongs_to_with_counter_cache_assigning_nil
    comment = Comment.create! :post => posts(:thinking), :body => "fuu"
    comment.parent = nil
    comment.save!

    assert_equal nil, comment.reload.parent
    assert_equal 0, comments(:greetings).reload.children_count
  end

  def test_polymorphic_with_custom_primary_key
    toy = Toy.create!
    sponsor = Sponsor.create!(:sponsorable => toy)

    assert_equal toy, sponsor.reload.sponsorable
  end
end
