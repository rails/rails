# frozen_string_literal: true

require "cases/helper"
require "models/author"
require "models/post"
require "models/person"
require "models/reference"
require "models/job"
require "models/reader"
require "models/comment"
require "models/tag"
require "models/tagging"
require "models/subscriber"
require "models/book"
require "models/subscription"
require "models/rating"
require "models/member"
require "models/member_detail"
require "models/member_type"
require "models/sponsor"
require "models/club"
require "models/organization"
require "models/category"
require "models/categorization"
require "models/membership"
require "models/essay"
require "models/hotel"
require "models/department"
require "models/chef"
require "models/cake_designer"
require "models/drink_designer"

class NestedThroughAssociationsTest < ActiveRecord::TestCase
  fixtures :authors, :author_addresses, :books, :posts, :subscriptions, :subscribers, :tags, :taggings,
           :people, :readers, :references, :jobs, :ratings, :comments, :members, :member_details,
           :member_types, :sponsors, :clubs, :organizations, :categories, :categories_posts,
           :categorizations, :memberships, :essays

  # Through associations can either use the has_many or has_one macros.
  #
  # has_many
  #   - Source reflection can be has_many, has_one, belongs_to or has_and_belongs_to_many
  #   - Through reflection can be has_many, has_one, belongs_to or has_and_belongs_to_many
  #
  # has_one
  #   - Source reflection can be has_one or belongs_to
  #   - Through reflection can be has_one or belongs_to
  #
  # Additionally, the source reflection and/or through reflection may be subject to
  # polymorphism and/or STI.
  #
  # When testing these, we need to make sure it works via loading the association directly, or
  # joining the association, or including the association. We also need to ensure that associations
  # are readonly where relevant.

  # has_many through
  # Source: has_many through
  # Through: has_many
  def test_has_many_through_has_many_with_has_many_through_source_reflection
    general = tags(:general)
    assert_equal [general, general], authors(:david).tags
  end

  def test_has_many_through_has_many_with_has_many_through_source_reflection_preload
    author = assert_queries(5) { Author.includes(:tags).first }
    general = tags(:general)

    assert_no_queries do
      assert_equal [general, general], author.tags
    end
  end

  def test_has_many_through_has_many_with_has_many_through_source_reflection_preload_via_joins
    assert_includes_and_joins_equal(
      Author.where("tags.id" => tags(:general).id),
      [authors(:david)], :tags
    )

    # This ensures that the polymorphism of taggings is being observed correctly
    authors = Author.joins(:tags).where("taggings.taggable_type" => "FakeModel")
    assert_empty authors
  end

  # has_many through
  # Source: has_many
  # Through: has_many through
  def test_has_many_through_has_many_through_with_has_many_source_reflection
    luke, david = subscribers(:first), subscribers(:second)
    assert_equal [luke, david, david], authors(:david).subscribers.order("subscribers.nick")
  end

  def test_has_many_through_has_many_through_with_has_many_source_reflection_preload
    luke, david = subscribers(:first), subscribers(:second)
    author = assert_queries(4) { Author.includes(:subscribers).first }
    assert_no_queries do
      assert_equal [luke, david, david], author.subscribers.sort_by(&:nick)
    end
  end

  def test_has_many_through_has_many_through_with_has_many_source_reflection_preload_via_joins
    # All authors with subscribers where one of the subscribers' nick is 'alterself'
    assert_includes_and_joins_equal(
      Author.where("subscribers.nick" => "alterself"),
      [authors(:david)], :subscribers
    )
  end

  # has_many through
  # Source: has_one through
  # Through: has_one
  def test_has_many_through_has_one_with_has_one_through_source_reflection
    assert_equal [member_types(:founding)], members(:groucho).nested_member_types
  end

  def test_has_many_through_has_one_with_has_one_through_source_reflection_preload
    member = assert_queries(4) { Member.includes(:nested_member_types).first }
    founding = member_types(:founding)
    assert_no_queries do
      assert_equal [founding], member.nested_member_types
    end
  end

  def test_has_many_through_has_one_with_has_one_through_source_reflection_preload_via_joins
    assert_includes_and_joins_equal(
      Member.where("member_types.id" => member_types(:founding).id),
      [members(:groucho)], :nested_member_types
    )
  end

  # has_many through
  # Source: has_one
  # Through: has_one through
  def test_has_many_through_has_one_through_with_has_one_source_reflection
    assert_equal [sponsors(:moustache_club_sponsor_for_groucho)], members(:groucho).nested_sponsors
  end

  def test_has_many_through_has_one_through_with_has_one_source_reflection_preload
    member = assert_queries(4) { Member.includes(:nested_sponsors).first }
    mustache = sponsors(:moustache_club_sponsor_for_groucho)
    assert_no_queries do
      assert_equal [mustache], member.nested_sponsors
    end
  end

  def test_has_many_through_has_one_through_with_has_one_source_reflection_preload_via_joins
    assert_includes_and_joins_equal(
      Member.where("sponsors.id" => sponsors(:moustache_club_sponsor_for_groucho).id),
      [members(:groucho)], :nested_sponsors
    )
  end

  # has_many through
  # Source: has_many through
  # Through: has_one
  def test_has_many_through_has_one_with_has_many_through_source_reflection
    groucho_details, other_details = member_details(:groucho), member_details(:some_other_guy)

    assert_equal [groucho_details, other_details],
                 members(:groucho).organization_member_details.order("member_details.id")
  end

  def test_has_many_through_has_one_with_has_many_through_source_reflection_preload
    ActiveRecord::Base.connection.table_alias_length  # preheat cache
    member = assert_queries(4) { Member.includes(:organization_member_details).first }
    groucho_details, other_details = member_details(:groucho), member_details(:some_other_guy)

    assert_no_queries do
      assert_equal [groucho_details, other_details], member.organization_member_details.sort_by(&:id)
    end
  end

  def test_has_many_through_has_one_with_has_many_through_source_reflection_preload_via_joins
    assert_includes_and_joins_equal(
      Member.where("member_details.id" => member_details(:groucho).id).order("member_details.id"),
      [members(:groucho), members(:some_other_guy)], :organization_member_details
    )

    members = Member.joins(:organization_member_details).where("member_details.id" => 9)
    assert_empty members
  end

  # has_many through
  # Source: has_many
  # Through: has_one through
  def test_has_many_through_has_one_through_with_has_many_source_reflection
    groucho_details, other_details = member_details(:groucho), member_details(:some_other_guy)

    assert_equal [groucho_details, other_details],
                 members(:groucho).organization_member_details_2.order("member_details.id")
  end

  def test_has_many_through_has_one_through_with_has_many_source_reflection_preload
    member = assert_queries(4) { Member.includes(:organization_member_details_2).first }
    groucho_details, other_details = member_details(:groucho), member_details(:some_other_guy)

    # postgresql test if randomly executed then executes "SHOW max_identifier_length". Hence
    # the need to ignore certain predefined sqls that deal with system calls.
    assert_no_queries do
      assert_equal [groucho_details, other_details], member.organization_member_details_2.sort_by(&:id)
    end
  end

  def test_has_many_through_has_one_through_with_has_many_source_reflection_preload_via_joins
    assert_includes_and_joins_equal(
      Member.where("member_details.id" => member_details(:groucho).id).order("member_details.id"),
      [members(:groucho), members(:some_other_guy)], :organization_member_details_2
    )

    members = Member.joins(:organization_member_details_2).where("member_details.id" => 9)
    assert_empty members
  end

  # has_many through
  # Source: has_and_belongs_to_many
  # Through: has_many
  def test_has_many_through_has_many_with_has_and_belongs_to_many_source_reflection
    general, cooking = categories(:general), categories(:cooking)

    assert_equal [general, cooking], authors(:bob).post_categories.order("categories.id")
  end

  def test_has_many_through_has_many_with_has_and_belongs_to_many_source_reflection_preload
    author = assert_queries(4) { Author.includes(:post_categories).third }
    general, cooking = categories(:general), categories(:cooking)

    assert_no_queries do
      assert_equal [general, cooking], author.post_categories.sort_by(&:id)
    end
  end

  def test_has_many_through_has_many_with_has_and_belongs_to_many_source_reflection_preload_via_joins
    # preload table schemas
    Author.joins(:post_categories).first

    assert_includes_and_joins_equal(
      Author.where("categories.id" => categories(:cooking).id),
      [authors(:bob)], :post_categories
    )
  end

  # has_many through
  # Source: has_many
  # Through: has_and_belongs_to_many
  def test_has_many_through_has_and_belongs_to_many_with_has_many_source_reflection
    greetings, more = comments(:greetings), comments(:more_greetings)

    assert_equal [greetings, more], categories(:technology).post_comments.order("comments.id")
  end

  def test_has_many_through_has_and_belongs_to_many_with_has_many_source_reflection_preload
    Category.includes(:post_comments).to_a # preheat cache
    category = assert_queries(4) { Category.includes(:post_comments).second }
    greetings, more = comments(:greetings), comments(:more_greetings)

    assert_no_queries do
      assert_equal [greetings, more], category.post_comments.sort_by(&:id)
    end
  end

  def test_has_many_through_has_and_belongs_to_many_with_has_many_source_reflection_preload_via_joins
    # preload table schemas
    Category.joins(:post_comments).first

    assert_includes_and_joins_equal(
      Category.where("comments.id" => comments(:more_greetings).id).order("categories.id"),
      [categories(:general), categories(:technology)], :post_comments
    )
  end

  # has_many through
  # Source: has_many through a habtm
  # Through: has_many through
  def test_has_many_through_has_many_with_has_many_through_habtm_source_reflection
    greetings, more = comments(:greetings), comments(:more_greetings)

    assert_equal [greetings, more], authors(:bob).category_post_comments.order("comments.id")
  end

  def test_has_many_through_has_many_with_has_many_through_habtm_source_reflection_preload
    author = assert_queries(6) { Author.includes(:category_post_comments).third }
    greetings, more = comments(:greetings), comments(:more_greetings)

    assert_no_queries do
      assert_equal [greetings, more], author.category_post_comments.sort_by(&:id)
    end
  end

  def test_has_many_through_has_many_with_has_many_through_habtm_source_reflection_preload_via_joins
    # preload table schemas
    Author.joins(:category_post_comments).first

    assert_includes_and_joins_equal(
      Author.where("comments.id" => comments(:does_it_hurt).id).order("authors.id"),
      [authors(:david), authors(:mary)], :category_post_comments
    )
  end

  # has_many through
  # Source: belongs_to
  # Through: has_many through
  def test_has_many_through_has_many_through_with_belongs_to_source_reflection
    assert_equal [tags(:general), tags(:general)], authors(:david).tagging_tags
  end

  def test_has_many_through_has_many_through_with_belongs_to_source_reflection_preload
    author = assert_queries(5) { Author.includes(:tagging_tags).first }
    general = tags(:general)

    assert_no_queries do
      assert_equal [general, general], author.tagging_tags
    end
  end

  def test_has_many_through_has_many_through_with_belongs_to_source_reflection_preload_via_joins
    assert_includes_and_joins_equal(
      Author.where("tags.id" => tags(:general).id),
      [authors(:david)], :tagging_tags
    )
  end

  # has_many through
  # Source: has_many through
  # Through: belongs_to
  def test_has_many_through_belongs_to_with_has_many_through_source_reflection
    welcome_general, thinking_general = taggings(:welcome_general), taggings(:thinking_general)

    assert_equal [welcome_general, thinking_general],
                 categorizations(:david_welcome_general).post_taggings.order("taggings.id")
  end

  def test_has_many_through_belongs_to_with_has_many_through_source_reflection_preload
    categorization = assert_queries(4) { Categorization.includes(:post_taggings).first }
    welcome_general, thinking_general = taggings(:welcome_general), taggings(:thinking_general)

    assert_no_queries do
      assert_equal [welcome_general, thinking_general], categorization.post_taggings.sort_by(&:id)
    end
  end

  def test_has_many_through_belongs_to_with_has_many_through_source_reflection_preload_via_joins
    assert_includes_and_joins_equal(
      Categorization.where("taggings.id" => taggings(:welcome_general).id).order("taggings.id"),
      [categorizations(:david_welcome_general)], :post_taggings
    )
  end

  # has_one through
  # Source: has_one through
  # Through: has_one
  def test_has_one_through_has_one_with_has_one_through_source_reflection
    assert_equal member_types(:founding), members(:groucho).nested_member_type
  end

  def test_has_one_through_has_one_with_has_one_through_source_reflection_preload
    member = assert_queries(4) { Member.includes(:nested_member_type).first }
    founding = member_types(:founding)

    assert_no_queries do
      assert_equal founding, member.nested_member_type
    end
  end

  def test_has_one_through_has_one_with_has_one_through_source_reflection_preload_via_joins
    assert_includes_and_joins_equal(
      Member.where("member_types.id" => member_types(:founding).id),
      [members(:groucho)], :nested_member_type
    )
  end

  # has_one through
  # Source: belongs_to
  # Through: has_one through
  def test_has_one_through_has_one_through_with_belongs_to_source_reflection
    assert_equal categories(:general), members(:groucho).club_category
  end

  def test_joins_and_includes_from_through_models_not_included_in_association
    prev_default_scope = Club.default_scopes

    [:includes, :preload, :joins, :eager_load].each do |q|
      Club.default_scopes = [proc { Club.send(q, :category) }]
      assert_equal categories(:general), members(:groucho).reload.club_category
    end
  ensure
    Club.default_scopes = prev_default_scope
  end

  def test_has_one_through_has_one_through_with_belongs_to_source_reflection_preload
    member = assert_queries(4) { Member.includes(:club_category).first }
    general = categories(:general)

    assert_no_queries do
      assert_equal general, member.club_category
    end
  end

  def test_has_one_through_has_one_through_with_belongs_to_source_reflection_preload_via_joins
    assert_includes_and_joins_equal(
      Member.where("categories.id" => categories(:technology).id),
      [members(:blarpy_winkup)], :club_category
    )
  end

  def test_distinct_has_many_through_a_has_many_through_association_on_source_reflection
    author = authors(:david)
    assert_equal [tags(:general)], author.distinct_tags
  end

  def test_distinct_has_many_through_a_has_many_through_association_on_through_reflection
    author = authors(:david)
    assert_equal [subscribers(:first), subscribers(:second)],
                 author.distinct_subscribers.order("subscribers.nick")
  end

  def test_nested_has_many_through_with_a_table_referenced_multiple_times
    author = authors(:bob)
    assert_equal [posts(:misc_by_bob), posts(:misc_by_mary), posts(:other_by_bob), posts(:other_by_mary)],
                 author.similar_posts.sort_by(&:id)

    # Mary and Bob both have posts in misc, but they are the only ones.
    authors = Author.joins(:similar_posts).where("posts.id" => posts(:misc_by_bob).id)
    assert_equal [authors(:mary), authors(:bob)], authors.distinct.sort_by(&:id)

    # Check the polymorphism of taggings is being observed correctly (in both joins)
    authors = Author.joins(:similar_posts).where("taggings.taggable_type" => "FakeModel")
    assert_empty authors
    authors = Author.joins(:similar_posts).where("taggings_authors_join.taggable_type" => "FakeModel")
    assert_empty authors
  end

  def test_nested_has_many_through_with_scope_on_polymorphic_reflection
    authors = Author.joins(:ordered_posts).where("posts.id" => posts(:misc_by_bob).id)
    assert_equal [authors(:mary), authors(:bob)], authors.distinct.sort_by(&:id)
  end

  def test_has_many_through_with_foreign_key_option_on_through_reflection
    assert_equal [posts(:welcome), posts(:authorless)], people(:david).agents_posts.order("posts.id")
    assert_equal [authors(:david)], references(:david_unicyclist).agents_posts_authors

    references = Reference.joins(:agents_posts_authors).where("authors.id" => authors(:david).id)
    assert_equal [references(:david_unicyclist)], references
  end

  def test_has_many_through_with_foreign_key_option_on_source_reflection
    assert_equal [people(:michael), people(:susan)], jobs(:unicyclist).agents.order("people.id")

    jobs = Job.joins(:agents)
    assert_equal [jobs(:unicyclist), jobs(:unicyclist)], jobs
  end

  def test_has_many_through_with_sti_on_through_reflection
    ratings = posts(:sti_comments).special_comments_ratings.sort_by(&:id)
    assert_equal [ratings(:special_comment_rating), ratings(:sub_special_comment_rating)], ratings

    # Ensure STI is respected in the join
    scope = Post.joins(:special_comments_ratings).where(id: posts(:sti_comments).id)
    assert_empty scope.where("comments.type" => "Comment")
    assert_not_empty scope.where("comments.type" => "SpecialComment")
    assert_not_empty scope.where("comments.type" => "SubSpecialComment")
  end

  def test_has_many_through_with_sti_on_nested_through_reflection
    taggings = posts(:sti_comments).special_comments_ratings_taggings
    assert_equal [taggings(:special_comment_rating)], taggings

    scope = Post.joins(:special_comments_ratings_taggings).where(id: posts(:sti_comments).id)
    assert_empty scope.where("comments.type" => "Comment")
    assert_not_empty scope.where("comments.type" => "SpecialComment")
  end

  def test_nested_has_many_through_writers_should_raise_error
    david = authors(:david)
    subscriber = subscribers(:first)

    assert_raises(ActiveRecord::HasManyThroughNestedAssociationsAreReadonly) do
      david.subscribers = [subscriber]
    end

    assert_raises(ActiveRecord::HasManyThroughNestedAssociationsAreReadonly) do
      david.subscriber_ids = [subscriber.id]
    end

    assert_raises(ActiveRecord::HasManyThroughNestedAssociationsAreReadonly) do
      david.subscribers << subscriber
    end

    assert_raises(ActiveRecord::HasManyThroughNestedAssociationsAreReadonly) do
      david.subscribers.delete(subscriber)
    end

    assert_raises(ActiveRecord::HasManyThroughNestedAssociationsAreReadonly) do
      david.subscribers.clear
    end

    assert_raises(ActiveRecord::HasManyThroughNestedAssociationsAreReadonly) do
      david.subscribers.build
    end

    assert_raises(ActiveRecord::HasManyThroughNestedAssociationsAreReadonly) do
      david.subscribers.create
    end
  end

  def test_nested_has_one_through_writers_should_raise_error
    groucho = members(:groucho)
    founding = member_types(:founding)

    assert_raises(ActiveRecord::HasOneThroughNestedAssociationsAreReadonly) do
      groucho.nested_member_type = founding
    end
  end

  def test_nested_has_many_through_with_conditions_on_through_associations
    assert_equal [tags(:blue)], authors(:bob).misc_post_first_blue_tags
  end

  def test_nested_has_many_through_with_conditions_on_through_associations_preload
    assert_empty Author.where("tags.id" => 100).joins(:misc_post_first_blue_tags)

    author = assert_queries(2) { Author.includes(:misc_post_first_blue_tags).third }
    blue = tags(:blue)

    assert_no_queries do
      assert_equal [blue], author.misc_post_first_blue_tags
    end
  end

  def test_nested_has_many_through_with_conditions_on_through_associations_preload_via_joins
    # Pointless condition to force single-query loading
    assert_includes_and_joins_equal(
      Author.where("tags.id = tags.id").references(:tags),
      [authors(:bob)], :misc_post_first_blue_tags
    )
  end

  def test_nested_has_many_through_with_conditions_on_source_associations
    assert_equal [tags(:blue)], authors(:bob).misc_post_first_blue_tags_2
  end

  def test_nested_has_many_through_with_conditions_on_source_associations_preload
    author = assert_queries(2) { Author.includes(:misc_post_first_blue_tags_2).third }
    blue = tags(:blue)

    assert_no_queries do
      assert_equal [blue], author.misc_post_first_blue_tags_2
    end
  end

  def test_through_association_preload_doesnt_reset_source_association_if_already_preloaded
    blue = tags(:blue)
    author = Author.preload(posts: :first_blue_tags_2, misc_post_first_blue_tags_2: {}).third

    assert_no_queries do
      assert_equal [blue], author.posts.first.first_blue_tags_2
    end
  end

  def test_nested_has_many_through_with_conditions_on_source_associations_preload_via_joins
    # Pointless condition to force single-query loading
    assert_includes_and_joins_equal(
      Author.where("tags.id = tags.id").references(:tags),
      [authors(:bob)], :misc_post_first_blue_tags_2
    )
  end

  def test_nested_has_many_through_with_foreign_key_option_on_the_source_reflection_through_reflection
    assert_equal [categories(:general)], organizations(:nsa).author_essay_categories

    organizations = Organization.joins(:author_essay_categories).
                                 where("categories.id" => categories(:general).id)
    assert_equal [organizations(:nsa)], organizations

    assert_equal categories(:general), organizations(:nsa).author_owned_essay_category

    organizations = Organization.joins(:author_owned_essay_category).
                                 where("categories.id" => categories(:general).id)
    assert_equal [organizations(:nsa)], organizations
  end

  def test_nested_has_many_through_should_not_be_autosaved
    c = Categorization.new
    c.author = authors(:david)
    c.post_taggings.to_a
    assert_not_empty c.post_taggings
    c.save
    assert_not_empty c.post_taggings
  end

  def test_polymorphic_has_many_through_when_through_association_has_not_loaded
    cake_designer = CakeDesigner.create!(chef: Chef.new)
    drink_designer = DrinkDesigner.create!(chef: Chef.new)
    department = Department.create!(chefs: [cake_designer.chef, drink_designer.chef])
    Hotel.create!(departments: [department])
    hotel = Hotel.includes(:cake_designers, :drink_designers).take

    assert_equal [cake_designer], hotel.cake_designers
    assert_equal [drink_designer], hotel.drink_designers
  end

  def test_polymorphic_has_many_through_when_through_association_has_already_loaded
    cake_designer = CakeDesigner.create!(chef: Chef.new)
    drink_designer = DrinkDesigner.create!(chef: Chef.new)
    department = Department.create!(chefs: [cake_designer.chef, drink_designer.chef])
    Hotel.create!(departments: [department])
    hotel = Hotel.includes(:chefs, :cake_designers, :drink_designers).take

    assert_equal [cake_designer], hotel.cake_designers
    assert_equal [drink_designer], hotel.drink_designers
  end

  def test_polymorphic_has_many_through_joined_different_table_twice
    cake_designer = CakeDesigner.create!(chef: Chef.new)
    drink_designer = DrinkDesigner.create!(chef: Chef.new)
    department = Department.create!(chefs: [cake_designer.chef, drink_designer.chef])
    hotel = Hotel.create!(departments: [department])

    assert_equal hotel, Hotel.joins(:cake_designers, :drink_designers).take
  end

  def test_has_many_through_reset_source_reflection_after_loading_is_complete
    preloaded = Category.preload(:ordered_post_comments).find(1, 2).last
    original = Category.find(2)
    assert_equal original.ordered_post_comments.ids, preloaded.ordered_post_comments.ids
  end

  private
    def assert_includes_and_joins_equal(query, expected, association)
      query = query.order(:id)

      actual = assert_queries(1) { query.joins(association).to_a.uniq }
      assert_equal expected, actual

      actual = assert_queries(1) { query.includes(association).to_a.uniq }
      assert_equal expected, actual
    end
end
