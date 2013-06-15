require 'models/man'

class Face < ActiveRecord::Base
  belongs_to :man, :inverse_of => :face
  belongs_to :polymorphic_man, :polymorphic => true, :inverse_of => :polymorphic_face
  # These is a "broken" inverse_of for the purposes of testing
  belongs_to :horrible_man, :class_name => 'Man', :inverse_of => :horrible_face
  belongs_to :horrible_polymorphic_man, :polymorphic => true, :inverse_of => :horrible_polymorphic_face
end

class FaceWithUnscopedMan < ActiveRecord::Base
  self.table_name = 'faces'
  belongs_to :man, -> { unscoped }, class_name: ManWithCoolScope
end

class FaceWithUnscopeWhereMan < ActiveRecord::Base
  self.table_name = 'faces'
  belongs_to :man, -> { unscope(:where) }, class_name: ManWithCoolScope
end

class FaceWithExceptWhereMan < ActiveRecord::Base
  self.table_name = 'faces'
  belongs_to :man, -> { except(:where) }, class_name: ManWithCoolScope
end
