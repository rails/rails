require "cases/helper"
require "models/post"
require "models/author"
require "models/developer"
require "models/computer"
require "models/project"
require "models/comment"
require "models/category"
require "models/person"
require "models/reference"

class RelationScopingTest < ActiveRecord::TestCase
  fixtures :authors, :developers, :projects, :comments, :posts, :developers_projects

  setup do
    developers(:david)
  end

  def test_unscoped_breaks_caching
    author = authors :mary
    assert_nil author.first_post
    post = FirstPost.unscoped do
      author.reload.first_post
    end
    assert post
  end

  def test_scope_breaks_caching_on_collections
    author = authors :david
    ids = author.reload.special_posts_with_default_scope.map(&:id)
    assert_equal [1, 5, 6], ids.sort
    scoped_posts = SpecialPostWithDefaultScope.unscoped do
      author = authors :david
      author.reload.special_posts_with_default_scope.to_a
    end
    assert_equal author.posts.map(&:id).sort, scoped_posts.map(&:id).sort
  end

  def test_reverse_order
    assert_equal Developer.order("id DESC").to_a.reverse, Developer.order("id DESC").reverse_order
  end

  def test_reverse_order_with_arel_node
    assert_equal Developer.order("id DESC").to_a.reverse, Developer.order(Developer.arel_table[:id].desc).reverse_order
  end

  def test_reverse_order_with_multiple_arel_nodes
    assert_equal Developer.order("id DESC").order("name DESC").to_a.reverse, Developer.order(Developer.arel_table[:id].desc).order(Developer.arel_table[:name].desc).reverse_order
  end

  def test_reverse_order_with_arel_nodes_and_strings
    assert_equal Developer.order("id DESC").order("name DESC").to_a.reverse, Developer.order("id DESC").order(Developer.arel_table[:name].desc).reverse_order
  end

  def test_double_reverse_order_produces_original_order
    assert_equal Developer.order("name DESC"), Developer.order("name DESC").reverse_order.reverse_order
  end

  def test_scoped_find
    Developer.where("name = 'David'").scoping do
      assert_nothing_raised { Developer.find(1) }
    end
  end

  def test_scoped_find_first
    developer = Developer.find(10)
    Developer.where("salary = 100000").scoping do
      assert_equal developer, Developer.order("name").first
    end
  end

  def test_scoped_find_last
    highest_salary = Developer.order("salary DESC").first

    Developer.order("salary").scoping do
      assert_equal highest_salary, Developer.last
    end
  end

  def test_scoped_find_last_preserves_scope
    lowest_salary  = Developer.order("salary ASC").first
    highest_salary = Developer.order("salary DESC").first

    Developer.order("salary").scoping do
      assert_equal highest_salary, Developer.last
      assert_equal lowest_salary, Developer.first
    end
  end

  def test_scoped_find_combines_and_sanitizes_conditions
    Developer.where("salary = 9000").scoping do
      assert_equal developers(:poor_jamis), Developer.where("name = 'Jamis'").first
    end
  end

  def test_scoped_find_all
    Developer.where("name = 'David'").scoping do
      assert_equal [developers(:david)], Developer.all
    end
  end

  def test_scoped_find_select
    Developer.select("id, name").scoping do
      developer = Developer.where("name = 'David'").first
      assert_equal "David", developer.name
      assert !developer.has_attribute?(:salary)
    end
  end

  def test_scope_select_concatenates
    Developer.select("id, name").scoping do
      developer = Developer.select("salary").where("name = 'David'").first
      assert_equal 80000, developer.salary
      assert developer.has_attribute?(:id)
      assert developer.has_attribute?(:name)
      assert developer.has_attribute?(:salary)
    end
  end

  def test_scoped_count
    Developer.where("name = 'David'").scoping do
      assert_equal 1, Developer.count
    end

    Developer.where("salary = 100000").scoping do
      assert_equal 8, Developer.count
      assert_equal 1, Developer.where("name LIKE 'fixture_1%'").count
    end
  end

  def test_scoped_find_include
    # with the include, will retrieve only developers for the given project
    scoped_developers = Developer.includes(:projects).scoping do
      Developer.where("projects.id" => 2).to_a
    end
    assert_includes scoped_developers, developers(:david)
    assert_not_includes scoped_developers, developers(:jamis)
    assert_equal 1, scoped_developers.size
  end

  def test_scoped_find_joins
    scoped_developers = Developer.joins("JOIN developers_projects ON id = developer_id").scoping do
      Developer.where("developers_projects.project_id = 2").to_a
    end

    assert_includes scoped_developers, developers(:david)
    assert_not_includes scoped_developers, developers(:jamis)
    assert_equal 1, scoped_developers.size
    assert_equal developers(:david).attributes, scoped_developers.first.attributes
  end

  def test_scoped_create_with_where
    new_comment = VerySpecialComment.where(post_id: 1).scoping do
      VerySpecialComment.create body: "Wonderful world"
    end

    assert_equal 1, new_comment.post_id
    assert_includes Post.find(1).comments, new_comment
  end

  def test_scoped_create_with_create_with
    new_comment = VerySpecialComment.create_with(post_id: 1).scoping do
      VerySpecialComment.create body: "Wonderful world"
    end

    assert_equal 1, new_comment.post_id
    assert_includes Post.find(1).comments, new_comment
  end

  def test_scoped_create_with_create_with_has_higher_priority
    new_comment = VerySpecialComment.where(post_id: 2).create_with(post_id: 1).scoping do
      VerySpecialComment.create body: "Wonderful world"
    end

    assert_equal 1, new_comment.post_id
    assert_includes Post.find(1).comments, new_comment
  end

  def test_ensure_that_method_scoping_is_correctly_restored
    begin
      Developer.where("name = 'Jamis'").scoping do
        raise "an exception"
      end
    rescue
    end

    assert_not Developer.all.to_sql.include?("name = 'Jamis'"), "scope was not restored"
  end

  def test_default_scope_filters_on_joins
    assert_equal 1, DeveloperFilteredOnJoins.all.count
    assert_equal DeveloperFilteredOnJoins.all.first, developers(:david).becomes(DeveloperFilteredOnJoins)
  end

  def test_update_all_default_scope_filters_on_joins
    DeveloperFilteredOnJoins.update_all(salary: 65000)
    assert_equal 65000, Developer.find(developers(:david).id).salary

    # has not changed jamis
    assert_not_equal 65000, Developer.find(developers(:jamis).id).salary
  end

  def test_delete_all_default_scope_filters_on_joins
    assert_not_equal [], DeveloperFilteredOnJoins.all

    DeveloperFilteredOnJoins.delete_all()

    assert_equal [], DeveloperFilteredOnJoins.all
    assert_not_equal [], Developer.all
  end

  def test_current_scope_does_not_pollute_sibling_subclasses
    Comment.none.scoping do
      assert_not SpecialComment.all.any?
      assert_not VerySpecialComment.all.any?
      assert_not SubSpecialComment.all.any?
    end

    SpecialComment.none.scoping do
      assert Comment.all.any?
      assert VerySpecialComment.all.any?
      assert_not SubSpecialComment.all.any?
    end

    SubSpecialComment.none.scoping do
      assert Comment.all.any?
      assert VerySpecialComment.all.any?
      assert SpecialComment.all.any?
    end
  end

  def test_circular_joins_with_current_scope_does_not_crash
    posts = Post.joins(comments: :post).scoping do
      Post.current_scope.first(10)
    end
    assert_equal posts, Post.joins(comments: :post).first(10)
  end
