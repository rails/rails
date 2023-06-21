# frozen_string_literal: true

module Cpk
  class Book < ActiveRecord::Base
    self.table_name = :cpk_books

    belongs_to :order, autosave: true, query_constraints: [:shop_id, :order_id]
    belongs_to :author, class_name: "Cpk::Author"

    has_many :chapters, query_constraints: [:author_id, :book_number]
  end

  class BestSeller < Book
  end

  class BrokenBook < Book
    belongs_to :order
  end

  class NullifiedBook < Book
    has_one :chapter, query_constraints: [:author_id, :book_number], dependent: :nullify
  end
end
