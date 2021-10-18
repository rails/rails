class Folder < ActiveRecord::Base
  belongs_to :folder, required: false #, inverse_of: :things
  has_many :folders #, inverse_of: :folder
end
