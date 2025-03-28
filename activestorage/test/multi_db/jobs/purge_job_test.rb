# frozen_string_literal: true

require "multi_db_test_helper"
require "database/setup"

class ActiveStorage::PurgeJobTest < ActiveJob::TestCase
  setup do
    @main_blob = create_main_blob
    @animals_blob = create_animals_blob
  end

  test "purge main" do
    assert_difference -> { ActiveStorage::MainBlob.count }, -1 do
      ActiveStorage::PurgeJob.perform_now @main_blob
    end

    assert_not ActiveStorage::MainBlob.exists?(@main_blob.id)
    assert_not ActiveStorage::MainBlob.service.exist?(@main_blob.key)
  end

  test "purge animals" do
    assert_difference -> { ActiveStorage::AnimalsBlob.count }, -1 do
      ActiveStorage::PurgeJob.perform_now @animals_blob
    end

    assert_not ActiveStorage::AnimalsBlob.exists?(@animals_blob.id)
    assert_not ActiveStorage::AnimalsBlob.service.exist?(@animals_blob.key)
  end

  test "ignores missing main blob" do
    @main_blob.purge

    perform_enqueued_jobs do
      assert_nothing_raised do
        ActiveStorage::PurgeJob.perform_later @main_blob
      end
    end
  end

  test "ignores missing animals blob" do
    @animals_blob.purge

    perform_enqueued_jobs do
      assert_nothing_raised do
        ActiveStorage::PurgeJob.perform_later @animals_blob
      end
    end
  end
end
