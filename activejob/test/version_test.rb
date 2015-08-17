require 'helper'

class VersionTest < ActiveSupport::TestCase
  def test_framework_version_returns_a_string
    assert ActiveJob::VERSION.is_a?(String)
  end

  def test_framework_version_is_equal_to_rails_version_file
    assert_equal ActiveJob::VERSION, File.read(File.expand_path('../../../RAILS_VERSION', __FILE__)).strip
  end
end
