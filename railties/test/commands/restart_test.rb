require_relative '../isolation/abstract_unit'

module CommandsTests
  class RestartTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation

    def setup
      build_app
    end

    def teardown
      teardown_app
    end

    test 'restart restarts server' do
      Dir.chdir(app_path) do
        `rails restart`
        assert File.exist?("tmp/restart.txt")

        prev_mtime = File.mtime("tmp/restart.txt")
        sleep(1)
        `rails restart`
        curr_mtime = File.mtime("tmp/restart.txt")
        assert_not_equal prev_mtime, curr_mtime
      end
    end

    test 'rake restart should work even if tmp folder does not exist' do
      Dir.chdir(app_path) do
        FileUtils.remove_dir('tmp')
        `rails restart`
        assert File.exist?('tmp/restart.txt')
      end
    end
  end
end
