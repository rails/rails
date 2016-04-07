class Advisor < ActiveRecord::Base
  has_one :developer
  has_many :developer_comments, through: :developer, source: :comments
end
