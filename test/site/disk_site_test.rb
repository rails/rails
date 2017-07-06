require "tmpdir"
require "site/shared_site_tests"

class ActiveStorage::Site::DiskSiteTest < ActiveSupport::TestCase
  SITE = ActiveStorage::Site.configure(:Disk, root: File.join(Dir.tmpdir, "active_storage"))

  include ActiveStorage::Site::SharedSiteTests
end
