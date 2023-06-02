# frozen_string_literal: true

module Cpk
  class Book < ActiveRecord::Base
    self.table_name = :cpk_books
    self.primary_key = [:author_id, :number]

    belongs_to :order, autosave: true, query_constraints: [:shop_id, :order_id]
    belongs_to :author, class_name: "Cpk::Author"
  end

  class BestSeller < Book
  end

  class BrokenBook < Book
    belongs_to :order
  end
end
