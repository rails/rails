require 'abstract_unit'

class OutputBufferTest < ActionController::TestCase
  class TestController < ActionController::Base
    def index
      render :text => 'foo'
    end
  end

  tests TestController

  def test_flush_output_buffer
    # Start with the default body parts
    get :index
    assert_equal ['foo'], @response.body_parts
    assert_nil @response.template.output_buffer

    # Nil output buffer is skipped
    @response.template.flush_output_buffer
    assert_nil @response.template.output_buffer
    assert_equal ['foo'], @response.body_parts

    # Empty output buffer is skipped
    @response.template.output_buffer = ''
    @response.template.flush_output_buffer
    assert_equal '', @response.template.output_buffer
    assert_equal ['foo'], @response.body_parts

    # Flushing appends the output buffer to the body parts
    @response.template.output_buffer = 'bar'
    @response.template.flush_output_buffer
    assert_equal '', @response.template.output_buffer
    assert_equal ['foo', 'bar'], @response.body_parts
  end
end
