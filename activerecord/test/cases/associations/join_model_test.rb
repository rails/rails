require "cases/helper"
require "models/tag"
require "models/tagging"
require "models/post"
require "models/rating"
require "models/item"
require "models/comment"
require "models/author"
require "models/category"
require "models/categorization"
require "models/vertex"
require "models/edge"
require "models/book"
require "models/citation"
require "models/aircraft"
require "models/engine"
require "models/car"

class AssociationsJoinModelTest < ActiveRecord::TestCase
  self.use_transactional_tests = false unless supports_savepoints?

  fixtures :posts, :authors, :categories, :categorizations, :comments, :tags, :taggings, :author_favorites, :vertices, :items, :books,
    # Reload edges table from fixtures as otherwise repeated test was failing
    :edges

  def test_has_many
    assert_includes authors(:david).categories, categories(:general)
  end

  def test_has_many_inherited
    assert_includes authors(:mary).categories, categories(:sti_test)
  end

  def test_inherited_has_many
    assert_includes categories(:sti_test).authors, authors(:mary)
  end

  def test_has_many_distinct_through_join_model
    assert_equal 2, authors(:mary).categorized_posts.size
    assert_equal 1, authors(:mary).unique_categorized_posts.size
  end

  def test_has_many_distinct_through_count
    author = authors(:mary)
    assert !authors(:mary).unique_categorized_posts.loaded?
    assert_queries(1) { assert_equal 1, author.unique_categorized_posts.count }
    assert_queries(1) { assert_equal 1, author.unique_categorized_posts.count(:title) }
    assert_queries(1) { assert_equal 0, author.unique_categorized_posts.where(title: nil).count(:title) }
    assert !authors(:mary).unique_categorized_posts.loaded?
  end

  def test_has_many_distinct_through_find
    assert_equal 1, authors(:mary).unique_categorized_posts.to_a.size
  end

  def test_polymorphic_has_many_going_through_join_model
    assert_equal tags(:general), tag = posts(:welcome).tags.first
    assert_no_queries do
      tag.tagging
    end
  end

  def test_count_polymorphic_has_many
    assert_equal 1, posts(:welcome).taggings.count
    assert_equal 1, posts(:welcome).tags.count
  end

  def test_polymorphic_has_many_going_through_join_model_with_find
    assert_equal tags(:general), tag = posts(:welcome).tags.first
    assert_no_queries do
      tag.tagging
    end
  end

  def test_polymorphic_has_many_going_through_join_model_with_include_on_source_reflection
    assert_equal tags(:general), tag = posts(:welcome).funky_tags.first
    assert_no_queries do
      tag.tagging
    end
  end

  def test_polymorphic_has_many_going_through_join_model_with_include_on_source_reflection_with_find
    assert_equal tags(:general), tag = posts(:welcome).funky_tags.first
    assert_no_queries do
      tag.tagging
    end
  end

  def test_polymorphic_has_many_going_through_join_model_with_custom_select_and_joins
    assert_equal tags(:general), tag = posts(:welcome).tags.add_joins_and_select.first
    assert_nothing_raised { tag.author_id }
  end

  def test_polymorphic_has_many_going_through_join_model_with_custom_foreign_key
    assert_equal tags(:misc), taggings(:welcome_general).super_tag
    assert_equal tags(:misc), posts(:welcome).super_tags.first
  end

  def test_polymorphic_has_many_create_model_with_inheritance_and_custom_base_class
    post = SubStiPost.create title: "SubStiPost", body: "SubStiPost body"
    assert_instance_of SubStiPost, post

    tagging = tags(:misc).taggings.create(taggable: post)
    assert_equal "SubStiPost", tagging.taggable_type
  end

  def test_polymorphic_has_many_going_through_join_model_with_inheritance
    assert_equal tags(:general), posts(:thinking).tags.first
  end

  def test_polymorphic_has_many_going_through_join_model_with_inheritance_with_custom_class_name
    assert_equal tags(:general), posts(:thinking).funky_tags.first
  end

  def test_polymorphic_has_many_create_model_with_inheritance
    post = posts(:thinking)
    assert_instance_of SpecialPost, post

    tagging = tags(:misc).taggings.create(taggable: post)
    assert_equal "Post", tagging.taggable_type
  end

  def test_polymorphic_has_one_create_model_with_inheritance
    tagging = tags(:misc).create_tagging(taggable: posts(:thinking))
    assert_equal "Post", tagging.taggable_type
  end

  def test_set_polymorphic_has_many
    tagging = tags(:misc).taggings.create
    posts(:thinking).taggings << tagging
    assert_equal "Post", tagging.taggable_type
  end

  def test_set_polymorphic_has_one
    tagging = tags(:misc).taggings.create
    posts(:thinking).tagging = tagging

    assert_equal "Post",              tagging.taggable_type
    assert_equal posts(:thinking).id, tagging.taggable_id
    assert_equal posts(:thinking),    tagging.taggable
  end

  def test_set_polymorphic_has_one_on_new_record
    tagging = tags(:misc).taggings.create
    post = Post.new title: "foo", body: "bar"
    post.tagging = tagging
    post.save!

    assert_equal "Post",  tagging.taggable_type
    assert_equal post.id, tagging.taggable_id
    assert_equal post,    tagging.taggable
  end

  def test_create_polymorphic_has_many_with_scope
    old_count = posts(:welcome).taggings.count
    tagging = posts(:welcome).taggings.create(tag: tags(:misc))
    assert_equal "Post", tagging.taggable_type
    assert_equal old_count+1, posts(:welcome).taggings.count
  end

  def test_create_bang_polymorphic_with_has_many_scope
    old_count = posts(:welcome).taggings.count
    tagging = posts(:welcome).taggings.create!(tag: tags(:misc))
    assert_equal "Post", tagging.taggable_type
    assert_equal old_count+1, posts(:welcome).taggings.count
  end

  def test_create_polymorphic_has_one_with_scope
    old_count = Tagging.count
    tagging = posts(:welcome).create_tagging(tag: tags(:misc))
    assert_equal "Post", tagging.taggable_type
    assert_equal old_count+1, Tagging.count
  end

  def test_delete_polymorphic_has_many_with_delete_all
    assert_equal 1, posts(:welcome).taggings.count
    posts(:welcome).taggings.first.update_columns taggable_type: "PostWithHasManyDeleteAll"
    post = find_post_with_dependency(1, :has_many, :taggings, :delete_all)

    old_count = Tagging.count
    post.destroy
    assert_equal old_count-1, Tagging.count
    assert_equal 0, posts(:welcome).taggings.count
  end

  def test_delete_polymorphic_has_many_with_destroy
    assert_equal 1, posts(:welcome).taggings.count
    posts(:welcome).taggings.first.update_columns taggable_type: "PostWithHasManyDestroy"
    post = find_post_with_dependency(1, :has_many, :taggings, :destroy)

    old_count = Tagging.count
    post.destroy
    assert_equal old_count-1, Tagging.count
    assert_equal 0, posts(:welcome).taggings.count
  end

  def test_delete_polymorphic_has_many_with_nullify
    assert_equal 1, posts(:welcome).taggings.count
    posts(:welcome).taggings.first.update_columns taggable_type: "PostWithHasManyNullify"
    post = find_post_with_dependency(1, :has_many, :taggings, :nullify)

    old_count = Tagging.count
    post.destroy
    assert_equal old_count, Tagging.count
    assert_equal 0, posts(:welcome).taggings.count
  end

  def test_delete_polymorphic_has_one_with_destroy
    assert posts(:welcome).tagging
    posts(:welcome).tagging.update_columns taggable_type: "PostWithHasOneDestroy"
    post = find_post_with_dependency(1, :has_one, :tagging, :destroy)

    old_count = Tagging.count
    post.destroy
    assert_equal old_count-1, Tagging.count
    posts(:welcome).association(:tagging).reload
    assert_nil posts(:welcome).tagging
  end

  def test_delete_polymorphic_has_one_with_nullify
    assert posts(:welcome).tagging
    posts(:welcome).tagging.update_columns taggable_type: "PostWithHasOneNullify"
    post = find_post_with_dependency(1, :has_one, :tagging, :nullify)

    old_count = Tagging.count
    post.destroy
    assert_equal old_count, Tagging.count
    posts(:welcome).association(:tagging).reload
    assert_nil posts(:welcome).tagging
  end

  def test_has_many_with_piggyback
    assert_equal "2", categories(:sti_test).authors_with_select.first.post_id.to_s
  end

  def test_create_through_has_many_with_piggyback
    category = categories(:sti_test)
    ernie = category.authors_with_select.create(name: "Ernie")
    assert_nothing_raised do
      assert_equal ernie, category.authors_with_select.detect { |a| a.name == "Ernie" }
    end
  end

  def test_include_has_many_through
    posts              = Post.all.merge!(order: "posts.id").to_a
    posts_with_authors = Post.all.merge!(includes: :authors, order: "posts.id").to_a
    assert_equal posts.length, posts_with_authors.length
    posts.length.times do |i|
      assert_equal posts[i].authors.length, assert_no_queries { posts_with_authors[i].authors.length }
    end
  end

  def test_include_polymorphic_has_one
    post    = Post.includes(:tagging).find posts(:welcome).id
    tagging = taggings(:welcome_general)
    assert_no_queries do
      assert_equal tagging, post.tagging
    end
  end

  def test_include_polymorphic_has_one_defined_in_abstract_parent
    item    = Item.includes(:tagging).find items(:dvd).id
    tagging = taggings(:godfather)
    assert_no_queries do
      assert_equal tagging, item.tagging
    end
  end

  def test_include_polymorphic_has_many_through
    posts           = Post.all.merge!(order: "posts.id").to_a
    posts_with_tags = Post.all.merge!(includes: :tags, order: "posts.id").to_a
    assert_equal posts.length, posts_with_tags.length
    posts.length.times do |i|
      assert_equal posts[i].tags.length, assert_no_queries { posts_with_tags[i].tags.length }
    end
  end

  def test_include_polymorphic_has_many
    posts               = Post.all.merge!(order: "posts.id").to_a
    posts_with_taggings = Post.all.merge!(includes: :taggings, order: "posts.id").to_a
    assert_equal posts.length, posts_with_taggings.length
    posts.length.times do |i|
      assert_equal posts[i].taggings.length, assert_no_queries { posts_with_taggings[i].taggings.length }
    end
  end

  def test_has_many_find_all
    assert_equal [categories(:general)], authors(:david).categories.to_a
  end

  def test_has_many_find_first
    assert_equal categories(:general), authors(:david).categories.first
  end

  def test_has_many_with_hash_conditions
    assert_equal categories(:general), authors(:david).categories_like_general.first
  end

  def test_has_many_find_conditions
    assert_equal categories(:general), authors(:david).categories.where("categories.name = 'General'").first
    assert_nil authors(:david).categories.where("categories.name = 'Technology'").first
  end

  def test_has_many_array_methods_called_by_method_missing
    assert authors(:david).categories.any? { |category| category.name == "General" }
    assert_nothing_raised { authors(:david).categories.sort }
  end

  def test_has_many_going_through_join_model_with_custom_foreign_key
    assert_equal [authors(:bob)], posts(:thinking).authors
    assert_equal [authors(:mary)], posts(:authorless).authors
  end

  def test_has_many_going_through_join_model_with_custom_primary_key
    assert_equal [authors(:david)], posts(:thinking).authors_using_author_id
  end

  def test_has_many_going_through_polymorphic_join_model_with_custom_primary_key
    assert_equal [tags(:general)], posts(:eager_other).tags_using_author_id
  end

  def test_has_many_through_with_custom_primary_key_on_belongs_to_source
    assert_equal [authors(:david), authors(:david)], posts(:thinking).author_using_custom_pk
  end

  def test_has_many_through_with_custom_primary_key_on_has_many_source
    assert_equal [authors(:david), authors(:bob)], posts(:thinking).authors_using_custom_pk.order("authors.id")
  end

  def test_belongs_to_polymorphic_with_counter_cache
    assert_equal 1, posts(:welcome)[:tags_count]
    tagging = posts(:welcome).taggings.create(tag: tags(:general))
    assert_equal 2, posts(:welcome, :reload)[:tags_count]
    tagging.destroy
    assert_equal 1, posts(:welcome, :reload)[:tags_count]
  end

  def test_unavailable_through_reflection
    assert_raise(ActiveRecord::HasManyThroughAssociationNotFoundError) { authors(:david).nothings }
  end

  def test_has_many_through_join_model_with_conditions
    assert_equal [], posts(:welcome).invalid_taggings
    assert_equal [], posts(:welcome).invalid_tags
  end

  def test_has_many_polymorphic
    assert_raise ActiveRecord::HasManyThroughAssociationPolymorphicSourceError do
      tags(:general).taggables
    end

    assert_raise ActiveRecord::HasManyThroughAssociationPolymorphicThroughError do
      taggings(:welcome_general).things
    end

    assert_raise ActiveRecord::EagerLoadPolymorphicError do
      tags(:general).taggings.includes(:taggable).where("bogus_table.column = 1").references(:bogus_table).to_a
    end
  end

  def test_has_many_polymorphic_with_source_type
    # added sort by ID as otherwise Oracle select sometimes returned rows in different order
    assert_equal posts(:welcome, :thinking).sort_by(&:id), tags(:general).tagged_posts.sort_by(&:id)
  end

  def test_has_many_polymorphic_associations_merges_through_scope
    Tag.has_many :null_taggings, -> { none }, class_name: :Tagging
    Tag.has_many :null_tagged_posts, through: :null_taggings, source: "taggable", source_type: "Post"
    assert_equal [], tags(:general).null_tagged_posts
    refute_equal [], tags(:general).tagged_posts
  end

  def test_eager_has_many_polymorphic_with_source_type
    tag_with_include = Tag.all.merge!(includes: :tagged_posts).find(tags(:general).id)
    desired = posts(:welcome, :thinking)
    assert_no_queries do
      # added sort by ID as otherwise test using JRuby was failing as array elements were in different order
      assert_equal desired.sort_by(&:id), tag_with_include.tagged_posts.sort_by(&:id)
    end
    assert_equal 5, tag_with_include.taggings.length
  end

  def test_has_many_through_has_many_find_all
    assert_equal comments(:greetings), authors(:david).comments.order("comments.id").to_a.first
  end

  def test_has_many_through_has_many_find_all_with_custom_class
    assert_equal comments(:greetings), authors(:david).funky_comments.order("comments.id").to_a.first
  end

  def test_has_many_through_has_many_find_first
    assert_equal comments(:greetings), authors(:david).comments.order("comments.id").first
  end

  def test_has_many_through_has_many_find_conditions
    options = { where: "comments.#{QUOTED_TYPE}='SpecialComment'", order: "comments.id" }
    assert_equal comments(:does_it_hurt), authors(:david).comments.merge(options).first
  end

  def test_has_many_through_has_many_find_by_id
    assert_equal comments(:more_greetings), authors(:david).comments.find(2)
  end

  def test_has_many_through_polymorphic_has_one
    assert_equal Tagging.find(1,2).sort_by(&:id), authors(:david).taggings_2
  end

  def test_has_many_through_polymorphic_has_many
    assert_equal taggings(:welcome_general, :thinking_general), authors(:david).taggings.distinct.sort_by(&:id)
  end

  def test_include_has_many_through_polymorphic_has_many
    author            = Author.includes(:taggings).find authors(:david).id
    expected_taggings = taggings(:welcome_general, :thinking_general)
    assert_no_queries do
      assert_equal expected_taggings, author.taggings.distinct.sort_by(&:id)
    end
  end

  def test_eager_load_has_many_through_has_many
    author = Author.all.merge!(where: ["name = ?", "David"], includes: :comments, order: "comments.id").first
    SpecialComment.new; VerySpecialComment.new
    assert_no_queries do
      assert_equal [1,2,3,5,6,7,8,9,10,12], author.comments.collect(&:id)
    end
  end

  def test_eager_load_has_many_through_has_many_with_conditions
    post = Post.all.merge!(includes: :invalid_tags).first
    assert_no_queries do
      post.invalid_tags
    end
  end

  def test_eager_belongs_to_and_has_one_not_singularized
    assert_nothing_raised do
      Author.all.merge!(includes: :author_address).first
      AuthorAddress.all.merge!(includes: :author).first
    end
  end

  def test_self_referential_has_many_through
    assert_equal [authors(:mary)], authors(:david).favorite_authors
    assert_equal [],               authors(:mary).favorite_authors
  end

  def test_add_to_self_referential_has_many_through
    new_author = Author.create(name: "Bob")
    authors(:david).author_favorites.create favorite_author: new_author
    assert_equal new_author, authors(:david).reload.favorite_authors.first
  end

  def test_has_many_through_uses_conditions_specified_on_the_has_many_association
    author = Author.first
    assert author.comments.present?
    assert author.nonexistent_comments.blank?
  end

  def test_has_many_through_uses_correct_attributes
    assert_nil posts(:thinking).tags.find_by_name("General").attributes["tag_id"]
  end

  def test_associating_unsaved_records_with_has_many_through
    saved_post = posts(:thinking)
    new_tag = Tag.new(name: "new")

    saved_post.tags << new_tag
    assert new_tag.persisted? #consistent with habtm!
    assert saved_post.persisted?
    assert_includes saved_post.tags, new_tag

    assert new_tag.persisted?
    assert_includes saved_post.reload.tags.reload, new_tag

    new_post = Post.new(title: "Association replacement works!", body: "You best believe it.")
    saved_tag = tags(:general)

    new_post.tags << saved_tag
    assert !new_post.persisted?
    assert saved_tag.persisted?
    assert_includes new_post.tags, saved_tag

    new_post.save!
    assert new_post.persisted?
    assert_includes new_post.reload.tags.reload, saved_tag

    assert !posts(:thinking).tags.build.persisted?
    assert !posts(:thinking).tags.new.persisted?
  end

  def test_create_associate_when_adding_to_has_many_through
    count = posts(:thinking).tags.count
    push = Tag.create!(name: "pushme")
    post_thinking = posts(:thinking)
    assert_nothing_raised { post_thinking.tags << push }
    assert_nil( wrong = post_thinking.tags.detect { |t| t.class != Tag },
                message = "Expected a Tag in tags collection, got #{wrong.class}.")
    assert_nil( wrong = post_thinking.taggings.detect { |t| t.class != Tagging },
                message = "Expected a Tagging in taggings collection, got #{wrong.class}.")
    assert_equal(count + 1, post_thinking.reload.tags.size)
    assert_equal(count + 1, post_thinking.tags.reload.size)

    assert_kind_of Tag, post_thinking.tags.create!(name: "foo")
    assert_nil( wrong = post_thinking.tags.detect { |t| t.class != Tag },
                message = "Expected a Tag in tags collection, got #{wrong.class}.")
    assert_nil( wrong = post_thinking.taggings.detect { |t| t.class != Tagging },
                message = "Expected a Tagging in taggings collection, got #{wrong.class}.")
    assert_equal(count + 2, post_thinking.reload.tags.size)
    assert_equal(count + 2, post_thinking.tags.reload.size)

    assert_nothing_raised { post_thinking.tags.concat(Tag.create!(name: "abc"), Tag.create!(name: "def")) }
    assert_nil( wrong = post_thinking.tags.detect { |t| t.class != Tag },
                message = "Expected a Tag in tags collection, got #{wrong.class}.")
    assert_nil( wrong = post_thinking.taggings.detect { |t| t.class != Tagging },
                message = "Expected a Tagging in taggings collection, got #{wrong.class}.")
    assert_equal(count + 4, post_thinking.reload.tags.size)
    assert_equal(count + 4, post_thinking.tags.reload.size)

    # Raises if the wrong reflection name is used to set the Edge belongs_to
    assert_nothing_raised { vertices(:vertex_1).sinks << vertices(:vertex_5) }
  end

  def test_add_to_join_table_with_no_id
    assert_nothing_raised { vertices(:vertex_1).sinks << vertices(:vertex_5) }
  end

  def test_has_many_through_collection_size_doesnt_load_target_if_not_loaded
    author = authors(:david)
    assert_equal 10, author.comments.size
    assert !author.comments.loaded?
  end

  def test_has_many_through_collection_size_uses_counter_cache_if_it_exists
    c = categories(:general)
    c.categorizations_count = 100
    assert_equal 100, c.categorizations.size
    assert !c.categorizations.loaded?
  end

  def test_adding_junk_to_has_many_through_should_raise_type_mismatch
    assert_raise(ActiveRecord::AssociationTypeMismatch) { posts(:thinking).tags << "Uhh what now?" }
  end

  def test_adding_to_has_many_through_should_return_self
    tags = posts(:thinking).tags
    assert_equal tags, posts(:thinking).tags.push(tags(:general))
  end

  def test_delete_associate_when_deleting_from_has_many_through_with_nonstandard_id
    count = books(:awdr).references.count
    references_before = books(:awdr).references
    book = Book.create!(name: "Getting Real")
    book_awdr = books(:awdr)
    book_awdr.references << book
    assert_equal(count + 1, book_awdr.references.reload.size)

    assert_nothing_raised { book_awdr.references.delete(book) }
    assert_equal(count, book_awdr.references.size)
    assert_equal(count, book_awdr.references.reload.size)
    assert_equal(references_before.sort, book_awdr.references.sort)
  end

  def test_delete_associate_when_deleting_from_has_many_through
    count = posts(:thinking).tags.count
    tags_before = posts(:thinking).tags.sort
    tag = Tag.create!(name: "doomed")
    post_thinking = posts(:thinking)
    post_thinking.tags << tag
    assert_equal(count + 1, post_thinking.taggings.reload.size)
    assert_equal(count + 1, post_thinking.reload.tags.reload.size)
    assert_not_equal(tags_before, post_thinking.tags.sort)

    assert_nothing_raised { post_thinking.tags.delete(tag) }
    assert_equal(count, post_thinking.tags.size)
    assert_equal(count, post_thinking.tags.reload.size)
    assert_equal(count, post_thinking.taggings.reload.size)
    assert_equal(tags_before, post_thinking.tags.sort)
  end

  def test_delete_associate_when_deleting_from_has_many_through_with_multiple_tags
    count = posts(:thinking).tags.count
    tags_before = posts(:thinking).tags.sort
    doomed = Tag.create!(name: "doomed")
    doomed2 = Tag.create!(name: "doomed2")
    quaked = Tag.create!(name: "quaked")
    post_thinking = posts(:thinking)
    post_thinking.tags << doomed << doomed2
    assert_equal(count + 2, post_thinking.reload.tags.reload.size)

    assert_nothing_raised { post_thinking.tags.delete(doomed, doomed2, quaked) }
    assert_equal(count, post_thinking.tags.size)
    assert_equal(count, post_thinking.tags.reload.size)
    assert_equal(tags_before, post_thinking.tags.sort)
  end

  def test_deleting_junk_from_has_many_through_should_raise_type_mismatch
    assert_raise(ActiveRecord::AssociationTypeMismatch) { posts(:thinking).tags.delete(Object.new) }
  end

  def test_deleting_by_integer_id_from_has_many_through
    post = posts(:thinking)

    assert_difference "post.tags.count", -1 do
      assert_equal 1, post.tags.delete(1).size
    end

    assert_equal 0, post.tags.size
  end

  def test_deleting_by_string_id_from_has_many_through
    post = posts(:thinking)

    assert_difference "post.tags.count", -1 do
      assert_equal 1, post.tags.delete("1").size
    end

    assert_equal 0, post.tags.size
  end

  def test_has_many_through_sum_uses_calculations
    assert_nothing_raised { authors(:david).comments.sum(:post_id) }
  end

  def test_calculations_on_has_many_through_should_disambiguate_fields
    assert_nothing_raised { authors(:david).categories.maximum(:id) }
  end

  def test_calculations_on_has_many_through_should_not_disambiguate_fields_unless_necessary
    assert_nothing_raised { authors(:david).categories.maximum("categories.id") }
  end

  def test_has_many_through_has_many_with_sti
    assert_equal [comments(:does_it_hurt)], authors(:david).special_post_comments
  end

  def test_distinct_has_many_through_should_retain_order
    comment_ids = authors(:david).comments.map(&:id)
    assert_equal comment_ids.sort, authors(:david).ordered_uniq_comments.map(&:id)
    assert_equal comment_ids.sort.reverse, authors(:david).ordered_uniq_comments_desc.map(&:id)
  end

  def test_polymorphic_has_many
    expected = taggings(:welcome_general)
    p = Post.all.merge!(includes: :taggings).find(posts(:welcome).id)
    assert_no_queries { assert_includes p.taggings, expected }
    assert_includes posts(:welcome).taggings, taggings(:welcome_general)
  end

  def test_polymorphic_has_one
    expected = posts(:welcome)

    tagging  = Tagging.all.merge!(includes: :taggable).find(taggings(:welcome_general).id)
    assert_no_queries { assert_equal expected, tagging.taggable }
  end

  def test_polymorphic_belongs_to
    p = Post.all.merge!(includes: { taggings: :taggable }).find(posts(:welcome).id)
    assert_no_queries { assert_equal posts(:welcome), p.taggings.first.taggable }
  end

  def test_preload_polymorphic_has_many_through
    posts           = Post.all.merge!(order: "posts.id").to_a
    posts_with_tags = Post.all.merge!(includes: :tags, order: "posts.id").to_a
    assert_equal posts.length, posts_with_tags.length
    posts.length.times do |i|
      assert_equal posts[i].tags.length, assert_no_queries { posts_with_tags[i].tags.length }
    end
  end

  def test_preload_polymorph_many_types
    taggings = Tagging.all.merge!(includes: :taggable, where: ["taggable_type != ?", "FakeModel"]).to_a
    assert_no_queries do
      taggings.first.taggable.id
      taggings[1].taggable.id
    end

    taggables = taggings.map(&:taggable)
    assert_includes taggables, items(:dvd)
    assert_includes taggables, posts(:welcome)
  end

  def test_preload_nil_polymorphic_belongs_to
    assert_nothing_raised do
      Tagging.all.merge!(includes: :taggable, where: ["taggable_type IS NULL"]).to_a
    end
  end

  def test_preload_polymorphic_has_many
    posts               = Post.all.merge!(order: "posts.id").to_a
    posts_with_taggings = Post.all.merge!(includes: :taggings, order: "posts.id").to_a
    assert_equal posts.length, posts_with_taggings.length
    posts.length.times do |i|
      assert_equal posts[i].taggings.length, assert_no_queries { posts_with_taggings[i].taggings.length }
    end
  end

  def test_belongs_to_shared_parent
    comments = Comment.all.merge!(includes: :post, where: "post_id = 1").to_a
    assert_no_queries do
      assert_equal comments.first.post, comments[1].post
    end
  end

  def test_has_many_through_include_uses_array_include_after_loaded
    david = authors(:david)
    david.categories.load_target

    category = david.categories.first

    assert_no_queries do
      assert david.categories.loaded?
      assert_includes david.categories, category
    end
  end

  def test_has_many_through_include_checks_if_record_exists_if_target_not_loaded
    david = authors(:david)
    category = david.categories.first

    david.reload
    assert ! david.categories.loaded?
    assert_queries(1) do
      assert_includes david.categories, category
    end
    assert ! david.categories.loaded?
  end

  def test_has_many_through_include_returns_false_for_non_matching_record_to_verify_scoping
    david = authors(:david)
    category = Category.create!(name: "Not Associated")

    assert ! david.categories.loaded?
    assert ! david.categories.include?(category)
  end

  def test_has_many_through_goes_through_all_sti_classes
    sub_sti_post = SubStiPost.create!(title: "test", body: "test", author_id: 1)
    new_comment = sub_sti_post.comments.create(body: "test")

    assert_equal [9, 10, new_comment.id], authors(:david).sti_post_comments.map(&:id).sort
  end

  def test_has_many_with_pluralize_table_names_false
    aircraft = Aircraft.create!(name: "Airbus 380")
    engine = Engine.create!(car_id: aircraft.id)
    assert_equal aircraft.engines, [engine]
  end

  def test_proper_error_message_for_eager_load_and_includes_association_errors
    includes_error = assert_raises(ActiveRecord::ConfigurationError) {
      Post.includes(:nonexistent_relation).where(nonexistent_relation: { name: "Rochester" }).find(1)
    }
    assert_equal("Can't join 'Post' to association named 'nonexistent_relation'; perhaps you misspelled it?", includes_error.message)

    eager_load_error = assert_raises(ActiveRecord::ConfigurationError) {
      Post.eager_load(:nonexistent_relation).where(nonexistent_relation: { name: "Rochester" }).find(1)
    }
    assert_equal("Can't join 'Post' to association named 'nonexistent_relation'; perhaps you misspelled it?", eager_load_error.message)

    includes_and_eager_load_error = assert_raises(ActiveRecord::ConfigurationError) {
      Post.eager_load(:nonexistent_relation).includes(:nonexistent_relation).where(nonexistent_relation: { name: "Rochester" }).find(1)
    }
    assert_equal("Can't join 'Post' to association named 'nonexistent_relation'; perhaps you misspelled it?", includes_and_eager_load_error.message)
  end

  private
    # create dynamic Post models to allow different dependency options
    def find_post_with_dependency(post_id, association, association_name, dependency)
      class_name = "PostWith#{association.to_s.classify}#{dependency.to_s.classify}"
      Post.find(post_id).update_columns type: class_name
      klass = Object.const_set(class_name, Class.new(ActiveRecord::Base))
      klass.table_name = "posts"
      klass.send(association, association_name, as: :taggable, dependent: dependency)
      klass.find(post_id)
    end
end
