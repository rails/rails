# frozen_string_literal: true

module Cpk
  class Book < ActiveRecord::Base
    self.table_name = :cpk_books
    self.primary_key = [:author_id, :number]
  end

  class BestSeller < Book
  end
end
