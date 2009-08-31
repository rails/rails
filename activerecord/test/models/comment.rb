class Comment < ActiveRecord::Base
  named_scope :containing_the_letter_e, :conditions => "comments.body LIKE '%e%'"
  named_scope :for_first_post, :conditions => { :post_id => 1 }
  named_scope :for_first_author,
              :joins => :post,
              :conditions => { "posts.author_id" => 1 }

  belongs_to :post, :counter_cache => true

  def self.what_are_you
    'a comment...'
  end

  def self.search_by_type(q)
    self.find(:all, :conditions => ["#{QUOTED_TYPE} = ?", q])
  end
end

class SpecialComment < Comment
  def self.what_are_you
    'a special comment...'
  end
end

class VerySpecialComment < Comment
  def self.what_are_you
    'a very special comment...'
  end
end
