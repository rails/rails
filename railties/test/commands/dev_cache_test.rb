require_relative '../isolation/abstract_unit'

module CommandsTests
  class DevCacheTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation

    def setup
      build_app
    end

    def teardown
      teardown_app
    end

    test 'dev:cache creates file and outputs message' do
      Dir.chdir(app_path) do
        output = `rails dev:cache`
        assert File.exist?('tmp/caching-dev.txt')
        assert_match(%r{Development mode is now being cached}, output)
      end
    end

    test 'dev:cache deletes file and outputs message' do
      Dir.chdir(app_path) do
        output = `rails dev:cache`        
        output = `rails dev:cache`
        assert_not File.exist?('tmp/caching-dev.txt')
        assert_match(%r{Development mode is no longer being cached}, output)
      end
    end
  end
end
