# frozen_string_literal: true

module Cpk
  class Comment < ActiveRecord::Base
    self.table_name = :cpk_comments
    belongs_to :commentable, class_name: "Cpk::Post", query_constraints: %i[commentable_title commentable_author], polymorphic: true
  end
end
