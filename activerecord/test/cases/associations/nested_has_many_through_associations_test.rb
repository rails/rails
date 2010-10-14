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
require 'models/owner'
require 'models/pet'
require 'models/toy'
require 'models/contract'
require 'models/company'
require 'models/developer'
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

# NOTE: Some of these tests might not really test "nested" HMT associations, as opposed to ones which
# are just one level deep. But it's all the same thing really, as the "nested" code is being 
# written in a generic way which applies to "non-nested" HMT associations too. So let's just shove
# all useful tests in here for now and then work out where they ought to live properly later.

class NestedHasManyThroughAssociationsTest < ActiveRecord::TestCase
  fixtures :authors, :books, :posts, :subscriptions, :subscribers, :tags, :taggings,
           :people, :readers, :references, :jobs, :ratings, :comments, :members, :member_details,
           :member_types, :sponsors, :clubs, :organizations, :categories, :categories_posts,
           :categorizations

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
    author = authors(:david)
    assert_equal [tags(:general), tags(:general)], author.tags
    
    # Only David has a Post tagged with General
    authors = Author.joins(:tags).where('tags.id' => tags(:general).id)
    assert_equal [authors(:david)], authors.uniq
    
    authors = Author.includes(:tags)
    assert_equal [tags(:general), tags(:general)], authors.first.tags
    
    # This ensures that the polymorphism of taggings is being observed correctly
    authors = Author.joins(:tags).where('taggings.taggable_type' => 'FakeModel')
    assert authors.empty?
  end

  # has_many through
  # Source: has_many
  # Through: has_many through
  def test_has_many_through_has_many_through_with_has_many_source_reflection
    author = authors(:david)
    assert_equal [subscribers(:first), subscribers(:second), subscribers(:second)], author.subscribers
    
    # All authors with subscribers where one of the subscribers' nick is 'alterself'
    authors = Author.joins(:subscribers).where('subscribers.nick' => 'alterself')
    assert_equal [authors(:david)], authors
    
    # TODO: Make this work
    # authors = Author.includes(:subscribers)
    # assert_equal [subscribers(:first), subscribers(:second), subscribers(:second)], authors.first.subscribers
  end
  
  # has_many through
  # Source: has_one through
  # Through: has_one
  def test_has_many_through_has_one_with_has_one_through_source_reflection
    assert_equal [member_types(:founding)], members(:groucho).nested_member_types
    
    members = Member.joins(:nested_member_types).where('member_types.id' => member_types(:founding).id)
    assert_equal [members(:groucho)], members
    
    members = Member.includes(:nested_member_types)
    assert_equal [member_types(:founding)], members.first.nested_member_types
  end
  
  # has_many through
  # Source: has_one
  # Through: has_one through
  def test_has_many_through_has_one_through_with_has_one_source_reflection
    assert_equal [sponsors(:moustache_club_sponsor_for_groucho)], members(:groucho).nested_sponsors
    
    members = Member.joins(:nested_sponsors).where('sponsors.id' => sponsors(:moustache_club_sponsor_for_groucho).id)
    assert_equal [members(:groucho)], members
    
    # TODO: Make this work
    # members = Member.includes(:nested_sponsors)
    # assert_equal [sponsors(:moustache_club_sponsor_for_groucho)], members.first.nested_sponsors
  end
  
  # has_many through
  # Source: has_many through
  # Through: has_one
  def test_has_many_through_has_one_with_has_many_through_source_reflection
    assert_equal [member_details(:groucho), member_details(:some_other_guy)],
                 members(:groucho).organization_member_details
    
    members = Member.joins(:organization_member_details).
                     where('member_details.id' => member_details(:groucho).id)
    assert_equal [members(:groucho), members(:some_other_guy)], members
    
    members = Member.joins(:organization_member_details).
                     where('member_details.id' => 9)
    assert members.empty?
    
    members = Member.includes(:organization_member_details)
    assert_equal [member_details(:groucho), member_details(:some_other_guy)],
                 members.first.organization_member_details
  end
  
  # has_many through
  # Source: has_many
  # Through: has_one through
  def test_has_many_through_has_one_through_with_has_many_source_reflection
    assert_equal [member_details(:groucho), member_details(:some_other_guy)],
                 members(:groucho).organization_member_details_2
    
    members = Member.joins(:organization_member_details_2).
                     where('member_details.id' => member_details(:groucho).id)
    assert_equal [members(:groucho), members(:some_other_guy)], members
    
    members = Member.joins(:organization_member_details_2).
                     where('member_details.id' => 9)
    assert members.empty?
    
    # TODO: Make this work
    # members = Member.includes(:organization_member_details_2)
    # assert_equal [member_details(:groucho), member_details(:some_other_guy)],
    #              members.first.organization_member_details_2
  end
  
  # has_many through
  # Source: has_and_belongs_to_many
  # Through: has_many
  def test_has_many_through_has_many_with_has_and_belongs_to_many_source_reflection
    assert_equal [categories(:general), categories(:cooking)], authors(:bob).post_categories
    
    authors = Author.joins(:post_categories).where('categories.id' => categories(:cooking).id)
    assert_equal [authors(:bob)], authors
    
    authors = Author.includes(:post_categories)
    assert_equal [categories(:general), categories(:cooking)], authors[2].post_categories
  end
  
  # has_many through
  # Source: has_many
  # Through: has_and_belongs_to_many
  def test_has_many_through_has_and_belongs_to_many_with_has_many_source_reflection
    assert_equal [comments(:greetings), comments(:more_greetings)], categories(:technology).post_comments
    
    categories = Category.joins(:post_comments).where('comments.id' => comments(:more_greetings).id)
    assert_equal [categories(:general), categories(:technology)], categories
    
    # TODO: Make this work
    # categories = Category.includes(:post_comments)
    # assert_equal [comments(:greetings), comments(:more_greetings)], categories[1].post_comments
  end
  
  # has_many through
  # Source: has_many through a habtm
  # Through: has_many through
  def test_has_many_through_has_many_with_has_many_through_habtm_source_reflection
    assert_equal [comments(:greetings), comments(:more_greetings)], authors(:bob).category_post_comments
    
    authors = Author.joins(:category_post_comments).where('comments.id' => comments(:does_it_hurt).id)
    assert_equal [authors(:david), authors(:mary)], authors
    
    comments = Author.joins(:category_post_comments)
    assert_equal [comments(:greetings), comments(:more_greetings)], comments[2].category_post_comments
  end
  
  # has_many through
  # Source: belongs_to
  # Through: has_many through
  def test_has_many_through_has_many_through_with_belongs_to_source_reflection
    author = authors(:david)
    assert_equal [tags(:general), tags(:general)], author.tagging_tags
    
    authors = Author.joins(:tagging_tags).where('tags.id' => tags(:general).id)
    assert_equal [authors(:david)], authors.uniq
    
    # TODO: Make this work
    # authors = Author.includes(:tagging_tags)
    # assert_equal [tags(:general), tags(:general)], authors.first.tagging_tags
  end
  
  # has_many through
  # Source: has_many through
  # Through: belongs_to
  def test_has_many_through_belongs_to_with_has_many_through_source_reflection
    assert_equal [taggings(:welcome_general), taggings(:thinking_general)],
                 categorizations(:david_welcome_general).post_taggings
    
    categorizations = Categorization.joins(:post_taggings).where('taggings.id' => taggings(:welcome_general).id)
    assert_equal [categorizations(:david_welcome_general)], categorizations
    
    categorizations = Categorization.includes(:post_taggings)
    assert_equal [taggings(:welcome_general), taggings(:thinking_general)],
                 categorizations.first.post_taggings
  end
  
  # has_one through
  # Source: has_one through
  # Through: has_one
  def test_has_one_through_has_one_with_has_one_through_source_reflection
    assert_equal member_types(:founding), members(:groucho).nested_member_type
    
    members = Member.joins(:nested_member_type).where('member_types.id' => member_types(:founding).id)
    assert_equal [members(:groucho)], members
    
    members = Member.includes(:nested_member_type)
    assert_equal member_types(:founding), members.first.nested_member_type
  end
  
  # TODO: has_one through
  # Source: belongs_to
  # Through: has_one through

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
end
