# frozen_string_literal: true

require 'isolation/abstract_unit'
require 'rails/gem_version'

class VersionTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::Isolation

  def setup
    build_app
  end

  def teardown
    teardown_app
  end

  test 'command works' do
    output = rails('version')
    assert_equal "Rails #{Rails.gem_version}\n", output
  end

  test 'short-cut alias works' do
    output = rails('-v')
    assert_equal "Rails #{Rails.gem_version}\n", output
  end
end
