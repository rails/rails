require "abstract_unit"
require "controller/fake_models"
require "active_support/logger"

class RenderersTest < ActionController::TestCase
  class XmlRenderable
    def to_xml(options)
      options[:root] ||= "i-am-xml"
      "<#{options[:root]}/>"
    end
  end
  class JsonRenderable
    def as_json(options={})
      hash = { a: :b, c: :d, e: :f }
      hash.except!(*options[:except]) if options[:except]
      hash
    end

    def to_json(options = {})
      super except: [:c, :e]
    end
  end
  class CsvRenderable
    def to_csv
      "c,s,v"
    end
  end
  class TestController < ActionController::Base

    def render_simon_says
      render simon: "foo"
    end

    def respond_to_mime
      respond_to do |type|
        type.json do
          render json: JsonRenderable.new
        end
        type.js   { render json: "JS", callback: "alert" }
        type.csv  { render csv: CsvRenderable.new    }
        type.xml  { render xml: XmlRenderable.new     }
        type.html { render body: "HTML"    }
        type.rss  { render body: "RSS"     }
        type.all  { render body: "Nothing" }
        type.any(:js, :xml) { render body: "Either JS or XML" }
      end
    end
  end

  tests TestController

  def setup
    # enable a logger so that (e.g.) the benchmarking stuff runs, so we can get
    # a more accurate simulation of what happens in "real life".
    super
    @controller.logger = ActiveSupport::Logger.new(nil)
  end

  def test_using_custom_render_option
    ActionController.add_renderer :simon do |says, options|
      self.content_type  = Mime[:text]
      self.response_body = "Simon says: #{says}"
    end

    get :render_simon_says
    assert_equal "Simon says: foo", @response.body
  ensure
    ActionController.remove_renderer :simon
  end

  def test_raises_missing_template_no_renderer
    assert_raise ActionView::MissingTemplate do
      get :respond_to_mime, format: "csv"
    end
    assert_equal Mime[:csv], @response.content_type
    assert_equal "", @response.body
  end

  def test_adding_csv_rendering_via_renderers_add
    ActionController::Renderers.add :csv do |value, options|
      send_data value.to_csv, type: Mime[:csv]
    end
    @request.accept = "text/csv"
    get :respond_to_mime, format: "csv"
    assert_equal Mime[:csv], @response.content_type
    assert_equal "c,s,v", @response.body
  ensure
    ActionController::Renderers.remove :csv
  end
end
