# frozen_string_literal: true

require "isolation/abstract_unit"
require "rails/zeitwerk_checker"

class ZeitwerkCheckerTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::Isolation

  def setup
    build_app
  end

  def boot(env = "development")
    app(env)
  end

  test "returns an empty list for a default application" do
    boot

    assert_empty Rails::ZeitwerkChecker.check
  end

  test "raises if there is a missing constants in autoload_paths" do
    app_file "app/models/user.rb", ""

    boot

    e = assert_raises(Zeitwerk::NameError) do
      Rails::ZeitwerkChecker.check
    end
    assert_includes e.message, "expected file #{app_path}/app/models/user.rb to define constant User"
  end

  test "raises if there is a missing constant in autoload_once_paths" do
    app_dir "extras"
    app_file "extras/x.rb", ""

    add_to_config 'config.autoload_once_paths << "#{Rails.root}/extras"'
    add_to_config 'config.eager_load_paths << "#{Rails.root}/extras"'

    boot

    e = assert_raises(Zeitwerk::NameError) do
      Rails::ZeitwerkChecker.check
    end
    assert_includes e.message, "expected file #{Rails.root}/extras/x.rb to define constant X"
  end

  test "returns an empty list unchecked directories do not exist" do
    add_to_config 'config.autoload_paths << "#{Rails.root}/dir1"'
    add_to_config 'config.autoload_once_paths << "#{Rails.root}/dir2"'

    boot

    assert_empty Rails::ZeitwerkChecker.check
  end

  test "returns an empty list if unchecked directories are empty" do
    app_dir "dir1"
    add_to_config 'config.autoload_paths << "#{Rails.root}/dir1"'

    app_dir "dir2"
    add_to_config 'config.autoload_once_paths << "#{Rails.root}/dir2"'

    boot

    assert_empty Rails::ZeitwerkChecker.check
  end

  test "returns unchecked directories" do
    app_dir "dir1"
    app_file "dir1/x.rb", "X = 1"
    add_to_config 'config.autoload_paths << "#{Rails.root}/dir1"'

    app_dir "dir2"
    app_file "dir2/y.rb", "Y = 1"
    add_to_config 'config.autoload_once_paths << "#{Rails.root}/dir2"'

    boot

    assert_equal ["#{app_path}/dir1", "#{app_path}/dir2"], Rails::ZeitwerkChecker.check.sort
  end
end
