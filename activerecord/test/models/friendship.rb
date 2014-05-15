class Friendship < ActiveRecord::Base
  belongs_to :friend, class_name: 'Person'
  # friend_too exists to test a bug, and probably shouldn't be used elsewhere
  belongs_to :friend_too, foreign_key: 'friend_id', class_name: 'Person', counter_cache: :friends_too_count
  belongs_to :follower, class_name: 'Person'
end
