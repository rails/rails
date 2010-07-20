class Reference < ActiveRecord::Base
  belongs_to :person
  belongs_to :job
end

class BadReference < ActiveRecord::Base
  self.table_name ='references'
  default_scope :conditions => {:favourite => false }
end
