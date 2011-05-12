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

class AwesomeComment < Comment
  def body=(the_body)
    self.send('write_attribute', 'body', Awesomeness.awesomeify(the_body))
  end
  
  def self.awesomeify(str)
    "Awesome " + str
  end
end

class SuperAwesomeComment < Comment
  composed_of :body, :class_name => 'Awesomeness', :mapping => [%w(body text)]
end

class Awesomeness
  def self.awesomeify(str)
    "Awesome " + str
  end
  
  attr_reader :text
  
  def initialize(awesome_text)
    @text = awesome_text
  end
  
  def to_s
    self.class.awesomeify text
  end
end
