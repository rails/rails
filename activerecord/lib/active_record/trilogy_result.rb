# frozen_string_literal: true

module ActiveRecord
  class TrilogyResult < Result
    def last_insert_id
      @raw_result.last_insert_id
    end
  end
end
