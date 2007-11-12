class Developer < ActiveRecord::Base
  has_and_belongs_to_many :projects
  has_many :replies
  has_many :topics, :through => :replies
end

class DeVeLoPeR < ActiveRecord::Base
  set_table_name "developers"
end
