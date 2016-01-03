class UuidParent < ActiveRecord::Base
  has_many :uuid_children
end
