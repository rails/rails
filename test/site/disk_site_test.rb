require "tmpdir"
require "site/shared_site_tests"

class ActiveVault::Site::DiskSiteTest < ActiveSupport::TestCase
  SITE = ActiveVault::Site.configure(:Disk, root: File.join(Dir.tmpdir, "active_vault"))

  include ActiveVault::Site::SharedSiteTests
end
