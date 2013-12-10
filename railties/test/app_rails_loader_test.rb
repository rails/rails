require 'tmpdir'
require 'abstract_unit'
require 'rails/app_rails_loader'

class AppRailsLoaderTest < ActiveSupport::TestCase
  def write(filename, contents=nil)
    FileUtils.mkdir_p(File.dirname(filename))
    File.write(filename, contents)
  end

  def expects_exec(exe)
    Rails::AppRailsLoader.expects(:exec).with(Rails::AppRailsLoader::RUBY, exe)
  end

  setup do
    @tmp = Dir.mktmpdir('railties-rails-loader-test-suite')
    @cwd = Dir.pwd
    Dir.chdir(@tmp)
  end

  ['bin', 'script'].each do |script_dir|
    exe = "#{script_dir}/rails"

    test "is not in a Rails application if #{exe} is not found in the current or parent directories" do
      File.stubs(:exist?).with('bin/rails').returns(false)
      File.stubs(:exist?).with('script/rails').returns(false)

      assert !Rails::AppRailsLoader.exec_app_rails
    end

    ['APP_PATH', 'ENGINE_PATH'].each do |keyword|
      test "is in a Rails application if #{exe} exists and contains #{keyword}" do
        write exe, keyword

        expects_exec exe
        Rails::AppRailsLoader.exec_app_rails
      end

      test "is not in a Rails application if #{exe} exists but doesn't contain #{keyword}" do
        write exe

        assert !Rails::AppRailsLoader.exec_app_rails
      end

      test "is in a Rails application if parent directory has #{exe} containing #{keyword} and chdirs to the root directory" do
        write "foo/bar/#{exe}"
        write "foo/#{exe}", keyword

        Dir.chdir('foo/bar')

        expects_exec exe
        Rails::AppRailsLoader.exec_app_rails

        # Compare the realpath in case either of them has symlinks.
        #
        # This happens in particular in Mac OS X, where @tmp starts
        # with "/var", and Dir.pwd with "/private/var", due to a
        # default system symlink var -> private/var.
        assert_equal File.realpath("#@tmp/foo"), File.realpath(Dir.pwd)
      end
    end
  end

  teardown do
    Dir.chdir(@cwd)
    FileUtils.rm_rf(@tmp)
  end
end
