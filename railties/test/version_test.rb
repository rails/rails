# frozen_string_literal: true

require "abstract_unit"

class VersionTest < ActiveSupport::TestCase
  def test_rails_version_returns_a_string
    assert Rails.version.is_a? String
  end

  def test_rails_gem_version_returns_a_correct_gem_version_object
    assert Rails.gem_version.is_a? Gem::Version
    assert_equal Rails.version, Rails.gem_version.to_s
  end

  def test_version_predicates
    assert_respond_to Rails, :v9?
    assert_respond_to Rails, :v9_0?
    assert_respond_to Rails, :v9_99?
    assert_respond_to Rails, :v9_0_0?
    assert_respond_to Rails, :v9_99_99?
    assert_respond_to Rails, :v9_0_0_0?
    assert_respond_to Rails, :v9_99_99_99?

    assert Rails.send("v#{Rails::VERSION::MAJOR}?")
    assert Rails.send("v#{Rails::VERSION::MAJOR}_#{Rails::VERSION::MINOR}?")
    assert Rails.send("v#{Rails::VERSION::MAJOR}_#{Rails::VERSION::MINOR}_#{Rails::VERSION::TINY}?")

    assert_not Rails.send("v#{Rails::VERSION::MAJOR - 1}?")
    assert_not Rails.send("v#{Rails::VERSION::MAJOR}_#{Rails::VERSION::MINOR + 1}?")
    assert_not Rails.send("v#{Rails::VERSION::MAJOR}_#{Rails::VERSION::MINOR}_#{Rails::VERSION::TINY - 1}?")
  end
end
