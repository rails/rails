class Author < ActiveRecord::Base
  has_many :posts
  has_one :post
  has_many :very_special_comments, :through => :posts
  has_many :posts_with_comments, -> { includes(:comments) }, :class_name => "Post"
  has_many :popular_grouped_posts, -> { includes(:comments).group("type").having("SUM(comments_count) > 1").select("type") }, :class_name => "Post"
  has_many :posts_with_comments_sorted_by_comment_id, -> { includes(:comments).order('comments.id') }, :class_name => "Post"
  has_many :posts_sorted_by_id_limited, -> { order('posts.id').limit(1) }, :class_name => "Post"
  has_many :posts_with_categories, -> { includes(:categories) }, :class_name => "Post"
  has_many :posts_with_comments_and_categories, -> { includes(:comments, :categories).order("posts.id") }, :class_name => "Post"
  has_many :posts_containing_the_letter_a, :class_name => "Post"
  has_many :posts_with_extension, :class_name => "Post" do #, :extend => ProxyTestExtension
    def testing_proxy_owner
      proxy_owner
    end
    def testing_proxy_reflection
      proxy_reflection
    end
    def testing_proxy_target
      proxy_target
    end
  end
  has_one  :post_about_thinking, -> { where("posts.title like '%thinking%'") }, :class_name => 'Post'
  has_one  :post_about_thinking_with_last_comment, -> { where("posts.title like '%thinking%'").includes(:last_comment) }, :class_name => 'Post'
  has_many :comments, :through => :posts
  has_many :comments_containing_the_letter_e, :through => :posts, :source => :comments
  has_many :comments_with_order_and_conditions, -> { order('comments.body').where("comments.body like 'Thank%'") }, :through => :posts, :source => :comments
  has_many :comments_with_include, -> { includes(:post) }, :through => :posts, :source => :comments

  has_many :first_posts
  has_many :comments_on_first_posts, -> { order('posts.id desc, comments.id asc') }, :through => :first_posts, :source => :comments

  has_one :first_post
  has_one :comment_on_first_post, -> { order('posts.id desc, comments.id asc') }, :through => :first_post, :source => :comments

  has_many :thinking_posts, -> { where(:title => 'So I was thinking') }, :dependent => :delete_all, :class_name => 'Post'
  has_many :welcome_posts, -> { where(:title => 'Welcome to the weblog') }, :class_name => 'Post'

  has_many :comments_desc, -> { order('comments.id DESC') }, :through => :posts, :source => :comments
  has_many :limited_comments, -> { limit(1) }, :through => :posts, :source => :comments
  has_many :funky_comments, :through => :posts, :source => :comments
  has_many :ordered_uniq_comments, -> { uniq.order('comments.id') }, :through => :posts, :source => :comments
  has_many :ordered_uniq_comments_desc, -> { uniq.order('comments.id DESC') }, :through => :posts, :source => :comments
  has_many :readonly_comments, -> { readonly }, :through => :posts, :source => :comments

  has_many :special_posts
  has_many :special_post_comments, :through => :special_posts, :source => :comments

  has_many :sti_posts, :class_name => 'StiPost'
  has_many :sti_post_comments, :through => :sti_posts, :source => :comments

  has_many :special_nonexistant_posts, -> { where("posts.body = 'nonexistant'") }, :class_name => "SpecialPost"
  has_many :special_nonexistant_post_comments, -> { where('comments.post_id' => 0) }, :through => :special_nonexistant_posts, :source => :comments
  has_many :nonexistant_comments, :through => :posts

  has_many :hello_posts, -> { where "posts.body = 'hello'" }, :class_name => "Post"
  has_many :hello_post_comments, :through => :hello_posts, :source => :comments
  has_many :posts_with_no_comments, -> { where('comments.id' => nil).includes(:comments) }, :class_name => 'Post'

  has_many :hello_posts_with_hash_conditions, -> { where(:body => 'hello') }, :class_name => "Post"
  has_many :hello_post_comments_with_hash_conditions, :through =>
