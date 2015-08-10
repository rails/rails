class Comment < ActiveRecord::Base
  scope :limit_by, lambda {|l| limit(l) }
  scope :containing_the_letter_e, -> { where("comments.body LIKE '%e%'") }
  scope :not_again, -> { where("comments.body NOT LIKE '%again%'") }
  scope :for_first_post, -> { where(:post_id => 1) }
  scope :for_first_author, -> { joins(:post).where("posts.author_id" => 1) }
  scope :created, -> { all }

  belongs_to :post, :counter_cache => true
  belongs_to :author,   polymorphic: true
  belongs_to :resource, polymorphic: true
  belongs_to :developer

  has_many :ratings

  belongs_to :first_post, :foreign_key => :post_id

  has_many :children, :class_name => 'Comment', :foreign_key => :parent_id
  belongs_to :parent, :class_name => 'Comment', :counter_cache => :children_count

  def self.what_are_you
    'a comment...'
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
end

class SubSpecialComment < SpecialComment
end

class VerySpecialComment < Comment
end

class CommentThatAutomaticallyAltersPostBody < Comment
  belongs_to :post, class_name: "PostThatLoadsCommentsInAnAfterSaveHook", foreign_key: :post_id

  after_save do |comment|
    comment.post.update_attributes(body: "Automatically altered")
  end
end

class CommentWithDefaultScopeReferencesAssociation < Comment
  default_scope ->{ includes(:developer).order('developers.name').references(:developer) }
  belongs_to :developer
end

class CommentWithConflictingDefaultScope < Comment
  default_scope ->{ where(author_id: 42) }
  belongs_to :post_with_conflicting_default_scope, foreign_key: :post_id
end
