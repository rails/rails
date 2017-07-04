require "site/shared_site_tests"

if SITE_CONFIGURATIONS[:s3]
  class ActiveFile::Site::S3SiteTest < ActiveSupport::TestCase
    SITE = ActiveFile::Site.configure(:S3, SITE_CONFIGURATIONS[:s3])

    include ActiveFile::Site::SharedSiteTests
  end
else
  puts "Skipping S3 Site tests because no S3 configuration was supplied"
end
