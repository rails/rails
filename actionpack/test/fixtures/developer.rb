class Developer < ActiveRecord::Base
  has_and_belongs_to_many :projects
end

class DeVeLoPeR < ActiveRecord::Base
  set_table_name "developers"
end
