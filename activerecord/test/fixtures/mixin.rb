class Mixin < ActiveRecord::Base
  acts_as_tree :foreign_key => "parent_id", :order => "id"

end

class ListMixin < ActiveRecord::Base
  acts_as_list :column => "pos", :scope => :parent_id

  def self.table_name
    "mixins"
  end
    
end