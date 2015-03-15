class Chef < ActiveRecord::Base
  belongs_to :employable, polymorphic: true
  has_many :recipes
end
