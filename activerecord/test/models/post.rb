# frozen_string_literal: true

class Post < ActiveRecord::Base
  class CategoryPost < ActiveRecord::Base
    self.table_name = "categories_posts"
    belongs_to :category
    belongs_to :post
  end

  module NamedExtension
    def author
      "lifo"
    end

    def greeting
      super + " :)"
    end
  end

  module NamedExtension2
    def greeting
      "hullo"
    end
  end

  alias_attribute :text, :body
  alias_attribute :comments_count, :legacy_comments_count

  scope :containing_the_letter_a, -> { where("body LIKE '%a%'") }
  scope :titled_with_an_apostrophe, -> { where("title LIKE '%''%'") }
  scope :ranked_by_comments, -> { order(arel_attribute(:comments_count).desc) }

  scope :limit_by, lambda { |l| limit(l) }
  scope :locked, -> { lock }

  belongs_to :author
  belongs_to :readonly_author, -> { readonly }, class_name: "Author", foreign_key: :author_id

  belongs_to :author_with_posts, -> { includes(:posts) }, class_name: "Author", foreign_key: :author_id
  belongs_to :author_with_address, -> { includes(:author_address) }, class_name: "Author", foreign_key: :author_id
  belongs_to :author_with_select, -> { select(:id) }, class_name: "Author", foreign_key: :author_id

  def first_comment
    super.body
  end
  has_one :first_comment, -> { order("id ASC") }, class_name: "Comment"
  has_one :last_comment, -> { order("id desc") }, class_name: "Comment"

  scope :no_comments, -> { left_joins(:comments).where(comments: { id: nil }) }
  scope :with_special_comments, -> { joins(:comments).where(comments: { type: "SpecialComment" }) }
  scope :with_very_special_comments, -> { joins(:comments).where(comments: { type: "VerySpecialComment" }) }
  scope :with_post, ->(post_id) { joins(:comments).where(comments: { post_id: post_id }) }

  scope :with_comments, -> { preload(:comments) }
  scope :with_tags, -> { preload(:taggings) }

  scope :tagged_with, ->(id) { joins(:taggings).where(taggings: { tag_id: id }) }
  scope :tagged_with_comment, ->(comment) { joins(:taggings).where(taggings: { comment: comment }) }

  scope :typographically_interesting, -> { containing_the_letter_a.or(titled_with_an_apostrophe) }

  has_many :comments do
    def find_most_recent
      order("id DESC").first
    end

    def newest
      created.last
    end

    def the_association
      proxy_association
    end

    def with_content(content)
      self.detect { |comment| comment.body == content }
    end
  end

  has_many :comments_with_extend, extend: NamedExtension, class_name: "Comment", foreign_key: "post_id" do
    def greeting
      "hello"
    end
  end

  has_many :comments_with_extend_2, extend: [NamedExtension, NamedExtension2], class_name: "Comment", foreign_key: "post_id"

  has_many :author_favorites, through: :author
  has_many :author_favorites_with_scope, through: :author, class_name: "AuthorFavoriteWithScope", source: "author_favorites"
  has_many :author_categorizations, through: :author, source: :categorizations
  has_many :author_addresses, through: :author
  has_many :author_address_extra_with_address,
    through: :author_with_address,
    source: :author_address_extra

  has_one  :very_special_comment
  has_one  :very_special_comment_with_post, -> { includes(:post) }, class_name: "VerySpecialComment"
  has_one :very_special_comment_with_post_with_joins, -> { joins(:post).order("posts.id") }, class_name: "VerySpecialComment"
  has_many :special_comments
  has_many :nonexistent_comments, -> { where "comments.id < 0" }, class_name: "Comment"

  has_many :special_comments_ratings, through: :special_comments, source: :ratings
  has_many :special_comments_ratings_taggings, through: :special_comments_ratings, source: :taggings

  has_many :category_posts, class_name: "CategoryPost"
  has_many :scategories, through: :category_posts, source: :category
  has_and_belongs_to_many :categories
  has_and_belongs_to_many :special_categories, join_table: "categories_posts", association_foreign_key: "category_id"

  has_many :taggings, as: :taggable, counter_cache: :tags_count
  has_many :tags, through: :taggings do
    def add_joins_and_select
      select("tags.*, authors.id as author_id")
        .joins("left outer join posts on taggings.taggable_id = posts.id left outer join authors on posts.author_id = authors.id")
        .to_a
    end
  end

  has_many :indestructible_taggings, as: :taggable, counter_cache: :indestructible_tags_count
  has_many :indestructible_tags, through: :indestructible_taggings, source: :tag

  has_many :taggings_with_delete_all, class_name: "Tagging", as: :taggable, dependent: :delete_all, counter_cache: :taggings_with_delete_all_count
  has_many :taggings_with_destroy, class_name: "Tagging", as: :taggable, dependent: :destroy, counter_cache: :taggings_with_destroy_count

  has_many :tags_with_destroy, through: :taggings, source: :tag, dependent: :destroy, counter_cache: :tags_with_destroy_count
  has_many :tags_with_nullify, through: :taggings, source: :tag, dependent: :nullify, counter_cache: :tags_with_nullify_count

  has_many :misc_tags, -> { where tags: { name: "Misc" } }, through: :taggings, source: :tag
  has_many :funky_tags, through: :taggings, source: :tag
  has_many :super_tags, through: :taggings
  has_many :ordered_tags, through: :taggings
  has_many :tags_with_primary_key, through: :taggings, source: :tag_with_primary_key
  has_one :tagging, as: :taggable

  has_many :first_taggings, -> { where taggings: { comment: "first" } }, as: :taggable, class_name: "Tagging"
  has_many :first_blue_tags, -> { where tags: { name: "Blue" } }, through: :first_taggings, source: :tag

  has_many :first_blue_tags_2, -> { where taggings: { comment: "first" } }, through: :taggings, source: :blue_tag

  has_many :invalid_taggings, -> { where "taggings.id < 0" }, as: :taggable, class_name: "Tagging"
  has_many :invalid_tags, through: :invalid_taggings, source: :tag

  has_many :categorizations, foreign_key: :category_id
  has_many :authors, through: :categorizations

  has_many :categorizations_using_author_id, primary_key: :author_id, foreign_key: :post_id, class_name: "Categorization"
  has_many :authors_using_author_id, through: :categorizations_using_author_id, source: :author

  has_many :taggings_using_author_id, primary_key: :author_id, as: :taggable, class_name: "Tagging"
  has_many :tags_using_author_id, through: :taggings_using_author_id, source: :tag

  has_many :images, as: :imageable, foreign_key: :imageable_identifier, foreign_type: :imageable_class
  has_one :main_image, as: :imageable, foreign_key: :imageable_identifier, foreign_type: :imageable_class, class_name: "Image"

  has_many :standard_categorizations, class_name: "Categorization", foreign_key: :post_id
  has_many :author_using_custom_pk,  through: :standard_categorizations
  has_many :authors_using_custom_pk, through: :standard_categorizations
  has_many :named_categories, through: :standard_categorizations

  has_many :readers
  has_many :secure_readers
  has_many :readers_with_person, -> { includes(:person) }, class_name: "Reader"
  has_many :people, through: :readers
  has_many :single_people, through: :readers
  has_many :people_with_callbacks, source: :person, through: :readers,
              before_add: lambda { |owner, reader| log(:added,   :before, reader.first_name) },
              after_add: lambda { |owner, reader| log(:added,   :after,  reader.first_name) },
              before_remove: lambda { |owner, reader| log(:removed, :before, reader.first_name) },
              after_remove: lambda { |owner, reader| log(:removed, :after,  reader.first_name) }
  has_many :skimmers, -> { where skimmer: true }, class_name: "Reader"
  has_many :impatient_people, through: :skimmers, source: :person

  has_many :lazy_readers
  has_many :lazy_readers_skimmers_or_not, -> { where(skimmer: [ true, false ]) }, class_name: "LazyReader"

  has_many :lazy_people, through: :lazy_readers, source: :person
  has_many :lazy_readers_unscope_skimmers, -> { skimmers_or_not }, class_name: "LazyReader"
  has_many :lazy_people_unscope_skimmers, through: :lazy_readers_unscope_skimmers, source: :person

  def self.top(limit)
    ranked_by_comments.limit_by(limit)
  end

  def self.written_by(author)
    where(id: author.posts.pluck(:id))
  end

  def self.reset_log
    @log = []
  end

  def self.log(message = nil, side = nil, new_record = nil)
    return @log if message.nil?
    @log << [message, side, new_record]
  end
