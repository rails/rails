require "site/shared_site_tests"

if SITE_CONFIGURATIONS[:gcs]
  class ActiveFile::Site::GCSSiteTest < ActiveSupport::TestCase
    SITE = ActiveFile::Site.configure(:GCS, SITE_CONFIGURATIONS[:gcs])

    include ActiveFile::Site::SharedSiteTests

    test "signed URL generation" do
      travel_to Time.now do
        url = SITE.bucket.signed_url(path: FIXTURE_KEY, expires: 120) +
          "&response-content-disposition=inline%3B+filename%3D%22test.txt%22"

        assert_equal url, @site.url(FIXTURE_KEY, expires_in: 2.minutes, disposition: :inline, filename: "test.txt")
      end
    end
  end
else
  puts "Skipping GCS Site tests because no GCS configuration was supplied"
end
