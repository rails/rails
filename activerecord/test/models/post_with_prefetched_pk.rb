# frozen_string_literal: true

class PostWithPrefetchedPk < ActiveRecord::Base
  self.table_name = "posts"

  class << self
    def prefetch_primary_key?
      true
    end

    def next_sequence_value
      123456
    end
  end
end
