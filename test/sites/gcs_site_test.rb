require "sites/shared_site_tests"

if SITE_CONFIGURATIONS[:gcs]
  class ActiveFile::Sites::GCSSiteTest < ActiveSupport::TestCase
    SITE = ActiveFile::Sites::GCSSite.new(SITE_CONFIGURATIONS[:gcs])

    include ActiveFile::Sites::SharedSiteTests
  end
else
  puts "Skipping GCS Site tests because no GCS configuration was supplied"
end
