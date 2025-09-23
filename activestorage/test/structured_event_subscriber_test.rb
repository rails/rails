# frozen_string_literal: true

require "test_helper"
require "active_support/testing/event_reporter_assertions"
require "active_storage/structured_event_subscriber"
require "database/setup"

module ActiveStorage
  class StructuredEventSubscriberTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::EventReporterAssertions

    test "service_upload" do
      assert_event_reported("active_storage.service_upload", payload: { key: /.*/, checksum: /.*/ }) do
        User.create!(name: "Test", avatar: { io: StringIO.new, filename: "avatar.jpg" })
      end
    end

    test "service_download" do
      blob = create_blob(filename: "avatar.jpg")
      user = User.create!(name: "Test", avatar: blob)

      assert_event_reported("active_storage.service_download", payload: { key: user.avatar.key }) do
        user.avatar.download
      end
    end

    test "service_streaming_download" do
      blob = create_blob(filename: "avatar.jpg")
      user = User.create!(name: "Test", avatar: blob)

      assert_event_reported("active_storage.service_streaming_download", payload: { key: user.avatar.key }) do
        user.avatar.download { }
      end
    end

    test "preview" do
      blob = create_file_blob(filename: "cropped.pdf", content_type: "application/pdf")
      user = User.create!(name: "Test", avatar: blob)

      assert_event_reported("active_storage.preview", payload: { key: user.avatar.key }) do
        user.avatar.preview(resize_to_limit: [640, 280]).processed
      end
    end

    test "service_delete" do
      blob = create_blob(filename: "avatar.jpg")
      user = User.create!(name: "Test", avatar: blob)

      assert_event_reported("active_storage.service_delete", payload: { key: user.avatar.key }) do
        user.avatar.purge
      end
    end

    test "service_delete_prefixed" do
      blob = create_file_blob(fixture: "colors.bmp")
      user = User.create!(name: "Test", avatar: blob)

      assert_event_reported("active_storage.service_delete_prefixed", payload: { prefix: /variants\/.*/ }) do
        user.avatar.purge
      end
    end

    test "service_exist" do
      blob = create_blob(filename: "avatar.jpg")
      user = User.create!(name: "Test", avatar: blob)

      with_debug_event_reporting do
        assert_event_reported("active_storage.service_exist", payload: { key: /.*/, exist: true }) do
          user.avatar.service.exist? user.avatar.key
        end
      end
    end

    test "service_url" do
      blob = create_blob(filename: "avatar.jpg")
      user = User.create!(name: "Test", avatar: blob)

      with_debug_event_reporting do
        assert_event_reported("active_storage.service_url", payload: { key: /.*/, url: /.*/ }) do
          user.avatar.url
        end
      end
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

      with_debug_event_reporting do
        assert_event_reported("active_storage.service_mirror", payload: { key: /.*/, url: /.*/ }) do
          service.mirror blob.key, checksum: blob.checksum
        end
      end
    end
  end
end
