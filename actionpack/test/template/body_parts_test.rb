require 'abstract_unit'
require 'action_view/body_parts/concurrent_block'

class BodyPartTest < ActionController::TestCase
  module EdgeSideInclude
    QUEUE_REDEMPTION_URL = 'http://render.farm/renderings/%s'
    ESI_INCLUDE_TAG = '<esi:include src="%s" />'

    def self.redemption_tag(receipt)
      ESI_INCLUDE_TAG % QUEUE_REDEMPTION_URL % receipt
    end

    class BodyPart
      def initialize(rendering)
        @receipt = enqueue(rendering)
      end

      def to_s
        EdgeSideInclude.redemption_tag(@receipt)
      end

      protected
        # Pretend we sent this rendering off for processing.
        def enqueue(rendering)
          rendering.object_id.to_s
        end
    end
  end

  class TestController < ActionController::Base
    RENDERINGS = [Object.new, Object.new, Object.new]

    def index
      RENDERINGS.each do |rendering|
        edge_side_include rendering
      end
      @performed_render = true
    end

    def edge_side_include(rendering)
      response.template.punctuate_body! EdgeSideInclude::BodyPart.new(rendering)
    end
  end

  tests TestController

  def test_queued_parts
    get :index
    expected = TestController::RENDERINGS.map { |rendering| EdgeSideInclude.redemption_tag(rendering.object_id) }.join
    assert_equal expected, @response.body
  end
end


class ConcurrentBlockPartTest < ActionController::TestCase
  class TestController < ActionController::Base
    def index
      append_thread_id = lambda do |parts|
        parts << Thread.current.object_id
        parts << '::'
        parts << Time.now.to_i
        sleep 0.1
      end

      future_render &append_thread_id
      response.body_parts << '-'

      future_render &append_thread_id
      response.body_parts << '-'

      future_render do |parts|
        parts << ActionView::BodyParts::ConcurrentBlock.new(&append_thread_id)
        parts << '-'
        parts << ActionView::BodyParts::ConcurrentBlock.new(&append_thread_id)
      end

      @performed_render = true
    end

    def future_render(&block)
      response.template.punctuate_body! ActionView::BodyParts::ConcurrentBlock.new(&block)
    end
  end

  tests TestController

  def test_concurrent_threaded_parts
    get :index

    elapsed = Benchmark.ms do
      thread_ids = @response.body.split('-').map { |part| part.split('::').first.to_i }
      assert_equal thread_ids.size, thread_ids.uniq.size
    end
    assert (elapsed - 100).abs < 10, elapsed
  end
end


class OpenUriPartTest < ActionController::TestCase
  class OpenUriPart < ActionView::BodyParts::ConcurrentBlock
    def initialize(url)
      url = URI::Generic === url ? url : URI.parse(url)
      super() { |body| body << url.read }
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
      def url.read; sleep 0.1; path end
      response.template.punctuate_body! OpenUriPart.new(url)
    end
  end

  tests TestController

  def test_concurrent_open_uri_parts
    get :index

    elapsed = Benchmark.ms do
      assert_equal '/foo/bar/baz', @response.body
    end
    assert (elapsed - 100).abs < 10, elapsed
  end
end
