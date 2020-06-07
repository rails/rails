# frozen_string_literal: true

require "cases/helper"
require "models/post"
require "models/author"
require "models/account"
require "models/categorization"
require "models/comment"
require "models/company"
require "models/tagging"
require "models/topic"
require "models/reply"
require "models/rating"
require "models/entrant"
require "models/project"
require "models/developer"
require "models/computer"
require "models/customer"
require "models/toy"
require "models/matey"
require "models/dog"
require "models/car"
require "models/tyre"
require "models/subscriber"
require "models/non_primary_key"
require "support/stubs/strong_parameters"

class FinderTest < ActiveRecord::TestCase
  fixtures :companies, :topics, :entrants, :developers, :developers_projects, :posts, :comments, :accounts, :authors, :author_addresses, :customers, :categories, :categorizations, :cars

  def test_find_by_id_with_hash
    assert_nothing_raised do
      Post.find_by_id(limit: 1)
    end
  end

  def test_find_by_title_and_id_with_hash
    assert_nothing_raised do
      Post.find_by_title_and_id("foo", limit: 1)
    end
  end

  def test_find
    assert_equal(topics(:first).title, Topic.find(1).title)
  end

  def test_find_with_proc_parameter_and_block
    exception = assert_raises(RuntimeError) do
      Topic.all.find(-> { raise "should happen" }) { |e| e.title == "non-existing-title" }
    end
    assert_equal "should happen", exception.message

    assert_nothing_raised do
      Topic.all.find(-> { raise "should not happen" }) { |e| e.title == topics(:first).title }
    end
  end

  def test_find_with_ids_returning_ordered
    records = Topic.find([4, 2, 5])
    assert_equal "The Fourth Topic of the day", records[0].title
    assert_equal "The Second Topic of the day", records[1].title
    assert_equal "The Fifth Topic of the day", records[2].title

    records = Topic.find(4, 2, 5)
    assert_equal "The Fourth Topic of the day", records[0].title
    assert_equal "The Second Topic of the day", records[1].title
    assert_equal "The Fifth Topic of the day", records[2].title

    records = Topic.find(["4", "2", "5"])
    assert_equal "The Fourth Topic of the day", records[0].title
    assert_equal "The Second Topic of the day", records[1].title
    assert_equal "The Fifth Topic of the day", records[2].title

    records = Topic.find("4", "2", "5")
    assert_equal "The Fourth Topic of the day", records[0].title
    assert_equal "The Second Topic of the day", records[1].title
    assert_equal "The Fifth Topic of the day", records[2].title
  end

  def test_find_with_ids_and_order_clause
    # The order clause takes precedence over the informed ids
    records = Topic.order(:author_name).find([5, 3, 1])
    assert_equal "The Third Topic of the day", records[0].title
    assert_equal "The First Topic",            records[1].title
    assert_equal "The Fifth Topic of the day", records[2].title

    records = Topic.order(:id).find([5, 3, 1])
    assert_equal "The First Topic",            records[0].title
    assert_equal "The Third Topic of the day", records[1].title
    assert_equal "The Fifth Topic of the day", records[2].title
  end

  def test_find_with_ids_with_limit_and_order_clause
    # The order clause takes precedence over the informed ids
    records = Topic.limit(2).order(:id).find([5, 3, 1])
    assert_equal 2, records.size
    assert_equal "The First Topic",            records[0].title
    assert_equal "The Third Topic of the day", records[1].title
  end

  def test_find_with_ids_and_limit
    records = Topic.limit(3).find([3, 2, 5, 1, 4])
    assert_equal 3, records.size
    assert_equal "The Third Topic of the day",  records[0].title
    assert_equal "The Second Topic of the day", records[1].title
    assert_equal "The Fifth Topic of the day",  records[2].title
  end

  def test_find_with_ids_where_and_limit
    # Please note that Topic 1 is the only not approved so
    # if it were among the first 3 it would raise an ActiveRecord::RecordNotFound
    records = Topic.where(approved: true).limit(3).find([3, 2, 5, 1, 4])
    assert_equal 3, records.size
    assert_equal "The Third Topic of the day",  records[0].title
    assert_equal "The Second Topic of the day", records[1].title
    assert_equal "The Fifth Topic of the day",  records[2].title
  end

  def test_find_with_ids_and_offset
    records = Topic.offset(2).find([3, 2, 5, 1, 4])
    assert_equal 3, records.size
    assert_equal "The Fifth Topic of the day",  records[0].title
    assert_equal "The First Topic",             records[1].title
    assert_equal "The Fourth Topic of the day", records[2].title
  end

  def test_find_with_ids_with_no_id_passed
    exception = assert_raises(ActiveRecord::RecordNotFound) { Topic.find }
    assert_equal exception.model, "Topic"
    assert_equal exception.primary_key, "id"
  end

  def test_find_with_ids_with_id_out_of_range
    exception = assert_raises(ActiveRecord::RecordNotFound) do
      Topic.find("9999999999999999999999999999999")
    end

    assert_equal exception.model, "Topic"
    assert_equal exception.primary_key, "id"
  end

  def test_find_passing_active_record_object_is_not_permitted
    assert_raises(ArgumentError) do
      Topic.find(Topic.last)
    end
  end

  def test_symbols_table_ref
    gc_disabled = GC.disable
    Post.where("author_id" => nil)  # warm up
    x = Symbol.all_symbols.count
    Post.where("title" => { "xxxqqqq" => "bar" })
    assert_equal x, Symbol.all_symbols.count
  ensure
    GC.enable if gc_disabled == false
  end

  # find should handle strings that come from URLs
  # (example: Category.find(params[:id]))
  def test_find_with_string
    assert_equal(Topic.find(1).title, Topic.find("1").title)
  end

  def test_exists
    assert_equal true, Topic.exists?(1)
    assert_equal true, Topic.exists?("1")
    assert_equal true, Topic.exists?(title: "The First Topic")
    assert_equal true, Topic.exists?(heading: "The First Topic")
    assert_equal true, Topic.exists?(author_name: "Mary", approved: true)
    assert_equal true, Topic.exists?(["parent_id = ?", 1])
    assert_equal true, Topic.exists?(id: [1, 9999])

    assert_equal false, Topic.exists?(45)
    assert_equal false, Topic.exists?(9999999999999999999999999999999)
    assert_equal false, Topic.exists?(Topic.new.id)

    assert_raise(NoMethodError) { Topic.exists?([1, 2]) }
  end

  def test_exists_with_scope
    davids = Author.where(name: "David")
    assert_equal true, davids.exists?
    assert_equal true, davids.exists?(authors(:david).id)
    assert_equal false, davids.exists?(authors(:mary).id)
    assert_equal false, davids.exists?("42")
    assert_equal false, davids.exists?(42)
    assert_equal false, davids.exists?(davids.new.id)

    fake = Author.where(name: "fake author")
    assert_equal false, fake.exists?
    assert_equal false, fake.exists?(authors(:david).id)
  end

  def test_exists_uses_existing_scope
    post = authors(:david).posts.first
    authors = Author.includes(:posts).where(name: "David", posts: { id: post.id })
    assert_equal true, authors.exists?(authors(:david).id)
  end

  def test_any_with_scope_on_hash_includes
    post = authors(:david).posts.first
    categories = Categorization.includes(author: :posts).where(posts: { id: post.id })
    assert_equal true, categories.exists?
  end

  def test_exists_with_polymorphic_relation
    post = Post.create!(title: "Post", body: "default", taggings: [Tagging.new(comment: "tagging comment")])
    relation = Post.tagged_with_comment("tagging comment")

    assert_equal true, relation.exists?(title: ["Post"])
    assert_equal true, relation.exists?(["title LIKE ?", "Post%"])
    assert_equal true, relation.exists?
    assert_equal true, relation.exists?(post.id)
    assert_equal true, relation.exists?(post.id.to_s)

    assert_equal false, relation.exists?(false)
  end

  def test_exists_with_string
    assert_equal false, Subscriber.exists?("foo")
    assert_equal false, Subscriber.exists?("   ")

    Subscriber.create!(id: "foo")
    Subscriber.create!(id: "   ")

    assert_equal true, Subscriber.exists?("foo")
    assert_equal true, Subscriber.exists?("   ")
  end

  def test_exists_with_strong_parameters
    assert_equal false, Subscriber.exists?(ProtectedParams.new(nick: "foo").permit!)

    Subscriber.create!(nick: "foo")

    assert_equal true, Subscriber.exists?(ProtectedParams.new(nick: "foo").permit!)

    assert_raises(ActiveModel::ForbiddenAttributesError) do
      Subscriber.exists?(ProtectedParams.new(nick: "foo"))
    end
  end

  def test_exists_passing_active_record_object_is_not_permitted
    assert_raises(ArgumentError) do
      Topic.exists?(Topic.new)
    end
  end

  def test_exists_does_not_select_columns_without_alias
    c = Topic.connection
    assert_sql(/SELECT 1 AS one FROM #{Regexp.escape(c.quote_table_name("topics"))}/i) do
      Topic.exists?
    end
  end

  def test_exists_returns_true_with_one_record_and_no_args
    assert_equal true, Topic.exists?
  end

  def test_exists_returns_false_with_false_arg
    assert_equal false, Topic.exists?(false)
  end

  # exists? should handle nil for id's that come from URLs and always return false
  # (example: Topic.exists?(params[:id])) where params[:id] is nil
  def test_exists_with_nil_arg
    assert_equal false, Topic.exists?(nil)
    assert_equal true, Topic.exists?

    assert_equal false, Topic.first.replies.exists?(nil)
    assert_equal true, Topic.first.replies.exists?
  end

  def test_exists_with_empty_hash_arg
    assert_equal true, Topic.exists?({})
  end

  def test_exists_with_distinct_and_offset_and_joins
    assert Post.left_joins(:comments).distinct.offset(10).exists?
    assert_not Post.left_joins(:comments).distinct.offset(11).exists?
  end

  def test_exists_with_distinct_and_offset_and_select
    assert Post.select(:body).distinct.offset(4).exists?
    assert_not Post.select(:body).distinct.offset(5).exists?
  end

  def test_exists_with_distinct_and_offset_and_eagerload_and_order
    assert Post.eager_load(:comments).distinct.offset(10).merge(Comment.order(post_id: :asc)).exists?
    assert_not Post.eager_load(:comments).distinct.offset(11).merge(Comment.order(post_id: :asc)).exists?
  end

  # Ensure +exists?+ runs without an error by excluding distinct value.
  # See https://github.com/rails/rails/pull/26981.
  def test_exists_with_order_and_distinct
    assert_equal true, Topic.order(:id).distinct.exists?
  end

  # Ensure +exists?+ runs without an error by excluding order value.
  def test_exists_with_order
    assert_equal true, Topic.order(Arel.sql("invalid sql here")).exists?
  end

  def test_exists_with_large_number
    assert_equal true, Topic.where(id: [1, 9223372036854775808]).exists?
    assert_equal true, Topic.where(id: 1..9223372036854775808).exists?
    assert_equal true, Topic.where(id: -9223372036854775809..9223372036854775808).exists?
    assert_equal false, Topic.where(id: 9223372036854775808..9223372036854775809).exists?
    assert_equal false, Topic.where(id: -9223372036854775810..-9223372036854775809).exists?
    assert_equal false, Topic.where(id: 9223372036854775808..1).exists?
    assert_equal true, Topic.where(id: 1).or(Topic.where(id: 9223372036854775808)).exists?
    assert_equal true, Topic.where.not(id: 9223372036854775808).exists?
  end

  def test_exists_with_joins
    assert_equal true, Topic.joins(:replies).where(replies_topics: { approved: true }).order("replies_topics.created_at DESC").exists?
  end

  def test_exists_with_left_joins
    assert_equal true, Topic.left_joins(:replies).where(replies_topics: { approved: true }).order("replies_topics.created_at DESC").exists?
  end

  def test_exists_with_eager_load
    assert_equal true, Topic.eager_load(:replies).where(replies_topics: { approved: true }).order("replies_topics.created_at DESC").exists?
  end

  def test_exists_with_includes_limit_and_empty_result
    assert_no_queries { assert_equal false, Topic.includes(:replies).limit(0).exists? }
    assert_queries(1) { assert_equal false, Topic.includes(:replies).limit(1).where("0 = 1").exists? }
  end

  def test_exists_with_distinct_association_includes_and_limit
    author = Author.first
    unique_categorized_posts = author.unique_categorized_posts.includes(:special_comments)
    assert_no_queries { assert_equal false, unique_categorized_posts.limit(0).exists? }
    assert_queries(1) { assert_equal true, unique_categorized_posts.limit(1).exists? }
  end

  def test_exists_with_distinct_association_includes_limit_and_order
    author = Author.first
    unique_categorized_posts = author.unique_categorized_posts.includes(:special_comments).order("comments.tags_count DESC")
    assert_no_queries { assert_equal false, unique_categorized_posts.limit(0).exists? }
    assert_queries(1) { assert_equal true, unique_categorized_posts.limit(1).exists? }
  end

  def test_exists_should_reference_correct_aliases_while_joining_tables_of_has_many_through_association
    ratings = developers(:david).ratings.includes(comment: :post).where(posts: { id: 1 })
    assert_queries(1) { assert_not_predicate ratings.limit(1), :exists? }
  end

  def test_exists_with_empty_table_and_no_args_given
    Topic.delete_all
    assert_equal false, Topic.exists?
  end

  def test_exists_with_aggregate_having_three_mappings
    existing_address = customers(:david).address
    assert_equal true, Customer.exists?(address: existing_address)
  end

  def test_exists_with_aggregate_having_three_mappings_with_one_difference
    existing_address = customers(:david).address
    assert_equal false, Customer.exists?(address: Address.new(existing_address.street, existing_address.city, existing_address.country + "1"))
    assert_equal false, Customer.exists?(address: Address.new(existing_address.street, existing_address.city + "1", existing_address.country))
    assert_equal false, Customer.exists?(address: Address.new(existing_address.street + "1", existing_address.city, existing_address.country))
  end

  def test_exists_does_not_instantiate_records
    assert_not_called(Developer, :instantiate) do
      Developer.exists?
    end
  end

  def test_find_by_array_of_one_id
    assert_kind_of(Array, Topic.find([ 1 ]))
    assert_equal(1, Topic.find([ 1 ]).length)
  end

  def test_find_by_ids
    assert_equal 2, Topic.find(1, 2).size
    assert_equal topics(:second).title, Topic.find([2]).first.title
  end

  def test_find_by_ids_with_limit_and_offset
    assert_equal 2, Entrant.limit(2).find([1, 3, 2]).size
    entrants = Entrant.limit(3).offset(2).find([1, 3, 2])
    assert_equal 1, entrants.size
    assert_equal "Ruby Guru", entrants.first.name

    # Also test an edge case: If you have 11 results, and you set a
    #   limit of 3 and offset of 9, then you should find that there
    #   will be only 2 results, regardless of the limit.
    devs = Developer.all
    last_devs = Developer.limit(3).offset(9).find(devs.map(&:id).sort)
    assert_equal 2, last_devs.size
    assert_equal "fixture_10", last_devs[0].name
    assert_equal "Jamis", last_devs[1].name
  end

  def test_find_with_large_number
    assert_queries(0) do
      assert_raises(ActiveRecord::RecordNotFound) { Topic.find("9999999999999999999999999999999") }
    end
  end

  def test_find_by_with_large_number
    assert_queries(0) do
      assert_nil Topic.find_by(id: "9999999999999999999999999999999")
    end
  end

  def test_find_by_id_with_large_number
    assert_queries(0) do
      assert_nil Topic.find_by_id("9999999999999999999999999999999")
    end
  end

  def test_find_on_relation_with_large_number
    assert_raises(ActiveRecord::RecordNotFound) do
      Topic.where("1=1").find(9999999999999999999999999999999)
    end
    assert_equal topics(:first), Topic.where(id: [1, 9999999999999999999999999999999]).find(1)
  end

  def test_find_by_on_relation_with_large_number
    assert_nil Topic.where("1=1").find_by(id: 9999999999999999999999999999999)
    assert_equal topics(:first), Topic.where(id: [1, 9999999999999999999999999999999]).find_by(id: 1)
  end

  def test_find_by_bang_on_relation_with_large_number
    assert_raises(ActiveRecord::RecordNotFound) do
      Topic.where("1=1").find_by!(id: 9999999999999999999999999999999)
    end
    assert_equal topics(:first), Topic.where(id: [1, 9999999999999999999999999999999]).find_by!(id: 1)
  end

  def test_find_an_empty_array
    empty_array = []
    result = Topic.find(empty_array)
    assert_equal [], result
    assert_not_same empty_array, result
  end

  def test_find_doesnt_have_implicit_ordering
    assert_sql(/^((?!ORDER).)*$/) { Topic.find(1) }
  end

  def test_find_by_ids_missing_one
    assert_raise(ActiveRecord::RecordNotFound) { Topic.find(1, 2, 45) }
  end

  def test_find_with_group_and_sanitized_having_method
    developers = Developer.group(:salary).having("sum(salary) > ?", 10000).select("salary").to_a
    assert_equal 3, developers.size
    assert_equal 3, developers.map(&:salary).uniq.size
    assert developers.all? { |developer| developer.salary > 10000 }
  end

  def test_find_with_entire_select_statement
    topics = Topic.find_by_sql "SELECT * FROM topics WHERE author_name = 'Mary'"

    assert_equal(1, topics.size)
    assert_equal(topics(:second).title, topics.first.title)
  end

  def test_find_with_prepared_select_statement
    topics = Topic.find_by_sql ["SELECT * FROM topics WHERE author_name = ?", "Mary"]

    assert_equal(1, topics.size)
    assert_equal(topics(:second).title, topics.first.title)
  end

  def test_find_by_sql_with_sti_on_joined_table
    accounts = Account.find_by_sql("SELECT * FROM accounts INNER JOIN companies ON companies.id = accounts.firm_id")
    assert_equal [Account], accounts.collect(&:class).uniq
  end

  def test_find_by_association_subquery
    firm = companies(:first_firm)
    assert_equal firm.account, Account.find_by(firm: Firm.where(id: firm))
    assert_equal firm.account, Account.find_by(firm_id: Firm.where(id: firm))
  end

  def test_find_by_and_where_consistency_with_active_record_instance
    firm = companies(:first_firm)
    assert_equal Account.where(firm_id: firm).take, Account.find_by(firm_id: firm)
  end

  def test_find_by_with_alias
    account = accounts(:last_account)
    assert_equal account, Account.find_by(available_credit: account.available_credit)
  end

  def test_take
    assert_equal topics(:first), Topic.where("title = 'The First Topic'").take
  end

  def test_take_failing
    assert_nil Topic.where("title = 'This title does not exist'").take
  end

  def test_take_bang_present
    assert_nothing_raised do
      assert_equal topics(:second), Topic.where("title = 'The Second Topic of the day'").take!
    end
  end

  def test_take_bang_missing
    assert_raises_with_message ActiveRecord::RecordNotFound, "Couldn't find Topic" do
      Topic.where("title = 'This title does not exist'").take!
    end
  end

  def test_first
    assert_equal topics(:second).title, Topic.where("title = 'The Second Topic of the day'").first.title
  end

  def test_first_failing
    assert_nil Topic.where("title = 'The Second Topic of the day!'").first
  end

  def test_first_bang_present
    assert_nothing_raised do
      assert_equal topics(:second), Topic.where("title = 'The Second Topic of the day'").first!
    end
  end

  def test_first_bang_missing
    assert_raises_with_message ActiveRecord::RecordNotFound, "Couldn't find Topic" do
      Topic.where("title = 'This title does not exist'").first!
    end
  end

  def test_first_have_primary_key_order_by_default
    expected = topics(:first)
    expected.touch # PostgreSQL changes the default order if no order clause is used
    assert_equal expected, Topic.first
    assert_equal expected, Topic.limit(5).first
    assert_equal expected, Topic.order(nil).first
  end

  def test_model_class_responds_to_first_bang
    assert Topic.first!
    Topic.delete_all
    assert_raises_with_message ActiveRecord::RecordNotFound, "Couldn't find Topic" do
      Topic.first!
    end
  end

  def test_second
    assert_equal topics(:second).title, Topic.second.title
  end

  def test_second_with_offset
    assert_equal topics(:fifth), Topic.offset(3).second
  end

  def test_second_have_primary_key_order_by_default
    expected = topics(:second)
    expected.touch # PostgreSQL changes the default order if no order clause is used
    assert_equal expected, Topic.second
    assert_equal expected, Topic.limit(5).second
    assert_equal expected, Topic.order(nil).second
  end

  def test_model_class_responds_to_second_bang
    assert Topic.second!
    Topic.delete_all
    assert_raises_with_message ActiveRecord::RecordNotFound, "Couldn't find Topic" do
      Topic.second!
    end
  end

  def test_third
    assert_equal topics(:third).title, Topic.third.title
  end

  def test_third_with_offset
    assert_equal topics(:fifth), Topic.offset(2).third
  end

  def test_third_have_primary_key_order_by_default
    expected = topics(:third)
    expected.touch # PostgreSQL changes the default order if no order clause is used
    assert_equal expected, Topic.third
    assert_equal expected, Topic.limit(5).third
    assert_equal expected, Topic.order(nil).third
  end

  def test_model_class_responds_to_third_bang
    assert Topic.third!
    Topic.delete_all
    assert_raises_with_message ActiveRecord::RecordNotFound, "Couldn't find Topic" do
      Topic.third!
    end
  end

  def test_fourth
    assert_equal topics(:fourth).title, Topic.fourth.title
  end

  def test_fourth_with_offset
    assert_equal topics(:fifth), Topic.offset(1).fourth
  end

  def test_fourth_have_primary_key_order_by_default
    expected = topics(:fourth)
    expected.touch # PostgreSQL changes the default order if no order clause is used
    assert_equal expected, Topic.fourth
    assert_equal expected, Topic.limit(5).fourth
    assert_equal expected, Topic.order(nil).fourth
  end

  def test_model_class_responds_to_fourth_bang
    assert Topic.fourth!
    Topic.delete_all
    assert_raises_with_message ActiveRecord::RecordNotFound, "Couldn't find Topic" do
      Topic.fourth!
    end
  end

  def test_fifth
    assert_equal topics(:fifth).title, Topic.fifth.title
  end

  def test_fifth_with_offset
    assert_equal topics(:fifth), Topic.offset(0).fifth
  end

  def test_fifth_have_primary_key_order_by_default
    expected = topics(:fifth)
    expected.touch # PostgreSQL changes the default order if no order clause is used
    assert_equal expected, Topic.fifth
    assert_equal expected, Topic.limit(5).fifth
    assert_equal expected, Topic.order(nil).fifth
  end

  def test_model_class_responds_to_fifth_bang
    assert Topic.fifth!
    Topic.delete_all
    assert_raises_with_message ActiveRecord::RecordNotFound, "Couldn't find Topic" do
      Topic.fifth!
    end
  end

  def test_second_to_last
    assert_equal topics(:fourth).title, Topic.second_to_last.title

    # test with offset
    assert_equal topics(:fourth), Topic.offset(1).second_to_last
    assert_equal topics(:fourth), Topic.offset(2).second_to_last
    assert_equal topics(:fourth), Topic.offset(3).second_to_last
    assert_nil Topic.offset(4).second_to_last
    assert_nil Topic.offset(5).second_to_last

    # test with limit
    assert_nil Topic.limit(1).second
    assert_nil Topic.limit(1).second_to_last
  end

  def test_second_to_last_have_primary_key_order_by_default
    expected = topics(:fourth)
    expected.touch # PostgreSQL changes the default order if no order clause is used
    assert_equal expected, Topic.second_to_last
  end

  def test_model_class_responds_to_second_to_last_bang
    assert Topic.second_to_last!
    Topic.delete_all
    assert_raises_with_message ActiveRecord::RecordNotFound, "Couldn't find Topic" do
      Topic.second_to_last!
    end
  end

  def test_third_to_last
    assert_equal topics(:third).title, Topic.third_to_last.title

    # test with offset
    assert_equal topics(:third), Topic.offset(1).third_to_last
    assert_equal topics(:third), Topic.offset(2).third_to_last
    assert_nil Topic.offset(3).third_to_last
    assert_nil Topic.offset(4).third_to_last
    assert_nil Topic.offset(5).third_to_last

    # test with limit
    assert_nil Topic.limit(1).third
    assert_nil Topic.limit(1).third_to_last
    assert_nil Topic.limit(2).third
    assert_nil Topic.limit(2).third_to_last
  end

  def test_third_to_last_have_primary_key_order_by_default
    expected = topics(:third)
    expected.touch # PostgreSQL changes the default order if no order clause is used
    assert_equal expected, Topic.third_to_last
  end

  def test_model_class_responds_to_third_to_last_bang
    assert Topic.third_to_last!
    Topic.delete_all
    assert_raises_with_message ActiveRecord::RecordNotFound, "Couldn't find Topic" do
      Topic.third_to_last!
    end
  end

  def test_last_bang_present
    assert_nothing_raised do
      assert_equal topics(:second), Topic.where("title = 'The Second Topic of the day'").last!
    end
  end

  def test_last_bang_missing
    assert_raises_with_message ActiveRecord::RecordNotFound, "Couldn't find Topic" do
      Topic.where("title = 'This title does not exist'").last!
    end
  end

  def test_model_class_responds_to_last_bang
    assert_equal topics(:fifth), Topic.last!
    assert_raises_with_message ActiveRecord::RecordNotFound, "Couldn't find Topic" do
      Topic.delete_all
      Topic.last!
    end
  end

  def test_take_and_first_and_last_with_integer_should_use_sql_limit
    assert_sql(/LIMIT|ROWNUM <=|FETCH FIRST/) { Topic.take(3).entries }
    assert_sql(/LIMIT|ROWNUM <=|FETCH FIRST/) { Topic.first(2).entries }
    assert_sql(/LIMIT|ROWNUM <=|FETCH FIRST/) { Topic.last(5).entries }
  end

  def test_last_with_integer_and_order_should_keep_the_order
    assert_equal Topic.order("title").to_a.last(2), Topic.order("title").last(2)
  end

  def test_last_with_integer_and_order_should_use_sql_limit
    relation = Topic.order("title")
    assert_queries(1) { relation.last(5) }
    assert_not_predicate relation, :loaded?
  end

  def test_last_with_integer_and_reorder_should_use_sql_limit
    relation = Topic.reorder("title")
    assert_queries(1) { relation.last(5) }
    assert_not_predicate relation, :loaded?
  end

  def test_last_on_loaded_relation_should_not_use_sql
    relation = Topic.limit(10).load
    assert_no_queries do
      relation.last
      relation.last(2)
    end
  end

  def test_last_with_irreversible_order
    assert_raises(ActiveRecord::IrreversibleOrderError) do
      Topic.order(Arel.sql("coalesce(author_name, title)")).last
    end
  end

  def test_last_on_relation_with_limit_and_offset
    post = posts("sti_comments")

    comments = post.comments.order(id: :asc)
    assert_equal comments.limit(2).to_a.last, comments.limit(2).last
    assert_equal comments.limit(2).to_a.last(2), comments.limit(2).last(2)
    assert_equal comments.limit(2).to_a.last(3), comments.limit(2).last(3)

    assert_equal comments.offset(2).to_a.last, comments.offset(2).last
    assert_equal comments.offset(2).to_a.last(2), comments.offset(2).last(2)
    assert_equal comments.offset(2).to_a.last(3), comments.offset(2).last(3)

    comments = comments.offset(1)
    assert_equal comments.limit(2).to_a.last, comments.limit(2).last
    assert_equal comments.limit(2).to_a.last(2), comments.limit(2).last(2)
    assert_equal comments.limit(2).to_a.last(3), comments.limit(2).last(3)
  end

  def test_first_on_relation_with_limit_and_offset
    post = posts("sti_comments")

    comments = post.comments.order(id: :asc)
    assert_equal comments.limit(2).to_a.first, comments.limit(2).first
    assert_equal comments.limit(2).to_a.first(2), comments.limit(2).first(2)
    assert_equal comments.limit(2).to_a.first(3), comments.limit(2).first(3)

    assert_equal comments.offset(2).to_a.first, comments.offset(2).first
    assert_equal comments.offset(2).to_a.first(2), comments.offset(2).first(2)
    assert_equal comments.offset(2).to_a.first(3), comments.offset(2).first(3)

    comments = comments.offset(1)
    assert_equal comments.limit(2).to_a.first, comments.limit(2).first
    assert_equal comments.limit(2).to_a.first(2), comments.limit(2).first(2)
    assert_equal comments.limit(2).to_a.first(3), comments.limit(2).first(3)
  end

  def test_first_have_determined_order_by_default
    expected = [companies(:second_client), companies(:another_client)]
    clients = Client.where(name: expected.map(&:name))

    assert_equal expected, clients.first(2)
    assert_equal expected, clients.limit(5).first(2)
    assert_equal expected, clients.order(nil).first(2)
  end

  def test_implicit_order_column_is_configurable
    old_implicit_order_column = Topic.implicit_order_column
    Topic.implicit_order_column = "title"

    assert_equal topics(:fifth), Topic.first
    assert_equal topics(:third), Topic.last

    c = Topic.connection
    assert_sql(/ORDER BY #{Regexp.escape(c.quote_table_name("topics.title"))} DESC, #{Regexp.escape(c.quote_table_name("topics.id"))} DESC LIMIT/i) {
      Topic.last
    }
  ensure
    Topic.implicit_order_column = old_implicit_order_column
  end

  def test_implicit_order_set_to_primary_key
    old_implicit_order_column = Topic.implicit_order_column
    Topic.implicit_order_column = "id"

    c = Topic.connection
    assert_sql(/ORDER BY #{Regexp.escape(c.quote_table_name("topics.id"))} DESC LIMIT/i) {
      Topic.last
    }
  ensure
    Topic.implicit_order_column = old_implicit_order_column
  end

  def test_implicit_order_for_model_without_primary_key
    old_implicit_order_column = NonPrimaryKey.implicit_order_column
    NonPrimaryKey.implicit_order_column = "created_at"

    c = NonPrimaryKey.connection
    assert_sql(/ORDER BY #{Regexp.escape(c.quote_table_name("non_primary_keys.created_at"))} DESC LIMIT/i) {
      NonPrimaryKey.last
    }
  ensure
    NonPrimaryKey.implicit_order_column = old_implicit_order_column
  end

  def test_take_and_first_and_last_with_integer_should_return_an_array
    assert_kind_of Array, Topic.take(5)
    assert_kind_of Array, Topic.first(5)
    assert_kind_of Array, Topic.last(5)
  end

  def test_unexisting_record_exception_handling
    assert_raise(ActiveRecord::RecordNotFound) {
      Topic.find(1).parent
    }

    Topic.find(2).topic
  end

  def test_find_only_some_columns
    topic = Topic.select("author_name").find(1)
    assert_raise(ActiveModel::MissingAttributeError) { topic.title }
    assert_raise(ActiveModel::MissingAttributeError) { topic.title? }
    assert_nil topic.read_attribute("title")
    assert_equal "David", topic.author_name
    assert_not topic.attribute_present?("title")
    assert_not topic.attribute_present?(:title)
    assert topic.attribute_present?("author_name")
    assert_respond_to topic, "author_name"
  end

  def test_find_on_array_conditions
    assert Topic.where(["approved = ?", false]).find(1)
    assert_raise(ActiveRecord::RecordNotFound) { Topic.where(["approved = ?", true]).find(1) }
  end

  def test_find_on_hash_conditions
    assert Topic.where(approved: false).find(1)
    assert_raise(ActiveRecord::RecordNotFound) { Topic.where(approved: true).find(1) }
  end

  def test_find_on_hash_conditions_with_qualified_attribute_dot_notation_string
    assert Topic.where("topics.approved" => false).find(1)
    assert_raise(ActiveRecord::RecordNotFound) { Topic.where("topics.approved" => true).find(1) }
  end

  def test_find_on_hash_conditions_with_qualified_attribute_dot_notation_symbol
    assert Topic.where('topics.approved': false).find(1)
    assert_raise(ActiveRecord::RecordNotFound) { Topic.where('topics.approved': true).find(1) }
  end

  def test_find_on_hash_conditions_with_hashed_table_name
    assert Topic.where(topics: { approved: false }).find(1)
    assert_raise(ActiveRecord::RecordNotFound) { Topic.where(topics: { approved: true }).find(1) }
  end

  def test_find_on_combined_explicit_and_hashed_table_names
    assert Topic.where("topics.approved" => false, topics: { author_name: "David" }).find(1)
    assert_raise(ActiveRecord::RecordNotFound) { Topic.where("topics.approved" => true, topics: { author_name: "David" }).find(1) }
    assert_raise(ActiveRecord::RecordNotFound) { Topic.where("topics.approved" => false, topics: { author_name: "Melanie" }).find(1) }
  end

  def test_find_with_hash_conditions_on_joined_table
    firms = Firm.joins(:account).where(accounts: { credit_limit: 50 })
    assert_equal 1, firms.size
    assert_equal companies(:first_firm), firms.first
  end

  def test_find_with_hash_conditions_on_joined_table_and_with_range
    firms = DependentFirm.joins(:account).where(name: "RailsCore", accounts: { credit_limit: 55..60 })
    assert_equal 1, firms.size
    assert_equal companies(:rails_core), firms.first
  end

  def test_find_on_hash_conditions_with_explicit_table_name_and_aggregate
    david = customers(:david)
    assert Customer.where("customers.name" => david.name, :address => david.address).find(david.id)
    assert_raise(ActiveRecord::RecordNotFound) {
      Customer.where("customers.name" => david.name + "1", :address => david.address).find(david.id)
    }
  end

  def test_find_on_association_proxy_conditions
    assert_equal [1, 2, 3, 5, 6, 7, 8, 9, 10, 12], Comment.where(post_id: authors(:david).posts).map(&:id).sort
  end

  def test_find_on_hash_conditions_with_range
    assert_equal [1, 2], Topic.where(id: 1..2).to_a.map(&:id).sort
    assert_raise(ActiveRecord::RecordNotFound) { Topic.where(id: 2..3).find(1) }
  end

  def test_find_on_hash_conditions_with_end_exclusive_range
    assert_equal [1, 2, 3], Topic.where(id: 1..3).to_a.map(&:id).sort
    assert_equal [1, 2], Topic.where(id: 1...3).to_a.map(&:id).sort
    assert_raise(ActiveRecord::RecordNotFound) { Topic.where(id: 2...3).find(3) }
  end

  def test_find_on_hash_conditions_with_multiple_ranges
    assert_equal [1, 2, 3], Comment.where(id: 1..3, post_id: 1..2).to_a.map(&:id).sort
    assert_equal [1], Comment.where(id: 1..1, post_id: 1..10).to_a.map(&:id).sort
  end

  def test_find_on_hash_conditions_with_array_of_integers_and_ranges
    assert_equal [1, 2, 3, 5, 6, 7, 8, 9], Comment.where(id: [1..2, 3, 5, 6..8, 9]).to_a.map(&:id).sort
  end

  def test_find_on_hash_conditions_with_array_of_ranges
    assert_equal [1, 2, 6, 7, 8], Comment.where(id: [1..2, 6..8]).to_a.map(&:id).sort
  end

  def test_find_on_hash_conditions_with_open_ended_range
    assert_equal [1, 2, 3], Comment.where(id: Float::INFINITY..3).to_a.map(&:id).sort
  end

  def test_find_on_hash_conditions_with_numeric_range_for_string
    topic = Topic.create!(title: "12 Factor App")
    assert_equal [topic], Topic.where(title: 10..2).to_a
  end

  def test_find_on_multiple_hash_conditions
    assert Topic.where(author_name: "David", title: "The First Topic", replies_count: 1, approved: false).find(1)
    assert_raise(ActiveRecord::RecordNotFound) { Topic.where(author_name: "David", title: "The First Topic", replies_count: 1, approved: true).find(1) }
    assert_raise(ActiveRecord::RecordNotFound) { Topic.where(author_name: "David", title: "HHC", replies_count: 1, approved: false).find(1) }
  end

  def test_condition_interpolation
    assert_kind_of Firm, Company.where("name = '%s'", "37signals").first
    assert_nil Company.where(["name = '%s'", "37signals!"]).first
    assert_nil Company.where(["name = '%s'", "37signals!' OR 1=1"]).first
    assert_kind_of Time, Topic.where(["id = %d", 1]).first.written_on
  end

  def test_condition_array_interpolation
    assert_kind_of Firm, Company.where(["name = '%s'", "37signals"]).first
    assert_nil Company.where(["name = '%s'", "37signals!"]).first
    assert_nil Company.where(["name = '%s'", "37signals!' OR 1=1"]).first
    assert_kind_of Time, Topic.where(["id = %d", 1]).first.written_on
  end

  def test_condition_hash_interpolation
    assert_kind_of Firm, Company.where(name: "37signals").first
    assert_nil Company.where(name: "37signals!").first
    assert_kind_of Time, Topic.where(id: 1).first.written_on
  end

  def test_hash_condition_find_malformed
    assert_raise(ActiveRecord::StatementInvalid) {
      Company.where(id: 2, dhh: true).first
    }
  end

  def test_hash_condition_find_with_escaped_characters
    Company.create("name" => "Ain't noth'n like' \#stuff")
    assert Company.where(name: "Ain't noth'n like' \#stuff").first
  end

  def test_hash_condition_find_with_array
    p1, p2 = Post.limit(2).order("id asc").to_a
    assert_equal [p1, p2], Post.where(id: [p1, p2]).order("id asc").to_a
    assert_equal [p1, p2], Post.where(id: [p1, p2.id]).order("id asc").to_a
  end

  def test_hash_condition_find_with_nil
    topic = Topic.where(last_read: nil).first
    assert_not_nil topic
    assert_nil topic.last_read
  end

  def test_hash_condition_find_with_aggregate_having_one_mapping
    balance = customers(:david).balance
    assert_kind_of Money, balance
    found_customer = Customer.where(balance: balance).first
    assert_equal customers(:david), found_customer
  end

  def test_hash_condition_find_with_aggregate_having_three_mappings_array
    david_address = customers(:david).address
    zaphod_address = customers(:zaphod).address
    barney_address = customers(:barney).address
    assert_kind_of Address, david_address
    assert_kind_of Address, zaphod_address
    found_customers = Customer.where(address: [david_address, zaphod_address, barney_address])
    assert_equal [customers(:david), customers(:zaphod), customers(:barney)], found_customers.sort_by(&:id)
  end

  def test_hash_condition_find_with_aggregate_having_one_mapping_array
    david_balance = customers(:david).balance
    zaphod_balance = customers(:zaphod).balance
    assert_kind_of Money, david_balance
    assert_kind_of Money, zaphod_balance
    found_customers = Customer.where(balance: [david_balance, zaphod_balance])
    assert_equal [customers(:david), customers(:zaphod)], found_customers.sort_by(&:id)
    assert_equal Customer.where(balance: [david_balance.amount, zaphod_balance.amount]).to_sql, found_customers.to_sql
  end

  def test_hash_condition_find_with_aggregate_attribute_having_same_name_as_field_and_key_value_being_aggregate
    gps_location = customers(:david).gps_location
    assert_kind_of GpsLocation, gps_location
    found_customer = Customer.where(gps_location: gps_location).first
    assert_equal customers(:david), found_customer
  end

  def test_hash_condition_find_with_aggregate_having_one_mapping_and_key_value_being_attribute_value
    balance = customers(:david).balance
    assert_kind_of Money, balance
    found_customer = Customer.where(balance: balance.amount).first
    assert_equal customers(:david), found_customer
  end

  def test_hash_condition_find_with_aggregate_attribute_having_same_name_as_field_and_key_value_being_attribute_value
    gps_location = customers(:david).gps_location
    assert_kind_of GpsLocation, gps_location
    found_customer = Customer.where(gps_location: gps_location.gps_location).first
    assert_equal customers(:david), found_customer
  end

  def test_hash_condition_find_with_aggregate_having_three_mappings
    address = customers(:david).address
    assert_kind_of Address, address
    customers = Customer.where(address: address).order(:id)
    assert_equal [customers(:david)], customers
    assert_equal customers(:david, :mary), customers.unscope(where: [:address_city, :address_country])
  end

  def test_hash_condition_find_with_one_condition_being_aggregate_and_another_not
    address = customers(:david).address
    assert_kind_of Address, address
    found_customer = Customer.where(address: address, name: customers(:david).name).first
    assert_equal customers(:david), found_customer
  end

  def test_hash_condition_find_nil_with_aggregate_having_one_mapping
    assert_nil customers(:zaphod).gps_location
    found_customer = Customer.where(gps_location: nil, name: customers(:zaphod).name).first
    assert_equal customers(:zaphod), found_customer
  end

  def test_hash_condition_find_nil_with_aggregate_having_multiple_mappings
    customers(:david).update(address: nil)
    assert_nil customers(:david).address_street
    assert_nil customers(:david).address_city
    found_customer = Customer.where(address: nil, name: customers(:david).name).first
    assert_equal customers(:david), found_customer
  end

  def test_hash_condition_find_empty_array_with_aggregate_having_multiple_mappings
    assert_nil Customer.where(address: []).first
  end

  def test_condition_utc_time_interpolation_with_default_timezone_local
    with_env_tz "America/New_York" do
      with_timezone_config default: :local do
        topic = Topic.first
        assert_equal topic, Topic.where(["written_on = ?", topic.written_on.getutc]).first
      end
    end
  end

  def test_hash_condition_utc_time_interpolation_with_default_timezone_local
    with_env_tz "America/New_York" do
      with_timezone_config default: :local do
        topic = Topic.first
        assert_equal topic, Topic.where(written_on: topic.written_on.getutc).first
      end
    end
  end

  def test_condition_local_time_interpolation_with_default_timezone_utc
    with_env_tz "America/New_York" do
      with_timezone_config default: :utc do
        topic = Topic.first
        assert_equal topic, Topic.where(["written_on = ?", topic.written_on.getlocal]).first
      end
    end
  end

  def test_hash_condition_local_time_interpolation_with_default_timezone_utc
    with_env_tz "America/New_York" do
      with_timezone_config default: :utc do
        topic = Topic.first
        assert_equal topic, Topic.where(written_on: topic.written_on.getlocal).first
      end
    end
  end

  def test_bind_variables
    assert_kind_of Firm, Company.where(["name = ?", "37signals"]).first
    assert_nil Company.where(["name = ?", "37signals!"]).first
    assert_nil Company.where(["name = ?", "37signals!' OR 1=1"]).first
    assert_kind_of Time, Topic.where(["id = ?", 1]).first.written_on
    assert_raise(ActiveRecord::PreparedStatementInvalid) {
      Company.where(["id=? AND name = ?", 2]).first
    }
    assert_raise(ActiveRecord::PreparedStatementInvalid) {
      Company.where(["id=?", 2, 3, 4]).first
    }
  end

  def test_bind_variables_with_quotes
    Company.create("name" => "37signals' go'es against")
    assert Company.where(["name = ?", "37signals' go'es against"]).first
  end

  def test_named_bind_variables_with_quotes
    Company.create("name" => "37signals' go'es against")
    assert Company.where(["name = :name", { name: "37signals' go'es against" }]).first
  end

  def test_named_bind_variables
    assert_kind_of Firm, Company.where(["name = :name", { name: "37signals" }]).first
    assert_nil Company.where(["name = :name", { name: "37signals!" }]).first
    assert_nil Company.where(["name = :name", { name: "37signals!' OR 1=1" }]).first
    assert_kind_of Time, Topic.where(["id = :id", { id: 1 }]).first.written_on
  end

  def test_count_by_sql
    assert_equal(0, Entrant.count_by_sql("SELECT COUNT(*) FROM entrants WHERE id > 3"))
    assert_equal(1, Entrant.count_by_sql(["SELECT COUNT(*) FROM entrants WHERE id > ?", 2]))
    assert_equal(2, Entrant.count_by_sql(["SELECT COUNT(*) FROM entrants WHERE id > ?", 1]))
  end

  def test_find_by_one_attribute
    assert_equal topics(:first), Topic.find_by_title("The First Topic")
    assert_nil Topic.find_by_title("The First Topic!")
  end

  def test_find_by_one_attribute_bang
    assert_equal topics(:first), Topic.find_by_title!("The First Topic")
    assert_raises_with_message(ActiveRecord::RecordNotFound, "Couldn't find Topic") do
      Topic.find_by_title!("The First Topic!")
    end
  end

  def test_find_by_on_attribute_that_is_a_reserved_word
    dog_alias = "Dog"
    dog = Dog.create(alias: dog_alias)

    assert_equal dog, Dog.find_by_alias(dog_alias)
  end

  def test_find_by_one_attribute_that_is_an_alias
    assert_equal topics(:first), Topic.find_by_heading("The First Topic")
    assert_nil Topic.find_by_heading("The First Topic!")
  end

  def test_find_by_one_attribute_bang_with_blank_defined
    blank_topic = BlankTopic.create(title: "The Blank One")
    assert_equal blank_topic, BlankTopic.find_by_title!("The Blank One")
  end

  def test_find_by_one_attribute_with_conditions
    assert_equal accounts(:rails_core_account), Account.where("firm_id = ?", 6).find_by_credit_limit(50)
  end

  def test_find_by_one_attribute_that_is_an_aggregate
    address = customers(:david).address
    assert_kind_of Address, address
    found_customer = Customer.find_by_address(address)
    assert_equal customers(:david), found_customer
  end

  def test_find_by_one_attribute_that_is_an_aggregate_with_one_attribute_difference
    address = customers(:david).address
    assert_kind_of Address, address
    missing_address = Address.new(address.street, address.city, address.country + "1")
    assert_nil Customer.find_by_address(missing_address)
    missing_address = Address.new(address.street, address.city + "1", address.country)
    assert_nil Customer.find_by_address(missing_address)
    missing_address = Address.new(address.street + "1", address.city, address.country)
    assert_nil Customer.find_by_address(missing_address)
  end

  def test_find_by_two_attributes_that_are_both_aggregates
    balance = customers(:david).balance
    address = customers(:david).address
    assert_kind_of Money, balance
    assert_kind_of Address, address
    found_customer = Customer.find_by_balance_and_address(balance, address)
    assert_equal customers(:david), found_customer
  end

  def test_find_by_two_attributes_with_one_being_an_aggregate
    balance = customers(:david).balance
    assert_kind_of Money, balance
    found_customer = Customer.find_by_balance_and_name(balance, customers(:david).name)
    assert_equal customers(:david), found_customer
  end

  def test_dynamic_finder_on_one_attribute_with_conditions_returns_same_results_after_caching
    # ensure this test can run independently of order
    Account.singleton_class.remove_method :find_by_credit_limit if Account.public_methods.include?(:find_by_credit_limit)
    a = Account.where("firm_id = ?", 6).find_by_credit_limit(50)
    assert_equal a, Account.where("firm_id = ?", 6).find_by_credit_limit(50) # find_by_credit_limit has been cached
  end

  def test_find_by_one_attribute_with_several_options
    assert_equal accounts(:unknown), Account.order("id DESC").where("id != ?", 3).find_by_credit_limit(50)
  end

  def test_find_by_one_missing_attribute
    assert_raise(NoMethodError) { Topic.find_by_undertitle("The First Topic!") }
  end

  def test_find_by_invalid_method_syntax
    assert_raise(NoMethodError) { Topic.fail_to_find_by_title("The First Topic") }
    assert_raise(NoMethodError) { Topic.find_by_title?("The First Topic") }
    assert_raise(NoMethodError) { Topic.fail_to_find_or_create_by_title("Nonexistent Title") }
    assert_raise(NoMethodError) { Topic.find_or_create_by_title?("Nonexistent Title") }
  end

  def test_find_by_two_attributes
    assert_equal topics(:first), Topic.find_by_title_and_author_name("The First Topic", "David")
    assert_nil Topic.find_by_title_and_author_name("The First Topic", "Mary")
  end

  def test_find_by_two_attributes_but_passing_only_one
    assert_raise(ArgumentError) { Topic.find_by_title_and_author_name("The First Topic") }
  end

  def test_find_by_nil_attribute
    topic = Topic.find_by_last_read nil
    assert_not_nil topic
    assert_nil topic.last_read
  end

  def test_find_by_nil_and_not_nil_attributes
    topic = Topic.find_by_last_read_and_author_name nil, "Mary"
    assert_equal "Mary", topic.author_name
  end

  def test_find_with_bad_sql
    assert_raise(ActiveRecord::StatementInvalid) { Topic.find_by_sql "select 1 from badtable" }
  end

  def test_joins_dont_clobber_id
    first = Firm.
      joins("INNER JOIN companies clients ON clients.firm_id = companies.id").
      where("companies.id = 1").first
    assert_equal 1, first.id
  end

  def test_joins_with_string_array
    person_with_reader_and_post = Post.
      joins(["INNER JOIN categorizations ON categorizations.post_id = posts.id",
             "INNER JOIN categories ON categories.id = categorizations.category_id AND categories.type = 'SpecialCategory'"
            ])
    assert_equal 1, person_with_reader_and_post.size
  end

  def test_find_by_id_with_conditions_with_or
    assert_nothing_raised do
      Post.where("posts.id <= 3 OR posts.#{QUOTED_TYPE} = 'Post'").find([1, 2, 3])
    end
  end

  def test_find_ignores_previously_inserted_record
    Post.create!(title: "test", body: "it out")
    assert_equal [], Post.where(id: nil)
  end

  def test_find_by_empty_ids
    assert_equal [], Post.find([])
  end

  def test_find_by_empty_in_condition
    assert_equal [], Post.where("id in (?)", [])
  end

  def test_find_by_records
    p1, p2 = Post.limit(2).order("id asc").to_a
    assert_equal [p1, p2], Post.where(["id in (?)", [p1, p2]]).order("id asc")
    assert_equal [p1, p2], Post.where(["id in (?)", [p1, p2.id]]).order("id asc")
  end

  def test_select_value
    assert_equal "37signals", Company.connection.select_value("SELECT name FROM companies WHERE id = 1")
    assert_nil Company.connection.select_value("SELECT name FROM companies WHERE id = -1")
    # make sure we didn't break count...
    assert_equal 0, Company.count_by_sql("SELECT COUNT(*) FROM companies WHERE name = 'Halliburton'")
    assert_equal 1, Company.count_by_sql("SELECT COUNT(*) FROM companies WHERE name = '37signals'")
  end

  def test_select_values
    assert_equal ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11"], Company.connection.select_values("SELECT id FROM companies ORDER BY id").map!(&:to_s)
    assert_equal ["37signals", "Summit", "Microsoft", "Flamboyant Software", "Ex Nihilo", "RailsCore", "Leetsoft", "Jadedpixel", "Odegy", "Ex Nihilo Part Deux", "Apex"], Company.connection.select_values("SELECT name FROM companies ORDER BY id")
  end

  def test_select_rows
    assert_equal(
      [["1", "1", nil, "37signals"],
       ["2", "1", "2", "Summit"],
       ["3", "1", "1", "Microsoft"]],
      Company.connection.select_rows("SELECT id, firm_id, client_of, name FROM companies WHERE id IN (1,2,3) ORDER BY id").map! { |i| i.map! { |j| j.to_s unless j.nil? } })
    assert_equal [["1", "37signals"], ["2", "Summit"], ["3", "Microsoft"]],
      Company.connection.select_rows("SELECT id, name FROM companies WHERE id IN (1,2,3) ORDER BY id").map! { |i| i.map! { |j| j.to_s unless j.nil? } }
  end

  def test_find_with_order_on_included_associations_with_construct_finder_sql_for_association_limiting_and_is_distinct
    assert_equal 2, Post.includes(authors: :author_address).
      where.not(author_addresses: { id: nil }).
      order("author_addresses.id DESC").limit(2).to_a.size

    assert_equal 3, Post.includes(author: :author_address, authors: :author_address).
      where.not(author_addresses_authors: { id: nil }).
      order("author_addresses_authors.id DESC").limit(3).to_a.size
  end

  def test_find_with_eager_loading_collection_and_ordering_by_collection_primary_key
    assert_equal Post.first, Post.eager_load(comments: :ratings).
      order("posts.id, ratings.id, comments.id").first
  end

  def test_find_with_nil_inside_set_passed_for_one_attribute
    client_of = Company.
      where(client_of: [2, 1, nil],
            name: ["37signals", "Summit", "Microsoft"]).
      order("client_of DESC").
      map(&:client_of)

    assert_includes client_of, nil
    assert_equal [2, 1].sort, client_of.compact.sort
  end

  def test_find_with_nil_inside_set_passed_for_attribute
    client_of = Company.
      where(client_of: [nil]).
      order("client_of DESC").
      map(&:client_of)

    assert_equal [], client_of.compact
  end

  def test_with_limiting_with_custom_select
    posts = Post.references(:authors).merge(
      includes: :author, select: 'posts.*, authors.id as "author_id"',
      limit: 3, order: "posts.id"
    ).to_a
    assert_equal 3, posts.size
    assert_equal [0, 1, 1], posts.map(&:author_id).sort
  end

  def test_eager_load_for_no_has_many_with_limit_and_joins_for_has_many
    relation = Post.eager_load(:author).joins(comments: :post)
    assert_equal 5, relation.to_a.size
    assert_equal 5, relation.limit(5).to_a.size
  end

  def test_eager_load_for_no_has_many_with_limit_and_left_joins_for_has_many
    relation = Post.eager_load(:author).left_joins(comments: :post)
    assert_equal 11, relation.to_a.size
    assert_equal 11, relation.limit(11).to_a.size
  end

  def test_find_one_message_on_primary_key
    e = assert_raises(ActiveRecord::RecordNotFound) do
      Car.find(0)
    end
    assert_equal 0, e.id
    assert_equal "id", e.primary_key
    assert_equal "Car", e.model
    assert_equal "Couldn't find Car with 'id'=0", e.message
  end

  def test_find_one_message_with_custom_primary_key
    table_with_custom_primary_key do |model|
      model.primary_key = :name
      e = assert_raises(ActiveRecord::RecordNotFound) do
        model.find "Hello World!"
      end
      assert_equal "Couldn't find MercedesCar with 'name'=Hello World!", e.message
    end
  end

  def test_find_some_message_with_custom_primary_key
    table_with_custom_primary_key do |model|
      model.primary_key = :name
      e = assert_raises(ActiveRecord::RecordNotFound) do
        model.find "Hello", "World!"
      end
      assert_equal "Couldn't find all MercedesCars with 'name': (Hello, World!) (found 0 results, but was looking for 2).", e.message
    end
  end

  def test_find_without_primary_key
    assert_raises(ActiveRecord::UnknownPrimaryKey) do
      Matey.find(1)
    end
  end

  def test_finder_with_offset_string
    assert_nothing_raised { Topic.offset("3").to_a }
  end

  test "find_by with hash conditions returns the first matching record" do
    assert_equal posts(:eager_other), Post.find_by(id: posts(:eager_other).id)
  end

  test "find_by with non-hash conditions returns the first matching record" do
    assert_equal posts(:eager_other), Post.find_by("id = #{posts(:eager_other).id}")
  end

  test "find_by with multi-arg conditions returns the first matching record" do
    assert_equal posts(:eager_other), Post.find_by("id = ?", posts(:eager_other).id)
  end

  test "find_by with range conditions returns the first matching record" do
    assert_equal posts(:eager_other), Post.find_by(id: posts(:eager_other).id...posts(:misc_by_bob).id)
  end

  test "find_by returns nil if the record is missing" do
    assert_nil Post.find_by("1 = 0")
  end

  test "find_by with associations" do
    assert_equal authors(:david), Post.find_by(author: authors(:david)).author
    assert_equal authors(:mary), Post.find_by(author: authors(:mary)).author
  end

  test "find_by doesn't have implicit ordering" do
    assert_sql(/^((?!ORDER).)*$/) { Post.find_by(id: posts(:eager_other).id) }
  end

  test "find_by! with hash conditions returns the first matching record" do
    assert_equal posts(:eager_other), Post.find_by!(id: posts(:eager_other).id)
  end

  test "find_by! with non-hash conditions returns the first matching record" do
    assert_equal posts(:eager_other), Post.find_by!("id = #{posts(:eager_other).id}")
  end

  test "find_by! with multi-arg conditions returns the first matching record" do
    assert_equal posts(:eager_other), Post.find_by!("id = ?", posts(:eager_other).id)
  end

  test "find_by! doesn't have implicit ordering" do
    assert_sql(/^((?!ORDER).)*$/) { Post.find_by!(id: posts(:eager_other).id) }
  end

  test "find_by! raises RecordNotFound if the record is missing" do
    assert_raises(ActiveRecord::RecordNotFound) do
      Post.find_by!("1 = 0")
    end
  end

  test "find on a scope does not perform statement caching" do
    honda = cars(:honda)
    zyke = cars(:zyke)
    tyre = honda.tyres.create!
    tyre2 = zyke.tyres.create!

    assert_equal tyre, honda.tyres.custom_find(tyre.id)
    assert_equal tyre2, zyke.tyres.custom_find(tyre2.id)
  end

  test "find_by on a scope does not perform statement caching" do
    honda = cars(:honda)
    zyke = cars(:zyke)
    tyre = honda.tyres.create!
    tyre2 = zyke.tyres.create!

    assert_equal tyre, honda.tyres.custom_find_by(id: tyre.id)
    assert_equal tyre2, zyke.tyres.custom_find_by(id: tyre2.id)
  end

  test "#skip_query_cache! for #exists?" do
    Topic.cache do
      assert_queries(1) do
        Topic.exists?
        Topic.exists?
      end

      assert_queries(2) do
        Topic.all.skip_query_cache!.exists?
        Topic.all.skip_query_cache!.exists?
      end
    end
  end

  test "#skip_query_cache! for #exists? with a limited eager load" do
    Topic.cache do
      assert_queries(1) do
        Topic.eager_load(:replies).limit(1).exists?
        Topic.eager_load(:replies).limit(1).exists?
      end

      assert_queries(2) do
        Topic.eager_load(:replies).limit(1).skip_query_cache!.exists?
        Topic.eager_load(:replies).limit(1).skip_query_cache!.exists?
      end
    end
  end

  private
    def table_with_custom_primary_key
      yield(Class.new(Toy) do
        def self.name
          "MercedesCar"
        end
      end)
    end

    def assert_raises_with_message(exception_class, message, &block)
      err = assert_raises(exception_class) { block.call }
      assert_match message, err.message
    end
end
