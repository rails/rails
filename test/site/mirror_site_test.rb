require "tmpdir"
require "site/shared_site_tests"

class ActiveVault::Site::MirrorSiteTest < ActiveSupport::TestCase
  PRIMARY_DISK_SITE   = ActiveVault::Site.configure(:Disk, root: File.join(Dir.tmpdir, "active_vault"))
  SECONDARY_DISK_SITE = ActiveVault::Site.configure(:Disk, root: File.join(Dir.tmpdir, "active_vault_mirror"))

  SITE = ActiveVault::Site.configure :Mirror, sites: [ PRIMARY_DISK_SITE, SECONDARY_DISK_SITE ]

  include ActiveVault::Site::SharedSiteTests

  test "uploading was done to all sites" do
    begin
      key  = SecureRandom.base58(24)
      data = "Something else entirely!"
      io   = StringIO.new(data)
      @site.upload(key, io)

      assert_equal data, PRIMARY_DISK_SITE.download(key)
      assert_equal data, SECONDARY_DISK_SITE.download(key)
    ensure
      @site.delete key
    end
  end

  test "existing in all sites" do
    assert PRIMARY_DISK_SITE.exist?(FIXTURE_KEY)
    assert SECONDARY_DISK_SITE.exist?(FIXTURE_KEY)
  end
end
