require 'abstract_unit'
require 'stringio'

class BenchmarkHelperTest < ActionView::TestCase
  include RenderERBUtils
  tests ActionView::Helpers::BenchmarkHelper

  def test_output_in_erb
    output   = render_erb("Hello <%= benchmark do %>world<% end %>")
    expected = 'Hello world'
    assert_equal expected, output
  end

  def test_returns_value_from_block
    assert_equal 'test', benchmark { 'test' }
  end

  def test_default_message
    log = StringIO.new
    self.stubs(:logger).returns(Logger.new(log))
    benchmark {}
    assert_match(/Benchmarking \(\d+.\d+ms\)/, log.rewind && log.read)
  end
end
