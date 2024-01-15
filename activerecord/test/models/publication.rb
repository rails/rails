# frozen_string_literal: true

class Publication < ActiveRecord::Base
  belongs_to :editor_in_chief, class_name: "Editor", inverse_of: :publication, optional: true
  has_many :editorships
  has_many :editors, through: :editorships

  after_initialize do
    self.editor_in_chief = build_editor_in_chief(name: "John Doe")
  end

  after_save_commit :touch_name
  def touch_name
    self.name = "#{name} (touched)"
  end
end
