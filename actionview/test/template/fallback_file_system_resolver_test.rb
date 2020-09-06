# frozen_string_literal: true

require 'abstract_unit'

class FallbackFileSystemResolverTest < ActiveSupport::TestCase
  def setup
    @root_resolver = ActionView::FallbackFileSystemResolver.send(:new, '/')
  end

  def test_should_have_no_virtual_path
    templates = @root_resolver.find_all('hello_world', "#{FIXTURE_LOAD_PATH}/test", false, locale: [], formats: [:html], variants: [], handlers: [:erb])
    assert_equal 1, templates.size
    assert_equal 'Hello world!', templates[0].source
    assert_nil templates[0].virtual_path
  end
end
