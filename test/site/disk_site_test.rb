require "tmpdir"
require "site/shared_site_tests"

class ActiveFile::Site::DiskSiteTest < ActiveSupport::TestCase
  SITE = ActiveFile::Site.configure(:Disk, root: File.join(Dir.tmpdir, "active_file"))

  include ActiveFile::Site::SharedSiteTests
end
