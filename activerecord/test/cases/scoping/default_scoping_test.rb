# frozen_string_literal: true

require "cases/helper"
require "models/post"
require "models/comment"
require "models/developer"
require "models/project"
require "models/computer"
require "models/cat"
require "models/mentor"
require "concurrent/atomic/cyclic_barrier"

class DefaultScopingTest < ActiveRecord::TestCase
  fixtures :developers, :posts, :comments

  def test_default_scope
    expected = Developer.all.merge!(order: "salary DESC").to_a.collect(&:salary)
    received = DeveloperOrderedBySalary.all.collect(&:salary)
    assert_equal expected, received
  end

  def test_default_scope_as_class_method
    assert_equal [developers(:david).becomes(ClassMethodDeveloperCalledDavid)], ClassMethodDeveloperCalledDavid.all
  end

  def test_default_scope_as_class_method_referencing_scope
    assert_equal [developers(:david).becomes(ClassMethodReferencingScopeDeveloperCalledDavid)], ClassMethodReferencingScopeDeveloperCalledDavid.all
  end

  def test_default_scope_as_block_referencing_scope
    assert_equal [developers(:david).becomes(LazyBlockReferencingScopeDeveloperCalledDavid)], LazyBlockReferencingScopeDeveloperCalledDavid.all
  end

  def test_default_scope_with_lambda
    assert_equal [developers(:david).becomes(LazyLambdaDeveloperCalledDavid)], LazyLambdaDeveloperCalledDavid.all
  end

  def test_default_scope_with_block
    assert_equal [developers(:david).becomes(LazyBlockDeveloperCalledDavid)], LazyBlockDeveloperCalledDavid.all
  end

  def test_default_scope_with_callable
    assert_equal [developers(:david).becomes(CallableDeveloperCalledDavid)], CallableDeveloperCalledDavid.all
  end

  def test_default_scope_is_unscoped_on_find
    assert_equal 1, DeveloperCalledDavid.count
    assert_equal 11, DeveloperCalledDavid.unscoped.count
  end

  def test_default_scope_is_unscoped_on_create
    assert_nil DeveloperCalledJamis.unscoped.create!.name
  end

  def test_default_scope_with_conditions_string
    assert_equal Developer.where(name: "David").map(&:id).sort, DeveloperCalledDavid.all.map(&:id).sort
    assert_nil DeveloperCalledDavid.create!.name
  end

  def test_default_scope_with_conditions_hash
    assert_equal Developer.where(name: "Jamis").map(&:id).sort, DeveloperCalledJamis.all.map(&:id).sort
    assert_equal "Jamis", DeveloperCalledJamis.create!.name
  end

  def test_default_scope_with_inheritance
    wheres = InheritedPoorDeveloperCalledJamis.all.where_values_hash
    assert_equal "Jamis", wheres["name"]
    assert_equal 50000,   wheres["salary"]
  end

  def test_default_scope_with_module_includes
    wheres = ModuleIncludedPoorDeveloperCalledJamis.all.where_values_hash
    assert_equal "Jamis", wheres["name"]
    assert_equal 50000,   wheres["salary"]
  end

  def test_default_scope_with_multiple_calls
    wheres = MultiplePoorDeveloperCalledJamis.all.where_values_hash
    assert_equal "Jamis", wheres["name"]
    assert_equal 50000,   wheres["salary"]
  end

  def test_combined_default_scope_without_and_with_all_queries_works
    Mentor.create!
    klass = DeveloperWithIncludedMentorDefaultScopeNotAllQueriesAndDefaultScopeFirmWithAllQueries

    create_sql = capture_sql { klass.create!(name: "Steve") }.second

    assert_match(/mentor_id/, create_sql)
    assert_match(/firm_id/, create_sql)

    developer = klass.find_by!(name: "Steve")

    update_sql = capture_sql { developer.update(name: "Stephen") }.second

    assert_no_match(/mentor_id/, update_sql)
    assert_match(/firm_id/, update_sql)
  end

  def test_default_scope_runs_on_create
    Mentor.create!
    create_sql = capture_sql { DeveloperwithDefaultMentorScopeNot.create!(name: "Eileen") }.second

    assert_match(/mentor_id/, create_sql)
  end

  def test_default_scope_with_all_queries_runs_on_create
    Mentor.create!
    create_sql = capture_sql { DeveloperWithDefaultMentorScopeAllQueries.create!(name: "Eileen") }.second

    assert_match(/mentor_id/, create_sql)
  end

  def test_nilable_default_scope_with_all_queries_runs_on_create
    create_sql = capture_sql { DeveloperWithDefaultNilableFirmScopeAllQueries.create!(name: "Nikita") }.first

    assert_no_match(/AND$/, create_sql)
  end

  def test_default_scope_runs_on_select
    Mentor.create!
    DeveloperwithDefaultMentorScopeNot.create!(name: "Eileen")
    select_sql = capture_sql { DeveloperwithDefaultMentorScopeNot.find_by(name: "Eileen") }.first

    assert_match(/mentor_id/, select_sql)
  end

  def test_default_scope_with_all_queries_runs_on_select
    Mentor.create!
    DeveloperWithDefaultMentorScopeAllQueries.create!(name: "Eileen")
    select_sql = capture_sql { DeveloperWithDefaultMentorScopeAllQueries.find_by(name: "Eileen") }.first

    assert_match(/mentor_id/, select_sql)
  end

  def test_nilable_default_scope_with_all_queries_runs_on_select
    DeveloperWithDefaultNilableFirmScopeAllQueries.create!(name: "Nikita")
    select_sql = capture_sql { DeveloperWithDefaultNilableFirmScopeAllQueries.find_by(name: "Nikita") }.first

    assert_no_match(/AND$/, select_sql)
  end

  def test_default_scope_doesnt_run_on_update
    Mentor.create!
    dev = DeveloperwithDefaultMentorScopeNot.create!(name: "Eileen")
    update_sql = capture_sql { dev.update!(name: "Not Eileen") }.first

    assert_no_match(/mentor_id/, update_sql)
  end

  def test_default_scope_with_all_queries_runs_on_update
    Mentor.create!
    dev = DeveloperWithDefaultMentorScopeAllQueries.create!(name: "Eileen")
    update_sql = capture_sql { dev.update!(name: "Not Eileen") }.second

    assert_match(/mentor_id/, update_sql)
  end

  def test_nilable_default_scope_with_all_queries_runs_on_update
    dev = DeveloperWithDefaultNilableFirmScopeAllQueries.create!(name: "Nikita")
    update_sql = capture_sql { dev.update!(name: "Not Nikita") }.first

    assert_no_match(/AND$/, update_sql)
  end

  def test_default_scope_doesnt_run_on_update_columns
    Mentor.create!
    dev = DeveloperwithDefaultMentorScopeNot.create!(name: "Eileen")
    update_sql = capture_sql { dev.update_columns(name: "Not Eileen") }.first

    assert_no_match(/mentor_id/, update_sql)
  end

  def test_default_scope_with_all_queries_runs_on_update_columns
    Mentor.create!
    dev = DeveloperWithDefaultMentorScopeAllQueries.create!(name: "Eileen")
    update_sql = capture_sql { dev.update_columns(name: "Not Eileen") }.first

    assert_match(/mentor_id/, update_sql)
  end

  def test_nilable_default_scope_with_all_queries_runs_on_update_columns
    dev = DeveloperWithDefaultNilableFirmScopeAllQueries.create!(name: "Nikita")
    update_sql = capture_sql { dev.update_columns(name: "Not Nikita") }.first

    assert_no_match(/AND$/, update_sql)
  end

  def test_default_scope_doesnt_run_on_destroy
    Mentor.create!
    dev = DeveloperwithDefaultMentorScopeNot.create!(name: "Eileen")
    destroy_sql = capture_sql { dev.destroy }.first

    assert_no_match(/mentor_id/, destroy_sql)
  end

  def test_default_scope_with_all_queries_runs_on_destroy
    Mentor.create!
    dev = DeveloperWithDefaultMentorScopeAllQueries.create!(name: "Eileen")
    destroy_sql = capture_sql { dev.destroy }.second

    assert_match(/mentor_id/, destroy_sql)
  end

  def test_nilable_default_scope_with_all_queries_runs_on_destroy
    dev = DeveloperWithDefaultNilableFirmScopeAllQueries.create!(name: "Nikita")
    destroy_sql = capture_sql { dev.destroy }.first

    assert_no_match(/AND$/, destroy_sql)
  end

  def test_default_scope_doesnt_run_on_reload
    Mentor.create!
    dev = DeveloperwithDefaultMentorScopeNot.create!(name: "Eileen")
    reload_sql = capture_sql { dev.reload }.first

    assert_no_match(/mentor_id/, reload_sql)
  end

  def test_default_scope_with_all_queries_runs_on_reload
    Mentor.create!
    dev = DeveloperWithDefaultMentorScopeAllQueries.create!(name: "Eileen")
    reload_sql = capture_sql { dev.reload }.first

    assert_match(/mentor_id/, reload_sql)
  end

  def test_default_scope_with_all_queries_runs_on_reload_but_default_scope_without_all_queries_does_not
    Mentor.create!
    dev = DeveloperWithIncludedMentorDefaultScopeNotAllQueriesAndDefaultScopeFirmWithAllQueries.create!(name: "Eileen")
    reload_sql = capture_sql { dev.reload }.first

    assert_no_match(/mentor_id/, reload_sql)
    assert_match(/firm_id/, reload_sql)
  end

  def test_nilable_default_scope_with_all_queries_runs_on_reload
    dev = DeveloperWithDefaultNilableFirmScopeAllQueries.create!(name: "Nikita")
    reload_sql = capture_sql { dev.reload }.first

    assert_no_match(/AND$/, reload_sql)
  end

  def test_default_scope_with_all_queries_doesnt_run_on_destroy_when_unscoped
    dev = DeveloperWithDefaultMentorScopeAllQueries.create!(name: "Eileen", mentor_id: 2)
    reload_sql = capture_sql { dev.reload({ unscoped: true }) }.first

    assert_no_match(/mentor_id/, reload_sql)
  end

  def test_scope_overwrites_default
    expected = Developer.all.merge!(order: "salary DESC, name DESC").to_a.collect(&:name)
    received = DeveloperOrderedBySalary.by_name.to_a.collect(&:name)
    assert_equal expected, received
  end

  def test_reorder_overrides_default_scope_order
    expected = Developer.order("name DESC").collect(&:name)
    received = DeveloperOrderedBySalary.reorder("name DESC").collect(&:name)
    assert_equal expected, received
  end

  def test_order_after_reorder_combines_orders
    expected = Developer.order("name DESC, id DESC").collect { |dev| [dev.name, dev.id] }
    received = Developer.order("name ASC").reorder("name DESC").order("id DESC").collect { |dev| [dev.name, dev.id] }
    assert_equal expected, received
  end

  def test_unscope_overrides_default_scope
    expected = Developer.all.collect { |dev| [dev.name, dev.id] }
    received = DeveloperCalledJamis.unscope(:where).collect { |dev| [dev.name, dev.id] }
    assert_equal expected, received
  end

  def test_unscope_after_reordering_and_combining
    expected = Developer.order("id DESC, name DESC").collect { |dev| [dev.name, dev.id] }
    received = DeveloperOrderedBySalary.reorder("name DESC").unscope(:order).order("id DESC, name DESC").collect { |dev| [dev.name, dev.id] }
    assert_equal expected, received

    expected_2 = Developer.all.collect { |dev| [dev.name, dev.id] }
    received_2 = Developer.order("id DESC, name DESC").unscope(:order).collect { |dev| [dev.name, dev.id] }
    assert_equal expected_2, received_2

    expected_3 = Developer.all.collect { |dev| [dev.name, dev.id] }
    received_3 = Developer.reorder("name DESC").unscope(:order).collect { |dev| [dev.name, dev.id] }
    assert_equal expected_3, received_3
  end

  def test_unscope_with_where_attributes
    expected = Developer.order("salary DESC").collect(&:name)
    received = DeveloperOrderedBySalary.where(name: "David").unscope(where: :name).collect(&:name)
    assert_equal expected.sort, received.sort

    expected_2 = Developer.order("salary DESC").collect(&:name)
    received_2 = DeveloperOrderedBySalary.select("id").where("name" => "Jamis").unscope({ where: :name }, :select).collect(&:name)
    assert_equal expected_2.sort, received_2.sort

    expected_3 = Developer.order("salary DESC").collect(&:name)
    received_3 = DeveloperOrderedBySalary.select("id").where("name" => "Jamis").unscope(:select, :where).collect(&:name)
    assert_equal expected_3.sort, received_3.sort

    expected_4 = Developer.order("salary DESC").collect(&:name)
    received_4 = DeveloperOrderedBySalary.where.not("name" => "Jamis").unscope(where: :name).collect(&:name)
    assert_equal expected_4.sort, received_4.sort

    expected_5 = Developer.order("salary DESC").collect(&:name)
    received_5 = DeveloperOrderedBySalary.where.not("name" => ["Jamis", "David"]).unscope(where: :name).collect(&:name)
    assert_equal expected_5.sort, received_5.sort

    expected_6 = Developer.order("salary DESC").collect(&:name)
    received_6 = DeveloperOrderedBySalary.where(Developer.arel_table["name"].eq("David")).unscope(where: :name).collect(&:name)
    assert_equal expected_6.sort, received_6.sort

    expected_7 = Developer.order("salary DESC").collect(&:name)
    received_7 = DeveloperOrderedBySalary.where(Developer.arel_table[:name].eq("David")).unscope(where: :name).collect(&:name)
    assert_equal expected_7.sort, received_7.sort
  end

  def test_unscope_comparison_where_clauses
    # unscoped for WHERE (`developers`.`id` <= 2)
    expected = Developer.order("salary DESC").collect(&:name)
    received = DeveloperOrderedBySalary.where(id: -Float::INFINITY..2).unscope(where: :id).collect { |dev| dev.name }
    assert_equal expected.sort, received.sort

    # unscoped for WHERE (`developers`.`id` < 2)
    expected = Developer.order("salary DESC").collect(&:name)
    received = DeveloperOrderedBySalary.where(id: -Float::INFINITY...2).unscope(where: :id).collect { |dev| dev.name }
    assert_equal expected.sort, received.sort
  end

  def test_unscope_multiple_where_clauses
    expected = Developer.order("salary DESC").collect(&:name)
    received = DeveloperOrderedBySalary.where(name: "Jamis").where(id: 1).unscope(where: [:name, :id]).collect(&:name)
    assert_equal expected.sort, received.sort
  end

  def test_unscope_string_where_clauses_involved
    dev_relation = Developer.order("salary DESC").where("legacy_created_at > ?", 1.year.ago)
    expected = dev_relation.collect(&:name)

    dev_ordered_relation = DeveloperOrderedBySalary.where(name: "Jamis").where("legacy_created_at > ?", 1.year.ago)
    received = dev_ordered_relation.unscope(where: [:name]).collect(&:name)

    assert_equal expected.sort, received.sort
  end

  def test_unscope_with_grouping_attributes
    expected = Developer.order("salary DESC").collect(&:name)
    received = DeveloperOrderedBySalary.group(:name).unscope(:group).collect(&:name)
    assert_equal expected.sort, received.sort

    expected_2 = Developer.order("salary DESC").collect(&:name)
    received_2 = DeveloperOrderedBySalary.group("name").unscope(:group).collect(&:name)
    assert_equal expected_2.sort, received_2.sort
  end

  def test_unscope_with_limit_in_query
    expected = Developer.order("salary DESC").collect(&:name)
    received = DeveloperOrderedBySalary.limit(1).unscope(:limit).collect(&:name)
    assert_equal expected.sort, received.sort
  end

  def test_order_to_unscope_reordering
    scope = DeveloperOrderedBySalary.order("salary DESC, name ASC").reverse_order.unscope(:order)
    assert_no_match(/order/i, scope.to_sql)
  end

  def test_unscope_reverse_order
    expected = Developer.all.collect(&:name)
    received = Developer.order("salary DESC").reverse_order.unscope(:order).collect(&:name)
    assert_equal expected, received
  end

  def test_unscope_select
    expected = Developer.order("salary ASC").collect(&:name)
    received = Developer.order("salary DESC").reverse_order.select(:name).unscope(:select).collect(&:name)
    assert_equal expected, received

    expected_2 = Developer.all.collect(&:id)
    received_2 = Developer.select(:name).unscope(:select).collect(&:id)
    assert_equal expected_2, received_2
  end

  def test_unscope_offset
    expected = Developer.all.collect(&:name)
    received = Developer.offset(5).unscope(:offset).collect(&:name)
    assert_equal expected, received
  end

  def test_unscope_joins_and_select_on_developers_projects
    expected = Developer.all.collect(&:name)
    received = Developer.joins("JOIN developers_projects ON id = developer_id").select(:id).unscope(:joins, :select).collect(&:name)
    assert_equal expected, received
  end

  def test_unscope_left_outer_joins
    expected = Developer.all.collect(&:name)
    received = Developer.left_outer_joins(:projects).select(:id).unscope(:left_outer_joins, :select).collect(&:name)
    assert_equal expected, received
  end

  def test_unscope_left_joins
    expected = Developer.all.collect(&:name)
    received = Developer.left_joins(:projects).select(:id).unscope(:left_joins, :select).collect(&:name)
    assert_equal expected, received
  end

  def test_unscope_includes
    expected = Developer.all.collect(&:name)
    received = Developer.includes(:projects).select(:id).unscope(:includes, :select).collect(&:name)
    assert_equal expected, received
  end

  def test_unscope_eager_load
    expected = Developer.all.collect(&:name)
    received = Developer.eager_load(:projects).select(:id).unscope(:eager_load, :select)
    assert_equal expected, received.collect(&:name)
    assert_equal false, received.first.projects.loaded?
  end

  def test_unscope_preloads
    expected = Developer.all.collect(&:name)
    received = Developer.preload(:projects).select(:id).unscope(:preload, :select)
    assert_equal expected, received.collect(&:name)
    assert_equal false, received.first.projects.loaded?
  end

  def test_unscope_having
    expected = DeveloperOrderedBySalary.all.collect(&:name)
    received = DeveloperOrderedBySalary.having("name IN ('Jamis', 'David')").unscope(:having).collect(&:name)
    assert_equal expected, received
  end

  def test_unscope_and_scope
    developer_klass = Class.new(Developer) do
      scope :by_name, -> name { unscope(where: :name).where(name: name) }
    end

    expected = developer_klass.where(name: "Jamis").collect { |dev| [dev.name, dev.id] }
    received = developer_klass.where(name: "David").by_name("Jamis").collect { |dev| [dev.name, dev.id] }
    assert_equal expected, received
  end

  def test_unscope_errors_with_invalid_value
    assert_raises(ArgumentError) do
      Developer.includes(:projects).where(name: "Jamis").unscope(:incorrect_value)
    end

    assert_raises(ArgumentError) do
      Developer.all.unscope(:includes, :select, :some_broken_value)
    end

    assert_raises(ArgumentError) do
      Developer.order("name DESC").reverse_order.unscope(:reverse_order)
    end

    assert_raises(ArgumentError) do
      Developer.order("name DESC").where(name: "Jamis").unscope()
    end
  end

  def test_unscope_errors_with_non_where_hash_keys
    assert_raises(ArgumentError) do
      Developer.where(name: "Jamis").limit(4).unscope(limit: 4)
    end

    assert_raises(ArgumentError) do
      Developer.where(name: "Jamis").unscope("where" => :name)
    end
  end

  def test_unscope_errors_with_non_symbol_or_hash_arguments
    assert_raises(ArgumentError) do
      Developer.where(name: "Jamis").limit(3).unscope("limit")
    end

    assert_raises(ArgumentError) do
      Developer.select("id").unscope("select")
    end

    assert_raises(ArgumentError) do
      Developer.select("id").unscope(5)
    end
  end

  def test_unscope_merging
    merged = Developer.where(name: "Jamis").merge(Developer.unscope(:where))
    assert_empty merged.where_clause
    assert_not_empty merged.where(name: "Jon").where_clause
  end

  def test_order_in_default_scope_should_not_prevail
    expected = Developer.all.merge!(order: "salary desc").to_a.collect(&:salary)
    received = DeveloperOrderedBySalary.all.merge!(order: "salary").to_a.collect(&:salary)
    assert_equal expected, received
  end

  def test_create_attribute_overwrites_default_scoping
    assert_equal "David", PoorDeveloperCalledJamis.create!(name: "David").name
    assert_equal 200000, PoorDeveloperCalledJamis.create!(name: "David", salary: 200000).salary
  end

  def test_create_attribute_overwrites_default_values
    assert_nil PoorDeveloperCalledJamis.create!(salary: nil).salary
    assert_equal 50000, PoorDeveloperCalledJamis.create!(name: "David").salary
  end

  def test_default_scope_attribute
    jamis = PoorDeveloperCalledJamis.new(name: "David")
    assert_equal 50000, jamis.salary
  end

  def test_where_attribute
    aaron = PoorDeveloperCalledJamis.where(salary: 20).new(name: "Aaron")
    assert_equal 20, aaron.salary
    assert_equal "Aaron", aaron.name
  end

  def test_where_attribute_merge
    aaron = PoorDeveloperCalledJamis.where(name: "foo").new(name: "Aaron")
    assert_equal "Aaron", aaron.name
  end

  def test_scope_composed_by_limit_and_then_offset_is_equal_to_scope_composed_by_offset_and_then_limit
    posts_limit_offset = Post.limit(3).offset(2)
    posts_offset_limit = Post.offset(2).limit(3)
    assert_equal posts_limit_offset, posts_offset_limit
  end

  def test_create_with_merge
    aaron = PoorDeveloperCalledJamis.create_with(name: "foo", salary: 20).merge(
      PoorDeveloperCalledJamis.create_with(name: "Aaron")).new
    assert_equal 20, aaron.salary
    assert_equal "Aaron", aaron.name

    aaron = PoorDeveloperCalledJamis.create_with(name: "foo", salary: 20).
                                     create_with(name: "Aaron").new
    assert_equal 20, aaron.salary
    assert_equal "Aaron", aaron.name
  end

  def test_create_with_using_both_string_and_symbol
    jamis = PoorDeveloperCalledJamis.create_with(name: "foo").create_with("name" => "Aaron").new
    assert_equal "Aaron", jamis.name
  end

  def test_create_with_reset
    jamis = PoorDeveloperCalledJamis.create_with(name: "Aaron").create_with(nil).new
    assert_equal "Jamis", jamis.name
  end

  def test_create_with_takes_precedence_over_where
    developer = Developer.where(name: nil).create_with(name: "Aaron").new
    assert_equal "Aaron", developer.name
  end

  def test_create_with_nested_attributes
    assert_difference("Project.count", 1) do
      Developer.create_with(
        projects_attributes: [{ name: "p1" }]
      ).scoping do
        Developer.create!(name: "Aaron")
      end
    end
  end

  # FIXME: I don't know if this is *desired* behavior, but it is *today's*
  # behavior.
  def test_create_with_empty_hash_will_not_reset
    jamis = PoorDeveloperCalledJamis.create_with(name: "Aaron").create_with({}).new
    assert_equal "Aaron", jamis.name
  end

  def test_unscoped_with_named_scope_should_not_have_default_scope
    assert_equal [DeveloperCalledJamis.find(developers(:poor_jamis).id)], DeveloperCalledJamis.poor

    assert_includes DeveloperCalledJamis.unscoped.poor, developers(:david).becomes(DeveloperCalledJamis)

    assert_equal 11, DeveloperCalledJamis.unscoped.length
    assert_equal 1,  DeveloperCalledJamis.poor.length
    assert_equal 10, DeveloperCalledJamis.unscoped.poor.length
    assert_equal 10, DeveloperCalledJamis.unscoped { DeveloperCalledJamis.poor }.length
  end

  def test_default_scope_with_joins
    assert_equal Comment.where(post_id: SpecialPostWithDefaultScope.pluck(:id)).count,
                 Comment.joins(:special_post_with_default_scope).count
    assert_equal Comment.where(post_id: Post.pluck(:id)).count,
                 Comment.joins(:post).count
  end

  def test_joins_not_affected_by_scope_other_than_default_or_unscoped
    without_scope_on_post = Comment.joins(:post).sort_by(&:id)
    with_scope_on_post = nil
    Post.where(id: [1, 5, 6]).scoping do
      with_scope_on_post = Comment.joins(:post).sort_by(&:id)
    end

    assert_equal without_scope_on_post, with_scope_on_post
  end

  def test_unscoped_with_joins_should_not_have_default_scope
    assert_equal Comment.joins(:post).sort_by(&:id),
      SpecialPostWithDefaultScope.unscoped { Comment.joins(:special_post_with_default_scope).sort_by(&:id) }
  end

  def test_sti_association_with_unscoped_not_affected_by_default_scope
    post = posts(:thinking)
    comments = [comments(:does_it_hurt)]

    post.special_comments.update_all(deleted_at: Time.now)

    assert_raises(ActiveRecord::RecordNotFound) { Post.joins(:special_comments).find(post.id) }
    assert_equal [], post.special_comments

    SpecialComment.unscoped do
      assert_equal post, Post.joins(:special_comments).find(post.id)
      assert_equal comments, Post.joins(:special_comments).find(post.id).special_comments
      assert_equal comments, Post.eager_load(:special_comments).find(post.id).special_comments
      assert_equal comments, Post.includes(:special_comments).find(post.id).special_comments
      assert_equal comments, Post.preload(:special_comments).find(post.id).special_comments
    end
  end

  def test_default_scope_select_ignored_by_aggregations
    assert_equal DeveloperWithSelect.all.to_a.count, DeveloperWithSelect.count
  end

  def test_default_scope_select_ignored_by_grouped_aggregations
    assert_equal Developer.all.group_by(&:salary).transform_values(&:count),
                 DeveloperWithSelect.group(:salary).count
  end

  def test_default_scope_order_ignored_by_aggregations
    assert_equal DeveloperOrderedBySalary.all.count, DeveloperOrderedBySalary.count
  end

  def test_default_scope_find_last
    assert DeveloperOrderedBySalary.count > 1, "need more than one row for test"

    lowest_salary_dev = DeveloperOrderedBySalary.find(developers(:poor_jamis).id)
    assert_equal lowest_salary_dev, DeveloperOrderedBySalary.last
  end

  def test_default_scope_include_with_count
    d = DeveloperWithIncludes.create!
    d.audit_logs.create! message: "foo"

    assert_equal 1, DeveloperWithIncludes.where(audit_logs: { message: "foo" }).count
  end

  def test_default_scope_with_references_works_through_collection_association
    post = PostWithCommentWithDefaultScopeReferencesAssociation.create!(title: "Hello World", body: "Here we go.")
    comment = post.comment_with_default_scope_references_associations.create!(body: "Great post.", developer_id: Developer.first.id)
    assert_equal comment, post.comment_with_default_scope_references_associations.to_a.first
  end

  def test_default_scope_with_references_works_through_association
    post = PostWithCommentWithDefaultScopeReferencesAssociation.create!(title: "Hello World", body: "Here we go.")
    comment = post.comment_with_default_scope_references_associations.create!(body: "Great post.", developer_id: Developer.first.id)
    assert_equal comment, post.first_comment
  end

  def test_default_scope_with_references_works_with_find_by
    post = PostWithCommentWithDefaultScopeReferencesAssociation.create!(title: "Hello World", body: "Here we go.")
    comment = post.comment_with_default_scope_references_associations.create!(body: "Great post.", developer_id: Developer.first.id)
    assert_equal comment, CommentWithDefaultScopeReferencesAssociation.find_by(id: comment.id)
  end

  test "additional conditions are ANDed with the default scope" do
    scope = DeveloperCalledJamis.where(name: "David")
    assert_equal 2, scope.where_clause.ast.children.length
    assert_equal [], scope.to_a
  end

  test "additional conditions in a scope are ANDed with the default scope" do
    scope = DeveloperCalledJamis.david
    assert_equal 2, scope.where_clause.ast.children.length
    assert_equal [], scope.to_a
  end

  test "a scope can remove the condition from the default scope" do
    scope = DeveloperCalledJamis.david2
    assert_instance_of Arel::Nodes::Equality, scope.where_clause.ast
    assert_equal Developer.where(name: "David").map(&:id), scope.map(&:id)
  end

  def test_with_abstract_class_where_clause_should_not_be_duplicated
    scope = Lion.all
    assert_instance_of Arel::Nodes::Equality, scope.where_clause.ast
  end

  def test_sti_conditions_are_not_carried_in_default_scope
    ConditionalStiPost.create! body: ""
    SubConditionalStiPost.create! body: ""
    SubConditionalStiPost.create! title: "Hello world", body: ""

    assert_equal 2, ConditionalStiPost.count
    assert_equal 2, ConditionalStiPost.all.to_a.size
    assert_equal 3, ConditionalStiPost.unscope(where: :title).to_a.size

    assert_equal 1, SubConditionalStiPost.count
    assert_equal 1, SubConditionalStiPost.all.to_a.size
    assert_equal 2, SubConditionalStiPost.unscope(where: :title).to_a.size
  end

  def test_with_abstract_class_scope_should_be_executed_in_correct_context
    assert_match %r/#{Regexp.escape(quote_table_name("lions.is_vegetarian"))}/i, Lion.all.to_sql
    assert_match %r/#{Regexp.escape(quote_table_name("lions.gender"))}/i, Lion.female.to_sql
  end
