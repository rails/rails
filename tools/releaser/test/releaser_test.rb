# frozen_string_literal: true

require "test_helper"

class TestReleaser < ActiveSupport::TestCase
  test "framework list" do
    assert_equal(
      [
        "activesupport",
        "activemodel",
        "activerecord",
        "actionview",
        "actionpack",
        "activejob",
        "actionmailer",
        "actioncable",
        "activestorage",
        "actionmailbox",
        "actiontext",
        "railties"
      ],
      Releaser::FRAMEWORKS
    )
  end

  test "has a root" do
    releaser = Releaser.new(__dir__, "2.0.0")
    assert_equal Pathname.new(__dir__), releaser.root
  end

  test "has a version" do
    releaser = Releaser.new(__dir__, "2.0.0")
    assert_equal "2.0.0", releaser.version
  end

  test "knows about the tag name" do
    releaser = Releaser.new(__dir__, "2.0.0")
    assert_equal "v2.0.0", releaser.tag
  end

  test "knows about the parts that make up a version" do
    releaser = Releaser.new(__dir__, "2.0.1")
    assert_equal "2", releaser.major
    assert_equal "0", releaser.minor
    assert_equal "1", releaser.tiny
    assert_nil releaser.pre
  end

  test "knows if the release is a pre-release" do
    releaser = Releaser.new(__dir__, "2.0.0.beta1")
    assert_equal true, releaser.pre_release?

    releaser = Releaser.new(__dir__, "2.0.0.1")
    assert_equal false, releaser.pre_release?
  end

  test "#npm_tag returns the pre tag for a pre-release" do
    releaser = Releaser.new(__dir__, "2.0.0.beta1")
    assert_equal "pre", releaser.npm_tag
  end

  test "#npm_tag returns the latest tag for a pre-release" do
    releaser = Releaser.new(__dir__, "2.0.0")
    assert_equal "latest", releaser.npm_tag
  end

  test "#npm_version transforms version with rc to npm format" do
    releaser = Releaser.new(__dir__, "5.0.0.rc1")
    assert_equal "5.0.0-rc1", releaser.npm_version
  end

  test "#npm_version transforms version with beta to npm format with security patch" do
    releaser = Releaser.new(__dir__, "5.0.0.beta1.1")
    assert_equal "5.0.0-beta1-1", releaser.npm_version
  end

  test "#npm_version when the patch level is 0" do
    releaser = Releaser.new(__dir__, "5.0.0")
    assert_equal "5.0.0", releaser.npm_version
  end

  test "#npm_version when the patch level is 0 and there is a security patch" do
    releaser = Releaser.new(__dir__, "5.0.0.1")
    assert_equal "5.0.1", releaser.npm_version
  end

  test "#npm_version when the patch level is different from 0 and there is a security path" do
    releaser = Releaser.new(__dir__, "5.0.2.1")
    assert_equal "5.0.201", releaser.npm_version
  end

  test "#gem_file returns the gem file name" do
    releaser = Releaser.new(__dir__, "5.0.0")
    assert_equal "rails-5.0.0.gem", releaser.gem_file("rails")
  end

  test "#gem_path returns the gem name" do
    releaser = Releaser.new(__dir__, "5.0.0")
    assert_equal "pkg/rails-5.0.0.gem", releaser.gem_path("rails")
  end

  test "#gemspect returns the gemspec name" do
    releaser = Releaser.new(__dir__, "5.0.0")
    assert_equal "rails.gemspec", releaser.gemspec("rails")
  end

  test "#update_versions updates the version of a gem and the npm package" do
    Dir.mktmpdir("rails") do |root|
      FileUtils.cp_r(File.expand_path("fixtures", __dir__), root)

      root = "#{root}/fixtures"

      releaser = Releaser.new(root, "5.0.0")
      releaser.update_versions("activestorage")

      gem_version_file = File.read("#{root}/activestorage/lib/active_storage/gem_version.rb")

      assert_equal "5", gem_version_file[/MAJOR = (\d+)/, 1]
      assert_equal "0", gem_version_file[/MINOR = (\d+)/, 1]
      assert_equal "0", gem_version_file[/TINY  = (\d+)/, 1]
      assert_equal "nil", gem_version_file[/PRE   = (.*?)$/, 1]
      assert_equal "5.0.0", JSON.parse(File.read("#{root}/activestorage/package.json"))["version"]

      releaser = Releaser.new(root, "5.0.0.beta1")
      releaser.update_versions("activestorage")

      gem_version_file = File.read("#{root}/activestorage/lib/active_storage/gem_version.rb")

      assert_equal "5", gem_version_file[/MAJOR = (\d+)/, 1]
      assert_equal "0", gem_version_file[/MINOR = (\d+)/, 1]
      assert_equal "0", gem_version_file[/TINY  = (\d+)/, 1]
      assert_equal "\"beta1\"", gem_version_file[/PRE   = (.*?)$/, 1]
      assert_equal "5.0.0-beta1", JSON.parse(File.read("#{root}/activestorage/package.json"))["version"]
    end
  end

  test "#update_versions with rails does nothing" do
    Dir.mktmpdir("rails") do |root|
      FileUtils.cp_r(File.expand_path("fixtures", __dir__), root)

      root = "#{root}/fixtures"

      releaser = Releaser.new(root, "5.0.0")
      releaser.update_versions("rails")

      assert_equal false, File.exist?("#{root}/rails/lib/rails/gem_version.rb")
    end
  end
end
