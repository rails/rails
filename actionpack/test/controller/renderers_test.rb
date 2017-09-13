# frozen_string_literal: true

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
    def as_json(options = {})
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

  def test_explicit_render_using_custom_render_option
    ActionController.add_renderer :simon do |says, options|
      self.content_type = Mime[:text]
      says
    end
    ActionController.add_serializer :simon do |says, options|
      "Simon says: #{says}"
    end

    get :render_simon_says
    assert_equal "Simon says: foo", @response.body
  ensure
    ActionController.remove_renderer :simon
    ActionController.remove_serializer :simon
  end

  def test_explicit_render_raises_missing_template_when_no_such_renderer
    exception = assert_raise ActionView::MissingTemplate do
      get :render_simon_says
    end
    assert_equal Mime[:html], @response.content_type
    assert_equal "", @response.body
    expected_message = "Missing template renderers_test/test/render_simon_says with {:locale=>[:en], :formats=>[:html], :variants=>[], :handlers=>[:raw, :erb, :html, :builder, :ruby]}. Searched in:"
    assert exception.message.start_with?(expected_message), "Expected\n#{exception.message}\nto start with\n#{expected_message}"
  end

  def test_respond_to_raises_missing_template_when_no_renderer
    @request.accept = "text/csv"

    exception = assert_raise ActionView::MissingTemplate do
      get :respond_to_mime
    end

    assert_equal Mime[:csv], @response.content_type
    assert_equal "", @response.body
    expected_message = "Missing template renderers_test/test/respond_to_mime with {:locale=>[:en], :formats=>[:csv], :variants=>[], :handlers=>[:raw, :erb, :html, :builder, :ruby]}. Searched in:"
    assert exception.message.start_with?(expected_message), "Expected\n#{exception.message}\nto start with\n#{expected_message}"
  end

  def test_responds_to_csv_format_when_adding_csv_renderer_via_renderers_add
    ActionController.add_renderer :csv do |value, options|
      send_data value, type: Mime[:csv]
    end
    ActionController.add_serializer :csv do |value, options|
      value.to_csv
    end
    @request.accept = "text/csv"

    get :respond_to_mime

    assert_equal Mime[:csv], @response.content_type
    assert_equal "c,s,v", @response.body
  ensure
    ActionController.remove_renderer :csv
    ActionController.remove_serializer :csv
  end

  def test_respond_to_raises_missing_serializer_when_only_renderer_defined
    ActionController.add_renderer :csv do |value, options|
      send_data value, type: Mime[:csv]
    end
    @request.accept = "text/csv"

    exception = assert_raise ActionController::MissingSerializer do
      get :respond_to_mime
    end

    assert_equal Mime[:csv], @response.content_type
    assert_equal "", @response.body
    expected_message = "No serializer defined for format: There is no 'csv' serializer.\nKnown serializers are [:json, :js, :xml]"
    assert_equal expected_message, exception.message
  ensure
    ActionController.remove_renderer :csv
  end
end
