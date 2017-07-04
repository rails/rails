require "sites/shared_site_tests"

if ENV["AWS_ACCESS_KEY_ID"] && ENV["AWS_SECRET_ACCESS_KEY"] && ENV["AWS_REGION"] && ENV["AWS_S3_BUCKET"]
  class ActiveFile::Sites::S3SiteTest < ActiveSupport::TestCase
    SITE = ActiveFile::Sites::S3Site.new(
      access_key_id: ENV["AWS_ACCESS_KEY_ID"],
      secret_access_key: ENV["AWS_SECRET_ACCESS_KEY"],
      region: ENV["AWS_REGION"],
      bucket: ENV["AWS_S3_BUCKET"]
    )

    include ActiveFile::Sites::SharedSiteTests
  end
else
  puts "Skipping S3 Site tests because ENV variables are missing"
end
