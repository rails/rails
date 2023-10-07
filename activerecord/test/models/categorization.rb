# frozen_string_literal: true

class Categorization < ActiveRecord::Base
  belongs_to :post, optional: true
  belongs_to :category, counter_cache: true, optional: true
  belongs_to :named_category, class_name: "Category", foreign_key: :named_category_name, primary_key: :name, optional: true
  belongs_to :author, optional: true

  has_many :post_taggings, through: :author, source: :taggings

  belongs_to :author_using_custom_pk,  class_name: "Author", foreign_key: :author_id, primary_key: :author_address_extra_id, optional: true
  has_many   :authors_using_custom_pk, class_name: "Author", foreign_key: :id,        primary_key: :category_id
end

class SpecialCategorization < ActiveRecord::Base
  self.table_name = "categorizations"
  default_scope { where(special: true) }

  belongs_to :author, optional: true
  belongs_to :category, optional: true
end
