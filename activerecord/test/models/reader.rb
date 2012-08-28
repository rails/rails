class Reader < ActiveRecord::Base
  belongs_to :post
  belongs_to :person, :inverse_of => :readers
  belongs_to :single_person, :class_name => 'Person', :foreign_key => :person_id, :inverse_of => :reader
end

class SecureReader < ActiveRecord::Base
  self.table_name = "readers"

  belongs_to :secure_post, :class_name => "Post", :foreign_key => "post_id"
  belongs_to :secure_person, :inverse_of => :secure_readers, :class_name => "Person", :foreign_key => "person_id"

  attr_accessible nil
end

class LazyReader < ActiveRecord::Base
  self.table_name = 'readers'
  default_scope where(:skimmer => true)

  belongs_to :post
  belongs_to :person
end
