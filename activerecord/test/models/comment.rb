class Comment < ActiveRecord::Base
  scope :limit_by, lambda {|l| limit(l) }
  scope :containing_the_letter_e, -> { where("comments.body LIKE '%e%'") }
  scope :not_again, -> { where("comments.body NOT LIKE '%again%'") }
  scope :for_first_post, -> { where(:post_id => 1) }
  scope :for_first_author, -> { joins(:post).where("posts.author_id" => 1) }
  scope :created, -> { all }

  belongs_to :post, :counter_cache => true
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
end

class SpecialComment < Comment
  def self.what_are_you
    'a special comment...'
  end
end

class SubSpecialComment < SpecialComment
end

class VerySpecialComment < Comment
  def self.what_are_you
    'a very special comment...'
  end
end
