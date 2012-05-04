class Friendship < ActiveRecord::Base
  belongs_to :friend, class_name: 'Person'
  belongs_to :follower, foreign_key: 'friend_id', class_name: 'Person', counter_cache: :followers_count
end
