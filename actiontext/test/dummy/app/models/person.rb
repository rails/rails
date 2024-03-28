class Person < ApplicationRecord
  include ActionText::Attachable

  def self.to_missing_attachable_partial_path
    "people/missing_attachable"
  end

  def to_editor_content_attachment_partial_path(editor_name)
    "people/editor_content_attachment"
  end

  def to_trix_content_attachment_partial_path
    to_editor_content_attachment_partial_path(:trix)
  end

  def to_attachable_partial_path
    "people/attachable"
  end
end
