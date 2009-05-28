require 'abstract_unit'

class OutputBufferTest < ActionController::TestCase
  class TestController < ActionController::Base
    def index
      render :text => 'foo'
    end
  end

  tests TestController

  def setup
    get :index
    assert_equal ['foo'], body_parts
  end

  test 'output buffer is nil after rendering' do
    assert_nil output_buffer
  end

  test 'flushing ignores nil output buffer' do
    @controller.template.flush_output_buffer
    assert_nil output_buffer
    assert_equal ['foo'], body_parts
  end

  test 'flushing ignores empty output buffer' do
    @controller.template.output_buffer = ''
    @controller.template.flush_output_buffer
    assert_equal '', output_buffer
    assert_equal ['foo'], body_parts
  end

  test 'flushing appends the output buffer to the body parts' do
    @controller.template.output_buffer = 'bar'
    @controller.template.flush_output_buffer
    assert_equal '', output_buffer
    assert_equal ['foo', 'bar'], body_parts
  end

  if '1.9'.respond_to?(:force_encoding)
    test 'flushing preserves output buffer encoding' do
      original_buffer = ' '.force_encoding(Encoding::EUC_JP)
      @controller.template.output_buffer = original_buffer
      @controller.template.flush_output_buffer
      assert_equal ['foo', original_buffer], body_parts
      assert_not_equal original_buffer, output_buffer
      assert_equal Encoding::EUC_JP, output_buffer.encoding
    end
  end

  protected
    def output_buffer
      @controller.template.output_buffer
    end

    def body_parts
      @controller.template.response.body_parts
    end
end
