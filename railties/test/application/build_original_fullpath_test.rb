require "abstract_unit"

module ApplicationTests
  class BuildOriginalPathTest < ActiveSupport::TestCase
    def test_include_original_PATH_info_in_ORIGINAL_FULLPATH
      env = { 'PATH_INFO' => '/foo/' }
      assert_equal "/foo/", Rails.application.send(:build_original_fullpath, env)
    end

    def test_include_SCRIPT_NAME
      env = {
        'SCRIPT_NAME' => '/foo',
        'PATH_INFO' => '/bar'
      }

      assert_equal "/foo/bar", Rails.application.send(:build_original_fullpath, env)
    end

    def test_include_QUERY_STRING
      env = {
        'PATH_INFO' => '/foo',
        'QUERY_STRING' => 'bar',
      }
      assert_equal "/foo?bar", Rails.application.send(:build_original_fullpath, env)
    end
  end
end
