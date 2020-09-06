# frozen_string_literal: true

require 'test_helper'
require 'database/setup'

class ActiveStorage::PurgeJobTest < ActiveJob::TestCase
  setup { @blob = create_blob }

  test 'purges' do
    assert_difference -> { ActiveStorage::Blob.count }, -1 do
      ActiveStorage::PurgeJob.perform_now @blob
    end

    assert_not ActiveStorage::Blob.exists?(@blob.id)
    assert_not ActiveStorage::Blob.service.exist?(@blob.key)
  end

  test 'ignores missing blob' do
    @blob.purge

    perform_enqueued_jobs do
      assert_nothing_raised do
        ActiveStorage::PurgeJob.perform_later @blob
      end
    end
  end
end
