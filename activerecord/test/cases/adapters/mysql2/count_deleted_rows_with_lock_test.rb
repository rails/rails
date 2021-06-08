# frozen_string_literal: true

require "cases/helper"
require "support/connection_helper"
require "models/author"
require "models/bulb"
require "models/car"

module ActiveRecord
  class CountDeletedRowsWithLockTest < ActiveRecord::Mysql2TestCase
    test "delete and create in different threads synchronize correctly" do
      Bulb.unscoped.delete_all
      Bulb.create!(name: "Jimmy", color: "blue")

      delete_thread = Thread.new do
        Bulb.unscoped.delete_all
      end

      create_thread = Thread.new do
        Author.create!(name: "Tommy")
      end

      delete_thread.join
      create_thread.join

      assert_equal 1, delete_thread.value
    end
  end
end
