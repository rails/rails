# frozen_string_literal: true

module Cpk
  class ChapterDestroyAsync < ActiveRecord::Base
    self.table_name = :cpk_chapters
    self.primary_key = [:author_id, :id]

    belongs_to :book, foreign_key: [:author_id, :book_id], class_name: "Cpk::BookDestroyAsync"
  end
end
