require "site/shared_site_tests"

if SITE_CONFIGURATIONS[:s3]
  class ActiveStorage::Site::S3SiteTest < ActiveSupport::TestCase
    SITE = ActiveStorage::Site.configure(:S3, SITE_CONFIGURATIONS[:s3])

    include ActiveStorage::Site::SharedSiteTests
  end
else
  puts "Skipping S3 Site tests because no S3 configuration was supplied"
end
