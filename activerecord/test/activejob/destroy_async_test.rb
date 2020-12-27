# frozen_string_literal: true

require "activejob/helper"

require "models/tag"
require "models/minivan"
require "models/bulb"

class UnusedDestroyAsync < ActiveRecord::Base
  self.destroy_async_job = nil
end


class DestroyAsyncTest < ActiveRecord::TestCase
  include ActiveJob::TestHelper

  test "running the job destroys the object" do
    tag = Tag.create!(name: "Der be treasure")
    tag.destroy_async
    assert_difference -> { Tag.count }, -1 do
      perform_enqueued_jobs only: ActiveRecord::DestroyAsyncJob
    end
  end

  test "destroy runs all callbacks" do
    funky = FunkyBulb.create!
    funky.destroy_async
    # The funky destroy throws a Runtime error in its before destroy
    assert_raises RuntimeError do
      perform_enqueued_jobs only: ActiveRecord::DestroyAsyncJob
    end
  end

  test "non-persisted objects cannot be enqueued" do
    tag = Tag.new(name: "Der be treasure")

    assert_raises ActiveRecord::DestroyAsyncError do
      tag.destroy_async
    end
  end

  test "cannot enqueue on a read only db" do
    van = Minivan.create!(name: "Der be treasure")
    van.destroy_async
  end

  test "destroying an all ready destroyed object in a job just passes" do
    tag = Tag.create!(name: "Der be treasure")
    tag.destroy_async
    tag.delete
    perform_enqueued_jobs only: ActiveRecord::DestroyAsyncJob
  end

  test "ActiveJob not present error" do
    record = UnusedDestroyAsync.create!
    assert_raises ActiveRecord::ActiveJobRequiredError do
      record.destroy_async
    end
  end
end
