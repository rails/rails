require "test_helper"
require "active_support/core_ext/securerandom"

module ActiveFile::Sites::SharedSiteTests
  extend ActiveSupport::Concern
  
  FIXTURE_KEY  = SecureRandom.base58(24)
  FIXTURE_FILE = StringIO.new("Hello world!")

  included do
    setup do
      @site = self.class.const_get(:SITE)
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
end
