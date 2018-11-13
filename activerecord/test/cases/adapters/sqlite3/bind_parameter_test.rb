# frozen_string_literal: true

require "cases/helper"
require "models/topic"

module ActiveRecord
  module ConnectionAdapters
    class SQLite3Adapter
      class BindParameterTest < ActiveRecord::SQLite3TestCase
        def test_too_many_binds
          topics = Topic.where(id: (1..999).to_a << 2**63)
          assert_equal Topic.count, topics.count

          topics = Topic.where.not(id: (1..999).to_a << 2**63)
          assert_equal 0, topics.count
        end
      end
    end
  end
end
