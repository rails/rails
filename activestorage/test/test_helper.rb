# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"
require_relative "dummy/config/environment.rb"

require "bundler/setup"
require "active_support"
require "active_support/test_case"
require "active_support/testing/autorun"
require "mini_magick"

begin
  require "byebug"
rescue LoadError
end

require "active_job"
ActiveJob::Base.queue_adapter = :test
ActiveJob::Base.logger = ActiveSupport::Logger.new(nil)

# Filter out Minitest backtrace while allowing backtrace from other libraries
# to be shown.
Minitest.backtrace_filter = Minitest::BacktraceFilter.new

require "yaml"
SERVICE_CONFIGURATIONS = begin
  erb = ERB.new(Pathname.new(File.expand_path("service/configurations.yml", __dir__)).read)
  configuration = YAML.load(erb.result) || {}
  configuration.deep_symbolize_keys
rescue Errno::ENOENT
  puts "Missing service configuration file in test/service/configurations.yml"
  {}
end

require "tmpdir"
ActiveStorage::Blob.service = ActiveStorage::Service::DiskService.new(root: Dir.mktmpdir("active_storage_tests"))

ActiveStorage.logger = ActiveSupport::Logger.new(nil)
ActiveStorage.verifier = ActiveSupport::MessageVerifier.new("Testing")

class ActiveSupport::TestCase
  self.file_fixture_path = File.expand_path("fixtures/files", __dir__)

  private
    def create_blob(data: "Hello world!", filename: "hello.txt", content_type: "text/plain")
      ActiveStorage::Blob.create_after_upload! io: StringIO.new(data), filename: filename, content_type: content_type
    end

    def create_file_blob(filename: "racecar.jpg", content_type: "image/jpeg", metadata: nil)
      ActiveStorage::Blob.create_after_upload! io: file_fixture(filename).open, filename: filename, content_type: content_type, metadata: metadata
    end

    def create_blob_before_direct_upload(filename: "hello.txt", byte_size:, checksum:, content_type: "text/plain")
      ActiveStorage::Blob.create_before_direct_upload! filename: filename, byte_size: byte_size, checksum: checksum, content_type: content_type
    end

    def directly_upload_file_blob(filename: "racecar.jpg", content_type: "image/jpeg")
      file = file_fixture(filename)
      byte_size = file.size
      checksum = Digest::MD5.file(file).base64digest

      create_blob_before_direct_upload(filename: filename, byte_size: byte_size, checksum: checksum, content_type: content_type).tap do |blob|
        ActiveStorage::Blob.service.upload(blob.key, file.open)
      end
    end

    def read_image(blob_or_variant)
      MiniMagick::Image.open blob_or_variant.service.send(:path_for, blob_or_variant.key)
    end
end

require "global_id"
GlobalID.app = "ActiveStorageExampleApp"
ActiveRecord::Base.send :include, GlobalID::Identification

class User < ActiveRecord::Base
  has_one_attached :avatar
  has_one_attached :cover_photo, dependent: false

  has_many_attached :highlights
  has_many_attached :vlogs, dependent: false
end
