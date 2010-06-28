require "cases/helper"
require 'models/post'
require 'models/tagging'
require 'models/tag'
require 'models/comment'
require 'models/author'
require 'models/category'
require 'models/company'
require 'models/person'
require 'models/reader'
require 'models/owner'
require 'models/pet'
require 'models/reference'
require 'models/job'
require 'models/subscriber'
require 'models/subscription'
require 'models/book'
require 'models/developer'
require 'models/project'

class EagerAssociationTest < ActiveRecord::TestCase
  fixtures :posts, :comments, :authors, :author_addresses, :categories, :categories_posts,
            :companies, :accounts, :tags, :taggings, :people, :readers,
            :owners, :pets, :author_favorites, :jobs, :references, :subscribers, :subscriptions, :books,
            :developers, :projects, :developers_projects

  def test_loading_with_one_association
    posts = Post.find(:all, :include => :comments)
    post = posts.find { |p| p.id == 1 }
    assert_equal 2, post.comments.size
    assert post.comments.include?(comments(:greetings))

    post = Post.find(:first, :include => :comments, :conditions => "posts.title = 'Welcome to the weblog'")
    assert_equal 2, post.comments.size
    assert post.comments.include?(comments(:greetings))

    posts = Post.find(:all, :include => :last_comment)
    post = posts.find { |p| p.id == 1 }
    assert_equal Post.find(1).last_comment, post.last_comment
  end

  def test_loading_with_one_association_with_non_preload
    posts = Post.find(:all, :include => :last_comment, :order => 'comments.id DESC')
    post = posts.find { |p| p.id == 1 }
    assert_equal Post.find(1).last_comment, post.last_comment
  end

  def test_loading_conditions_with_or
    posts = authors(:david).posts.find(:all, :include => :comments, :conditions => "comments.body like 'Normal%' OR comments.#{QUOTED_TYPE} = 'SpecialComment'")
    assert_nil posts.detect { |p| p.author_id != authors(:david).id },
      "expected to find only david's posts"
  end

  def test_with_ordering
    list = Post.find(:all, :include => :comments, :order => "posts.id DESC")
    [:eager_other, :sti_habtm, :sti_post_and_comments, :sti_comments,
     :authorless, :thinking, :welcome
    ].each_with_index do |post, index|
      assert_equal posts(post), list[index]
    end
  end

  def test_with_two_tables_in_from_without_getting_double_quoted
    posts = Post.find(:all,
      :select     => "posts.*",
      :from       => "authors, posts",
      :include    => :comments,
      :conditions => "posts.author_id = authors.id",
      :order      => "posts.id"
    )

    assert_equal 2, posts.first.comments.size
  end

  def test_loading_with_multiple_associations
    posts = Post.find(:all, :include => [ :comments, :author, :categories ], :order => "posts.id")
    assert_equal 2, posts.first.comments.size
    assert_equal 2, posts.first.categories.size
    assert posts.first.comments.include?(comments(:greetings))
  end

  def test_duplicate_middle_objects
    comments = Comment.find :all, :conditions => 'post_id = 1', :include => [:post => :author]
    assert_no_queries do
      comments.each {|comment| comment.post.author.name}
    end
  end

  def test_including_duplicate_objects_from_belongs_to
    popular_post = Post.create!(:title => 'foo', :body => "I like cars!")
    comment = popular_post.comments.create!(:body => "lol")
    popular_post.readers.create!(:person => people(:michael))
    popular_post.readers.create!(:person => people(:david))

    readers = Reader.find(:all, :conditions => ["post_id = ?", popular_post.id],
                                :include => {:post => :comments})
    readers.each do |reader|
      assert_equal [comment], reader.post.comments
    end
  end

  def test_including_duplicate_objects_from_has_many
    car_post = Post.create!(:title => 'foo', :body => "I like cars!")
    car_post.categories << categories(:general)
    car_post.categories << categories(:technology)

    comment = car_post.comments.create!(:body => "hmm")
    categories = Category.find(:all, :conditions => ["posts.id=?", car_post.id],
                                 :include => {:posts => :comments})
    categories.each do |category|
      assert_equal [comment], category.posts[0].comments
    end
  end

  def test_finding_with_includes_on_has_many_association_with_same_include_includes_only_once
    author_id = authors(:david).id
    author = assert_queries(3) { Author.find(author_id, :include => {:posts_with_comments => :comments}) } # find the author, then find the posts, then find the comments
    author.posts_with_comments.each do |post_with_comments|
      assert_equal post_with_comments.comments.length, post_with_comments.comments.count
      assert_equal nil, post_with_comments.comments.uniq!
    end
  end

  def test_finding_with_includes_on_has_one_assocation_with_same_include_includes_only_once
    author = authors(:david)
    post = author.post_about_thinking_with_last_comment
    last_comment = post.last_comment
    author = assert_queries(3) { Author.find(author.id, :include => {:post_about_thinking_with_last_comment => :last_comment})} # find the author, then find the posts, then find the comments
    assert_no_queries do
      assert_equal post, author.post_about_thinking_with_last_comment
      assert_equal last_comment, author.post_about_thinking_with_last_comment.last_comment
    end
  end

  def test_finding_with_includes_on_belongs_to_association_with_same_include_includes_only_once
    post = posts(:welcome)
    author = post.author
    author_address = author.author_address
    post = assert_queries(3) { Post.find(post.id, :include => {:author_with_address => :author_address}) } # find the post, then find the author, then find the address
    assert_no_queries do
      assert_equal author, post.author_with_address
      assert_equal author_address, post.author_with_address.author_address
    end
  end

  def test_finding_with_includes_on_null_belongs_to_association_with_same_include_includes_only_once
    post = posts(:welcome)
    post.update_attributes!(:author => nil)
    post = assert_queries(1) { Post.find(post.id, :include => {:author_with_address => :author_address}) } # find the post, then find the author which is null so no query for the author or address
    assert_no_queries do
      assert_equal nil, post.author_with_address
    end
  end

  def test_loading_from_an_association
    posts = authors(:david).posts.find(:all, :include => :comments, :order => "posts.id")
    assert_equal 2, posts.first.comments.size
  end

  def test_loading_from_an_association_that_has_a_hash_of_conditions
    assert_nothing_raised do
      Author.find(:all, :include => :hello_posts_with_hash_conditions)
    end
    assert !Author.find(authors(:david).id, :include => :hello_posts_with_hash_conditions).hello_posts.empty?
  end

  def test_loading_with_no_associations
    assert_nil Post.find(posts(:authorless).id, :include => :author).author
  end

  def test_nested_loading_with_no_associations
    assert_nothing_raised do
      Post.find(posts(:authorless).id, :include => {:author => :author_addresss})
    end
  end

  def test_eager_association_loading_with_belongs_to_and_foreign_keys
    pets = Pet.find(:all, :include => :owner)
    assert_equal 3, pets.length
  end

  def test_eager_association_loading_with_belongs_to
    comments = Comment.find(:all, :include => :post)
    assert_equal 10, comments.length
    titles = comments.map { |c| c.post.title }
    assert titles.include?(posts(:welcome).title)
    assert titles.include?(posts(:sti_post_and_comments).title)
  end

  def test_eager_association_loading_with_belongs_to_and_limit
    comments = Comment.find(:all, :include => :post, :limit => 5, :order => 'comments.id')
    assert_equal 5, comments.length
    assert_equal [1,2,3,5,6], comments.collect { |c| c.id }
  end

  def test_eager_association_loading_with_belongs_to_and_limit_and_conditions
    comments = Comment.find(:all, :include => :post, :conditions => 'post_id = 4', :limit => 3, :order => 'comments.id')
    assert_equal 3, comments.length
    assert_equal [5,6,7], comments.collect { |c| c.id }
  end

  def test_eager_association_loading_with_belongs_to_and_limit_and_offset
    comments = Comment.find(:all, :include => :post, :limit => 3, :offset => 2, :order => 'comments.id')
    assert_equal 3, comments.length
    assert_equal [3,5,6], comments.collect { |c| c.id }
  end

  def test_eager_association_loading_with_belongs_to_and_limit_and_offset_and_conditions
    comments = Comment.find(:all, :include => :post, :conditions => 'post_id = 4', :limit => 3, :offset => 1, :order => 'comments.id')
    assert_equal 3, comments.length
    assert_equal [6,7,8], comments.collect { |c| c.id }
  end

  def test_eager_association_loading_with_belongs_to_and_limit_and_offset_and_conditions_array
    comments = Comment.find(:all, :include => :post, :conditions => ['post_id = ?',4], :limit => 3, :offset => 1, :order => 'comments.id')
    assert_equal 3, comments.length
    assert_equal [6,7,8], comments.collect { |c| c.id }
  end

  def test_eager_association_loading_with_belongs_to_and_conditions_string_with_unquoted_table_name
    assert_nothing_raised do
      Comment.find(:all, :include => :post, :conditions => ['posts.id = ?',4])
    end
  end

  def test_eager_association_loading_with_belongs_to_and_conditions_hash
    comments = []
    assert_nothing_raised do
      comments = Comment.find(:all, :include => :post, :conditions => {:posts => {:id => 4}}, :limit => 3, :order => 'comments.id')
    end
    assert_equal 3, comments.length
    assert_equal [5,6,7], comments.collect { |c| c.id }
    assert_no_queries do
      comments.first.post
    end
  end

  def test_eager_association_loading_with_belongs_to_and_conditions_string_with_quoted_table_name
    quoted_posts_id= Comment.connection.quote_table_name('posts') + '.' + Comment.connection.quote_column_name('id')
    assert_nothing_raised do
      Comment.find(:all, :include => :post, :conditions => ["#{quoted_posts_id} = ?",4])
    end
  end

  def test_eager_association_loading_with_belongs_to_and_order_string_with_unquoted_table_name
    assert_nothing_raised do
      Comment.find(:all, :include => :post, :order => 'posts.id')
    end
  end

  def test_eager_association_loading_with_belongs_to_and_order_string_with_quoted_table_name
    quoted_posts_id= Comment.connection.quote_table_name('posts') + '.' + Comment.connection.quote_column_name('id')
    assert_nothing_raised do
      Comment.find(:all, :include => :post, :order => quoted_posts_id)
    end
  end

  def test_eager_association_loading_with_belongs_to_and_limit_and_multiple_associations
    posts = Post.find(:all, :include => [:author, :very_special_comment], :limit => 1, :order => 'posts.id')
    assert_equal 1, posts.length
    assert_equal [1], posts.collect { |p| p.id }
  end

  def test_eager_association_loading_with_belongs_to_and_limit_and_offset_and_multiple_associations
    posts = Post.find(:all, :include => [:author, :very_special_comment], :limit => 1, :offset => 1, :order => 'posts.id')
    assert_equal 1, posts.length
    assert_equal [2], posts.collect { |p| p.id }
  end

  def test_eager_association_loading_with_belongs_to_inferred_foreign_key_from_association_name
    author_favorite = AuthorFavorite.find(:first, :include => :favorite_author)
    assert_equal authors(:mary), assert_no_queries { author_favorite.favorite_author }
  end

  def test_eager_load_belongs_to_quotes_table_and_column_names
    job = Job.find jobs(:unicyclist).id, :include => :ideal_reference
    references(:michael_unicyclist)
    assert_no_queries{ assert_equal references(:michael_unicyclist), job.ideal_reference}
  end

  def test_eager_load_has_one_quotes_table_and_column_names
    michael = Person.find(people(:michael), :include => :favourite_reference)
    references(:michael_unicyclist)
    assert_no_queries{ assert_equal references(:michael_unicyclist), michael.favourite_reference}
  end

  def test_eager_load_has_many_quotes_table_and_column_names
    michael = Person.find(people(:michael), :include => :references)
    references(:michael_magician,:michael_unicyclist)
    assert_no_queries{ assert_equal references(:michael_magician,:michael_unicyclist), michael.references.sort_by(&:id) }
  end

  def test_eager_load_has_many_through_quotes_table_and_column_names
    michael = Person.find(people(:michael), :include => :jobs)
    jobs(:magician, :unicyclist)
    assert_no_queries{ assert_equal jobs(:unicyclist, :magician), michael.jobs.sort_by(&:id) }
  end

  def test_eager_load_has_many_with_string_keys
    subscriptions = subscriptions(:webster_awdr, :webster_rfr)
    subscriber =Subscriber.find(subscribers(:second).id, :include => :subscriptions)
    assert_equal subscriptions, subscriber.subscriptions.sort_by(&:id)
  end
  
  def test_eager_load_has_many_through_with_string_keys
    books = books(:awdr, :rfr)
    subscriber = Subscriber.find(subscribers(:second).id, :include => :books)
    assert_equal books, subscriber.books.sort_by(&:id)
  end
  
  def test_eager_load_belongs_to_with_string_keys
    subscriber = subscribers(:second)
    subscription = Subscription.find(subscriptions(:webster_awdr).id, :include => :subscriber)
    assert_equal subscriber, subscription.subscriber
  end

  def test_eager_association_loading_with_explicit_join
    posts = Post.find(:all, :include => :comments, :joins => "INNER JOIN authors ON posts.author_id = authors.id AND authors.name = 'Mary'", :limit => 1, :order => 'author_id')
    assert_equal 1, posts.length
  end

  def test_eager_with_has_many_through
    posts_with_comments = people(:michael).posts.find(:all, :include => :comments, :order => 'posts.id')
    posts_with_author = people(:michael).posts.find(:all, :include => :author, :order => 'posts.id')
    posts_with_comments_and_author = people(:michael).posts.find(:all, :include => [ :comments, :author ], :order => 'posts.id')
    assert_equal 2, posts_with_comments.inject(0) { |sum, post| sum += post.comments.size }
    assert_equal authors(:david), assert_no_queries { posts_with_author.first.author }
    assert_equal authors(:david), assert_no_queries { posts_with_comments_and_author.first.author }
  end

  def test_eager_with_has_many_through_a_belongs_to_association
    author = authors(:mary)
    post = Post.create!(:author => author, :title => "TITLE", :body => "BODY")
    author.author_favorites.create(:favorite_author_id => 1)
    author.author_favorites.create(:favorite_author_id => 2)
    posts_with_author_favorites = author.posts.find(:all, :include => :author_favorites)
    assert_no_queries { posts_with_author_favorites.first.author_favorites.first.author_id }
  end

  def test_eager_with_has_many_through_an_sti_join_model
    author = Author.find(:first, :include => :special_post_comments, :order => 'authors.id')
    assert_equal [comments(:does_it_hurt)], assert_no_queries { author.special_post_comments }
  end

  def test_eager_with_has_many_through_an_sti_join_model_with_conditions_on_both
    author = Author.find(:first, :include => :special_nonexistant_post_comments, :order => 'authors.id')
    assert_equal [], author.special_nonexistant_post_comments
  end

  def test_eager_with_has_many_through_join_model_with_conditions
    assert_equal Author.find(:first, :include => :hello_post_comments,
                             :order => 'authors.id').hello_post_comments.sort_by(&:id),
                 Author.find(:first, :order => 'authors.id').hello_post_comments.sort_by(&:id)
  end

  def test_eager_with_has_many_through_join_model_with_conditions_on_top_level
    assert_equal comments(:more_greetings), Author.find(authors(:david).id, :include => :comments_with_order_and_conditions).comments_with_order_and_conditions.first
  end

  def test_eager_with_has_many_through_with_conditions_join_model_with_include
    post_tags = Post.find(posts(:welcome).id).misc_tags
    eager_post_tags = Post.find(1, :include => :misc_tags).misc_tags
    assert_equal post_tags, eager_post_tags
  end


  def test_eager_with_has_many_through_join_model_with_include
    author_comments = Author.find(authors(:david).id, :include => :comments_with_include).comments_with_include.to_a
    assert_no_queries do
      author_comments.first.post.title
    end
  end

  def test_eager_with_has_many_and_limit
    posts = Post.find(:all, :order => 'posts.id asc', :include => [ :author, :comments ], :limit => 2)
    assert_equal 2, posts.size
    assert_equal 3, posts.inject(0) { |sum, post| sum += post.comments.size }
  end

  def test_eager_with_has_many_and_limit_and_conditions
    if current_adapter?(:OpenBaseAdapter)
      posts = Post.find(:all, :include => [ :author, :comments ], :limit => 2, :conditions => "FETCHBLOB(posts.body) = 'hello'", :order => "posts.id")
    else
      posts = Post.find(:all, :include => [ :author, :comments ], :limit => 2, :conditions => "posts.body = 'hello'", :order => "posts.id")
    end
    assert_equal 2, posts.size
    assert_equal [4,5], posts.collect { |p| p.id }
  end

  def test_eager_with_has_many_and_limit_and_conditions_array
    if current_adapter?(:OpenBaseAdapter)
      posts = Post.find(:all, :include => [ :author, :comments ], :limit => 2, :conditions => [ "FETCHBLOB(posts.body) = ?", 'hello' ], :order => "posts.id")
    else
      posts = Post.find(:all, :include => [ :author, :comments ], :limit => 2, :conditions => [ "posts.body = ?", 'hello' ], :order => "posts.id")
    end
    assert_equal 2, posts.size
    assert_equal [4,5], posts.collect { |p| p.id }
  end

  def test_eager_with_has_many_and_limit_and_conditions_array_on_the_eagers
    posts = Post.find(:all, :include => [ :author, :comments ], :limit => 2, :conditions => [ "authors.name = ?", 'David' ])
    assert_equal 2, posts.size

    count = Post.count(:include => [ :author, :comments ], :limit => 2, :conditions => [ "authors.name = ?", 'David' ])
    assert_equal count, posts.size
  end

  def test_eager_with_has_many_and_limit_and_high_offset
    posts = Post.find(:all, :include => [ :author, :comments ], :limit => 2, :offset => 10, :conditions => [ "authors.name = ?", 'David' ])
    assert_equal 0, posts.size
  end

  def test_eager_with_has_many_and_limit_and_high_offset_and_multiple_array_conditions
    assert_queries(1) do
      posts = Post.find(:all, :include => [ :author, :comments ], :limit => 2, :offset => 10,
        :conditions => [ "authors.name = ? and comments.body = ?", 'David', 'go crazy' ])
      assert_equal 0, posts.size
    end
  end

  def test_eager_with_has_many_and_limit_and_high_offset_and_multiple_hash_conditions
    assert_queries(1) do
      posts = Post.find(:all, :include => [ :author, :comments ], :limit => 2, :offset => 10,
        :conditions => { 'authors.name' => 'David', 'comments.body' => 'go crazy' })
      assert_equal 0, posts.size
    end
  end

  def test_count_eager_with_has_many_and_limit_and_high_offset
    posts = Post.count(:all, :include => [ :author, :comments ], :limit => 2, :offset => 10, :conditions => [ "authors.name = ?", 'David' ])
    assert_equal 0, posts
  end

  def test_eager_with_has_many_and_limit_with_no_results
    posts = Post.find(:all, :include => [ :author, :comments ], :limit => 2, :conditions => "posts.title = 'magic forest'")
    assert_equal 0, posts.size
  end

  def test_eager_count_performed_on_a_has_many_association_with_multi_table_conditional
    author = authors(:david)
    author_posts_without_comments = author.posts.select { |post| post.comments.blank? }
    assert_equal author_posts_without_comments.size, author.posts.count(:all, :include => :comments, :conditions => 'comments.id is null')
  end
  
  def test_eager_count_performed_on_a_has_many_through_association_with_multi_table_conditional
    person = people(:michael)
    person_posts_without_comments = person.posts.select { |post| post.comments.blank? }
    assert_equal person_posts_without_comments.size, person.posts_with_no_comments.count
  end

  def test_eager_with_has_and_belongs_to_many_and_limit
    posts = Post.find(:all, :include => :categories, :order => "posts.id", :limit => 3)
    assert_equal 3, posts.size
    assert_equal 2, posts[0].categories.size
    assert_equal 1, posts[1].categories.size
    assert_equal 0, posts[2].categories.size
    assert posts[0].categories.include?(categories(:technology))
    assert posts[1].categories.include?(categories(:general))
  end

  def test_eager_with_has_many_and_limit_and_conditions_on_the_eagers
    posts = authors(:david).posts.find(:all,
      :include    => :comments,
      :conditions => "comments.body like 'Normal%' OR comments.#{QUOTED_TYPE}= 'SpecialComment'",
      :limit      => 2
    )
    assert_equal 2, posts.size

    count = Post.count(
      :include    => [ :comments, :author ],
      :conditions => "authors.name = 'David' AND (comments.body like 'Normal%' OR comments.#{QUOTED_TYPE}= 'SpecialComment')",
      :limit      => 2
    )
    assert_equal count, posts.size
  end

  def test_eager_with_has_many_and_limit_and_scoped_conditions_on_the_eagers
    posts = nil
    Post.with_scope(:find => {
      :include    => :comments,
      :conditions => "comments.body like 'Normal%' OR comments.#{QUOTED_TYPE}= 'SpecialComment'"
    }) do
      posts = authors(:david).posts.find(:all, :limit => 2)
      assert_equal 2, posts.size
    end

    Post.with_scope(:find => {
      :include    => [ :comments, :author ],
      :conditions => "authors.name = 'David' AND (comments.body like 'Normal%' OR comments.#{QUOTED_TYPE}= 'SpecialComment')"
    }) do
      count = Post.count(:limit => 2)
      assert_equal count, posts.size
    end
  end

  def test_eager_with_has_many_and_limit_and_scoped_and_explicit_conditions_on_the_eagers
    Post.with_scope(:find => { :conditions => "1=1" }) do
      posts = authors(:david).posts.find(:all,
        :include    => :comments,
        :conditions => "comments.body like 'Normal%' OR comments.#{QUOTED_TYPE}= 'SpecialComment'",
        :limit      => 2
      )
      assert_equal 2, posts.size

      count = Post.count(
        :include    => [ :comments, :author ],
        :conditions => "authors.name = 'David' AND (comments.body like 'Normal%' OR comments.#{QUOTED_TYPE}= 'SpecialComment')",
        :limit      => 2
      )
      assert_equal count, posts.size
    end
  end

  def test_eager_with_scoped_order_using_association_limiting_without_explicit_scope
    posts_with_explicit_order = Post.find(:all, :conditions => 'comments.id is not null', :include => :comments, :order => 'posts.id DESC', :limit => 2)
    posts_with_scoped_order = Post.with_scope(:find => {:order => 'posts.id DESC'}) do
      Post.find(:all, :conditions => 'comments.id is not null', :include => :comments, :limit => 2)
    end
    assert_equal posts_with_explicit_order, posts_with_scoped_order
  end

  def test_eager_association_loading_with_habtm
    posts = Post.find(:all, :include => :categories, :order => "posts.id")
    assert_equal 2, posts[0].categories.size
    assert_equal 1, posts[1].categories.size
    assert_equal 0, posts[2].categories.size
    assert posts[0].categories.include?(categories(:technology))
    assert posts[1].categories.include?(categories(:general))
  end

  def test_eager_with_inheritance
    posts = SpecialPost.find(:all, :include => [ :comments ])
  end

  def test_eager_has_one_with_association_inheritance
    post = Post.find(4, :include => [ :very_special_comment ])
    assert_equal "VerySpecialComment", post.very_special_comment.class.to_s
  end

  def test_eager_has_many_with_association_inheritance
    post = Post.find(4, :include => [ :special_comments ])
    post.special_comments.each do |special_comment|
      assert_equal "SpecialComment", special_comment.class.to_s
    end
  end

  def test_eager_habtm_with_association_inheritance
    post = Post.find(6, :include => [ :special_categories ])
    assert_equal 1, post.special_categories.size
    post.special_categories.each do |special_category|
      assert_equal "SpecialCategory", special_category.class.to_s
    end
  end

  def test_eager_with_has_one_dependent_does_not_destroy_dependent
    assert_not_nil companies(:first_firm).account
    f = Firm.find(:first, :include => :account,
            :conditions => ["companies.name = ?", "37signals"])
    assert_not_nil f.account
    assert_equal companies(:first_firm, :reload).account, f.account
  end

  def test_eager_with_multi_table_conditional_properly_counts_the_records_when_using_size
    author = authors(:david)
    posts_with_no_comments = author.posts.select { |post| post.comments.blank? }
    assert_equal posts_with_no_comments.size, author.posts_with_no_comments.size
    assert_equal posts_with_no_comments, author.posts_with_no_comments
  end

  def test_eager_with_invalid_association_reference
    assert_raise(ActiveRecord::ConfigurationError, "Association was not found; perhaps you misspelled it?  You specified :include => :monkeys") {
      post = Post.find(6, :include=> :monkeys )
    }
    assert_raise(ActiveRecord::ConfigurationError, "Association was not found; perhaps you misspelled it?  You specified :include => :monkeys") {
      post = Post.find(6, :include=>[ :monkeys ])
    }
    assert_raise(ActiveRecord::ConfigurationError, "Association was not found; perhaps you misspelled it?  You specified :include => :monkeys") {
      post = Post.find(6, :include=>[ 'monkeys' ])
    }
    assert_raise(ActiveRecord::ConfigurationError, "Association was not found; perhaps you misspelled it?  You specified :include => :monkeys, :elephants") {
      post = Post.find(6, :include=>[ :monkeys, :elephants ])
    }
  end

  def find_all_ordered(className, include=nil)
    className.find(:all, :order=>"#{className.table_name}.#{className.primary_key}", :include=>include)
  end

  def test_limited_eager_with_order
    assert_equal posts(:thinking, :sti_comments), Post.find(:all, :include => [:author, :comments], :conditions => "authors.name = 'David'", :order => 'UPPER(posts.title)', :limit => 2, :offset => 1)
    assert_equal posts(:sti_post_and_comments, :sti_comments), Post.find(:all, :include => [:author, :comments], :conditions => "authors.name = 'David'", :order => 'UPPER(posts.title) DESC', :limit => 2, :offset => 1)
  end

  def test_limited_eager_with_multiple_order_columns
    assert_equal posts(:thinking, :sti_comments), Post.find(:all, :include => [:author, :comments], :conditions => "authors.name = 'David'", :order => 'UPPER(posts.title), posts.id', :limit => 2, :offset => 1)
    assert_equal posts(:sti_post_and_comments, :sti_comments), Post.find(:all, :include => [:author, :comments], :conditions => "authors.name = 'David'", :order => 'UPPER(posts.title) DESC, posts.id', :limit => 2, :offset => 1)
  end

  def test_preload_with_interpolation
    assert_equal [comments(:greetings)], Post.find(posts(:welcome).id, :include => :comments_with_interpolated_conditions).comments_with_interpolated_conditions
  end

  def test_polymorphic_type_condition
    post = Post.find(posts(:thinking).id, :include => :taggings)
    assert post.taggings.include?(taggings(:thinking_general))
    post = SpecialPost.find(posts(:thinking).id, :include => :taggings)
    assert post.taggings.include?(taggings(:thinking_general))
  end

  def test_eager_with_multiple_associations_with_same_table_has_many_and_habtm
    # Eager includes of has many and habtm associations aren't necessarily sorted in the same way
    def assert_equal_after_sort(item1, item2, item3 = nil)
      assert_equal(item1.sort{|a,b| a.id <=> b.id}, item2.sort{|a,b| a.id <=> b.id})
      assert_equal(item3.sort{|a,b| a.id <=> b.id}, item2.sort{|a,b| a.id <=> b.id}) if item3
    end
    # Test regular association, association with conditions, association with
    # STI, and association with conditions assured not to be true
    post_types = [:posts, :other_posts, :special_posts]
    # test both has_many and has_and_belongs_to_many
    [Author, Category].each do |className|
      d1 = find_all_ordered(className)
      # test including all post types at once
      d2 = find_all_ordered(className, post_types)
      d1.each_index do |i|
        assert_equal(d1[i], d2[i])
        assert_equal_after_sort(d1[i].posts, d2[i].posts)
        post_types[1..-1].each do |post_type|
          # test including post_types together
          d3 = find_all_ordered(className, [:posts, post_type])
          assert_equal(d1[i], d3[i])
          assert_equal_after_sort(d1[i].posts, d3[i].posts)
          assert_equal_after_sort(d1[i].send(post_type), d2[i].send(post_type), d3[i].send(post_type))
        end
      end
    end
  end

  def test_eager_with_multiple_associations_with_same_table_has_one
    d1 = find_all_ordered(Firm)
    d2 = find_all_ordered(Firm, :account)
    d1.each_index do |i|
      assert_equal(d1[i], d2[i])
      assert_equal(d1[i].account, d2[i].account)
    end
  end

  def test_eager_with_multiple_associations_with_same_table_belongs_to
    firm_types = [:firm, :firm_with_basic_id, :firm_with_other_name, :firm_with_condition]
    d1 = find_all_ordered(Client)
    d2 = find_all_ordered(Client, firm_types)
    d1.each_index do |i|
      assert_equal(d1[i], d2[i])
      firm_types.each { |type| assert_equal(d1[i].send(type), d2[i].send(type)) }
    end
  end
  def test_eager_with_valid_association_as_string_not_symbol
    assert_nothing_raised { Post.find(:all, :include => 'comments') }
  end

  def test_eager_with_floating_point_numbers
    assert_queries(2) do
      # Before changes, the floating point numbers will be interpreted as table names and will cause this to run in one query
      Comment.find :all, :conditions => "123.456 = 123.456", :include => :post
    end
  end

  def test_preconfigured_includes_with_belongs_to
    author = posts(:welcome).author_with_posts
    assert_no_queries {assert_equal 5, author.posts.size}
  end

  def test_preconfigured_includes_with_has_one
    comment = posts(:sti_comments).very_special_comment_with_post
    assert_no_queries {assert_equal posts(:sti_comments), comment.post}
  end

  def test_preconfigured_includes_with_has_many
    posts = authors(:david).posts_with_comments
    one = posts.detect { |p| p.id == 1 }
    assert_no_queries do
      assert_equal 5, posts.size
      assert_equal 2, one.comments.size
    end
  end

  def test_preconfigured_includes_with_habtm
    posts = authors(:david).posts_with_categories
    one = posts.detect { |p| p.id == 1 }
    assert_no_queries do
      assert_equal 5, posts.size
      assert_equal 2, one.categories.size
    end
  end

  def test_preconfigured_includes_with_has_many_and_habtm
    posts = authors(:david).posts_with_comments_and_categories
    one = posts.detect { |p| p.id == 1 }
    assert_no_queries do
      assert_equal 5, posts.size
      assert_equal 2, one.comments.size
      assert_equal 2, one.categories.size
    end
  end

  def test_count_with_include
    if current_adapter?(:SybaseAdapter)
      assert_equal 3, authors(:david).posts_with_comments.count(:conditions => "len(comments.body) > 15")
    elsif current_adapter?(:OpenBaseAdapter)
      assert_equal 3, authors(:david).posts_with_comments.count(:conditions => "length(FETCHBLOB(comments.body)) > 15")
    else
      assert_equal 3, authors(:david).posts_with_comments.count(:conditions => "length(comments.body) > 15")
    end
  end

  def test_load_with_sti_sharing_association
    assert_queries(2) do #should not do 1 query per subclass
      Comment.find :all, :include => :post
    end
  end

  def test_conditions_on_join_table_with_include_and_limit
    assert_equal 3, Developer.find(:all, :include => 'projects', :conditions => 'developers_projects.access_level = 1', :limit => 5).size
  end

  def test_order_on_join_table_with_include_and_limit
    assert_equal 5, Developer.find(:all, :include => 'projects', :order => 'developers_projects.joined_on DESC', :limit => 5).size
  end

  def test_eager_loading_with_order_on_joined_table_preloads
    posts = assert_queries(2) do
      Post.find(:all, :joins => :comments, :include => :author, :order => 'comments.id DESC')
    end
    assert_equal posts(:eager_other), posts[0]
    assert_equal authors(:mary), assert_no_queries { posts[0].author}
  end

  def test_eager_loading_with_conditions_on_joined_table_preloads
    posts = assert_queries(2) do
      Post.find(:all, :select => 'distinct posts.*', :include => :author, :joins => [:comments], :conditions => "comments.body like 'Thank you%'", :order => 'posts.id')
    end
    assert_equal [posts(:welcome)], posts
    assert_equal authors(:david), assert_no_queries { posts[0].author}

    posts = assert_queries(2) do
      Post.find(:all, :select => 'distinct posts.*', :include => :author, :joins => [:comments], :conditions => "comments.body like 'Thank you%'", :order => 'posts.id')
    end
    assert_equal [posts(:welcome)], posts
    assert_equal authors(:david), assert_no_queries { posts[0].author}

    posts = assert_queries(2) do
      Post.find(:all, :include => :author, :joins => {:taggings => :tag}, :conditions => "tags.name = 'General'", :order => 'posts.id')
    end
    assert_equal posts(:welcome, :thinking), posts

    posts = assert_queries(2) do
      Post.find(:all, :include => :author, :joins => {:taggings => {:tag => :taggings}}, :conditions => "taggings_tags.super_tag_id=2", :order => 'posts.id')
    end
    assert_equal posts(:welcome, :thinking), posts

  end

  def test_eager_loading_with_conditions_on_string_joined_table_preloads
    posts = assert_queries(2) do
      Post.find(:all, :select => 'distinct posts.*', :include => :author, :joins => "INNER JOIN comments on comments.post_id = posts.id", :conditions => "comments.body like 'Thank you%'", :order => 'posts.id')
    end
    assert_equal [posts(:welcome)], posts
    assert_equal authors(:david), assert_no_queries { posts[0].author}

    posts = assert_queries(2) do
      Post.find(:all, :select => 'distinct posts.*', :include => :author, :joins => ["INNER JOIN comments on comments.post_id = posts.id"], :conditions => "comments.body like 'Thank you%'", :order => 'posts.id')
    end
    assert_equal [posts(:welcome)], posts
    assert_equal authors(:david), assert_no_queries { posts[0].author}

  end

  def test_eager_loading_with_select_on_joined_table_preloads
    posts = assert_queries(2) do
      Post.find(:all, :select => 'posts.*, authors.name as author_name', :include => :comments, :joins => :author, :order => 'posts.id')
    end
    assert_equal 'David', posts[0].author_name
    assert_equal posts(:welcome).comments, assert_no_queries { posts[0].comments}
  end

  def test_eager_loading_with_conditions_on_join_model_preloads
    authors = assert_queries(2) do
      Author.find(:all, :include => :author_address, :joins => :comments, :conditions => "posts.title like 'Welcome%'")
    end
    assert_equal authors(:david), authors[0]
    assert_equal author_addresses(:david_address), authors[0].author_address
  end

  def test_preload_belongs_to_uses_exclusive_scope
    people = Person.males.find(:all, :include => :primary_contact)
    assert_not_equal people.length, 0
    people.each do |person|
      assert_no_queries {assert_not_nil person.primary_contact}
      assert_equal Person.find(person.id).primary_contact, person.primary_contact
    end
  end

  def test_preload_has_many_uses_exclusive_scope
    people = Person.males.find :all, :include => :agents
    people.each do |person|
      assert_equal Person.find(person.id).agents, person.agents
    end
  end

  def test_preload_has_many_using_primary_key
    expected = Firm.find(:first).clients_using_primary_key.to_a
    firm = Firm.find :first, :include => :clients_using_primary_key
    assert_no_queries do
      assert_equal expected, firm.clients_using_primary_key
    end
  end

  def test_include_has_many_using_primary_key
    expected = Firm.find(1).clients_using_primary_key.sort_by &:name
    firm = Firm.find 1, :include => :clients_using_primary_key, :order => 'clients_using_primary_keys_companies.name'
    assert_no_queries do
      assert_equal expected, firm.clients_using_primary_key
    end
  end
  
  def test_preload_has_one_using_primary_key
    expected = Firm.find(:first).account_using_primary_key
    firm = Firm.find :first, :include => :account_using_primary_key
    assert_no_queries do
      assert_equal expected, firm.account_using_primary_key
    end
  end

  def test_include_has_one_using_primary_key
    expected = Firm.find(1).account_using_primary_key
    firm = Firm.find(:all, :include => :account_using_primary_key, :order => 'accounts.id').detect {|f| f.id == 1}
    assert_no_queries do
      assert_equal expected, firm.account_using_primary_key
    end
  end

  def test_preloading_empty_polymorphic_parent
    t = Tagging.create!(:taggable_type => 'Post', :taggable_id => Post.maximum(:id) + 1, :tag => tags(:general))

    assert_queries(2) { @tagging = Tagging.find(t.id, :include => :taggable) }
    assert_no_queries { assert ! @tagging.taggable }
  end
end
