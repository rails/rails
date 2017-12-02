# frozen_string_literal: true

require "test_helper"
require "active_support/core_ext/securerandom"

module ActiveStorage::Service::SharedServiceTests
  extend ActiveSupport::Concern

  FIXTURE_KEY  = SecureRandom.base58(24)
  FIXTURE_DATA = "\211PNG\r\n\032\n\000\000\000\rIHDR\000\000\000\020\000\000\000\020\001\003\000\000\000%=m\"\000\000\000\006PLTE\000\000\000\377\377\377\245\331\237\335\000\000\0003IDATx\234c\370\377\237\341\377_\206\377\237\031\016\2603\334?\314p\1772\303\315\315\f7\215\031\356\024\203\320\275\317\f\367\201R\314\f\017\300\350\377\177\000Q\206\027(\316]\233P\000\000\000\000IEND\256B`\202".dup.force_encoding(Encoding::BINARY)

  included do
    setup do
      @service = self.class.const_get(:SERVICE)
      @service.upload FIXTURE_KEY, StringIO.new(FIXTURE_DATA)
    end

    teardown do
      @service.delete FIXTURE_KEY
    end

    test "uploading with integrity" do
      begin
        key  = SecureRandom.base58(24)
        data = "Something else entirely!"
        @service.upload(key, StringIO.new(data), checksum: Digest::MD5.base64digest(data))

        assert_equal data, @service.download(key)
      ensure
        @service.delete key
      end
    end

    test "uploading without integrity" do
      begin
        key  = SecureRandom.base58(24)
        data = "Something else entirely!"

        assert_raises(ActiveStorage::IntegrityError) do
          @service.upload(key, StringIO.new(data), checksum: Digest::MD5.base64digest("bad data"))
        end

        assert_not @service.exist?(key)
      ensure
        @service.delete key
      end
    end

    test "downloading" do
      assert_equal FIXTURE_DATA, @service.download(FIXTURE_KEY)
    end

    test "downloading in chunks" do
      chunks = []

      @service.download(FIXTURE_KEY) do |chunk|
        chunks << chunk
      end

      assert_equal [ FIXTURE_DATA ], chunks
    end

    test "existing" do
      assert @service.exist?(FIXTURE_KEY)
      assert_not @service.exist?(FIXTURE_KEY + "nonsense")
    end

    test "deleting" do
      @service.delete FIXTURE_KEY
      assert_not @service.exist?(FIXTURE_KEY)
    end

    test "deleting nonexistent key" do
      assert_nothing_raised do
        @service.delete SecureRandom.base58(24)
      end
    end

    test "deleting by prefix" do
      begin
        @service.upload("a/a/a", StringIO.new(FIXTURE_DATA))
        @service.upload("a/a/b", StringIO.new(FIXTURE_DATA))
        @service.upload("a/b/a", StringIO.new(FIXTURE_DATA))

        @service.delete_prefixed("a/a/")
        assert_not @service.exist?("a/a/a")
        assert_not @service.exist?("a/a/b")
        assert @service.exist?("a/b/a")
      ensure
        @service.delete("a/a/a")
        @service.delete("a/a/b")
        @service.delete("a/b/a")
      end
    end
  end
end
