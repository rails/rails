require "bundler/setup"
require "active_support"
require "active_support/testing/autorun"
require "byebug"

require "active_file"

require "active_file/site"
ActiveFile::Blob.site = ActiveFile::Site.configure(:Disk, root: File.join(Dir.tmpdir, "active_file"))

require "active_file/verified_key_with_expiration"
ActiveFile::VerifiedKeyWithExpiration.verifier = ActiveSupport::MessageVerifier.new("Testing")
