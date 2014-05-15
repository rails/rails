require 'abstract_unit'

class OutputBufferTest < ActionController::TestCase
  class TestController < ActionController::Base
    def index
      render :text => 'foo'
    end
  end

  tests TestController

  def setup
    @vc = @controller.view_context
    get :index
    assert_equal ['foo'], body_parts
  end

  test 'output buffer is nil after rendering' do
    assert_nil output_buffer
  end

  test 'flushing ignores nil output buffer' do
    @controller.view_context.flush_output_buffer
    assert_nil output_buffer
    assert_equal ['foo'], body_parts
  end

  test 'flushing ignores empty output buffer' do
    @vc.output_buffer = ''
    @vc.flush_output_buffer
    assert_equal '', output_buffer
    assert_equal ['foo'], body_parts
  end

  test 'flushing appends the output buffer to the body parts' do
    @vc.output_buffer = 'bar'
    @vc.flush_output_buffer
    assert_equal '', output_buffer
    assert_equal ['foo', 'bar'], body_parts
  end

  test 'flushing preserves output buffer encoding' do
    original_buffer = ' '.force_encoding(Encoding::EUC_JP)
    @vc.output_buffer = original_buffer
    @vc.flush_output_buffer
    assert_equal ['foo', original_buffer], body_parts
    assert_not_equal original_buffer, output_buffer
    assert_equal Encoding::EUC_JP, output_buffer.encoding
  end

  protected
    def output_buffer
      @vc.output_buffer
    end

    def body_parts
      @controller.response.body_parts
    end
end
