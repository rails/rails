class Author < ActiveRecord::Base
  has_many :posts
  has_many :posts_with_comments, :include => :comments, :class_name => "Post"
  has_many :posts_with_comments_sorted_by_comment_id, :include => :comments, :class_name => "Post", :order => 'comments.id'
  has_many :posts_with_categories, :include => :categories, :class_name => "Post"
  has_many :posts_with_comments_and_categories, :include => [ :comments, :categories ], :order => "posts.id", :class_name => "Post"
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
  has_many :comments, :through => :posts
  has_many :comments_containing_the_letter_e, :through => :posts, :source => :comments
  has_many :comments_with_order_and_conditions, :through => :posts, :source => :comments, :order => 'comments.body', :conditions => "comments.body like 'Thank%'"
  has_many :comments_with_include, :through => :posts, :source => :comments, :include => :post


  has_many :comments_desc, :through => :posts, :source => :comments, :order => 'comments.id DESC'
  has_many :limited_comments, :through => :posts, :source => :comments, :limit => 1
  has_many :funky_comments, :through => :posts, :source => :comments
  has_many :ordered_uniq_comments, :through => :posts, :source => :comments, :uniq => true, :order => 'comments.id'
  has_many :ordered_uniq_comments_desc, :through => :posts, :source => :comments, :uniq => true, :order => 'comments.id DESC'
  has_many :readonly_comments, :through => :posts, :source => :comments, :readonly => true
  
  has_many :special_posts
  has_many :special_post_comments, :through => :special_posts, :source => :comments

  has_many :sti_posts, :class_name => 'StiPost'
  has_many :sti_post_comments, :through => :sti_posts, :source => :comments

  has_many :special_nonexistant_posts, :class_name => "SpecialPost", :conditions => "posts.body = 'nonexistant'"
  has_many :special_nonexistant_post_comments, :through => :special_nonexistant_posts, :source => :comments, :conditions => "comments.post_id = 0"
  has_many :nonexistant_comments, :through => :posts

  has_many :hello_posts, :class_name => "Post", :conditions => "posts.body = 'hello'"
  has_many :hello_post_comments, :through => :hello_posts, :source => :comments
  has_many :posts_with_no_comments, :class_name => 'Post', :conditions => 'comments.id is null', :include => :comments

  has_many :hello_posts_with_hash_conditions, :class_name => "Post",
:conditions => {:body => 'hello'}
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

  has_many :categories_like_general, :through => :categorizations, :source => :category, :class_name => 'Category', :conditions => { :name => 'General' }

  has_many :categorized_posts, :through => :categorizations, :source => :post
  has_many :unique_categorized_posts, :through => :categorizations, :source => :post, :uniq => true

  has_many :nothings, :through => :kateggorisatons, :class_name => 'Category'

  has_many :author_favorites
  has_many :favorite_authors, :through => :author_favorites, :order => 'name'

  has_many :tagging,  :through => :posts # through polymorphic has_one
  has_many :taggings, :through => :posts, :source => :taggings # through polymorphic has_many
  has_many :tags,     :through => :posts # through has_many :through
  has_many :post_categories, :through => :posts, :source => :categories

  belongs_to :author_address, :dependent => :destroy
  belongs_to :author_address_extra, :dependent => :delete, :class_name => "AuthorAddress"

  attr_accessor :post_log

  def after_initialize
    @post_log = []
  end

  def label
    "#{id}-#{name}"
  end

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
    @destroyed_author_address_ids ||= Hash.new { |h,k| h[k] = [] }
  end

  before_destroy do |author_address|
    if author_address.author
      AuthorAddress.destroyed_author_address_ids[author_address.author.id] << author_address.id
    end
    true
  end
end

class AuthorFavorite < ActiveRecord::Base
  belongs_to :author
  belongs_to :favorite_author, :class_name => "Author"
end
