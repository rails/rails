require "tmpdir"
require "sites/shared_site_tests"

class ActiveFile::Sites::DiskSiteTest < ActiveSupport::TestCase
  SITE = ActiveFile::Sites::DiskSite.new(root: File.join(Dir.tmpdir, "active_file"))

  include ActiveFile::Sites::SharedSiteTests
end
