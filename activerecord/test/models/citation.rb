class Citation < ActiveRecord::Base
  belongs_to :reference_of, class_name: "Book", foreign_key: :book2_id
end
