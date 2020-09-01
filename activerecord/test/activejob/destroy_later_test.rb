# frozen_string_literal: true

require "cases/helper"
require "activejob/helper"

require "models/destroy_later_parent"
require "models/book_destroy_later"

class DestroyLaterTest < ActiveRecord::TestCase
  include ActiveJob::TestHelper

  test ".destroy_later enqueues a job to destroy the record after the configured time after it is created" do
    freeze_time

    dl_parent = DestroyLaterParent.create!
    assert_enqueued_with job: ActiveRecord::DestroyJob, args: [ dl_parent, ensuring: nil ], at: 10.days.from_now

    travel 10.days

    assert_difference -> { DestroyLaterParent.count }, -1 do
      perform_enqueued_jobs only: ActiveRecord::DestroyJob
    end
  end

  test "updating a record configured to automatically be destroyed does not enqueue it for destruction" do
    dl_parent = DestroyLaterParent.create!
    assert_no_enqueued_jobs only: ActiveRecord::DestroyJob do
      dl_parent.update!(name: "Hello")
    end
  end

  test "updating a record configured to automatically be destroyed does not prevent its scheduled destruction" do
    freeze_time

    dl_parent = DestroyLaterParent.create!
    assert_enqueued_with job: ActiveRecord::DestroyJob, args: [ dl_parent, ensuring: nil ], at: 10.days.from_now

    travel 2.days

    dl_parent.update!(name: "Hello")

    travel 8.days

    assert_difference -> { DestroyLaterParent.count }, -1 do
      perform_enqueued_jobs only: ActiveRecord::DestroyJob
    end
  end

  test ".destroy_later respects the `if:` option" do
    freeze_time

    book = BookDestroyLater.create
    assert_no_enqueued_jobs

    assert_enqueued_with job: ActiveRecord::DestroyJob, args: [ book, ensuring: :published? ], at: 30.days.from_now do
      book.published!
    end

    travel 30.days

    assert_difference -> { BookDestroyLater.count }, -1 do
      perform_enqueued_jobs only: ActiveRecord::DestroyJob
    end
  end

  test ".destroy_later works when the `if:` option is met on creation" do
    freeze_time

    book = BookDestroyLater.create!(status: :published)
    assert_enqueued_with job: ActiveRecord::DestroyJob, args: [ book, ensuring: :published? ], at: 30.days.from_now

    travel 30.days

    assert_difference -> { BookDestroyLater.count }, -1 do
      perform_enqueued_jobs only: ActiveRecord::DestroyJob
    end
  end

  test ".destroy_later uses the `ensuring:` option to make sure a condition is met when destroying the record" do
    freeze_time

    book = BookDestroyLater.create
    assert_enqueued_with job: ActiveRecord::DestroyJob, args: [ book, ensuring: :published? ], at: 30.days.from_now do
      book.published!
    end

    travel 10.days

    assert_no_enqueued_jobs do
      book.proposed!
    end

    travel 20.days

    assert_no_difference -> { BookDestroyLater.count } do
      perform_enqueued_jobs only: ActiveRecord::DestroyJob
    end
  end
end