end

class SpecialPost < Post; end

class StiPost < Post
  has_one :special_comment, class_name: "SpecialComment"
end

class AbstractStiPost < Post
  self.abstract_class = true
end

class SubStiPost < StiPost
  self.table_name = Post.table_name
end

class SubAbstractStiPost < AbstractStiPost; end

class NullPost < Post
  default_scope { none }
end

class FirstPost < ActiveRecord::Base
  self.inheritance_column = :disabled
  self.table_name = "posts"
  default_scope { where(id: 1) }

  has_many :comments, foreign_key: :post_id
  has_one  :comment,  foreign_key: :post_id
end

class PostWithDefaultSelect < ActiveRecord::Base
  self.table_name = "posts"

  default_scope { select(:author_id) }
end

class TaggedPost < Post
  has_many :taggings, -> { rewhere(taggable_type: "TaggedPost") }, as: :taggable
  has_many :tags, through: :taggings
end

class PostWithDefaultInclude < ActiveRecord::Base
  self.inheritance_column = :disabled
  self.table_name = "posts"
  default_scope { includes(:comments) }
  has_many :comments, foreign_key: :post_id
end

class PostWithSpecialCategorization < Post
  has_many :categorizations, foreign_key: :post_id
  default_scope { where(type: "PostWithSpecialCategorization").joins(:categorizations).where(categorizations: { special: true }) }
