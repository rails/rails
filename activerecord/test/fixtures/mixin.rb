class Mixin < ActiveRecord::Base
  include ActiveRecord::Mixins::Touch
  include ActiveRecord::Mixins::Tree
end

class ListMixin < ActiveRecord::Base
  include ActiveRecord::Mixins::List
   
  def self.table_name
    "mixins"
  end
    
  def scope_condition
     "parent_id = #{self.parent_id}"
  end      
  
  def position_column
    "pos"
  end

end