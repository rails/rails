require "site/shared_site_tests"

if SITE_CONFIGURATIONS[:gcs]
  class ActiveFile::Site::GCSSiteTest < ActiveSupport::TestCase
    SITE = ActiveFile::Site.configure(:GCS, SITE_CONFIGURATIONS[:gcs])

    include ActiveFile::Site::SharedSiteTests
  end
else
  puts "Skipping GCS Site tests because no GCS configuration was supplied"
end
