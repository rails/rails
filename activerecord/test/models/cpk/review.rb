# frozen_string_literal: true

module Cpk
  class Review < ActiveRecord::Base
    self.table_name = :cpk_reviews

    belongs_to :book, class_name: "Cpk::Book", query_constraints: [:author_id, :number]
  end
end
