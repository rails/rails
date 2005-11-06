class Post < ActiveRecord::Base
  belongs_to :author do
    def greeting
      "hello"
    end
  end

  belongs_to :author_with_posts, :class_name => "Author", :include => :posts

  has_many   :comments, :order => "body" do
    def find_most_recent
      find(:first, :order => "id DESC")
    end
  end

  has_one  :very_special_comment
  has_one  :very_special_comment_with_post, :class_name => "VerySpecialComment", :include => :post
  has_many :special_comments

  has_and_belongs_to_many :categories
  has_and_belongs_to_many :special_categories, :join_table => "categories_posts"
  
  def self.what_are_you
    'a post...'
  end
end

class SpecialPost < Post; end;

class StiPost < Post
  has_one :special_comment, :class_name => "SpecialComment"
end
