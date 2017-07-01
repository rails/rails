require "abstract_unit"

class VersionTest < ActiveSupport::TestCase
  def test_rails_version_returns_a_string
    assert Rails.version.is_a? String
  end

  def test_rails_gem_version_returns_a_correct_gem_version_object
    assert Rails.gem_version.is_a? Gem::Version
    assert_equal Rails.version, Rails.gem_version.to_s
  end
end
