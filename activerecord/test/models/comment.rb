class Comment < ActiveRecord::Base
  scope :limit_by, lambda {|l| limit(l) }
  scope :containing_the_letter_e, :conditions => "comments.body LIKE '%e%'"
  scope :not_again, where("comments.body NOT LIKE '%again%'")
  scope :for_first_post, :conditions => { :post_id => 1 }
  scope :for_first_author,
              :joins => :post,
              :conditions => { "posts.author_id" => 1 }

  belongs_to :post, :counter_cache => true
  has_many :ratings

  has_many :children, :class_name => 'Comment', :foreign_key => :parent_id
  belongs_to :parent, :class_name => 'Comment', :counter_cache => :children_count

  def self.what_are_you
    'a comment...'
  end

  def self.search_by_type(q)
    self.find(:all, :conditions => ["#{QUOTED_TYPE} = ?", q])
  end

  def self.all_as_method
    all
  end
  scope :all_as_scope, {}
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
