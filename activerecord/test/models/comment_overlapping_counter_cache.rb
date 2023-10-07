# frozen_string_literal: true

class CommentOverlappingCounterCache < ActiveRecord::Base
  belongs_to :user_comments_count, counter_cache: :comments_count, optional: true
  belongs_to :post_comments_count, class_name: "PostCommentsCount", optional: true
  belongs_to :commentable, polymorphic: true, counter_cache: :comments_count, optional: true
end

class UserCommentsCount < ActiveRecord::Base
  has_many :comments, as: :commentable, class_name: "CommentOverlappingCounterCache"
end

class PostCommentsCount < ActiveRecord::Base
  has_many :comments, class_name: "CommentOverlappingCounterCache"
end
