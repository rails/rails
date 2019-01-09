# frozen_string_literal: true

require "cases/helper"

require "models/book"
require "models/pirate"
require "models/parrot"

class DestroyLaterTest < ActiveRecord::TestCase
  include ActiveJob::TestHelper

  fixtures :books, :pirates

  test "creating a pirate enqueues it for unconditional destruction 10 days later" do
    freeze_time

    pirate = Pirate.create!(catchphrase: "Arr, matey!")
    assert_enqueued_with job: ActiveRecord::DestroyJob, args: [ pirate, ensuring: nil ], at: 10.days.from_now

    travel 10.days

    assert_difference -> { Pirate.count }, -1 do
      perform_enqueued_jobs only: ActiveRecord::DestroyJob
    end
  end

  test "updating a pirate does not enqueue it for destruction" do
    assert_no_enqueued_jobs only: ActiveRecord::DestroyJob do
      pirates(:redbeard).update! catchphrase: "Shiver me timbers!"
    end
  end

  test "updating a pirate does not prevent its scheduled destruction" do
    freeze_time

    pirate = Pirate.create!(catchphrase: "Arr, matey!")
    assert_enqueued_with job: ActiveRecord::DestroyJob, args: [ pirate, ensuring: nil ], at: 10.days.from_now

    travel 2.days

    pirate.update! catchphrase: "Shiver me timbers!"

    travel 8.days

    assert_difference -> { Pirate.count }, -1 do
      perform_enqueued_jobs only: ActiveRecord::DestroyJob
    end
  end

  test "publishing a book enqueues it for destruction 30 days later" do
    freeze_time

    assert_enqueued_with job: ActiveRecord::DestroyJob, args: [ books(:rfr), ensuring: :published? ], at: 30.days.from_now do
      books(:rfr).published!
    end

    travel 30.days

    assert_difference -> { Book.count }, -1 do
      perform_enqueued_jobs only: ActiveRecord::DestroyJob
    end
  end

  test "creating a published book enqueues it for destruction 30 days later" do
    freeze_time

    book = Book.create!(name: "Getting Real", status: :published)
    assert_enqueued_with job: ActiveRecord::DestroyJob, args: [ book, ensuring: :published? ], at: 30.days.from_now

    travel 30.days

    assert_difference -> { Book.count }, -1 do
      perform_enqueued_jobs only: ActiveRecord::DestroyJob
    end
  end

  test "unpublishing a book prevents its scheduled destruction" do
    freeze_time

    assert_enqueued_with job: ActiveRecord::DestroyJob, args: [ books(:rfr), ensuring: :published? ], at: 30.days.from_now do
      books(:rfr).published!
    end

    travel 10.days

    assert_no_enqueued_jobs do
      books(:rfr).proposed!
    end

    travel 20.days

    assert_no_difference -> { Book.count } do
      perform_enqueued_jobs only: ActiveRecord::DestroyJob
    end
  end

  test "writing a book does not enqueue it for destruction" do
    assert_no_enqueued_jobs do
      books(:rfr).written!
    end
  end
end
