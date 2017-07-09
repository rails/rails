require "bundler/setup"
require "active_support"
require "active_support/test_case"
require "active_support/testing/autorun"
require "byebug"

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

require "active_storage/verified_key_with_expiration"
ActiveStorage::VerifiedKeyWithExpiration.verifier = ActiveSupport::MessageVerifier.new("Testing")

class ActiveSupport::TestCase
  private
    def create_blob(data: "Hello world!", filename: "hello.txt", content_type: "text/plain")
      ActiveStorage::Blob.create_after_upload! io: StringIO.new(data), filename: filename, content_type: content_type
    end
end

require "action_controller"
require "action_controller/test_case"

class ActionController::TestCase
  Routes = ActionDispatch::Routing::RouteSet.new.tap do |routes|
    routes.draw do
      eval(File.read(File.expand_path("../../lib/active_storage/routes.rb", __FILE__)))
    end
  end
end

require "active_storage/attached"
ActiveRecord::Base.send :extend, ActiveStorage::Attached::Macros

require "global_id"
GlobalID.app = "ActiveStorageExampleApp"
ActiveRecord::Base.send :include, GlobalID::Identification
SignedGlobalID.verifier = ActiveStorage::VerifiedKeyWithExpiration.verifier
