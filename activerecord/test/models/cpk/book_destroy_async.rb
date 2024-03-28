# frozen_string_literal: true

module Cpk
  class BookDestroyAsync < ActiveRecord::Base
    self.table_name = :cpk_books

    has_many :chapters, query_constraints: [:author_id, :book_id], class_name: "Cpk::ChapterDestroyAsync", dependent: :destroy_async
  end
end
