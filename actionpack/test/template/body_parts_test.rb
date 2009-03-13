require 'abstract_unit'
require 'action_view/body_parts/queued'
require 'action_view/body_parts/threaded'

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


class QueuedPartTest < ActionController::TestCase
  class EdgeSideInclude < ActionView::BodyParts::Queued
    QUEUE_REDEMPTION_URL = 'http://queue/jobs/%s'
    ESI_INCLUDE_TAG = '<esi:include src="%s" />'

    def self.redemption_tag(receipt)
      ESI_INCLUDE_TAG % QUEUE_REDEMPTION_URL % receipt
    end

    protected
      def submit(job)
        job.reverse
      end

      def redeem(receipt)
        self.class.redemption_tag(receipt)
      end
  end

  class TestController < ActionController::Base
    def index
      edge_side_include 'foo'
      edge_side_include 'bar'
      edge_side_include 'baz'
      @performed_render = true
    end

    def edge_side_include(job)
      response.template.punctuate_body! EdgeSideInclude.new(job)
    end
  end

  tests TestController

  def test_queued_parts
    get :index
    expected = %w(oof rab zab).map { |receipt| EdgeSideInclude.redemption_tag(receipt) }.join
    assert_equal expected, @response.body
  end
end


class ThreadedPartTest < ActionController::TestCase
  class TestController < ActionController::Base
    def index
      append_thread_id = lambda do |parts|
        parts << Thread.current.object_id
        parts << '::'
        parts << Time.now.to_i
        sleep 1
      end

      future_render &append_thread_id
      response.body_parts << '-'

      future_render &append_thread_id
      response.body_parts << '-'

      future_render do |parts|
        parts << ActionView::BodyParts::Threaded.new(true, &append_thread_id)
        parts << '-'
        parts << ActionView::BodyParts::Threaded.new(true, &append_thread_id)
      end

      @performed_render = true
    end

    def future_render(&block)
      response.template.punctuate_body! ActionView::BodyParts::Threaded.new(true, &block)
    end
  end

  tests TestController

  def test_concurrent_threaded_parts
    get :index

    before = Time.now.to_i
    thread_ids = @response.body.split('-').map { |part| part.split('::').first.to_i }
    elapsed = Time.now.to_i - before

    assert_equal thread_ids.size, thread_ids.uniq.size
    assert elapsed < 1.1
  end
end


class OpenUriPartTest < ActionController::TestCase
  class OpenUriPart < ActionView::BodyParts::Threaded
    def initialize(url)
      url = URI::Generic === url ? url : URI.parse(url)
      super(true) { |parts| parts << url.read }
    end
  end

  class TestController < ActionController::Base
    def index
      render_url 'http://localhost/foo'
      render_url 'http://localhost/bar'
      render_url 'http://localhost/baz'
      @performed_render = true
    end

    def render_url(url)
      url = URI.parse(url)
      def url.read; path end
      response.template.punctuate_body! OpenUriPart.new(url)
    end
  end

  tests TestController

  def test_concurrent_open_uri_parts
    get :index

    elapsed = Benchmark.ms do
      assert_equal '/foo/bar/baz', @response.body
    end
    assert elapsed < 1.1
  end
end
