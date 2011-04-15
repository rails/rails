class Categorization < ActiveRecord::Base
  belongs_to :post
  belongs_to :category
  belongs_to :author

  belongs_to :author_using_custom_pk, :class_name => 'Author', :foreign_key => :author_id, :primary_key => :author_address_extra_id
  has_many :authors_using_custom_pk, :class_name => 'Author', :foreign_key => :id, :primary_key => :category_id
end
