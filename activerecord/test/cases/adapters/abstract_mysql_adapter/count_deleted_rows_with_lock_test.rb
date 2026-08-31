# frozen_string_literal: true

require "cases/helper"
require "support/connection_helper"
require "models/author"
require "models/bulb"
require "models/car"

module ActiveRecord
  class CountDeletedRowsWithLockTest < ActiveRecord::AbstractMysqlTestCase
    test "delete and create in different threads synchronize correctly" do
      expected_count = 13

      Bulb.unscoped.delete_all
      expected_count.times do |i|
        Bulb.create!(name: "Jimmy #{i}", color: "blue")
      end

      delete_thread = Thread.new do
        Bulb.unscoped.delete_all
      end

      create_thread = Thread.new do
        Author.create!(name: "Tommy")
      end

      delete_thread.join
      create_thread.join

      assert_equal expected_count, delete_thread.value
    end
  end
end
