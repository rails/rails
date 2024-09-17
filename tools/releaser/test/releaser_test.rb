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
end
