# frozen_string_literal: true

require "test_helper"
require "active_support/core_ext/securerandom"

module ActiveStorage::Service::SharedServiceTests
  extend ActiveSupport::Concern

  FIXTURE_DATA = (+"\211PNG\r\n\032\n\000\000\000\rIHDR\000\000\000\020\000\000\000\020\001\003\000\000\000%=m\"\000\000\000\006PLTE\000\000\000\377\377\377\245\331\237\335\000\000\0003IDATx\234c\370\377\237\341\377_\206\377\237\031\016\2603\334?\314p\1772\303\315\315\f7\215\031\356\024\203\320\275\317\f\367\201R\314\f\017\300\350\377\177\000Q\206\027(\316]\233P\000\000\000\000IEND\256B`\202").force_encoding(Encoding::BINARY)

  included do
    setup do
      @key = SecureRandom.base58(24)
      @service = self.class.const_get(:SERVICE)
      @service.upload @key, StringIO.new(FIXTURE_DATA)
    end

    teardown do
      @service.delete @key
    end

    test "uploading with integrity" do
      key  = SecureRandom.base58(24)
      data = "Something else entirely!"
      @service.upload(key, StringIO.new(data), checksum: Digest::MD5.base64digest(data))

      assert_equal data, @service.download(key)
    ensure
      @service.delete key
    end

    test "uploading without integrity" do
      key  = SecureRandom.base58(24)
      data = "Something else entirely!"

      assert_raises(ActiveStorage::IntegrityError) do
        @service.upload(key, StringIO.new(data), checksum: Digest::MD5.base64digest("bad data"))
      end

      assert_not @service.exist?(key)
    ensure
      @service.delete key
    end

    test "uploading with integrity and multiple keys" do
      key  = SecureRandom.base58(24)
      data = "Something else entirely!"
      @service.upload(
        key,
        StringIO.new(data),
        checksum: Digest::MD5.base64digest(data),
        filename: "racecar.jpg",
        content_type: "image/jpg"
      )

      assert_equal data, @service.download(key)
    ensure
      @service.delete key
    end

    test "downloading" do
      assert_equal FIXTURE_DATA, @service.download(@key)
    end

    test "downloading a nonexistent file" do
      assert_raises(ActiveStorage::FileNotFoundError) do
        @service.download(SecureRandom.base58(24))
      end
    end

    test "downloading with index default" do
      key = SecureRandom.base58(24)
      expected_chunks = [ "a" * 5.megabytes, "b" ]
      actual_chunks = []
      expected_indexes = [0, 1]
      actual_indexes = []

      begin
        @service.upload key, StringIO.new(expected_chunks.join)

        @service.download_with_index key do |chunk, index|
          actual_chunks << chunk
          actual_indexes << index
        end

        assert_equal expected_chunks, actual_chunks, "Downloaded chunks did not match uploaded data"
        assert_equal expected_indexes, actual_indexes, "Downloaded indexes did not match uploaded data"
      ensure
        @service.delete key
      end
    end

    test "downloading with index value" do
      key = SecureRandom.base58(24)
      all_the_chunks = [ "a" * 5.megabytes, "b" ]
      expected_chunks = ["b"]
      actual_chunks = []
      expected_indexes = [1]
      actual_indexes = []
      index = 1

      begin
        @service.upload key, StringIO.new(all_the_chunks.join)

        @service.download_with_index(key, index) do |chunk, i|
          actual_chunks << chunk
          actual_indexes << i
        end

        assert_equal expected_chunks, actual_chunks, "Downloaded chunks did not match uploaded data"
        assert_equal expected_indexes, actual_indexes, "Downloaded indexes did not match uploaded data"
      ensure
        @service.delete key
      end
    end

    test "downloading in chunks" do
      key = SecureRandom.base58(24)
      expected_chunks = [ "a" * 5.megabytes, "b" ]
      actual_chunks = []

      begin
        @service.upload key, StringIO.new(expected_chunks.join)

        @service.download key do |chunk|
          actual_chunks << chunk
        end

        assert_equal expected_chunks, actual_chunks, "Downloaded chunks did not match uploaded data"
      ensure
        @service.delete key
      end
    end

    test "downloading a nonexistent file in chunks" do
      assert_raises(ActiveStorage::FileNotFoundError) do
        @service.download(SecureRandom.base58(24)) { }
      end
    end


    test "downloading partially" do
      assert_equal "\x10\x00\x00", @service.download_chunk(@key, 19..21)
      assert_equal "\x10\x00\x00", @service.download_chunk(@key, 19...22)
    end

    test "partially downloading a nonexistent file" do
      assert_raises(ActiveStorage::FileNotFoundError) do
        @service.download_chunk(SecureRandom.base58(24), 19..21)
      end
    end


    test "existing" do
      assert @service.exist?(@key)
      assert_not @service.exist?(@key + "nonsense")
    end

    test "deleting" do
      @service.delete @key
      assert_not @service.exist?(@key)
    end

    test "deleting nonexistent key" do
      assert_nothing_raised do
        @service.delete SecureRandom.base58(24)
      end
    end

    test "deleting by prefix" do
      key = SecureRandom.base58(24)

      @service.upload("#{key}/a/a/a", StringIO.new(FIXTURE_DATA))
      @service.upload("#{key}/a/a/b", StringIO.new(FIXTURE_DATA))
      @service.upload("#{key}/a/b/a", StringIO.new(FIXTURE_DATA))

      @service.delete_prefixed("#{key}/a/a/")
      assert_not @service.exist?("#{key}/a/a/a")
      assert_not @service.exist?("#{key}/a/a/b")
      assert @service.exist?("#{key}/a/b/a")
    ensure
      @service.delete("#{key}/a/a/a")
      @service.delete("#{key}/a/a/b")
      @service.delete("#{key}/a/b/a")
    end
  end
end
