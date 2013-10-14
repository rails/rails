class Chef < ActiveRecord::Base
  belongs_to :employable, polymorphic: true
end
