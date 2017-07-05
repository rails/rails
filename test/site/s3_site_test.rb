require "site/shared_site_tests"

if SITE_CONFIGURATIONS[:s3]
  class ActiveVault::Site::S3SiteTest < ActiveSupport::TestCase
    SITE = ActiveVault::Site.configure(:S3, SITE_CONFIGURATIONS[:s3])

    include ActiveVault::Site::SharedSiteTests
  end
else
  puts "Skipping S3 Site tests because no S3 configuration was supplied"
end
