# frozen_string_literal: true

class Editor < ActiveRecord::Base
  self.primary_key = "name"

  has_one :publication, foreign_key: :editor_in_chief_id, inverse_of: :editor_in_chief
  has_many :editorships
end
