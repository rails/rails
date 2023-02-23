# frozen_string_literal: true

require "test_helper"
require "database/setup"

class ActiveStorage::AnalyzeJobTest < ActiveJob::TestCase
  class DownloadAnalyzer < ActiveStorage::Analyzer
    def self.accept?(blob)
      true
    end

    def metadata
      download_blob_to_tempfile
      {}
    end
  end

  setup do
    ActiveStorage.analyzers.append DownloadAnalyzer
    @blob = create_blob
  end

  teardown do
    ActiveStorage.analyzers.delete DownloadAnalyzer
  end

  test "ignores missing blob" do
    @blob.purge

    perform_enqueued_jobs do
      assert_nothing_raised do
        ActiveStorage::AnalyzeJob.perform_later @blob
      end
    end
  end

  test "ignores missing file" do
    @blob.service.delete(@blob.key)

    perform_enqueued_jobs do
      assert_nothing_raised do
        ActiveStorage::AnalyzeJob.perform_later @blob
      end
    end
  end
end
