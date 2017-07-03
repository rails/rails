require "test_helper"
require "fileutils"
require "tmpdir"
require "active_support/core_ext/securerandom"
require "active_file/site"

if ENV["GCS_PROJECT"] && ENV["GCS_KEYFILE"] && ENV["GCS_BUCKET"]
  class ActiveFile::GCSSiteTest < ActiveSupport::TestCase
    FIXTURE_KEY  = SecureRandom.base58(24).to_s
    FIXTURE_FILE = StringIO.new("Hello world!")

    setup do
      @site = ActiveFile::Sites::GCSSite.new(
        project: ENV["GCS_PROJECT"],
        keyfile: ENV["GCS_KEYFILE"],
        bucket: ENV["GCS_BUCKET"]
      )

      @site.upload FIXTURE_KEY, FIXTURE_FILE
      FIXTURE_FILE.rewind
    end

    teardown do
      @site.delete FIXTURE_KEY
      FIXTURE_FILE.rewind
    end

    test "uploading" do
      begin
        key  = SecureRandom.base58(24)
        data = "Something else entirely!"
        @site.upload(key, StringIO.new(data))

        assert_equal data, @site.download(key)
      ensure
        @site.delete key
      end
    end

    test "downloading" do
      assert_equal FIXTURE_FILE.read, @site.download(FIXTURE_KEY)
    end

    test "existing" do
      assert @site.exist?(FIXTURE_KEY)
      assert_not @site.exist?(FIXTURE_KEY + "nonsense")
    end

    test "deleting" do
      @site.delete FIXTURE_KEY
      assert_not @site.exist?(FIXTURE_KEY)
    end

    test "sizing" do
      assert_equal FIXTURE_FILE.size, @site.byte_size(FIXTURE_KEY)
    end

    test "checksumming" do
      assert_equal Digest::MD5.hexdigest(FIXTURE_FILE.read), @site.checksum(FIXTURE_KEY)
    end
  end
else
  puts "Skipping GCS Site tests because ENV variables are missing"
end
