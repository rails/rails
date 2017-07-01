require "test_helper"
require "database/setup"
require "active_file/blob"

ActiveFile::Blob.site = ActiveFile::Sites::DiskSite.new(File.join(Dir.tmpdir, "active_file"))

class ActiveFile::BlobTest < ActiveSupport::TestCase
  test "create after upload" do
    blob = ActiveFile::Blob.create_after_upload! data: StringIO.new("Hello world!"), filename: "hello.txt", content_type: "text/plain"
    assert_equal "Hello world!", blob.download
  end
end
