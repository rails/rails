# frozen_string_literal: true

require "test_helper"

class TestReleaser < Minitest::Test
  def test_framework_list
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

  def test_has_a_root
    releaser = Releaser.new(__dir__, "2.0.0")
    assert_equal Pathname.new(__dir__), releaser.root
  end

  def test_has_a_version
    releaser = Releaser.new(__dir__, "2.0.0")
    assert_equal "2.0.0", releaser.version
  end

  def test_knows_about_the_tag_name
    releaser = Releaser.new(__dir__, "2.0.0")
    assert_equal "v2.0.0", releaser.tag
  end

  def test_knows_about_the_parts_that_make_up_a_version
    releaser = Releaser.new(__dir__, "2.0.1")
    assert_equal "2", releaser.major
    assert_equal "0", releaser.minor
    assert_equal "1", releaser.tiny
    assert_nil releaser.pre
  end

  def test_knows_if_the_release_is_a_pre_release
    releaser = Releaser.new(__dir__, "2.0.0.beta1")
    assert_equal true, releaser.pre_release?

    releaser = Releaser.new(__dir__, "2.0.0.1")
    assert_equal false, releaser.pre_release?
  end

  def test_npm_tag_returns_the_pre_tag_for_a_pre_release
    releaser = Releaser.new(__dir__, "2.0.0.beta1")
    assert_equal "pre", releaser.npm_tag
  end

  def test_npm_tag_returns_the_latest_tag_for_a_pre_release
    releaser = Releaser.new(__dir__, "2.0.0")
    assert_equal "latest", releaser.npm_tag
  end

  def test_npm_version_transforms_version_with_rc_to_npm_format
    releaser = Releaser.new(__dir__, "5.0.0.rc1")
    assert_equal "5.0.0-rc1", releaser.npm_version
  end

  def test_npm_version_transforms_version_with_beta_to_npm_format_with_security_patch
    releaser = Releaser.new(__dir__, "5.0.0.beta1.1")
    assert_equal "5.0.0-beta1-1", releaser.npm_version
  end

  def test_npm_version_when_the_patch_level_is_0
    releaser = Releaser.new(__dir__, "5.0.0")
    assert_equal "5.0.0", releaser.npm_version
  end

  def test_npm_version_when_the_patch_level_is_0_and_there_is_a_security_patch
    releaser = Releaser.new(__dir__, "5.0.0.1")
    assert_equal "5.0.1", releaser.npm_version
  end

  def test_npm_version_when_the_patch_level_is_different_from_0_and_there_is_a_security_path
    releaser = Releaser.new(__dir__, "5.0.2.1")
    assert_equal "5.0.201", releaser.npm_version
  end

  def test_gem_file_returns_the_gem_file_name
    releaser = Releaser.new(__dir__, "5.0.0")
    assert_equal "rails-5.0.0.gem", releaser.gem_file("rails")
  end

  def test_gem_path_returns_the_gem_name
    releaser = Releaser.new(__dir__, "5.0.0")
    assert_equal "pkg/rails-5.0.0.gem", releaser.gem_path("rails")
  end

  def test_gemspect_returns_the_gemspec_name
    releaser = Releaser.new(__dir__, "5.0.0")
    assert_equal "rails.gemspec", releaser.gemspec("rails")
  end

  def test_update_versions_updates_the_version_of_a_gem_and_the_npm_package
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

  def test_update_versions_with_rails_does_nothing
    Dir.mktmpdir("rails") do |root|
      FileUtils.cp_r(File.expand_path("fixtures", __dir__), root)

      root = "#{root}/fixtures"

      releaser = Releaser.new(root, "5.0.0")
      releaser.update_versions("rails")

      assert_equal false, File.exist?("#{root}/rails/lib/rails/gem_version.rb")
    end
  end

  def test_release_notes_returns_the_release_notes_for_a_framework
    Dir.mktmpdir("rails") do |root|
      FileUtils.cp_r(File.expand_path("fixtures", __dir__), root)

      root = "#{root}/fixtures"

      releaser = Releaser.new(root, "5.0.0")
      assert_equal(<<~RELEASE_NOTES, releaser.release_notes)
        ## Active Support

        *  Change in Active Support


        ## Active Model

        *  Changes in Active Model


        ## Active Record

        *  Changes in Active Record


        ## Action View

        *  Changes in Action View


        ## Action Pack

        *  Changes in Action Pack


        ## Active Job

        *  Changes in Active Job


        ## Action Mailer

        *  Changes in Action Mailer


        ## Action Cable

        *  Changes in Active Cable


        ## Active Storage

        *  Change in Active Storage


        ## Action Mailbox

        *  Changes in Action Mailbox


        ## Action Text

        *  Changes in Action Text


        ## Railties

        *  Changes in Railties


        ## Guides

        *  Change in guides


      RELEASE_NOTES
    end
  end

  def test_framework_name_humanizes_the_framework_name
    releaser = Releaser.new(__dir__, "5.0.0")
    assert_equal "Action View", releaser.framework_name("actionview")
    assert_equal "Active Record", releaser.framework_name("activerecord")
    assert_equal "Railties", releaser.framework_name("railties")
  end
end
