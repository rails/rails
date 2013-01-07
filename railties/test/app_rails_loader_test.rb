require 'abstract_unit'
require 'rails/app_rails_loader'

class AppRailsLoaderTest < ActiveSupport::TestCase
  test "is in a rails application if bin/rails exists and contains APP_PATH" do
    File.stubs(:exists?).returns(true)
    File.stubs(:read).with('bin/rails').returns('APP_PATH')
    assert Rails::AppRailsLoader.in_rails_application_or_engine?
  end

  test "is not in a rails application if bin/rails exists but doesn't contain APP_PATH" do
    File.stubs(:exists?).returns(true)
    File.stubs(:read).with('bin/rails').returns('railties bin/rails')
    assert !Rails::AppRailsLoader.in_rails_application_or_engine?
  end

  test "is in a rails application if parent directory has bin/rails containing APP_PATH" do
    File.stubs(:exists?).with("/foo/bar/bin/rails").returns(false)
    File.stubs(:exists?).with("/foo/bin/rails").returns(true)
    File.stubs(:read).with('/foo/bin/rails').returns('APP_PATH')
    assert Rails::AppRailsLoader.in_rails_application_or_engine_subdirectory?(Pathname.new("/foo/bar"))
  end

  test "is not in a rails application if at the root directory and doesn't have bin/rails" do
    Pathname.any_instance.stubs(:root?).returns true
    assert !Rails::AppRailsLoader.in_rails_application_or_engine?
  end

  test "is in a rails engine if parent directory has bin/rails containing ENGINE_PATH" do
    File.stubs(:exists?).with("/foo/bar/bin/rails").returns(false)
    File.stubs(:exists?).with("/foo/bin/rails").returns(true)
    File.stubs(:read).with('/foo/bin/rails').returns('ENGINE_PATH')
    assert Rails::AppRailsLoader.in_rails_application_or_engine_subdirectory?(Pathname.new("/foo/bar"))
  end

  test "is in a rails engine if bin/rails exists containing ENGINE_PATH" do
    File.stubs(:exists?).returns(true)
    File.stubs(:read).with('bin/rails').returns('ENGINE_PATH')
    assert Rails::AppRailsLoader.in_rails_application_or_engine?
  end
end
