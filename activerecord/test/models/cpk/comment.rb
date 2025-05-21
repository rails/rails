# frozen_string_literal: true

module Cpk
  class Comment < ActiveRecord::Base
    self.table_name = :cpk_comments
    belongs_to :commentable, class_name: "Cpk::Post", foreign_key: %i[commentable_title commentable_author], polymorphic: true
    belongs_to :post, class_name: "Cpk::Post", foreign_key: %i[commentable_title commentable_author]
  end
end
