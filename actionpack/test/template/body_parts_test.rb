require 'abstract_unit'
require 'action_view/body_parts/concurrent_block'

class BodyPartsTest < ActionController::TestCase
  RENDERINGS = [Object.new, Object.new, Object.new]

  class TestController < ActionController::Base
    def index
      RENDERINGS.each do |rendering|
        response.template.punctuate_body! rendering
      end
      @performed_render = true
    end
  end

  tests TestController

  def test_body_parts
    get :index
    assert_equal RENDERINGS, @response.body_parts
    assert_equal RENDERINGS.join, @response.body
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
