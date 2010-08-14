require 'abstract_unit'
require 'rails/script_rails_loader'

class ScriptRailsLoaderTest < ActiveSupport::TestCase

  test "is in a rails application if script/rails exists" do
    File.stubs(:exists?).returns(true)
    assert Rails::ScriptRailsLoader.in_rails_application?
  end

  test "is in a rails application if parent directory has script/rails" do
    File.stubs(:exists?).with("/foo/bar/script/rails").returns(false)
    File.stubs(:exists?).with("/foo/script/rails").returns(true)
    assert Rails::ScriptRailsLoader.in_rails_application_subdirectory?(Pathname.new("/foo/bar"))
  end

  test "is not in a rails application if at the root directory and doesn't have script/rails" do
    Pathname.any_instance.stubs(:root?).returns true
    assert !Rails::ScriptRailsLoader.in_rails_application?
  end

end