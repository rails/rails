# frozen_string_literal: true

require "pp"
require "cases/helper"
require "models/computer"
require "models/developer"
require "models/project"
require "models/company"
require "models/categorization"
require "models/category"
require "models/post"
require "models/author"
require "models/book"
require "models/comment"
require "models/tag"
require "models/tagging"
require "models/person"
require "models/reader"
require "models/ship_part"
require "models/ship"
require "models/liquid"
require "models/molecule"
require "models/electron"
require "models/human"
require "models/interest"
require "models/pirate"
require "models/parrot"
require "models/bird"
require "models/treasure"
require "models/price_estimate"
require "models/invoice"
require "models/discount"
require "models/line_item"
require "models/shipping_line"
require "models/essay"
require "models/member"
require "models/membership"
require "models/sharded"
require "models/cpk"
require "models/member_detail"
require "models/organization"
require "models/dog"
require "models/other_dog"


class AssociationsTest < ActiveRecord::TestCase
  fixtures :accounts, :companies, :developers, :projects, :developers_projects,
           :computers, :people, :readers, :authors, :author_addresses, :author_favorites,
           :comments, :posts, :sharded_blogs, :sharded_blog_posts, :sharded_comments, :sharded_tags, :sharded_blog_posts_tags,
           :cpk_orders, :cpk_books, :cpk_reviews

  def test_eager_loading_should_not_change_count_of_children
    liquid = Liquid.create(name: "salty")
    molecule = liquid.molecules.create(name: "molecule_1")
    molecule.electrons.create(name: "electron_1")
    molecule.electrons.create(name: "electron_2")

    liquids = Liquid.includes(molecules: :electrons).references(:molecules).where("molecules.id is not null")
    assert_equal 1, liquids[0].molecules.length
  end

  def test_subselect
    author = authors :david
    favs = author.author_favorites
    fav2 = author.author_favorites.where(author: Author.where(id: author.id)).to_a
    assert_equal favs, fav2
  end

  def test_loading_the_association_target_should_keep_child_records_marked_for_destruction
    ship = Ship.create!(name: "The good ship Dollypop")
    part = ship.parts.create!(name: "Mast")
    part.mark_for_destruction
    assert_predicate ship.parts[0], :marked_for_destruction?
  end

  def test_loading_the_association_target_should_load_most_recent_attributes_for_child_records_marked_for_destruction
    ship = Ship.create!(name: "The good ship Dollypop")
    part = ship.parts.create!(name: "Mast")
    part.mark_for_destruction
    ShipPart.find(part.id).update_columns(name: "Deck")
    assert_equal "Deck", ship.parts[0].name
  end

  def test_loading_cpk_association_when_persisted_and_in_memory_differ
    order = Cpk::Order.create!(id: [1, 2], status: "paid")
    book = order.books.create!(id: [3, 4], title: "Book")

    Cpk::Book.find(book.id).update_columns(title: "A different title")
    order.books.load

    assert_equal [3, 4], book.id
  end

  def test_include_with_order_works
    assert_nothing_raised { Account.all.merge!(order: "id", includes: :firm).first }
    assert_nothing_raised { Account.all.merge!(order: :id, includes: :firm).first }
  end

  def test_bad_collection_keys
    assert_raise(ArgumentError, "ActiveRecord should have barked on bad collection keys") do
      Class.new(ActiveRecord::Base).has_many(:wheels, name: "wheels")
    end
  end

  def test_should_construct_new_finder_sql_after_create
    person = Person.new first_name: "clark"
    assert_equal [], person.readers.to_a
    person.save!
    reader = Reader.create! person: person, post: Post.new(title: "foo", body: "bar")
    assert person.readers.find(reader.id)
  end

  def test_force_reload
    firm = Firm.new("name" => "A New Firm, Inc")
    firm.save
    firm.clients.each { } # forcing to load all clients
    assert_predicate firm.clients, :empty?, "New firm shouldn't have client objects"
    assert_equal 0, firm.clients.size, "New firm should have 0 clients"

    client = Client.new("name" => "TheClient.com", "firm_id" => firm.id)
    client.save

    assert_predicate firm.clients, :empty?, "New firm should have cached no client objects"
    assert_equal 0, firm.clients.size, "New firm should have cached 0 clients count"

    firm.clients.reload

    assert_not firm.clients.empty?, "New firm should have reloaded client objects"
    assert_equal 1, firm.clients.size, "New firm should have reloaded clients count"
  end

  def test_using_limitable_reflections_helper
    using_limitable_reflections = lambda { |reflections| Tagging.all.send :using_limitable_reflections?, reflections }
    belongs_to_reflections = [Tagging.reflect_on_association(:tag), Tagging.reflect_on_association(:super_tag)]
    has_many_reflections = [Tag.reflect_on_association(:taggings), Developer.reflect_on_association(:projects)]
    mixed_reflections = (belongs_to_reflections + has_many_reflections).uniq
    assert using_limitable_reflections.call(belongs_to_reflections), "Belong to associations are limitable"
    assert_not using_limitable_reflections.call(has_many_reflections), "All has many style associations are not limitable"
    assert_not using_limitable_reflections.call(mixed_reflections), "No collection associations (has many style) should pass"
  end

  def test_association_with_references
    firm = companies(:first_firm)
    assert_equal [:foo], firm.association_with_references.references_values
  end

  def test_belongs_to_a_model_with_composite_foreign_key_finds_associated_record
    comment = sharded_comments(:great_comment_blog_post_one)
    blog_post = sharded_blog_posts(:great_post_blog_one)

    assert_equal(blog_post, comment.blog_post)
  end

  def test_belongs_to_a_cpk_model_by_id_attribute
    order = cpk_orders(:cpk_groceries_order_1)
    _order_shop_id, order_id = order.id
    agreement = Cpk::OrderAgreement.create(order_id: order_id, signature: "signed")

    assert_equal(order, agreement.order)
  end

  def test_belongs_to_a_model_with_composite_primary_key_uses_composite_pk_in_sql
    comment = sharded_comments(:great_comment_blog_post_one)

    sql = capture_sql do
      comment.blog_post
    end.first

    assert_match(/#{Regexp.escape(quote_table_name("sharded_blog_posts.blog_id"))} =/, sql)
    assert_match(/#{Regexp.escape(quote_table_name("sharded_blog_posts.id"))} =/, sql)
  end

  def test_querying_by_whole_associated_records_using_query_constraints
    comments = [sharded_comments(:great_comment_blog_post_one), sharded_comments(:great_comment_blog_post_two)]

    blog_posts = Sharded::BlogPost.where(comments: comments).to_a

    expected_posts = [sharded_blog_posts(:great_post_blog_one), sharded_blog_posts(:great_post_blog_two)]
    assert_equal(expected_posts.map(&:id).sort, blog_posts.map(&:id).sort)
  end

  def test_querying_by_single_associated_record_works_using_query_constraints
    comments = [sharded_comments(:great_comment_blog_post_one), sharded_comments(:great_comment_blog_post_two)]

    blog_posts = Sharded::BlogPost.where(comments: comments.last).to_a

    expected_posts = [sharded_blog_posts(:great_post_blog_two)]
    assert_equal(expected_posts.map(&:id).sort, blog_posts.map(&:id).sort)
  end

  def test_querying_by_relation_with_composite_key
    expected_posts = [sharded_blog_posts(:great_post_blog_one), sharded_blog_posts(:great_post_blog_two)]

    blog_posts = Sharded::BlogPost.where(comments: Sharded::Comment.where(body: "I really enjoyed the post!")).to_a

    assert_equal(expected_posts.map(&:id).sort, blog_posts.map(&:id).sort)
  end

  def test_has_many_association_with_composite_foreign_key_loads_records
    blog_post = sharded_blog_posts(:great_post_blog_one)

    comments = blog_post.comments.to_a
    assert_includes(comments, sharded_comments(:wow_comment_blog_post_one))
    assert_includes(comments, sharded_comments(:great_comment_blog_post_one))
  end

  def test_belongs_to_with_explicit_composite_foreign_key
    car = Cpk::Car.create(make: "Tesla", model: "Model S")
    review = Cpk::CarReview.create(car: car, comment: "Great car!", rating: 5)

    review.reload

    sql = capture_sql do
      assert_equal(car, review.car)
    end

    assert_match(/#{Regexp.escape(quote_table_name("cpk_cars.make"))} =/, sql.first)
    assert_match(/#{Regexp.escape(quote_table_name("cpk_cars.model"))} =/, sql.first)
  end

  def test_cpk_model_has_many_records_by_id_attribute
    order = cpk_orders(:cpk_groceries_order_1)
    _order_shop_id, order_id = order.id
    agreements = 2.times.map { Cpk::OrderAgreement.create(order_id: order_id, signature: "signed") }

    assert_equal(agreements.sort, order.order_agreements.to_a.sort)
  end

  def test_has_many_association_from_a_model_with_query_constraints_different_from_the_association
    blog_post = sharded_blog_posts(:great_post_blog_one)
    blog_post = Sharded::BlogPostWithRevision.find(blog_post.id)
    comments = []
    expected_comments = Sharded::Comment.where(blog_id: blog_post.blog_id, blog_post_id: blog_post.id).to_a

    sql = capture_sql do
      comments = blog_post.comments.to_a
    end.first

    assert_match(/WHERE .*#{Regexp.escape(quote_table_name("sharded_comments.blog_id"))} =/, sql)
    assert_not_empty(comments)
    assert_equal(expected_comments.sort, comments.sort)
  end

  def test_query_constraints_over_three_without_defining_explicit_foreign_key_query_constraints_raises
    Sharded::BlogPostWithRevision.has_many :comments_without_query_constraints, primary_key: [:blog_id, :id], class_name: "Comment"
    blog_post = sharded_blog_posts(:great_post_blog_one)
    blog_post = Sharded::BlogPostWithRevision.find(blog_post.id)

    error = assert_raises ArgumentError do
      blog_post.comments_without_query_constraints.to_a
    end

    assert_equal "The query constraints list on the `Sharded::BlogPostWithRevision` model has more than 2 attributes. Active Record is unable to derive the query constraints for the association. You need to explicitly define the query constraints for this association.", error.message
  end

  def test_model_with_composite_query_constraints_has_many_association_sql
    blog_post = sharded_blog_posts(:great_post_blog_one)

    sql = capture_sql do
      blog_post.comments.to_a
    end.first

    assert_match(/#{Regexp.escape(quote_table_name("sharded_comments.blog_post_id"))} =/, sql)
    assert_match(/#{Regexp.escape(quote_table_name("sharded_comments.blog_id"))} =/, sql)
  end

  def test_belongs_to_association_does_not_use_parent_query_constraints_if_not_configured_to
    comment = sharded_comments(:great_comment_blog_post_one)
    blog_post = Sharded::BlogPost.new(blog_id: comment.blog_id, title: "Following best practices")

    comment.blog_post_by_id = blog_post

    comment.save

    assert_predicate blog_post, :persisted?
    assert_equal(blog_post, comment.blog_post_by_id)
  end

  def test_polymorphic_belongs_to_uses_parent_query_constraints
    parent_post = sharded_blog_posts(:great_post_blog_one)
    child_post = Sharded::BlogPost.create!(title: "Child post", blog_id: parent_post.blog_id, parent: parent_post)
    child_post.reload # reload to forget the parent association

    assert_equal parent_post, child_post.parent
  end

  def test_preloads_model_with_query_constraints_by_explicitly_configured_fk_and_pk
    comment = sharded_comments(:great_comment_blog_post_one)
    comments = Sharded::Comment.where(id: comment.id).preload(:blog_post_by_id).to_a
    comment = comments.first
    assert_equal(comment.blog_post_by_id, comment.blog_post)
  end

  def test_append_composite_foreign_key_has_many_association
    blog_post = sharded_blog_posts(:great_post_blog_one)
    comment = Sharded::Comment.new(body: "Great post! :clap:")
    comment.save
    blog_post.comments << comment

    assert_includes(blog_post.comments, comment)
    assert_equal(blog_post.id, comment.blog_post_id)
    assert_equal(blog_post.blog_id, comment.blog_id)
  end

  def test_nullify_composite_foreign_key_has_many_association
    blog_post = sharded_blog_posts(:great_post_blog_one)
    comment = sharded_comments(:great_comment_blog_post_one)

    assert_not_empty(blog_post.comments)
    blog_post.comments = []

    comment = Sharded::Comment.find(comment.id)
    assert_nil(comment.blog_post_id)
    assert_nil(comment.blog_id)

    assert_empty(blog_post.comments)
    assert_empty(blog_post.reload.comments)
  end

  def test_assign_persisted_composite_foreign_key_belongs_to_association
    comment = sharded_comments(:great_comment_blog_post_one)
    another_blog = sharded_blogs(:sharded_blog_two)
    assert_not_equal(comment.blog_id, another_blog.id)

    blog_post = Sharded::BlogPost.new(title: "New post", blog_id: another_blog.id)
    blog_post.save
    comment.blog_post = blog_post

    assert_equal(blog_post, comment.blog_post)
    assert_equal(comment.blog_id, blog_post.blog_id)
    assert_equal(another_blog.id, comment.blog_id)
    assert_equal(comment.blog_post_id, blog_post.id)
  end

  def test_nullify_composite_foreign_key_belongs_to_association
    comment = sharded_comments(:great_comment_blog_post_one)
    assert_not_nil(comment.blog_post)

    comment.blog_post = nil
    assert_nil(comment.blog_id)
    assert_nil(comment.blog_post_id)

    comment.save
    assert_nil(comment.blog_post)
    assert_nil(comment.reload.blog_post)
  end

  def test_assign_composite_foreign_key_belongs_to_association
    comment = sharded_comments(:great_comment_blog_post_one)
    another_blog = sharded_blogs(:sharded_blog_two)
    assert_not_equal(comment.blog_id, another_blog.id)

    blog_post = Sharded::BlogPost.new(title: "New post", blog_id: another_blog.id)
    comment.blog_post = blog_post

    assert_equal(blog_post, comment.blog_post)
    assert_equal(comment.blog_id, blog_post.blog_id)
    assert_equal(another_blog.id, comment.blog_id)
  end

  def test_query_constraints_that_dont_include_the_primary_key_raise_with_a_single_column
    original = Sharded::BlogPost.instance_variable_get(:@query_constraints_list)
    Sharded::BlogPost.query_constraints :title
    Sharded::BlogPost.has_many :comments_without_single_column_query_constraints, primary_key: [:blog_id, :id], class_name: "Comment"
    blog_post = sharded_blog_posts(:great_post_blog_one)

    error = assert_raises ArgumentError do
      blog_post.comments_without_single_column_query_constraints.to_a
    end

    assert_equal "The query constraints on the `Sharded::BlogPost` model does not include the primary key so Active Record is unable to derive the foreign key constraints for the association. You need to explicitly define the query constraints for this association.", error.message
  ensure
    Sharded::BlogPost.instance_variable_set(:@query_constraints_list, original)
  end

  def test_query_constraints_that_dont_include_the_primary_key_raise_with_multiple_columns
    original = Sharded::BlogPost.instance_variable_get(:@query_constraints_list)
    Sharded::BlogPost.query_constraints :title, :revision
    Sharded::BlogPost.has_many :comments_without_multiple_column_query_constraints, primary_key: [:blog_id, :id], class_name: "Comment"
    blog_post = sharded_blog_posts(:great_post_blog_one)

    error = assert_raises ArgumentError do
      blog_post.comments_without_multiple_column_query_constraints.to_a
    end

    assert_equal "The query constraints on the `Sharded::BlogPost` model does not include the primary key so Active Record is unable to derive the foreign key constraints for the association. You need to explicitly define the query constraints for this association.", error.message
  ensure
    Sharded::BlogPost.instance_variable_set(:@query_constraints_list, original)
  end

  def test_assign_belongs_to_cpk_model_by_id_attribute
    order = cpk_orders(:cpk_groceries_order_1)
    agreement = Cpk::OrderAgreement.new(signature: "signed")

    agreement.order = order
    agreement.save

    assert_not_nil(agreement.reload.order)
    assert_not_nil(agreement.order_id)

    assert_equal(order, agreement.order)
    _shop_id, order_id = order.id
    assert_equal(order_id, agreement.order_id)
  end

  def test_append_composite_foreign_key_has_many_association_with_autosave
    blog_post = sharded_blog_posts(:great_post_blog_one)
    comment = Sharded::Comment.new(body: "Great post! :clap:")
    blog_post.comments << comment

    assert_predicate(comment, :persisted?)
    assert_includes(blog_post.comments, comment)
    assert_equal(blog_post.id, comment.blog_post_id)
    assert_equal(blog_post.blog_id, comment.blog_id)
  end

  def test_assign_composite_foreign_key_belongs_to_association_with_autosave
    comment = sharded_comments(:great_comment_blog_post_one)
    another_blog = sharded_blogs(:sharded_blog_two)
    assert_not_equal(comment.blog_id, another_blog.id)

    blog_post = Sharded::BlogPost.new(title: "New post", blog_id: another_blog.id)
    comment.blog_post = blog_post
    comment.save

    assert_predicate(blog_post, :persisted?)
    assert_equal(blog_post, comment.blog_post)
    assert_equal(comment.blog_id, blog_post.blog_id)
    assert_equal(another_blog.id, comment.blog_id)
    assert_equal(comment.blog_post_id, blog_post.id)
  end

  def test_append_composite_has_many_through_association
    blog_post = sharded_blog_posts(:great_post_blog_one)
    tag = Sharded::Tag.new(name: "Ruby on Rails", blog_id: blog_post.blog_id)
    tag.save

    blog_post.tags << tag

    assert_includes(blog_post.reload.tags, tag)
    assert_predicate Sharded::BlogPostTag.where(blog_post_id: blog_post.id, blog_id: blog_post.blog_id, tag_id: tag.id), :exists?
  end

  def test_append_composite_has_many_through_association_with_autosave
    blog_post = sharded_blog_posts(:great_post_blog_one)
    tag = Sharded::Tag.new(name: "Ruby on Rails", blog_id: blog_post.blog_id)

    blog_post.tags << tag

    assert_includes(blog_post.reload.tags, tag)
    assert_predicate Sharded::BlogPostTag.where(blog_post_id: blog_post.id, blog_id: blog_post.blog_id, tag_id: tag.id), :exists?
  end

  def test_nullify_composite_has_many_through_association
    blog_post = sharded_blog_posts(:great_post_blog_one)
    assert_not_empty(blog_post.tags)

    blog_post.tags = []

    assert_empty(blog_post.tags)
    assert_empty(blog_post.reload.tags)
    assert_not_predicate Sharded::BlogPostTag.where(blog_post_id: blog_post.id, blog_id: blog_post.blog_id), :exists?
  end

  def test_using_query_constraints_warns_about_changing_behavior
    has_many_expected_message = <<~MSG.squish
      Setting `query_constraints:` option on `Sharded::BlogPost.has_many :qc_deprecated_comments` is not allowed.
      To get the same behavior, use the `foreign_key` option instead.
    MSG

    assert_raises(ActiveRecord::ConfigurationError, match: has_many_expected_message) do
      Sharded::BlogPost.has_many :qc_deprecated_comments,
        class_name: "Sharded::Comment", query_constraints: [:blog_id, :blog_post_id]
    end

    belongs_to_expected_message = <<~MSG.squish
      Setting `query_constraints:` option on `Sharded::Comment.belongs_to :qc_deprecated_blog_post` is not allowed.
      To get the same behavior, use the `foreign_key` option instead.
    MSG

    assert_raises(ActiveRecord::ConfigurationError, match: belongs_to_expected_message) do
      Sharded::Comment.belongs_to :qc_deprecated_blog_post,
        class_name: "Sharded::Blog", query_constraints: [:blog_id, :blog_post_id]
    end
  end
end

class AssociationProxyTest < ActiveRecord::TestCase
  fixtures :authors, :author_addresses, :posts, :categorizations, :categories, :developers, :projects, :developers_projects, :members

  def test_push_does_not_load_target
    david = authors(:david)

    david.posts << (post = Post.new(title: "New on Edge", body: "More cool stuff!"))
    assert_not_predicate david.posts, :loaded?
    assert_includes david.posts, post
  end

  def test_push_has_many_through_does_not_load_target
    david = authors(:david)

    david.categories << categories(:technology)
    assert_not_predicate david.categories, :loaded?
    assert_includes david.categories, categories(:technology)
  end

  def test_push_followed_by_save_does_not_load_target
    david = authors(:david)

    david.posts << (post = Post.new(title: "New on Edge", body: "More cool stuff!"))
    assert_not_predicate david.posts, :loaded?
    david.save
    assert_not_predicate david.posts, :loaded?
    assert_includes david.posts, post
  end

  def test_push_does_not_lose_additions_to_new_record
    josh = Author.new(name: "Josh")
    josh.posts << Post.new(title: "New on Edge", body: "More cool stuff!")
    assert_predicate josh.posts, :loaded?
    assert_equal 1, josh.posts.size
  end

  def test_append_behaves_like_push
    josh = Author.new(name: "Josh")
    josh.posts.append Post.new(title: "New on Edge", body: "More cool stuff!")
    assert_predicate josh.posts, :loaded?
    assert_equal 1, josh.posts.size
  end

  def test_prepend_is_not_defined
    josh = Author.new(name: "Josh")
    assert_raises(NoMethodError) { josh.posts.prepend Post.new }
  end

  def test_save_on_parent_does_not_load_target
    david = developers(:david)

    assert_not_predicate david.projects, :loaded?
    david.update_columns(created_at: Time.now)
    assert_not_predicate david.projects, :loaded?
  end

  def test_load_does_load_target
    david = developers(:david)

    assert_not_predicate david.projects, :loaded?
    david.projects.load
    assert_predicate david.projects, :loaded?
  end

  def test_inspect_does_not_reload_a_not_yet_loaded_target
    andreas = Developer.new name: "Andreas", log: "new developer added"
    assert_not_predicate andreas.audit_logs, :loaded?
    assert_match(/message: "new developer added"/, andreas.audit_logs.inspect)
    assert_predicate andreas.audit_logs, :loaded?
  end

  def test_pretty_print_does_not_reload_a_not_yet_loaded_target
    andreas = Developer.new(log: "new developer added")
    assert_not_predicate andreas.audit_logs, :loaded?
    out = StringIO.new
    PP.pp(andreas.audit_logs, out)
    assert_match(/message: "new developer added"/, out.string)
    assert_predicate andreas.audit_logs, :loaded?
  end

  def test_save_on_parent_saves_children
    developer = Developer.create name: "Bryan", salary: 50_000
    assert_equal 1, developer.reload.audit_logs.size
  end

  def test_create_via_association_with_block
    post = authors(:david).posts.create(title: "New on Edge") { |p| p.body = "More cool stuff!" }
    assert_equal "New on Edge", post.title
    assert_equal "More cool stuff!", post.body
  end

  def test_create_with_bang_via_association_with_block
    post = authors(:david).posts.create!(title: "New on Edge") { |p| p.body = "More cool stuff!" }
    assert_equal "New on Edge", post.title
    assert_equal "More cool stuff!", post.body
  end

  def test_reload_returns_association
    david = developers(:david)
    assert_nothing_raised do
      assert_equal david.projects, david.projects.reload.reload
    end
  end

  def test_proxy_association_accessor
    david = developers(:david)
    assert_equal david.association(:projects), david.projects.proxy_association
  end

  def test_scoped_allows_conditions
    assert developers(:david).projects.merge(where: "foo").to_sql.include?("foo")
  end

  test "getting a scope from an association" do
    david = developers(:david)

    assert david.projects.scope.is_a?(ActiveRecord::Relation)
    assert_equal david.projects, david.projects.scope
  end

  test "proxy object is cached" do
    david = developers(:david)
    assert_same david.projects, david.projects
  end

  test "proxy object can be stubbed" do
    david = developers(:david)
    david.projects.define_singleton_method(:extra_method) { 42 }

    assert_equal 42, david.projects.extra_method
  end

  test "inverses get set of subsets of the association" do
    human = Human.create
    human.interests.create

    human = Human.find(human.id)

    assert_queries_count(1) do
      assert_equal human, human.interests.where("1=1").first.human
    end
  end

  test "first! works on loaded associations" do
    david = authors(:david)
    assert_equal david.first_posts.first, david.first_posts.reload.first!
    assert_predicate david.first_posts, :loaded?
    assert_no_queries { david.first_posts.first! }
  end

  def test_pluck_uses_loaded_target
    david = authors(:david)
    assert_equal david.first_posts.pluck(:title), david.first_posts.load.pluck(:title)
    assert_predicate david.first_posts, :loaded?
    assert_no_queries { david.first_posts.pluck(:title) }
  end

  def test_pick_uses_loaded_target
    david = authors(:david)
    assert_equal david.first_posts.pick(:title), david.first_posts.load.pick(:title)
    assert_predicate david.first_posts, :loaded?
    assert_no_queries { david.first_posts.pick(:title) }
  end

  def test_reset_unloads_target
    david = authors(:david)
    david.posts.reload

    assert_predicate david.posts, :loaded?
    assert_predicate david.posts, :loaded
    david.posts.reset
    assert_not_predicate david.posts, :loaded?
    assert_not_predicate david.posts, :loaded
  end

  def test_target_merging_ignores_persisted_in_memory_records
    david = authors(:david)
    assert david.thinking_posts.include?(posts(:thinking))

    david.thinking_posts.create!(title: "Something else entirely", body: "Does not matter.")

    assert_equal 1, david.thinking_posts.size
    assert_equal 1, david.thinking_posts.to_a.size
  end

  def test_target_merging_ignores_persisted_in_memory_records_when_loaded_records_are_empty
    member = members(:blarpy_winkup)
    assert_empty member.favorite_memberships

    membership = member.favorite_memberships.create!
    membership.update!(favorite: false)

    assert_empty member.favorite_memberships.to_a
  end

  def test_target_merging_recognizes_updated_in_memory_records
    member = members(:blarpy_winkup)
    membership = member.create_membership!(favorite: false)

    assert_empty member.favorite_memberships

    membership.update!(favorite: true)

    assert_not_empty member.favorite_memberships.to_a
  end

  def test_size_differentiates_between_new_and_persisted_in_memory_records_when_loaded_records_are_empty
    member = members(:blarpy_winkup)
    assert_empty member.favorite_memberships

    membership = member.favorite_memberships.create!
    membership.update!(favorite: false)

    # CollectionAssociation#size has different behavior when loaded vs. non-loaded
    # the first call will mark the association as loaded and the second call will
    # take a different code path, so it's important to keep both assertions
    assert_equal 0, member.favorite_memberships.size
    assert_equal 0, member.favorite_memberships.size
  end
end

class OverridingAssociationsTest < ActiveRecord::TestCase
  class DifferentPerson < ActiveRecord::Base; end

  class PeopleList < ActiveRecord::Base
    has_and_belongs_to_many :has_and_belongs_to_many, before_add: :enlist
    has_many :has_many, before_add: :enlist
    belongs_to :belongs_to
    has_one :has_one
  end

  class DifferentPeopleList < PeopleList
    # Different association with the same name, callbacks should be omitted here.
    has_and_belongs_to_many :has_and_belongs_to_many, class_name: "DifferentPerson"
    has_many :has_many, class_name: "DifferentPerson"
    belongs_to :belongs_to, class_name: "DifferentPerson"
    has_one :has_one, class_name: "DifferentPerson"
  end

  def test_habtm_association_redefinition_callbacks_should_differ_and_not_inherited
    # redeclared association on AR descendant should not inherit callbacks from superclass
    callbacks = PeopleList.before_add_for_has_and_belongs_to_many
    assert_equal(1, callbacks.length)
    callbacks = DifferentPeopleList.before_add_for_has_and_belongs_to_many
    assert_equal([], callbacks)
  end

  def test_has_many_association_redefinition_callbacks_should_differ_and_not_inherited
    # redeclared association on AR descendant should not inherit callbacks from superclass
    callbacks = PeopleList.before_add_for_has_many
    assert_equal(1, callbacks.length)
    callbacks = DifferentPeopleList.before_add_for_has_many
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

  def test_requires_symbol_argument
    assert_raises ArgumentError do
      Class.new(Post) do
        belongs_to "author"
      end
    end
  end

  class ModelAssociatedToClassesThatDoNotExist < ActiveRecord::Base
    self.table_name = "accounts" # this is just to avoid adding a new model just for this test

    has_one :non_existent_has_one_class
    belongs_to :non_existent_belongs_to_class
    has_many :non_existent_has_many_classes
  end

  def test_associations_raise_with_name_error_if_associated_to_classes_that_do_not_exist
    assert_raises NameError do
      ModelAssociatedToClassesThatDoNotExist.new.non_existent_has_one_class
    end

    assert_raises NameError do
      ModelAssociatedToClassesThatDoNotExist.new.non_existent_belongs_to_class
    end

    assert_raises NameError do
      ModelAssociatedToClassesThatDoNotExist.new.non_existent_has_many_classes
    end
  end
end

class PreloaderTest < ActiveRecord::TestCase
  fixtures :posts, :comments, :books, :authors, :tags, :taggings, :essays, :categories, :author_addresses,
           :sharded_blog_posts, :sharded_comments, :sharded_blog_posts_tags, :sharded_tags,
           :members, :member_details, :organizations, :cpk_orders, :cpk_order_agreements,
           :dogs, :other_dogs

  def test_preload_with_scope
    post = posts(:welcome)

    preloader = ActiveRecord::Associations::Preloader.new(records: [post], associations: :comments, scope: Comment.where(body: "Thank you for the welcome"))
    preloader.call

    assert_predicate post.comments, :loaded?
    assert_equal [comments(:greetings)], post.comments
  end

  def test_preload_makes_correct_number_of_queries_on_array
    post = posts(:welcome)

    assert_queries_count(1) do
      preloader = ActiveRecord::Associations::Preloader.new(records: [post], associations: :comments)
      preloader.call
    end
  end

  def test_preload_makes_correct_number_of_queries_on_relation
    post = posts(:welcome)
    relation = Post.where(id: post.id)

    assert_queries_count(2) do
      preloader = ActiveRecord::Associations::Preloader.new(records: relation, associations: :comments)
      preloader.call
    end
  end

  def test_preload_does_not_concatenate_duplicate_records
    post = posts(:welcome)
    post.reload
    post.comments.create!(body: "A new comment")

    ActiveRecord::Associations::Preloader.new(records: [post], associations: :comments).call

    assert_equal post.comments.length, post.comments.count
    assert_equal post.comments.all.to_a, post.comments
  end

  def test_preload_for_hmt_with_conditions
    post = posts(:welcome)
    _normal_category = post.categories.create!(name: "Normal")
    special_category = post.special_categories.create!(name: "Special")

    preloader = ActiveRecord::Associations::Preloader.new(records: [post], associations: :hmt_special_categories)
    preloader.call

    assert_equal 1, post.hmt_special_categories.length
    assert_equal [special_category], post.hmt_special_categories
  end

  def test_preload_groups_queries_with_same_scope
    book = books(:awdr)
    post = posts(:welcome)

    assert_queries_count(1) do
      preloader = ActiveRecord::Associations::Preloader.new(records: [book, post], associations: :author)
      preloader.call
    end

    assert_no_queries do
      book.author
      post.author
    end
  end

  def test_preload_grouped_queries_with_already_loaded_records
    book = books(:awdr)
    post = posts(:welcome)
    book.author

    assert_no_queries do
      ActiveRecord::Associations::Preloader.new(records: [book, post], associations: :author).call
      book.author
      post.author
    end
  end

  def test_preload_grouped_queries_of_middle_records
    comments = [
      comments(:eager_sti_on_associations_s_comment1),
      comments(:eager_sti_on_associations_s_comment2),
    ]

    assert_queries_count(2) do
      ActiveRecord::Associations::Preloader.new(records: comments, associations: [:author, :ordinary_post]).call
    end
  end

  def test_preload_grouped_queries_of_through_records
    author = authors(:david)

    assert_queries_count(3) do
      ActiveRecord::Associations::Preloader.new(records: [author], associations: [:hello_post_comments, :comments]).call
    end
  end

  def test_preload_through_records_with_already_loaded_middle_record
    member = members(:groucho)
    expected_member_detail_ids = member.organization_member_details_2.pluck(:id)

    member.reload.organization # load through record

    assert_queries_count(1) do
      ActiveRecord::Associations::Preloader.new(records: [member], associations: :organization_member_details_2).call
    end

    assert_no_queries do
      assert_equal expected_member_detail_ids.sort, member.organization_member_details_2.map(&:id).sort
    end
  end

  def test_preload_with_instance_dependent_scope
    david = authors(:david)
    david2 = Author.create!(name: "David")
    bob = authors(:bob)
    post = Post.create!(
      author: david,
      title: "test post",
      body: "this post is about David"
    )
    post2 = Post.create!(
      author: david,
      title: "test post 2",
      body: "this post is also about David"
    )

    assert_queries_count(2) do
      preloader = ActiveRecord::Associations::Preloader.new(records: [david, david2, bob], associations: :posts_mentioning_author)
      preloader.call
    end

    assert_predicate david.posts_mentioning_author, :loaded?
    assert_predicate david2.posts_mentioning_author, :loaded?
    assert_predicate bob.posts_mentioning_author, :loaded?

    assert_equal [post, post2].sort, david.posts_mentioning_author.sort
    assert_equal [], david2.posts_mentioning_author
    assert_equal [], bob.posts_mentioning_author
  end

  def test_preload_with_instance_dependent_through_scope
    david = authors(:david)
    david2 = Author.create!(name: "David")
    bob = authors(:bob)
    comment1 = david.posts.first.comments.create!(body: "Hi David!")
    comment2 = david.posts.first.comments.create!(body: "This comment mentions david")

    assert_queries_count(2) do
      preloader = ActiveRecord::Associations::Preloader.new(records: [david, david2, bob], associations: :comments_mentioning_author)
      preloader.call
    end

    assert_predicate david.comments_mentioning_author, :loaded?
    assert_predicate david2.comments_mentioning_author, :loaded?
    assert_predicate bob.comments_mentioning_author, :loaded?

    assert_equal [comment1, comment2].sort, david.comments_mentioning_author.sort
    assert_equal [], david2.comments_mentioning_author
    assert_equal [], bob.comments_mentioning_author
  end

  def test_preload_with_through_instance_dependent_scope
    david = authors(:david)
    david2 = Author.create!(name: "David")
    bob = authors(:bob)
    post = Post.create!(
      author: david,
      title: "test post",
      body: "this post is about David"
    )
    Post.create!(
      author: david,
      title: "test post 2",
      body: "this post is also about David"
    )
    post3 = Post.create!(
      author: bob,
      title: "test post 3",
      body: "this post is about Bob"
    )
    comment1 = post.comments.create!(body: "hi!")
    comment2 = post.comments.create!(body: "hello!")
    comment3 = post3.comments.create!(body: "HI BOB!")

    assert_queries_count(3) do
      preloader = ActiveRecord::Associations::Preloader.new(records: [david, david2, bob], associations: :comments_on_posts_mentioning_author)
      preloader.call
    end

    assert_predicate david.comments_on_posts_mentioning_author, :loaded?
    assert_predicate david2.comments_on_posts_mentioning_author, :loaded?
    assert_predicate bob.comments_on_posts_mentioning_author, :loaded?

    assert_equal [comment1, comment2].sort, david.comments_on_posts_mentioning_author.sort
    assert_equal [], david2.comments_on_posts_mentioning_author
    assert_equal [comment3], bob.comments_on_posts_mentioning_author
  end

  def test_some_already_loaded_associations
    item_discount = Discount.create(amount: 5)
    shipping_discount = Discount.create(amount: 20)

    invoice = Invoice.new
    line_item = LineItem.new(amount: 20)
    line_item.discount_applications << LineItemDiscountApplication.new(discount: item_discount)
    invoice.line_items << line_item

    shipping_line = ShippingLine.new(amount: 50)
    shipping_line.discount_applications << ShippingLineDiscountApplication.new(discount: shipping_discount)
    invoice.shipping_lines << shipping_line

    invoice.save!
    invoice.reload

    # SELECT "line_items".* FROM "line_items" WHERE "line_items"."invoice_id" = ?
    # SELECT "shipping_lines".* FROM shipping_lines WHERE "shipping_lines"."invoice_id" = ?
    # SELECT "line_item_discount_applications".* FROM "line_item_discount_applications" WHERE "line_item_discount_applications"."line_item_id" = ?
    # SELECT "shipping_line_discount_applications".* FROM "shipping_line_discount_applications" WHERE "shipping_line_discount_applications"."shipping_line_id" = ?
    # SELECT "discounts".* FROM "discounts" WHERE "discounts"."id" IN (?, ?).
    assert_queries_count(5) do
      preloader = ActiveRecord::Associations::Preloader.new(records: [invoice], associations: [
        line_items: { discount_applications: :discount },
        shipping_lines: { discount_applications: :discount },
      ])
      preloader.call
    end

    assert_no_queries do
      assert_not_nil invoice.line_items.first.discount_applications.first.discount
      assert_not_nil invoice.shipping_lines.first.discount_applications.first.discount
    end

    invoice.reload
    invoice.line_items.map { |i| i.discount_applications.to_a }
    # `line_items` and `line_item_discount_applications` are already preloaded, so we expect:
    # SELECT "shipping_lines".* FROM shipping_lines WHERE "shipping_lines"."invoice_id" = ?
    # SELECT "shipping_line_discount_applications".* FROM "shipping_line_discount_applications" WHERE "shipping_line_discount_applications"."shipping_line_id" = ?
    # SELECT "discounts".* FROM "discounts" WHERE "discounts"."id" = ?.
    assert_queries_count(3) do
      preloader = ActiveRecord::Associations::Preloader.new(records: [invoice], associations: [
        line_items: { discount_applications: :discount },
        shipping_lines: { discount_applications: :discount },
      ])
      preloader.call
    end

    assert_no_queries do
      assert_not_nil invoice.line_items.first.discount_applications.first.discount
      assert_not_nil invoice.shipping_lines.first.discount_applications.first.discount
    end
  end

  def test_preload_through
    comments = [
      comments(:eager_sti_on_associations_s_comment1),
      comments(:eager_sti_on_associations_s_comment2),
    ]

    assert_queries_count(2) do
      preloader = ActiveRecord::Associations::Preloader.new(records: comments, associations: [:author, :post])
      preloader.call
    end

    assert_no_queries do
      comments.each(&:author)
    end
  end

  def test_preload_groups_queries_with_same_scope_at_second_level
    author = nil

    # Expected
    #   SELECT FROM authors ...
    #   SELECT FROM posts ... (thinking)
    #   SELECT FROM posts ... (welcome)
    #   SELECT FROM comments ... (comments for both welcome and thinking)
    assert_queries_count(4) do
      author = Author
        .where(name: "David")
        .includes(thinking_posts: :comments, welcome_posts: :comments)
        .first
    end

    assert_no_queries do
      author.thinking_posts.map(&:comments)
      author.welcome_posts.map(&:comments)
    end
  end

  def test_preload_groups_queries_with_same_sql_at_second_level
    author = nil

    # Expected
    #   SELECT FROM authors ...
    #   SELECT FROM posts ... (thinking)
    #   SELECT FROM posts ... (welcome)
    #   SELECT FROM comments ... (comments for both welcome and thinking)
    assert_queries_count(4) do
      author = Author
        .where(name: "David")
        .includes(thinking_posts: :comments, welcome_posts: :comments_with_extending)
        .first
    end

    assert_no_queries do
      author.thinking_posts.map(&:comments)
      author.welcome_posts.map(&:comments_with_extending)
    end
  end

  def test_preload_with_grouping_sets_inverse_association
    mary = authors(:mary)
    bob = authors(:bob)

    AuthorFavorite.create!(author: mary, favorite_author: bob)
    favorites = AuthorFavorite.all.load

    assert_queries_count(1) do
      preloader = ActiveRecord::Associations::Preloader.new(records: favorites, associations: [:author, :favorite_author])
      preloader.call
    end

    assert_no_queries do
      favorites.first.author
      favorites.first.favorite_author
    end
  end

  def test_preload_can_group_separate_levels
    mary = authors(:mary)
    bob = authors(:bob)

    AuthorFavorite.create!(author: mary, favorite_author: bob)

    assert_queries_count(3) do
      preloader = ActiveRecord::Associations::Preloader.new(records: [mary], associations: [:posts, favorite_authors: :posts])
      preloader.call
    end

    assert_no_queries do
      mary.posts
      mary.favorite_authors.map(&:posts)
    end
  end

  def test_preload_can_group_multi_level_ping_pong_through
    mary = authors(:mary)
    bob = authors(:bob)

    AuthorFavorite.create!(author: mary, favorite_author: bob)

    associations = { similar_posts: :comments, favorite_authors: { similar_posts: :comments } }

    assert_queries_count(9) do
      preloader = ActiveRecord::Associations::Preloader.new(records: [mary], associations: associations)
      preloader.call
    end

    assert_no_queries do
      mary.similar_posts.map(&:comments).each(&:to_a)
      mary.favorite_authors.flat_map(&:similar_posts).map(&:comments).each(&:to_a)
    end

    # Preloading with automatic scope inversing reduces the number of queries
    tag_reflection = Tagging.reflect_on_association(:tag)
    taggings_reflection = Tag.reflect_on_association(:taggings)

    assert tag_reflection.scope
    assert_not taggings_reflection.scope

    with_automatic_scope_inversing(tag_reflection, taggings_reflection) do
      mary.reload

      assert_queries_count(8) do
        preloader = ActiveRecord::Associations::Preloader.new(records: [mary], associations: associations)
        preloader.call
      end
    end
  end

  def test_preload_does_not_group_same_class_different_scope
    post = posts(:welcome)
    postesque = Postesque.create(author: Author.last)
    postesque.reload

    # When the scopes differ in the generated SQL:
    # SELECT "authors".* FROM "authors" WHERE (name LIKE '%a%') AND "authors"."id" = ?
    # SELECT "authors".* FROM "authors" WHERE "authors"."id" = ?.
    assert_queries_count(2) do
      preloader = ActiveRecord::Associations::Preloader.new(records: [post, postesque], associations: :author_with_the_letter_a)
      preloader.call
    end

    assert_no_queries do
      post.author_with_the_letter_a
      postesque.author_with_the_letter_a
    end

    post.reload
    postesque.reload

    # When the generated SQL is identical, but one scope has preload values.
    assert_queries_count(3) do
      preloader = ActiveRecord::Associations::Preloader.new(records: [post, postesque], associations: :author_with_address)
      preloader.call
    end

    assert_no_queries do
      post.author_with_address
      postesque.author_with_address
    end
  end

  def test_preload_does_not_group_same_scope_different_key_name
    post = posts(:welcome)
    postesque = Postesque.create(author: Author.last)
    postesque.reload

    assert_queries_count(2) do
      preloader = ActiveRecord::Associations::Preloader.new(records: [post, postesque], associations: :author)
      preloader.call
    end

    assert_no_queries do
      post.author
      postesque.author
    end
  end

  def test_multi_database_polymorphic_preload_with_same_table_name
    dog = dogs(:sophie)
    dog_comment = comments(:greetings)
    dog_comment.origin_type = dog.class.name
    dog_comment.origin_id = dog.id

    other_dog = other_dogs(:lassie)
    other_dog_comment = comments(:more_greetings)
    other_dog_comment.origin_type = other_dog.class.name
    other_dog_comment.origin_id = other_dog.id

    # Both Dog and OtherDog are backed by a table named `dogs`,
    # however they are stored in different databases and should
    # therefore result in two separate queries rather than be batched
    # together.
    #
    # Expected
    #   SELECT FROM dogs ... (Dog)
    #   SELECT FROM dogs ... (OtherDog)
    assert_queries_count(2) do
      preloader = ActiveRecord::Associations::Preloader.new(records: [dog_comment, other_dog_comment], associations: :origin)
      preloader.call
    end
  end

  def test_preload_with_available_records
    post = posts(:welcome)
    david = authors(:david)

    assert_no_queries do
      ActiveRecord::Associations::Preloader.new(records: [post], associations: :author, available_records: [[david]]).call

      assert_predicate post.association(:author), :loaded?
      assert_same david, post.author
    end
  end

  def test_preload_with_available_records_sti
    book = Book.create!
    essay_special = EssaySpecial.create!
    book.essay = essay_special
    book.save!
    book.reload

    assert_not_predicate book.association(:essay), :loaded?

    assert_no_queries do
      ActiveRecord::Associations::Preloader.new(records: [book], associations: :essay, available_records: [[essay_special]]).call
    end

    assert_predicate book.association(:essay), :loaded?
    assert_same essay_special, book.essay
  end

  def test_preload_with_only_some_records_available
    bob_post = posts(:misc_by_bob)
    mary_post = posts(:misc_by_mary)
    bob = authors(:bob)
    mary = authors(:mary)

    assert_queries_count(1) do
      ActiveRecord::Associations::Preloader.new(records: [bob_post, mary_post], associations: :author, available_records: [bob]).call
    end

    assert_no_queries do
      assert_same bob, bob_post.author
      assert_equal mary, mary_post.author
    end
  end

  def test_preload_with_some_records_already_loaded
    bob_post = posts(:misc_by_bob)
    mary_post = posts(:misc_by_mary)
    bob = bob_post.author
    mary = authors(:mary)

    assert_predicate bob_post.association(:author), :loaded?
    assert_not mary_post.association(:author).loaded?

    assert_queries_count(1) do
      ActiveRecord::Associations::Preloader.new(records: [bob_post, mary_post], associations: :author).call
    end

    assert_no_queries do
      assert_same bob, bob_post.author
      assert_equal mary, mary_post.author
    end
  end

  def test_preload_with_available_records_with_through_association
    author = authors(:david)
    categories = Category.all.to_a

    assert_queries_count(1) do
      # One query to get the middle records (i.e. essays)
      ActiveRecord::Associations::Preloader.new(records: [author], associations: :essay_category, available_records: categories).call
    end

    assert_predicate author.association(:essay_category), :loaded?
    assert categories.map(&:__id__).include?(author.essay_category.__id__)
  end

  def test_preload_with_only_some_records_available_with_through_associations
    mary = authors(:mary)
    mary_essay = essays(:mary_stay_home)
    mary_category = categories(:technology)
    mary_essay.update!(category: mary_category)

    dave = authors(:david)
    dave_category = categories(:general)

    assert_queries_count(2) do
      ActiveRecord::Associations::Preloader.new(records: [mary, dave], associations: :essay_category, available_records: [mary_category]).call
    end

    assert_no_queries do
      assert_same mary_category, mary.essay_category
      assert_equal dave_category, dave.essay_category
    end
  end

  def test_preload_with_available_records_with_multiple_classes
    essay = essays(:david_modest_proposal)
    general = categories(:general)
    david = authors(:david)

    assert_no_queries do
      ActiveRecord::Associations::Preloader.new(records: [essay], associations: [:category, :author], available_records: [general, david]).call

      assert_predicate essay.association(:category), :loaded?
      assert_predicate essay.association(:author), :loaded?
      assert_same general, essay.category
      assert_same david, essay.author
    end
  end

  def test_preload_with_available_records_queries_when_scoped
    post = posts(:welcome)
    david = authors(:david)

    assert_queries_count(1) do
      ActiveRecord::Associations::Preloader.new(records: [post], associations: :author, scope: Author.where(name: "David"), available_records: [david]).call
    end

    assert_predicate post.association(:author), :loaded?
    assert_not_equal david.__id__, post.author.__id__
  end

  def test_preload_with_available_records_queries_when_collection
    post = posts(:welcome)
    comments = Comment.all.to_a

    assert_queries_count(1) do
      ActiveRecord::Associations::Preloader.new(records: [post], associations: :comments, available_records: comments).call
    end

    assert_predicate post.association(:comments), :loaded?
    assert_empty post.comments.map(&:__id__) & comments.map(&:__id__)
  end

  def test_preload_with_available_records_queries_when_incomplete
    post = posts(:welcome)
    bob = authors(:bob)
    david = authors(:david)

    assert_queries_count(1) do
      ActiveRecord::Associations::Preloader.new(records: [post], associations: :author, available_records: [bob]).call
    end

    assert_no_queries do
      assert_predicate post.association(:author), :loaded?
      assert_equal david, post.author
    end
  end

  def test_preload_with_unpersisted_records_no_ops
    author = Author.new
    new_post_with_author = Post.new(author: author)
    new_post_without_author = Post.new
    posts = [new_post_with_author, new_post_without_author]

    assert_no_queries do
      ActiveRecord::Associations::Preloader.new(records: posts, associations: :author).call

      assert_same author, new_post_with_author.author
      assert_nil new_post_without_author.author
    end
  end

  def test_preload_wont_set_the_wrong_target
    post = posts(:welcome)
    post.update!(author_id: 54321)
    some_other_record = categories(:general)
    some_other_record.update!(id: 54321)

    assert_raises do
      some_other_record.association(:author)
    end

    assert_nothing_raised do
      ActiveRecord::Associations::Preloader.new(records: [post], associations: :author, available_records: [[some_other_record]]).call
      assert_predicate post.association(:author), :loaded?
      assert_not_equal some_other_record, post.author
    end
  end

  def test_preload_has_many_association_with_composite_foreign_key
    blog_post = sharded_blog_posts(:great_post_blog_one)
    blog_posts = [blog_post, sharded_blog_posts(:great_post_blog_two)]

    ::ActiveRecord::Associations::Preloader.new(records: blog_posts, associations: [:comments]).call

    assert_predicate blog_post.association(:comments), :loaded?
    assert_includes(blog_post.comments.to_a, sharded_comments(:great_comment_blog_post_one))
  end

  def test_preload_belongs_to_association_with_composite_foreign_key
    comment = sharded_comments(:great_comment_blog_post_one)
    comments = [comment, sharded_comments(:great_comment_blog_post_two)]

    ActiveRecord::Associations::Preloader.new(records: comments, associations: :blog_post).call

    assert_predicate comment.association(:blog_post), :loaded?
    assert_equal sharded_blog_posts(:great_post_blog_one), comment.blog_post
  end

  def test_preload_loaded_belongs_to_association_with_composite_foreign_key
    comment = sharded_comments(:great_comment_blog_post_one)
    comment.blog_post

    assert_no_queries do
      ActiveRecord::Associations::Preloader.new(records: [comment], associations: :blog_post).call
    end
  end

  def test_preload_has_many_through_association_with_composite_query_constraints
    tag = sharded_tags(:short_read_blog_one)

    tags = [tag, sharded_tags(:breaking_news_blog_2)]

    ActiveRecord::Associations::Preloader.new(records: tags, associations: :blog_posts).call

    assert tags.all? { |tag| tag.association(:blog_posts).loaded? }

    expected_blog_post_ids = Sharded::BlogPostTag
      .where(blog_id: tag.blog_id, tag_id: tag.id)
      .pluck(:blog_post_id)

    assert_not_empty(expected_blog_post_ids)

    assert_equal(expected_blog_post_ids.sort, tag.blog_posts.map(&:id).sort)
  end

  def test_preloads_has_many_on_model_with_a_composite_primary_key_through_id_attribute
    order = cpk_orders(:cpk_groceries_order_2)
    _shop_id, order_id = order.id
    order_agreements = Cpk::OrderAgreement.where(order_id: order_id).to_a

    assert_not_empty order_agreements
    assert_equal order_agreements.sort, order.order_agreements.sort

    loaded_order = nil
    sql = capture_sql do
      loaded_order = Cpk::Order.where(id: order_id).includes(:order_agreements).to_a.first
    end

    assert_equal 2, sql.size
    preload_sql = sql.last

    order_id_column = Regexp.escape(quote_table_name("cpk_order_agreements.order_id"))
    expectation = /SELECT.*WHERE.* #{order_id_column} = (\?|(\d+)|\$\d)$/

    assert_match(expectation, preload_sql)
    assert_equal order_agreements.sort, loaded_order.order_agreements.sort
  end

  def test_preloads_belongs_to_a_composite_primary_key_model_through_id_attribute
    order_agreement = cpk_order_agreements(:order_agreement_three)
    order = cpk_orders(:cpk_groceries_order_2)
    assert_equal order, order_agreement.order

    loaded_order_agreement = nil
    sql = capture_sql do
      loaded_order_agreement = Cpk::OrderAgreement.where(id: order_agreement.id).includes(:order).to_a.first
    end

    assert_equal 2, sql.size
    preload_sql = sql.last

    order_id = Regexp.escape(quote_table_name("cpk_orders.id"))
    expectation = /SELECT.*WHERE.* #{order_id} = (\?|(\d+)|\$\d)$/

    assert_match(expectation, preload_sql)
    assert_equal order, loaded_order_agreement.order
  end

  def test_preload_keeps_built_has_many_records_no_ops
    post = Post.new
    comment = post.comments.build

    assert_no_queries do
      ActiveRecord::Associations::Preloader.new(records: [post], associations: :comments).call

      assert_equal [comment], post.comments.to_a
    end
  end

  def test_preload_keeps_built_has_many_records_after_query
    post = posts(:welcome)
    comment = post.comments.build

    assert_queries_count(1) do
      ActiveRecord::Associations::Preloader.new(records: [post], associations: :comments).call

      assert_includes post.comments.to_a, comment
    end
  end


  def test_preload_keeps_built_belongs_to_records_no_ops
    post = Post.new
    author = post.build_author

    assert_no_queries do
      ActiveRecord::Associations::Preloader.new(records: [post], associations: :author).call

      assert_same author, post.author
    end
  end

  def test_preload_keeps_built_belongs_to_records_after_query
    post = posts(:welcome)
    author = post.build_author

    assert_no_queries do
      ActiveRecord::Associations::Preloader.new(records: [post], associations: :author).call

      assert_same author, post.author
    end
  end
end

class GeneratedMethodsTest < ActiveRecord::TestCase
  fixtures :developers, :computers, :posts, :comments

  def test_association_methods_override_attribute_methods_of_same_name
    assert_equal(developers(:david), computers(:workstation).developer)
    # this next line will fail if the attribute methods module is generated lazily
    # after the association methods module is generated
    assert_equal(developers(:david), computers(:workstation).developer)
    assert_equal(developers(:david).id, computers(:workstation)[:developer])
  end

  def test_model_method_overrides_association_method
    assert_equal(comments(:greetings).body, posts(:welcome).first_comment)
  end

  module MyModule
    def comments; :none end
  end

  class MyArticle < ActiveRecord::Base
    self.table_name = "articles"
    include MyModule
    has_many :comments, inverse_of: false
  end

  def test_included_module_overwrites_association_methods
    assert_equal :none, MyArticle.new.comments
  end
end

class WithAnnotationsTest < ActiveRecord::TestCase
  fixtures :pirates, :parrots, :parrots_pirates, :pirates, :treasures

  def test_belongs_to_with_annotation_includes_a_query_comment
    pirate = SpacePirate.where.not(parrot_id: nil).first
    assert pirate, "should have a Pirate record"

    log = capture_sql do
      pirate.parrot
    end
    assert_not_predicate log, :empty?
    assert_predicate log.select { |query| query.match?(%r{/\*}) }, :empty?

    assert_queries_match(%r{/\* that tells jokes \*/}) do
      pirate.parrot_with_annotation
    end
  end

  def test_has_and_belongs_to_many_with_annotation_includes_a_query_comment
    pirate = SpacePirate.first
    assert pirate, "should have a Pirate record"

    log = capture_sql do
      pirate.parrots.first
    end
    assert_not_predicate log, :empty?
    assert_predicate log.select { |query| query.match?(%r{/\*}) }, :empty?

    assert_queries_match(%r{/\* that are very colorful \*/}) do
      pirate.parrots_with_annotation.first
    end
  end

  def test_has_one_with_annotation_includes_a_query_comment
    pirate = SpacePirate.first
    assert pirate, "should have a Pirate record"

    log = capture_sql do
      pirate.ship
    end
    assert_not_predicate log, :empty?
    assert_predicate log.select { |query| query.match?(%r{/\*}) }, :empty?

    assert_queries_match(%r{/\* that is a rocket \*/}) do
      pirate.ship_with_annotation
    end
  end

  def test_has_many_with_annotation_includes_a_query_comment
    pirate = SpacePirate.first
    assert pirate, "should have a Pirate record"

    log = capture_sql do
      pirate.birds.first
    end
    assert_not_predicate log, :empty?
    assert_predicate log.select { |query| query.match?(%r{/\*}) }, :empty?

    assert_queries_match(%r{/\* that are also parrots \*/}) do
      pirate.birds_with_annotation.first
    end
  end

  def test_has_many_through_with_annotation_includes_a_query_comment
    pirate = SpacePirate.first
    assert pirate, "should have a Pirate record"

    log = capture_sql do
      pirate.treasure_estimates.first
    end
    assert_not_predicate log, :empty?
    assert_predicate log.select { |query| query.match?(%r{/\*}) }, :empty?

    assert_queries_match(%r{/\* yarrr \*/}) do
      pirate.treasure_estimates_with_annotation.first
    end
  end

  def test_has_many_through_with_annotation_includes_a_query_comment_when_eager_loading
    pirate = SpacePirate.first
    assert pirate, "should have a Pirate record"

    log = capture_sql do
      pirate.treasure_estimates.first
    end
    assert_not_predicate log, :empty?
    assert_predicate log.select { |query| query.match?(%r{/\*}) }, :empty?

    assert_queries_match(%r{/\* yarrr \*/}) do
      SpacePirate.includes(:treasure_estimates_with_annotation, :treasures).first
    end
  end
end
