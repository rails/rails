require "sites/shared_site_tests"

if ENV["GCS_PROJECT"] && ENV["GCS_KEYFILE"] && ENV["GCS_BUCKET"]
  class ActiveFile::Sites::GCSSiteTest < ActiveSupport::TestCase
    SITE = ActiveFile::Sites::GCSSite.new(
      project: ENV["GCS_PROJECT"], keyfile: ENV["GCS_KEYFILE"], bucket: ENV["GCS_BUCKET"]
    )

    include ActiveFile::Sites::SharedSiteTests
  end
else
  puts "Skipping GCS Site tests because ENV variables are missing"
end
