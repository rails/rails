class Article < ActiveRecord::Base
  has_many :sections, :inverse_of => :article
  accepts_nested_attributes_for :sections
end
