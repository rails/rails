class Reader < ActiveRecord::Base
  belongs_to :post
  belongs_to :person, :inverse_of => :readers
  belongs_to :single_person, :class_name => 'Person', :foreign_key => :person_id, :inverse_of => :reader
end

class LazyReader < ActiveRecord::Base
  set_table_name 'readers'
  default_scope where(:skimmer => true)

  belongs_to :post
  belongs_to :person
end
