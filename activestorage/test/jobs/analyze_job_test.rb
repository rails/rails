# frozen_string_literal: true

require 'test_helper'
require 'database/setup'

class ActiveStorage::AnalyzeJobTest < ActiveJob::TestCase
  setup { @blob = create_blob }

  test 'ignores missing blob' do
    @blob.purge

    perform_enqueued_jobs do
      assert_nothing_raised do
        ActiveStorage::AnalyzeJob.perform_later @blob
      end
    end
  end
end
