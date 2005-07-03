class Post < ActiveRecord::Base
  belongs_to :author
  has_many   :comments, :order => "body"
  has_one    :very_special_comment, :class_name => "VerySpecialComment"
  has_many   :special_comments, :class_name => "SpecialComment"
  has_and_belongs_to_many :categories
  has_and_belongs_to_many :special_categories, :join_table => "categories_posts"
end

class SpecialPost < Post; end;

class StiPost < Post
  has_one :special_comment, :class_name => "SpecialComment"
end
