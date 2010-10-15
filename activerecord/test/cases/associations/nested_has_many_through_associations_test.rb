require "cases/helper"
require 'models/author'
require 'models/post'
require 'models/person'
require 'models/reference'
require 'models/job'
require 'models/reader'
require 'models/comment'
require 'models/tag'
require 'models/tagging'
require 'models/subscriber'
require 'models/book'
require 'models/subscription'
require 'models/rating'
require 'models/member'
require 'models/member_detail'
require 'models/member_type'
require 'models/sponsor'
require 'models/club'
require 'models/organization'
require 'models/category'
require 'models/categorization'
require 'models/membership'

# NOTE: Some of these tests might not really test "nested" HMT associations, as opposed to ones which
# are just one level deep. But it's all the same thing really, as the "nested" code is being 
# written in a generic way which applies to "non-nested" HMT associations too. So let's just shove
# all useful tests in here for now and then work out where they ought to live properly later.

class NestedHasManyThroughAssociationsTest < ActiveRecord::TestCase
  fixtures :authors, :books, :posts, :subscriptions, :subscribers, :tags, :taggings,
           :people, :readers, :references, :jobs, :ratings, :comments, :members, :member_details,
           :member_types, :sponsors, :clubs, :organizations, :categories, :categories_posts,
           :categorizations, :memberships

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
    
    assert_includes_and_joins_equal(
      Author.where('tags.id' => tags(:general).id),
      [authors(:david)], :tags
    )
    
    # This ensures that the polymorphism of taggings is being observed correctly
    authors = Author.joins(:tags).where('taggings.taggable_type' => 'FakeModel')
    assert authors.empty?
    
    authors = assert_queries(5) { Author.includes(:tags).to_a }
    assert_no_queries do
      assert_equal [general, general], authors.first.tags
    end
  end

  # has_many through
  # Source: has_many
  # Through: has_many through
  def test_has_many_through_has_many_through_with_has_many_source_reflection
    luke, david = subscribers(:first), subscribers(:second)
    
    author = authors(:david)
    assert_equal [luke, david, david], author.subscribers
    
    # All authors with subscribers where one of the subscribers' nick is 'alterself'
    assert_includes_and_joins_equal(
      Author.where('subscribers.nick' => 'alterself'),
      [authors(:david)], :subscribers
    )
    
    authors = assert_queries(4) { Author.includes(:subscribers).to_a }
    assert_no_queries do
      assert_equal [luke, david, david], authors.first.subscribers.sort_by(&:nick)
    end
    
    # TODO: Add eager loading test using LEFT OUTER JOIN
  end
  
  # has_many through
  # Source: has_one through
  # Through: has_one
  def test_has_many_through_has_one_with_has_one_through_source_reflection
    founding = member_types(:founding)
  
    assert_equal [founding], members(:groucho).nested_member_types
    
    assert_includes_and_joins_equal(
      Member.where('member_types.id' => founding.id),
      [members(:groucho)], :nested_member_types
    )
    
    members = assert_queries(4) { Member.includes(:nested_member_types).to_a }
    assert_no_queries do
      assert_equal [founding], members.first.nested_member_types
    end
  end
  
  # has_many through
  # Source: has_one
  # Through: has_one through
  def test_has_many_through_has_one_through_with_has_one_source_reflection
    mustache = sponsors(:moustache_club_sponsor_for_groucho)
    
    assert_equal [mustache], members(:groucho).nested_sponsors
    
    assert_includes_and_joins_equal(
      Member.where('sponsors.id' => mustache.id),
      [members(:groucho)], :nested_sponsors
    )
    
    members = assert_queries(4) { Member.includes(:nested_sponsors).to_a }
    assert_no_queries do
      assert_equal [mustache], members.first.nested_sponsors
    end
  end
  
  # has_many through
  # Source: has_many through
  # Through: has_one
  def test_has_many_through_has_one_with_has_many_through_source_reflection
    groucho_details, other_details = member_details(:groucho), member_details(:some_other_guy)
  
    assert_equal [groucho_details, other_details], members(:groucho).organization_member_details
    
    assert_includes_and_joins_equal(
      Member.where('member_details.id' => member_details(:groucho).id),
      [members(:groucho), members(:some_other_guy)], :organization_member_details
    )
    
    members = Member.joins(:organization_member_details).
                     where('member_details.id' => 9)
    assert members.empty?
    
    members = assert_queries(4) { Member.includes(:organization_member_details).to_a }
    assert_no_queries do
      assert_equal [groucho_details, other_details], members.first.organization_member_details
    end
  end
  
  # has_many through
  # Source: has_many
  # Through: has_one through
  def test_has_many_through_has_one_through_with_has_many_source_reflection
    groucho_details, other_details = member_details(:groucho), member_details(:some_other_guy)
  
    assert_equal [groucho_details, other_details], members(:groucho).organization_member_details_2
    
    assert_includes_and_joins_equal(
      Member.where('member_details.id' => groucho_details.id),
      [members(:groucho), members(:some_other_guy)], :organization_member_details_2
    )
    
    members = Member.joins(:organization_member_details_2).
                     where('member_details.id' => 9)
    assert members.empty?
    
    members = assert_queries(4) { Member.includes(:organization_member_details_2).to_a }
    assert_no_queries do
      assert_equal [groucho_details, other_details], members.first.organization_member_details_2
    end
  end
  
  # has_many through
  # Source: has_and_belongs_to_many
  # Through: has_many
  def test_has_many_through_has_many_with_has_and_belongs_to_many_source_reflection
    general, cooking = categories(:general), categories(:cooking)
  
    assert_equal [general, cooking], authors(:bob).post_categories
    
    assert_includes_and_joins_equal(
      Author.where('categories.id' => cooking.id),
      [authors(:bob)], :post_categories
    )
    
    authors = assert_queries(3) { Author.includes(:post_categories).to_a }
    assert_no_queries do
      assert_equal [general, cooking], authors[2].post_categories
    end
  end
  
  # has_many through
  # Source: has_many
  # Through: has_and_belongs_to_many
  def test_has_many_through_has_and_belongs_to_many_with_has_many_source_reflection
    greetings, more = comments(:greetings), comments(:more_greetings)
  
    assert_equal [greetings, more], categories(:technology).post_comments
    
    assert_includes_and_joins_equal(
      Category.where('comments.id' => more.id),
      [categories(:general), categories(:technology)], :post_comments
    )
    
    categories = assert_queries(3) { Category.includes(:post_comments).to_a }
    assert_no_queries do
      assert_equal [greetings, more], categories[1].post_comments
    end
  end
  
  # has_many through
  # Source: has_many through a habtm
  # Through: has_many through
  def test_has_many_through_has_many_with_has_many_through_habtm_source_reflection
    greetings, more = comments(:greetings), comments(:more_greetings)
  
    assert_equal [greetings, more], authors(:bob).category_post_comments
    
    assert_includes_and_joins_equal(
      Author.where('comments.id' => comments(:does_it_hurt).id),
      [authors(:david), authors(:mary)], :category_post_comments
    )
    
    authors = assert_queries(5) { Author.includes(:category_post_comments).to_a }
    assert_no_queries do
      assert_equal [greetings, more], authors[2].category_post_comments
    end
  end
  
  # has_many through
  # Source: belongs_to
  # Through: has_many through
  def test_has_many_through_has_many_through_with_belongs_to_source_reflection
    general = tags(:general)
    
    assert_equal [general, general], authors(:david).tagging_tags
    
    assert_includes_and_joins_equal(
      Author.where('tags.id' => tags(:general).id),
      [authors(:david)], :tagging_tags
    )
    
    authors = assert_queries(5) { Author.includes(:tagging_tags).to_a }
    assert_no_queries do
      assert_equal [general, general], authors.first.tagging_tags
    end
  end
  
  # has_many through
  # Source: has_many through
  # Through: belongs_to
  def test_has_many_through_belongs_to_with_has_many_through_source_reflection
    welcome_general, thinking_general = taggings(:welcome_general), taggings(:thinking_general)
  
    assert_equal [welcome_general, thinking_general], categorizations(:david_welcome_general).post_taggings
    
    assert_includes_and_joins_equal(
      Categorization.where('taggings.id' => welcome_general.id),
      [categorizations(:david_welcome_general)], :post_taggings
    )
    
    categorizations = assert_queries(4) { Categorization.includes(:post_taggings).to_a }
    assert_no_queries do
      assert_equal [welcome_general, thinking_general], categorizations.first.post_taggings
    end
  end
  
  # has_one through
  # Source: has_one through
  # Through: has_one
  def test_has_one_through_has_one_with_has_one_through_source_reflection
    founding = member_types(:founding)
  
    assert_equal founding, members(:groucho).nested_member_type
    
    assert_includes_and_joins_equal(
      Member.where('member_types.id' => founding.id),
      [members(:groucho)], :nested_member_type
    )
    
    members = assert_queries(4) { Member.includes(:nested_member_type).to_a }
    assert_no_queries do
      assert_equal founding, members.first.nested_member_type
    end
  end
  
  # has_one through
  # Source: belongs_to
  # Through: has_one through
  def test_has_one_through_has_one_through_with_belongs_to_source_reflection
    general = categories(:general)
  
    assert_equal general, members(:groucho).club_category
    
    assert_includes_and_joins_equal(
      Member.where('categories.id' => categories(:technology).id),
      [members(:blarpy_winkup)], :club_category
    )
    
    members = assert_queries(4) { Member.includes(:club_category).to_a }
    assert_no_queries do
      assert_equal general, members.first.club_category
    end
  end

  def test_distinct_has_many_through_a_has_many_through_association_on_source_reflection
    author = authors(:david)
    assert_equal [tags(:general)], author.distinct_tags
  end

  def test_distinct_has_many_through_a_has_many_through_association_on_through_reflection
    author = authors(:david)
    assert_equal [subscribers(:first), subscribers(:second)], author.distinct_subscribers
  end
  
  def test_nested_has_many_through_with_a_table_referenced_multiple_times
    author = authors(:bob)
    assert_equal [posts(:misc_by_bob), posts(:misc_by_mary)], author.similar_posts.sort_by(&:id)
    
    # Mary and Bob both have posts in misc, but they are the only ones.
    authors = Author.joins(:similar_posts).where('posts.id' => posts(:misc_by_bob).id)
    assert_equal [authors(:mary), authors(:bob)], authors.uniq.sort_by(&:id)
    
    # Check the polymorphism of taggings is being observed correctly (in both joins)
    authors = Author.joins(:similar_posts).where('taggings.taggable_type' => 'FakeModel')
    assert authors.empty?
    authors = Author.joins(:similar_posts).where('taggings_authors_join.taggable_type' => 'FakeModel')
    assert authors.empty?
  end
  
  def test_has_many_through_with_foreign_key_option_on_through_reflection
    assert_equal [posts(:welcome), posts(:authorless)], people(:david).agents_posts
    assert_equal [authors(:david)], references(:david_unicyclist).agents_posts_authors
    
    references = Reference.joins(:agents_posts_authors).where('authors.id' => authors(:david).id)
    assert_equal [references(:david_unicyclist)], references
  end
  
  def test_has_many_through_with_foreign_key_option_on_source_reflection
    assert_equal [people(:michael), people(:susan)], jobs(:unicyclist).agents
    
    jobs = Job.joins(:agents)
    assert_equal [jobs(:unicyclist), jobs(:unicyclist)], jobs
  end

  def test_has_many_through_with_sti_on_through_reflection
    ratings = posts(:sti_comments).special_comments_ratings.sort_by(&:id)
    assert_equal [ratings(:special_comment_rating), ratings(:sub_special_comment_rating)], ratings
    
    # Ensure STI is respected in the join
    scope = Post.joins(:special_comments_ratings).where(:id => posts(:sti_comments).id)
    assert scope.where("comments.type" => "Comment").empty?
    assert !scope.where("comments.type" => "SpecialComment").empty?
    assert !scope.where("comments.type" => "SubSpecialComment").empty?
  end
  
  private
  
    def assert_includes_and_joins_equal(query, expected, association)
      actual = assert_queries(1) { query.joins(association).to_a.uniq }
      assert_equal expected, actual
      
      actual = assert_queries(1) { query.includes(association).to_a.uniq }
      assert_equal expected, actual
    end
end
