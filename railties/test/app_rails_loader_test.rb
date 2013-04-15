require 'abstract_unit'
require 'rails/app_rails_loader'

class AppRailsLoaderTest < ActiveSupport::TestCase

  setup do
    File.stubs(:exists?).returns(false)
  end

  ['bin/rails', 'script/rails'].each do |exe|
    test "is in a rails application if #{exe} exists and contains APP_PATH" do
      File.stubs(:exists?).with(exe).returns(true)
      File.stubs(:read).with(exe).returns('APP_PATH')
      assert Rails::AppRailsLoader.find_executable
    end

    test "is not in a rails application if #{exe} exists but doesn't contain APP_PATH" do
      File.stubs(:exists?).with(exe).returns(true)
      File.stubs(:read).with(exe).returns("railties #{exe}")
      assert !Rails::AppRailsLoader.find_executable
    end

    test "is in a rails application if parent directory has #{exe} containing APP_PATH" do
      File.stubs(:exists?).with("/foo/bar/#{exe}").returns(false)
      File.stubs(:exists?).with("/foo/#{exe}").returns(true)
      File.stubs(:read).with("/foo/#{exe}").returns('APP_PATH')
      assert Rails::AppRailsLoader.find_executable_in_parent_path(Pathname.new("/foo/bar"))
    end

    test "is not in a rails application if at the root directory and doesn't have #{exe}" do
      Pathname.any_instance.stubs(:root?).returns true
      assert !Rails::AppRailsLoader.find_executable
    end

    test "is in a rails engine if parent directory has #{exe} containing ENGINE_PATH" do
      File.stubs(:exists?).with("/foo/bar/#{exe}").returns(false)
      File.stubs(:exists?).with("/foo/#{exe}").returns(true)
      File.stubs(:read).with("/foo/#{exe}").returns('ENGINE_PATH')
      assert Rails::AppRailsLoader.find_executable_in_parent_path(Pathname.new("/foo/bar"))
    end

    test "is in a rails engine if #{exe} exists containing ENGINE_PATH" do
      File.stubs(:exists?).with(exe).returns(true)
      File.stubs(:read).with(exe).returns('ENGINE_PATH')
      assert Rails::AppRailsLoader.find_executable
    end
  end
end
