class Post < ActiveRecord::Base
  module NamedExtension
    def author
      'lifo'
    end
  end

  scope :containing_the_letter_a, -> { where("body LIKE '%a%'") }
  scope :ranked_by_comments,      -> { order("comments_count DESC") }

  scope :limit_by, lambda {|l| limit(l) }

  belongs_to :author do
    def greeting
      "hello"
    end
  end

  belongs_to :author_with_posts, -> { includes(:posts) }, :class_name => "Author", :foreign_key => :author_id
  belongs_to :author_with_address, -> { includes(:author_address) }, :class_name => "Author", :foreign_key => :author_id

  def first_comment
    super.body
  end
  has_one :first_comment, -> { order('id ASC') }, :class_name => 'Comment'
  has_one :last_comment, -> { order('id desc') }, :class_name => 'Comment'

  scope :with_special_comments, -> { joins(:comments).where(:comments => {:type => 'SpecialComment'}) }
  scope :with_very_special_comments, -> { joins(:comments).where(:comments => {:type => 'VerySpecialComment'}) }
  scope :with_post, ->(post_id) { joins(:comments).where(:comments => { :post_id => post_id }) }

  has_many   :comments do
    def find_most_recent
      order("id DESC").first
    end

    def newest
      created.last
    end

    def the_association
      proxy_association
    end
  end

  has_many :author_favorites, :through => :author
  has_many :author_categorizations, :through => :author, :source => :categorizations
  has_many :author_addresses, :through => :author

  has_many :comments_with_interpolated_conditions,
    ->(p) { where "#{"#{p.aliased_table_name}." rescue ""}body = ?", 'Thank you for the welcome' },
    :class_name => 'Comment'

  has_one  :very_special_comment
  has_one  :very_special_comment_with_post, -> { includes(:post) }, :class_name => "VerySpecialComment"
  has_many :special_comments
  has_many :nonexistant_comments, -> { where 'comments.id < 0' }, :class_name => 'Comment'

  has_many :special_comments_ratings, :through => :special_comments, :source => :ratings
  has_many :special_comments_ratings_taggings, :through => :special_comments_ratings, :source => :taggings

  has_and_belongs_to_many :categories
  has_and_belongs_to_many :special_categories, :join_table => "categories_posts", :association_foreign_key => 'category_id'

  has_many :taggings, :as => :taggable
  has_many :tags, :through => :taggings do
    def add_joins_and_select
      select('tags.*, authors.id as author_id')
        .joins('left outer join posts on taggings.taggable_id = posts.id left outer join authors on posts.author_id = authors.id')
        .to_a
    end
  end

  has_many :taggings_with_delete_all, :class_name => 'Tagging', :as => :taggable, :dependent => :delete_all
  has_many :taggings_with_destroy, :class_name => 'Tagging', :as => :taggable, :dependent => :destroy

  has_many :tags_with_destroy, :through => :taggings, :source => :tag, :dependent => :destroy
  has_many :tags_with_nullify, :through => :taggings, :source => :tag, :dependent => :nullify

  has_many :misc_tags, -> { where :tags => { :name => 'Misc' } }, :through => :taggings, :source => :tag
  has_many :funky_tags, :through => :taggings, :source => :tag
  has_many :super_tags, :through => :taggings
  has_many :tags_with_primary_key, :through => :taggings, :source => :tag_with_primary_key
  has_one :tagging, :as => :taggable

  has_many :first_taggings, -> { where :taggings => { :comment => 'first' } }, :as => :taggable, :class_name => 'Tagging'
  has_many :first_blue_tags, -> { where :tags => { :name => 'Blue' } }, :through => :first_taggings, :source => :tag

  has_many :first_blue_tags_2, -> { where :taggings => { :comment => 'first' } }, :through => :taggings, :source => :blue_tag

  has_many :invalid_taggings, -> { where 'taggings.id < 0' }, :as => :taggable, :class_name => "Tagging"
  has_many :invalid_tags, :through => :invalid_taggings, :source => :tag

  has_many :categorizations, :foreign_key => :category_id
  has_many :authors, :through => :categorizations

  has_many :categorizations_using_author_id, :primary_key => :author_id, :foreign_key => :post_id, :class_name => 'Categorization'
  has_many :authors_using_author_id, :through => :categorizations_using_author_id, :source => :author

  has_many :taggings_using_author_id, :primary_key => :author_id, :as => :taggable, :class_name => 'Tagging'
  has_many :tags_using_author_id, :through => :taggings_using_author_id, :source => :tag

  has_many :standard_categorizations, :class_name => 'Categorization', :foreign_key => :post_id
  has_many :author_using_custom_pk,  :through => :standard_categorizations
  has_many :authors_using_custom_pk, :through => :standard_categorizations
  has_many :named_categories, :through => :standard_categorizations

  has_many :readers
  has_many :secure_readers
  has_many :readers_with_person, -> { includes(:person) }, :class_name => "Reader"
  has_many :people, :through => :readers
  has_many :secure_people, :through => :secure_readers
  has_many :single_people, :through => :readers
  has_many :people_with_callbacks, :source=>:person, :through => :readers,
              :before_add    => lambda {|owner, reader| log(:added,   :before, reader.first_name) },
              :after_add     => lambda {|owner, reader| log(:added,   :after,  reader.first_name) },
              :before_remove => lambda {|owner, reader| log(:removed, :before, reader.first_name) },
              :after_remove  => lambda {|owner, reader| log(:removed, :after,  reader.first_name) }
  has_many :skimmers, -> { where :skimmer => true }, :class_name => 'Reader'
  has_many :impatient_people, :through => :skimmers, :source => :person

  has_many :lazy_readers
  has_many :lazy_readers_skimmers_or_not, -> { where(skimmer: [ true, false ]) }, :class_name => 'LazyReader'

  def self.top(limit)
    ranked_by_comments.limit_by(limit)
  end

  def self.reset_log
    @log = []
  end

  def self.log(message=nil, side=nil, new_record=nil)
    return @log if message.nil?
    @log << [message, side, new_record]
  end

  def self.what_are_you
    'a post...'
  end
end

class SpecialPost < Post; end

class StiPost < Post
  self.abstract_class = true
  has_one :special_comment, :class_name => "SpecialComment"
end

class SubStiPost < StiPost
  self.table_name = Post.table_name
end

ActiveSupport::Deprecation.silence do
  class DeprecatedPostWithComment < ActiveRecord::Base
    self.table_name = 'posts'
    default_scope where("posts.comments_count > 0").order("posts.comments_count ASC")
  end
end

class PostForAuthor < ActiveRecord::Base
  self.table_name = 'posts'
  cattr_accessor :selected_author
end

class FirstPost < ActiveRecord::Base
  self.table_name = 'posts'
  default_scope { where(:id => 1) }

  has_many :comments, :foreign_key => :post_id
  has_one  :comment,  :foreign_key => :post_id
end

class PostWithDefaultInclude < ActiveRecord::Base
  self.table_name = 'posts'
  default_scope { includes(:comments) }
  has_many :comments, :foreign_key => :post_id
end

class PostWithDefaultScope < ActiveRecord::Base
  self.table_name = 'posts'
  default_scope { order(:title) }
end

class SpecialPostWithDefaultScope < ActiveRecord::Base
  self.table_name = 'posts'
  default_scope { where(:id => [1, 5,6]) }
end