:hello_posts_with_hash_conditions, :source => :comments

  has_many :other_posts,          :class_name => "Post"
  has_many :posts_with_callbacks, :class_name => "Post", :before_add => :log_before_adding,
           :after_add     => :log_after_adding,
           :before_remove => :log_before_removing,
           :after_remove  => :log_after_removing
  has_many :posts_with_proc_callbacks, :class_name => "Post",
           :before_add    => Proc.new {|o, r| o.post_log << "before_adding#{r.id || '<new>'}"},
           :after_add     => Proc.new {|o, r| o.post_log << "after_adding#{r.id || '<new>'}"},
           :before_remove => Proc.new {|o, r| o.post_log << "before_removing#{r.id}"},
           :after_remove  => Proc.new {|o, r| o.post_log << "after_removing#{r.id}"}
  has_many :posts_with_multiple_callbacks, :class_name => "Post",
           :before_add => [:log_before_adding, Proc.new {|o, r| o.post_log << "before_adding_proc#{r.id || '<new>'}"}],
           :after_add  => [:log_after_adding,  Proc.new {|o, r| o.post_log << "after_adding_proc#{r.id || '<new>'}"}]
  has_many :unchangable_posts, :class_name => "Post", :before_add => :raise_exception, :after_add => :log_after_adding

  has_many :categorizations
  has_many :categories, :through => :categorizations
  has_many :named_categories, :through => :categorizations

  has_many :special_categorizations
  has_many :special_categories, :through => :special_categorizations, :source => :category
  has_one  :special_category,   :through => :special_categorizations, :source => :category

  has_many :categories_like_general, -> { where(:name => 'General') }, :through => :categorizations, :source => :category, :class_name => 'Category'

  has_many :categorized_posts, :through => :categorizations, :source => :post
  has_many :unique_categorized_posts, -> { uniq }, :through => :categorizations, :source => :post

  has_many :nothings, :through => :kateggorisatons, :class_name => 'Category'

  has_many :author_favorites
  has_many :favorite_authors, -> { order('name') }, :through => :author_favorites

  has_many :taggings,        :through => :posts
  has_many :taggings_2,      :through => :posts, :source => :tagging
  has_many :tags,            :through => :posts
  has_many :post_categories, :through => :posts, :source => :categories
  has_many :tagging_tags,    :through => :taggings, :source => :tag

  has_many :similar_posts, -> { uniq }, :through => :tags, :source => :tagged_posts
  has_many :distinct_tags, -> { select("DISTINCT tags.*").order("tags.name") }, :through => :posts, :source => :tags

  has_many :tags_with_primary_key, :through => :posts

  has_many :books
  has_many :subscriptions,        :through => :books
  has_many :subscribers, -> { order("subscribers.nick") }, :through => :subscriptions
  has_many :distinct_subscribers, -> { select("DISTINCT subscribers.*").order("subscribers.nick") }, :through => :subscriptions, :source => :subscriber

  has_one :essay, :primary_key => :name, :as => :writer
  has_one :essay_category, :through => :essay, :source => :category
  has_one :essay_owner, :through => :essay, :source => :owner

  has_one :essay_2, :primary_key => :name, :class_name => 'Essay', :foreign_key => :author_id
  has_one :essay_category_2, :through => :essay_2, :source => :category

  has_many :essays, :primary_key => :name, :as => :writer
  has_many :essay_categories, :through => :essays, :source => :category
  has_many :essay_owners, :through => :essays, :source => :owner

  has_many :essays_2, :primary_key => :name, :class_name => 'Essay', :foreign_key => :author_id
  has_many :essay_categories_2, :through => :essays_2, :source => :category

  belongs_to :owned_essay, :primary_key => :name, :class_name => 'Essay'
  has_one :owned_essay_category, :through => :owned_essay, :source => :category

  belongs_to :author_address,       :dependent => :destroy
  belongs_to :author_address_extra, :dependent => :delete, :class_name => "AuthorAddress"

  has_many :category_post_comments, :through => :categories, :source => :post_comments

  has_many :misc_posts, -> { where(:posts => { :title => ['misc post by bob', 'misc post by mary'] }) }, :class_name => 'Post'
  has_many :misc_post_first_blue_tags, :through => :misc_posts, :source => :first_blue_tags

  has_many :misc_post_first_blue_tags_2, -> { where(:posts => { :title => ['misc post by bob', 'misc post by mary'] }) },
           :through => :posts, :source => :first_blue_tags_2

  has_many :posts_with_default_include, :class_name => 'PostWithDefaultInclude'
  has_many :comments_on_posts_with_default_include, :through => :posts_with_default_include, :source => :comments

  scope :relation_include_posts, -> { includes(:posts) }
  scope :relation_include_tags,  -> { includes(:tags) }

  attr_accessor :post_log
  after_initialize :set_post_log

  def set_post_log
    @post_log = []
  end

  def label
    "#{id}-#{name}"
  end

  def social
    %w(twitter github)
  end

  validates_presence_of :name

  private
    def log_before_adding(object)
      @post_log << "before_adding#{object.id || '<new>'}"
    end

    def log_after_adding(object)
      @post_log << "after_adding#{object.id}"
    end

    def log_before_removing(object)
      @post_log << "before_removing#{object.id}"
    end

    def log_after_removing(object)
      @post_log << "after_removing#{object.id}"
    end

    def raise_exception(object)
      raise Exception.new("You can't add a post")
    end
end

class AuthorAddress < ActiveRecord::Base
  has_one :author

  def self.destroyed_author_address_ids
    @destroyed_author_address_ids ||= []
  end

  before_destroy do |author_address|
    AuthorAddress.destroyed_author_address_ids << author_address.id
  end
end

class AuthorFavorite < ActiveRecord::Base
  belongs_to :author
  belongs_to :favorite_author, :class_name => "Author"
end
