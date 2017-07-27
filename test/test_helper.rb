require File.expand_path("../../test/dummy/config/environment.rb", __FILE__)

require "bundler/setup"
require "active_support"
require "active_support/test_case"
require "active_support/testing/autorun"
require "byebug"

require "active_job"
ActiveJob::Base.queue_adapter = :test
ActiveJob::Base.logger = nil

require "active_storage"

require "yaml"
SERVICE_CONFIGURATIONS = begin
  YAML.load_file(File.expand_path("../service/configurations.yml", __FILE__)).deep_symbolize_keys
rescue Errno::ENOENT
  puts "Missing service configuration file in test/service/configurations.yml"
  {}
end

require "tmpdir"
ActiveStorage::Blob.service = ActiveStorage::Service::DiskService.new(root: Dir.mktmpdir("active_storage_tests"))
ActiveStorage::Service.logger = ActiveSupport::Logger.new(STDOUT)

ActiveStorage.verifier = ActiveSupport::MessageVerifier.new("Testing")

class ActiveSupport::TestCase
  self.file_fixture_path = File.expand_path("../fixtures/files", __FILE__)

  private
    def create_blob(data: "Hello world!", filename: "hello.txt", content_type: "text/plain")
      ActiveStorage::Blob.create_after_upload! io: StringIO.new(data), filename: filename, content_type: content_type
    end

    def create_image_blob(filename: "racecar.jpg", content_type: "image/jpeg")
      ActiveStorage::Blob.create_after_upload! \
        io: file_fixture(filename).open,
        filename: filename, content_type: content_type
    end

    def create_blob_before_direct_upload(filename: "hello.txt", byte_size:, checksum:, content_type: "text/plain")
      ActiveStorage::Blob.create_before_direct_upload! filename: filename, byte_size: byte_size, checksum: checksum, content_type: content_type
    end

    def read_image_variant(variant)
      MiniMagick::Image.open variant.service.send(:path_for, variant.key)
    end
end

require "global_id"
GlobalID.app = "ActiveStorageExampleApp"
ActiveRecord::Base.send :include, GlobalID::Identification
