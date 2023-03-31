class Person < ApplicationRecord
  include ActionText::Attachable

  def self.to_missing_attachable_partial_path
    "people/missing_attachable"
  end

  def to_trix_content_attachment_partial_path
    "people/trix_content_attachment"
  end

  def to_attachable_partial_path
    "people/attachable"
  end
end
