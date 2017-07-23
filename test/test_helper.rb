$LOAD_PATH << File.expand_path("../../app/controllers", __FILE__)
$LOAD_PATH << File.expand_path("../../app/models", __FILE__)
$LOAD_PATH << File.expand_path("../../app/jobs", __FILE__)

require "bundler/setup"
require "active_support"
require "active_support/test_case"
require "active_support/testing/autorun"
require "byebug"

require "active_job"
ActiveJob::Base.queue_adapter = :test
ActiveJob::Base.logger = nil

require "active_storage"

require "active_storage/service"
require "yaml"
SERVICE_CONFIGURATIONS = begin
  YAML.load_file(File.expand_path("../service/configurations.yml", __FILE__)).deep_symbolize_keys
rescue Errno::ENOENT
  puts "Missing service configuration file in test/service/configurations.yml"
  {}
end

require "active_storage/service/disk_service"
require "tmpdir"
ActiveStorage::Blob.service = ActiveStorage::Service::DiskService.new(root: Dir.mktmpdir("active_storage_tests"))
ActiveStorage::Service.logger = ActiveSupport::Logger.new(STDOUT)

ActiveStorage.verifier = ActiveSupport::MessageVerifier.new("Testing")

class ActiveSupport::TestCase
  private
    def create_blob(data: "Hello world!", filename: "hello.txt", content_type: "text/plain")
      ActiveStorage::Blob.create_after_upload! io: StringIO.new(data), filename: filename, content_type: content_type
    end

    def create_image_blob(filename: "racecar.jpg", content_type: "image/jpeg")
      ActiveStorage::Blob.create_after_upload! \
        io: File.open(File.expand_path("../fixtures/files/#{filename}", __FILE__)),
        filename: filename, content_type: content_type
    end

    def assert_same_image(fixture_filename, variant)
      assert_equal \
        File.binread(File.expand_path("../fixtures/files/#{fixture_filename}", __FILE__)),
        File.binread(variant.service.send(:path_for, variant.key))
    end
end

require "action_controller"
require "action_controller/test_case"
class ActionController::TestCase
  Routes = ActionDispatch::Routing::RouteSet.new.tap do |routes|
    routes.draw do
      # FIXME: Hacky way to avoid having to instantiate the real engine
      eval(File.readlines(File.expand_path("../../config/routes.rb", __FILE__)).slice(1..-2).join("\n"))
    end
  end
end

require "active_storage/attached"
ActiveRecord::Base.send :extend, ActiveStorage::Attached::Macros

require "global_id"
GlobalID.app = "ActiveStorageExampleApp"
ActiveRecord::Base.send :include, GlobalID::Identification
