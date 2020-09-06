# frozen_string_literal: true

require_relative '../../dependencies_test_helpers'

module AutoloadingCacheBehavior
  include DependenciesTestHelpers

  def test_simple_autoloading
    with_autoloading_fixtures do
      @cache.write('foo', EM.new)
    end

    remove_constants(:EM)
    ActiveSupport::Dependencies.clear

    with_autoloading_fixtures do
      assert_kind_of EM, @cache.read('foo')
    end

    remove_constants(:EM)
    ActiveSupport::Dependencies.clear
  end

  def test_two_classes_autoloading
    with_autoloading_fixtures do
      @cache.write('foo', [EM.new, ClassFolder.new])
    end

    remove_constants(:EM, :ClassFolder)
    ActiveSupport::Dependencies.clear

    with_autoloading_fixtures do
      loaded = @cache.read('foo')
      assert_kind_of Array, loaded
      assert_equal 2, loaded.size
      assert_kind_of EM, loaded[0]
      assert_kind_of ClassFolder, loaded[1]
    end

    remove_constants(:EM, :ClassFolder)
    ActiveSupport::Dependencies.clear
  end
end
