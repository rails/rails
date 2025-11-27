# frozen_string_literal: true

require "test_helper"
require "minitest/mock"
require "active_support/log_subscriber/test_helper"
require "active_support/testing/event_reporter_assertions"
require "active_storage/structured_event_subscriber"
require "active_storage/log_subscriber"
require "database/setup"

module ActiveStorage
  class LogSubscriberTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::EventReporterAssertions

    setup do
    @logger = ActiveSupport::LogSubscriber::TestHelper::MockLogger.new
    @old_logger = ActiveStorage::LogSubscriber.logger
    ActiveStorage::LogSubscriber.logger = @logger
  end

    teardown do
      ActiveStorage::LogSubscriber.logger = @old_logger
    end

    def run(*)
      with_debug_event_reporting do
        super
      end
    end

    test "service_upload" do
      User.create!(name: "Test", avatar: { io: StringIO.new, filename: "avatar.jpg" })

      assert_equal 1, @logger.logged(:info).count
      assert_match(/Uploaded file/, @logger.logged(:info).first)
    end

    test "service_upload logs failure when exception occurs" do
      error = StandardError.new("Storage connection failed")

      IO.stub(:copy_stream, ->(*) { raise error }) do
        assert_raises(StandardError) do
          User.create!(name: "Test", avatar: { io: StringIO.new("test"), filename: "avatar.jpg" })
        end
      end

      assert_no_match(/Uploaded file/, @logger.logged(:info).join)
      assert_equal 1, @logger.logged(:error).count
      assert_match(/Failed to upload file/, @logger.logged(:error).first)
    end

    test "service_download" do
      blob = create_blob(filename: "avatar.jpg")
      user = User.create!(name: "Test", avatar: blob)

      user.avatar.download

      assert_equal 2, @logger.logged(:info).count
      assert_match(/Downloaded file/, @logger.logged(:info).last)
    end

    test "service_download logs failure when exception occurs" do
      blob = create_blob(filename: "avatar.jpg")
      user = User.create!(name: "Test", avatar: blob)
      @logger.clear

      error = StandardError.new("Storage read failed")

      File.stub(:binread, ->(*) { raise error }) do
        assert_raises(StandardError) do
          user.avatar.download
        end
      end

      assert_no_match(/Downloaded file/, @logger.logged(:info).join)
      assert_equal 1, @logger.logged(:error).count
      assert_match(/Failed to download file/, @logger.logged(:error).first)
    end

    test "service_streaming_download" do
      blob = create_blob(filename: "avatar.jpg")
      user = User.create!(name: "Test", avatar: blob)

      user.avatar.download { }

      assert_equal 2, @logger.logged(:info).count
      assert_match(/Downloaded file/, @logger.logged(:info).last)
    end

    test "service_streaming_download logs failure when exception occurs" do
      blob = create_blob(filename: "avatar.jpg")
      user = User.create!(name: "Test", avatar: blob)
      @logger.clear

      error = StandardError.new("Storage stream failed")

      # stream method uses File.open inside the instrument block
      original_open = File.method(:open)
      File.stub(:open, ->(path, *args, &block) {
        if path.include?(user.avatar.key)
          raise error
        else
          original_open.call(path, *args, &block)
        end
      }) do
        assert_raises(StandardError) do
          user.avatar.download { }
        end
      end

      assert_no_match(/Downloaded file/, @logger.logged(:info).join)
      assert_equal 1, @logger.logged(:error).count
      assert_match(/Failed to download file/, @logger.logged(:error).first)
    end

    test "preview" do
      blob = create_file_blob(filename: "cropped.pdf", content_type: "application/pdf")
      user = User.create!(name: "Test", avatar: blob)

      user.avatar.preview(resize_to_limit: [640, 280]).processed

      assert_equal 6, @logger.logged(:info).count
      assert_match(/Previewed file/, @logger.logged(:info)[2])
    end

    test "service_delete" do
      blob = create_blob(filename: "avatar.jpg")
      user = User.create!(name: "Test", avatar: blob)

      user.avatar.purge

      assert_equal 2, @logger.logged(:info).count
      assert_match(/Deleted file/, @logger.logged(:info).last)
    end

    test "service_delete logs failure when exception occurs" do
      blob = create_blob(filename: "avatar.jpg")
      user = User.create!(name: "Test", avatar: blob)
      @logger.clear

      error = StandardError.new("Storage delete failed")

      File.stub(:delete, ->(*) { raise error }) do
        assert_raises(StandardError) do
          user.avatar.service.delete(user.avatar.key)
        end
      end

      assert_no_match(/Deleted file/, @logger.logged(:info).join)
      assert_equal 1, @logger.logged(:error).count
      assert_match(/Failed to delete file/, @logger.logged(:error).first)
    end

    test "service_delete_prefixed" do
      blob = create_file_blob(fixture: "colors.bmp")
      user = User.create!(name: "Test", avatar: blob)

      user.avatar.purge

      assert_equal 3, @logger.logged(:info).count
      assert_match(/Deleted files by key prefix/, @logger.logged(:info).last)
    end

    test "service_delete_prefixed logs failure when exception occurs" do
      blob = create_blob(filename: "avatar.jpg")
      user = User.create!(name: "Test", avatar: blob)
      @logger.clear

      error = StandardError.new("Storage delete prefixed failed")

      Dir.stub(:glob, ->(*) { raise error }) do
        assert_raises(StandardError) do
          user.avatar.service.delete_prefixed("test-prefix/")
        end
      end

      assert_no_match(/Deleted files by key prefix/, @logger.logged(:info).join)
      assert_equal 1, @logger.logged(:error).count
      assert_match(/Failed to delete files by key prefix/, @logger.logged(:error).first)
    end

    test "service_exist" do
      blob = create_blob(filename: "avatar.jpg")
      user = User.create!(name: "Test", avatar: blob)

      user.avatar.service.exist? user.avatar.key

      assert_equal 1, @logger.logged(:debug).count
      assert_match(/Checked if file exists/, @logger.logged(:debug).last)
    end

    test "service_exist logs failure when exception occurs" do
      blob = create_blob(filename: "avatar.jpg")
      user = User.create!(name: "Test", avatar: blob)
      @logger.clear

      error = StandardError.new("Storage exist check failed")

      File.stub(:exist?, ->(*) { raise error }) do
        assert_raises(StandardError) do
          user.avatar.service.exist?(user.avatar.key)
        end
      end

      assert_no_match(/Checked if file exists/, @logger.logged(:debug).join)
      assert_equal 1, @logger.logged(:error).count
      assert_match(/Failed to check if file exists/, @logger.logged(:error).first)
    end

    test "service_url" do
      blob = create_blob(filename: "avatar.jpg")
      user = User.create!(name: "Test", avatar: blob)

      user.avatar.url

      assert_equal 1, @logger.logged(:debug).count
      assert_match(/Generated URL for file/, @logger.logged(:debug).last)
    end

    test "service_url logs failure when exception occurs" do
      blob = create_blob(filename: "avatar.jpg")
      user = User.create!(name: "Test", avatar: blob)
      @logger.clear

      error = StandardError.new("URL generation failed")

      ActiveStorage.stub(:verifier, -> { raise error }) do
        assert_raises(StandardError) do
          user.avatar.service.url(user.avatar.key, expires_in: 5.minutes, disposition: :inline,
            filename: ActiveStorage::Filename.new("test.jpg"), content_type: "image/jpeg")
        end
      end

      assert_no_match(/Generated URL for file/, @logger.logged(:debug).join)
      assert_equal 1, @logger.logged(:error).count
      assert_match(/Failed to generate URL for file/, @logger.logged(:error).first)
    end

    test "service_mirror" do
      blob = create_blob(filename: "avatar.jpg")

      mirror_config = (1..3).to_h do |i|
        [ "mirror_#{i}",
          service: "Disk",
          root: Dir.mktmpdir("active_storage_tests_mirror_#{i}") ]
      end

      config = mirror_config.merge \
        mirror:  { service: "Mirror", primary: "primary", mirrors: mirror_config.keys },
        primary: { service: "Disk", root: Dir.mktmpdir("active_storage_tests_primary") }

      service = ActiveStorage::Service.configure :mirror, config
      service.upload blob.key, StringIO.new(blob.download), checksum: blob.checksum

      service.mirror blob.key, checksum: blob.checksum

      assert_equal 4, @logger.logged(:debug).count
      assert_match(/Mirrored file/, @logger.logged(:debug).last)
    end

    test "service_mirror logs failure when exception occurs" do
      blob = create_blob(filename: "avatar.jpg")
      @logger.clear

      mirror_config = (1..3).to_h do |i|
        [ "mirror_#{i}",
          service: "Disk",
          root: Dir.mktmpdir("active_storage_tests_mirror_#{i}") ]
      end

      config = mirror_config.merge \
        mirror:  { service: "Mirror", primary: "primary", mirrors: mirror_config.keys },
        primary: { service: "Disk", root: Dir.mktmpdir("active_storage_tests_primary") }

      service = ActiveStorage::Service.configure :mirror, config
      service.upload blob.key, StringIO.new(blob.download), checksum: blob.checksum
      @logger.clear

      error = StandardError.new("Mirror failed")

      # Mirror uses IO.copy_stream inside instrument block
      IO.stub(:copy_stream, ->(*) { raise error }) do
        assert_raises(StandardError) do
          service.mirror blob.key, checksum: blob.checksum
        end
      end

      assert_no_match(/Mirrored file/, @logger.logged(:debug).join)
      assert @logger.logged(:error).count >= 1
      assert @logger.logged(:error).any? { |msg| msg.include?("Failed to mirror file") }
    end
  end
end
