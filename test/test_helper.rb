require "bundler/setup"
require "active_support"
require "active_support/test_case"
require "active_support/testing/autorun"
require "byebug"

require "active_storage"
require "active_storage/service/disk_service"
ActiveStorage::Blob.service = ActiveStorage::Service::DiskService.new(root: File.join(Dir.tmpdir, "active_storage"))
ActiveStorage::Service.logger = ActiveSupport::Logger.new(STDOUT)

require "active_storage/verified_key_with_expiration"
ActiveStorage::VerifiedKeyWithExpiration.verifier = ActiveSupport::MessageVerifier.new("Testing")

class ActiveSupport::TestCase
  private
    def create_blob(data: "Hello world!", filename: "hello.txt", content_type: "text/plain")
      ActiveStorage::Blob.create_after_upload! io: StringIO.new(data), filename: filename, content_type: content_type
    end
end


require "active_storage/attached"
ActiveRecord::Base.send :extend, ActiveStorage::Attached::Macros

require "global_id"
GlobalID.app = "ActiveStorageExampleApp"
ActiveRecord::Base.send :include, GlobalID::Identification
