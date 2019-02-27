class Person < ApplicationRecord
  include ActionText::Attachable

  has_one :post

  accepts_nested_attributes_for :post

  def to_trix_content_attachment_partial_path
    "people/trix_content_attachment"
  end
end
