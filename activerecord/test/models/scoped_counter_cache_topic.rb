# frozen_string_literal: true

class ScopedCounterCacheTopic < ActiveRecord::Base
  self.table_name = "topics"
  self.inheritance_column = :_type_disabled

  has_many :replies, foreign_key: "parent_id", class_name: "Reply"

  default_scope :approved, -> { where(approved: true) }
  default_scope :first, -> { where(id: 1) }, all_queries: true
end
