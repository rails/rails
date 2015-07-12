class CommentReply < ActiveRecord::Base
  belongs_to :comment

  has_many :comment_subreplies
end