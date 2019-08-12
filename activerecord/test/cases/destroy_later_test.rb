# frozen_string_literal: true

require "cases/helper"
def setup_destroy_later
  ActiveRecord::Base.destroy_association_later_job = ActiveRecord::DestroyAssociationLaterJob
  ActiveRecord::Base.destroy_later_job = ActiveRecord::DestroyJob
  yield
ensure
  ActiveRecord::Base.destroy_association_later_job = false
  ActiveRecord::Base.destroy_later_job = false
end

setup_destroy_later do
  require "models/destroy_later_parent"
  require "models/content"
  require "models/book_destroy_later"
  require "models/essay_destroy_later"
  require "models/dl_keyed_belongs_to"
  require "models/dl_keyed_belongs_to_soft_delete"
  require "models/dl_keyed_has_one"
  require "models/dl_keyed_join"
  require "models/dl_keyed_has_many"
  require "models/dl_keyed_has_many_through"
  require "models/tag"
  require "models/tagging"
end


class DestroyLaterTest < ActiveRecord::TestCase
  include ActiveJob::TestHelper

  test "creating a destroy later parent enqueues it for unconditional destruction 10 days later" do
    setup_destroy_later do
      freeze_time

      dl_parent = DestroyLaterParent.create!()
      assert_enqueued_with job: ActiveRecord::DestroyJob, args: [ dl_parent, ensuring: nil ], at: 10.days.from_now

      travel 10.days

      assert_difference -> { DestroyLaterParent.count }, -1 do
        perform_enqueued_jobs only: ActiveRecord::DestroyJob
      end
    end
  end

  test "updating a destroy later parent does not enqueue it for destruction" do
    setup_destroy_later do
      dl_parent = DestroyLaterParent.create!()
      assert_no_enqueued_jobs only: ActiveRecord::DestroyJob do
        dl_parent.update!(name: "Hello")
      end
    end
  end

  test "updating a destroy later parent does not prevent its scheduled destruction" do
    setup_destroy_later do
      freeze_time

      dl_parent = DestroyLaterParent.create!()
      assert_enqueued_with job: ActiveRecord::DestroyJob, args: [ dl_parent, ensuring: nil ], at: 10.days.from_now

      travel 2.days

      dl_parent.update!(name: "Hello")

      travel 8.days

      assert_difference -> { DestroyLaterParent.count }, -1 do
        perform_enqueued_jobs only: ActiveRecord::DestroyJob
      end
    end
  end

  test "publishing a book destroy later enqueues it for destruction 30 days later" do
    setup_destroy_later do
      freeze_time
      book = BookDestroyLater.create

      assert_enqueued_with job: ActiveRecord::DestroyJob, args: [ book, ensuring: :published? ], at: 30.days.from_now do
        book.published!
      end

      travel 30.days

      assert_difference -> { BookDestroyLater.count }, -1 do
        perform_enqueued_jobs only: ActiveRecord::DestroyJob
      end
    end
  end

  test "creating a published book destroy later enqueues it for destruction 30 days later" do
    setup_destroy_later do
      freeze_time

      book = BookDestroyLater.create!(status: :published)
      assert_enqueued_with job: ActiveRecord::DestroyJob, args: [ book, ensuring: :published? ], at: 30.days.from_now

      travel 30.days

      assert_difference -> { BookDestroyLater.count }, -1 do
        perform_enqueued_jobs only: ActiveRecord::DestroyJob
      end
    end
  end

  test "unpublishing a book prevents its scheduled destruction" do
    setup_destroy_later do
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

  test "writing a book does not enqueue it for destruction" do
    setup_destroy_later do
      book = BookDestroyLater.create
      assert_no_enqueued_jobs do
        book.written!
      end
    end
  end
end