end

class PostWithDefaultScope < ActiveRecord::Base
  self.inheritance_column = :disabled
  self.table_name = "posts"
  default_scope { order(:title) }
end

class PostWithPreloadDefaultScope < ActiveRecord::Base
  self.table_name = "posts"

  has_many :readers, foreign_key: "post_id"

  default_scope { preload(:readers) }
end

class PostWithIncludesDefaultScope < ActiveRecord::Base
  self.table_name = "posts"

  has_many :readers, foreign_key: "post_id"

  default_scope { includes(:readers) }
end

class SpecialPostWithDefaultScope < ActiveRecord::Base
  self.inheritance_column = :disabled
  self.table_name = "posts"
  default_scope { where(id: [1, 5, 6]) }
  scope :unscoped_all, -> { unscoped { all } }
  scope :authorless, -> { unscoped { where(author_id: 0) } }
end

class PostThatLoadsCommentsInAnAfterSaveHook < ActiveRecord::Base
  self.inheritance_column = :disabled
  self.table_name = "posts"
  has_many :comments, class_name: "CommentThatAutomaticallyAltersPostBody", foreign_key: :post_id

  after_save do |post|
    post.comments.load
  end
end

class PostWithAfterCreateCallback < ActiveRecord::Base
  self.inheritance_column = :disabled
  self.table_name = "posts"
  has_many :comments, foreign_key: :post_id

  after_create do |post|
    update_attribute(:author_id, comments.first.id)
  end
end

class PostWithCommentWithDefaultScopeReferencesAssociation < ActiveRecord::Base
  self.inheritance_column = :disabled
  self.table_name = "posts"
  has_many :comment_with_default_scope_references_associations, foreign_key: :post_id
  has_one :first_comment, class_name: "CommentWithDefaultScopeReferencesAssociation", foreign_key: :post_id
end

class SerializedPost < ActiveRecord::Base
  serialize :title
end

class ConditionalStiPost < Post
  default_scope { where(title: "Untitled") }
end

class SubConditionalStiPost < ConditionalStiPost
end

class FakeKlass
  extend ActiveRecord::Delegation::DelegateCache

  class << self
    def connection
      Post.connection
    end

    def table_name
      "posts"
    end

    def attribute_aliases
      {}
    end

    def sanitize_sql(sql)
      sql
    end

    def sanitize_sql_for_order(sql)
      sql
    end

    def arel_attribute(name, table)
      table[name]
    end

    def disallow_raw_sql!(*args)
      # noop
    end

    def columns_hash
      { "name" => nil }
    end

    def arel_table
      Post.arel_table
    end

    def predicate_builder
      Post.predicate_builder
    end

    def base_class?
      true
    end
  end

  inherited self
end
