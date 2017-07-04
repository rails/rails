require "sites/shared_site_tests"

if SITE_CONFIGURATIONS[:s3]
  class ActiveFile::Sites::S3SiteTest < ActiveSupport::TestCase
    SITE = ActiveFile::Sites::S3Site.new(SITE_CONFIGURATIONS[:s3])

    include ActiveFile::Sites::SharedSiteTests
  end
else
  puts "Skipping S3 Site tests because no S3 configuration was supplied"
end
