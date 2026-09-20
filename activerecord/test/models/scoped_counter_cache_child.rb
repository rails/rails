# frozen_string_literal: true

class ScopedCounterCacheChild < ActiveRecord::Base
  self.table_name = "topics"
  self.inheritance_column = :_type_disabled

  belongs_to :parent, class_name: "ScopedCounterCacheTopic", foreign_key: "parent_id", counter_cache: "replies_count"
end
