require "test_helper"
require "database/setup"
require "active_file/blob"

ActiveFile::Blob.site = ActiveFile::Sites::DiskSite.new(root: File.join(Dir.tmpdir, "active_file"))

class ActiveFile::BlobTest < ActiveSupport::TestCase
  test "create after upload sets byte size and checksum" do
    data = "Hello world!"
    blob = ActiveFile::Blob.create_after_upload! data: StringIO.new(data), filename: "hello.txt", content_type: "text/plain"

    assert_equal data, blob.download
    assert_equal data.length, blob.byte_size
    assert_equal Digest::MD5.hexdigest(data), blob.checksum
  end
end
