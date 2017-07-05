require "bundler/setup"
require "active_support"
require "active_support/test_case"
require "active_support/testing/autorun"
require "byebug"

require "active_vault"

require "active_vault/site"
ActiveVault::Blob.site = ActiveVault::Site.configure(:Disk, root: File.join(Dir.tmpdir, "active_vault"))

require "active_vault/verified_key_with_expiration"
ActiveVault::VerifiedKeyWithExpiration.verifier = ActiveSupport::MessageVerifier.new("Testing")

class ActiveSupport::TestCase
  private
    def create_blob(data: "Hello world!", filename: "hello.txt", content_type: "text/plain")
      ActiveVault::Blob.create_after_upload! io: StringIO.new(data), filename: filename, content_type: content_type
    end
end


require "active_vault/attached"
ActiveRecord::Base.send :extend, ActiveVault::Attached::Macros

require "global_id"
GlobalID.app = "ActiveVaultExampleApp"
ActiveRecord::Base.send :include, GlobalID::Identification