end

class DefaultScopingWithThreadTest < ActiveRecord::TestCase
  unless in_memory_db?
    self.use_transactional_tests = false

    def test_default_scoping_with_threads
      2.times do
        Thread.new {
          assert_includes DeveloperOrderedBySalary.all.to_sql, "salary DESC"
          DeveloperOrderedBySalary.lease_connection.close
        }.join
      end
    end

    def test_default_scope_is_threadsafe
      2.times { ThreadsafeDeveloper.unscoped.create! }

      threads = []
      assert_not_equal 1, ThreadsafeDeveloper.unscoped.count

      barrier_1 = Concurrent::CyclicBarrier.new(2)
      barrier_2 = Concurrent::CyclicBarrier.new(2)

      threads << Thread.new do
        Thread.current[:default_scope_delay] = -> { barrier_1.wait; barrier_2.wait }
        assert_equal 1, ThreadsafeDeveloper.all.to_a.count
        ThreadsafeDeveloper.lease_connection.close
      end
      threads << Thread.new do
        Thread.current[:default_scope_delay] = -> { barrier_2.wait }
        barrier_1.wait
        assert_equal 1, ThreadsafeDeveloper.all.to_a.count
        ThreadsafeDeveloper.lease_connection.close
      end
      threads.each(&:join)
    ensure
      ThreadsafeDeveloper.unscoped.destroy_all
    end
  end
end
