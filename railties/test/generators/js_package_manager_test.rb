# frozen_string_literal: true

require "generators/generators_test_helper"
require "rails/generators/js_package_manager"

class JsPackageManagerTest < Rails::Generators::TestCase
  include GeneratorsTestHelper

  class DummyGenerator
    include Rails::Generators::JsPackageManager
    attr_accessor :destination_root

    def initialize(destination_root)
      @destination_root = destination_root
    end
  end

  setup :prepare_destination

  test "detects bun from bun.lockb" do
    FileUtils.touch(File.join(destination_root, "bun.lockb"))
    assert_equal :bun, Rails::Generators::JsPackageManager.detect(Pathname(destination_root))
  end

  test "detects bun from bun.lock" do
    FileUtils.touch(File.join(destination_root, "bun.lock"))
    assert_equal :bun, Rails::Generators::JsPackageManager.detect(Pathname(destination_root))
  end

  test "detects bun from bun.config.js" do
    FileUtils.touch(File.join(destination_root, "bun.config.js"))
    assert_equal :bun, Rails::Generators::JsPackageManager.detect(Pathname(destination_root))
  end

  test "detects pnpm from pnpm-lock.yaml" do
    FileUtils.touch(File.join(destination_root, "pnpm-lock.yaml"))
    assert_equal :pnpm, Rails::Generators::JsPackageManager.detect(Pathname(destination_root))
  end

  test "detects npm from package-lock.json" do
    FileUtils.touch(File.join(destination_root, "package-lock.json"))
    assert_equal :npm, Rails::Generators::JsPackageManager.detect(Pathname(destination_root))
  end

  test "defaults to yarn when yarn.lock exists" do
    FileUtils.touch(File.join(destination_root, "yarn.lock"))
    assert_equal :yarn, Rails::Generators::JsPackageManager.detect(Pathname(destination_root))
  end

  test "defaults to yarn when no lockfile exists" do
    assert_equal :yarn, Rails::Generators::JsPackageManager.detect(Pathname(destination_root))
  end

  test "package_add_command returns the correct command" do
    {
      "bun.lockb" => "bun add @rails/actioncable",
      "pnpm-lock.yaml" => "pnpm add @rails/actioncable",
      "package-lock.json" => "npm install @rails/actioncable",
      "yarn.lock" => "yarn add @rails/actioncable"
    }.each do |lockfile, expected|
      prepare_destination
      generator = DummyGenerator.new(destination_root)
      FileUtils.touch(File.join(destination_root, "package.json"))
      FileUtils.touch(File.join(destination_root, lockfile))
      assert_equal expected, generator.package_add_command("@rails/actioncable")
    end
  end

  test "package_install_command returns the correct command" do
    {
      "bun.lockb" => "bun install --frozen-lockfile",
      "pnpm-lock.yaml" => "pnpm install --frozen-lockfile",
      "package-lock.json" => "npm ci",
      "yarn.lock" => "yarn install --immutable"
    }.each do |lockfile, expected|
      prepare_destination
      generator = DummyGenerator.new(destination_root)
      FileUtils.touch(File.join(destination_root, "package.json"))
      FileUtils.touch(File.join(destination_root, lockfile))
      assert_equal expected, generator.package_install_command
    end
  end

  test "package_lockfile returns the correct lockfile name" do
    {
      "bun.lockb" => "bun.lockb",
      "pnpm-lock.yaml" => "pnpm-lock.yaml",
      "package-lock.json" => "package-lock.json",
      "yarn.lock" => "yarn.lock"
    }.each do |lockfile, expected|
      prepare_destination
      generator = DummyGenerator.new(destination_root)
      FileUtils.touch(File.join(destination_root, "package.json"))
      FileUtils.touch(File.join(destination_root, lockfile))
      assert_equal expected, generator.package_lockfile
    end
  end
end