end

class NestedRelationScopingTest < ActiveRecord::TestCase
  fixtures :authors, :developers, :projects, :comments, :posts

  def test_merge_options
    Developer.where("salary = 80000").scoping do
      Developer.limit(10).scoping do
        devs = Developer.all
        sql = devs.to_sql
        assert_match "(salary = 80000)", sql
        assert_match(/LIMIT 10|ROWNUM <= 10|FETCH FIRST 10 ROWS ONLY/, sql)
      end
    end
  end

  def test_merge_inner_scope_has_priority
    Developer.limit(5).scoping do
      Developer.limit(10).scoping do
        assert_equal 10, Developer.all.size
      end
    end
  end

  def test_replace_options
    Developer.where(name: "David").scoping do
      Developer.unscoped do
        assert_equal "Jamis", Developer.where(name: "Jamis").first[:name]
      end

      assert_equal "David", Developer.first[:name]
    end
  end

  def test_three_level_nested_exclusive_scoped_find
    Developer.where("name = 'Jamis'").scoping do
      assert_equal "Jamis", Developer.first.name

      Developer.unscoped.where("name = 'David'") do
        assert_equal "David", Developer.first.name

        Developer.unscoped.where("name = 'Maiha'") do
          assert_nil Developer.first
        end

        # ensure that scoping is restored
        assert_equal "David", Developer.first.name
      end

      # ensure that scoping is restored
      assert_equal "Jamis", Developer.first.name
    end
  end

  def test_nested_scoped_create
    comment = Comment.create_with(post_id: 1).scoping do
      Comment.create_with(post_id: 2).scoping do
        Comment.create body: "Hey guys, nested scopes are broken. Please fix!"
      end
    end

    assert_equal 2, comment.post_id
  end

  def test_nested_exclusive_scope_for_create
    comment = Comment.create_with(body: "Hey guys, nested scopes are broken. Please fix!").scoping do
      Comment.unscoped.create_with(post_id: 1).scoping do
        assert Comment.new.body.blank?
        Comment.create body: "Hey guys"
      end
    end

    assert_equal 1, comment.post_id
    assert_equal "Hey guys", comment.body
  end
