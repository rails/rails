class CommentSubreply < ActiveRecord::Base
  belongs_to :comment_reply

  has_one :comment, through: :comment_reply
  has_one :post, through: :comment
end