# frozen_string_literal: true

# `counter_cache` requires association class before `attr_readonly`.
class Post < ActiveRecord::Base; end

class Comment < ActiveRecord::Base
  scope :limit_by, lambda { |l| limit(l) }
  scope :containing_the_letter_e, -> { where("comments.body LIKE '%e%'") }
  scope :not_again, -> { where("comments.body NOT LIKE '%again%'") }
  scope :for_first_post, -> { where(post_id: 1) }
  scope :for_first_author, -> { joins(:post).where("posts.author_id" => 1) }
  scope :created, -> { all }

  belongs_to :post, counter_cache: true
  belongs_to :author,   polymorphic: true
  belongs_to :resource, polymorphic: true

  has_many :ratings

  belongs_to :first_post, foreign_key: :post_id
  belongs_to :special_post_with_default_scope, foreign_key: :post_id

  has_many :children, class_name: "Comment", foreign_key: :parent_id
  belongs_to :parent, class_name: "Comment", counter_cache: :children_count

  class ::OopsError < RuntimeError; end

  module OopsExtension
    def destroy_all(*)
      raise OopsError
    end
  end

  default_scope { extending OopsExtension }

  scope :oops_comments, -> { extending OopsExtension }

  # Should not be called if extending modules that having the method exists on an association.
  def self.greeting
    raise
  end

  def self.what_are_you
    "a comment..."
  end

  def self.search_by_type(q)
    where("#{QUOTED_TYPE} = ?", q)
  end

  def self.all_as_method
    all
  end
  scope :all_as_scope, -> { all }

  def to_s
    body
  end
end

class SpecialComment < Comment
  default_scope { where(deleted_at: nil) }

  def self.what_are_you
    "a special comment..."
  end
end

class SubSpecialComment < SpecialComment
end

class VerySpecialComment < Comment
end

class CommentThatAutomaticallyAltersPostBody < Comment
  belongs_to :post, class_name: "PostThatLoadsCommentsInAnAfterSaveHook", foreign_key: :post_id

  after_save do |comment|
    comment.post.update(body: "Automatically altered")
  end
end

class CommentWithDefaultScopeReferencesAssociation < Comment
  default_scope -> { includes(:developer).order("developers.name").references(:developer) }
  belongs_to :developer
end

class CommentWithAfterCreateUpdate < Comment
  after_create do
    update(body: "bar")
  end
end