end

class HasManyScopingTest < ActiveRecord::TestCase
  fixtures :comments, :posts, :people, :references

  def setup
    @welcome = Post.find(1)
  end

  def test_forwarding_of_static_methods
    assert_equal "a comment...", Comment.what_are_you
    assert_equal "a comment...", @welcome.comments.what_are_you
  end

  def test_forwarding_to_scoped
    assert_equal 4, Comment.search_by_type("Comment").size
    assert_equal 2, @welcome.comments.search_by_type("Comment").size
  end

  def test_nested_scope_finder
    Comment.where("1=0").scoping do
      assert_equal 0, @welcome.comments.count
      assert_equal "a comment...", @welcome.comments.what_are_you
    end

    Comment.where("1=1").scoping do
      assert_equal 2, @welcome.comments.count
      assert_equal "a comment...", @welcome.comments.what_are_you
    end
  end

  def test_should_maintain_default_scope_on_associations
    magician = BadReference.find(1)
    assert_equal [magician], people(:michael).bad_references
  end

  def test_should_default_scope_on_associations_is_overridden_by_association_conditions
    reference = references(:michael_unicyclist).becomes(BadReference)
    assert_equal [reference], people(:michael).fixed_bad_references
  end

  def test_should_maintain_default_scope_on_eager_loaded_associations
    michael = Person.where(id: people(:michael).id).includes(:bad_references).first
    magician = BadReference.find(1)
    assert_equal [magician], michael.bad_references
  end
end

class HasAndBelongsToManyScopingTest < ActiveRecord::TestCase
  fixtures :posts, :categories, :categories_posts

  def setup
    @welcome = Post.find(1)
  end

  def test_forwarding_of_static_methods
    assert_equal "a category...", Category.what_are_you
    assert_equal "a category...", @welcome.categories.what_are_you
  end

  def test_nested_scope_finder
    Category.where("1=0").scoping do
      assert_equal 0, @welcome.categories.count
      assert_equal "a category...", @welcome.categories.what_are_you
    end

    Category.where("1=1").scoping do
      assert_equal 2, @welcome.categories.count
      assert_equal "a category...", @welcome.categories.what_are_you
    end
  end
end
