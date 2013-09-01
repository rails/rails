class Citation < ActiveRecord::Base
  belongs_to :reference_of, :class_name => "Book", :foreign_key => :book2_id

  belongs_to :book1, :class_name => "Book", :foreign_key => :book1_id
  belongs_to :book2, :class_name => "Book", :foreign_key => :book2_id
end
