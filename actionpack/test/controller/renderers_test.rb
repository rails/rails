require 'abstract_unit'
require 'controller/fake_models'
require 'active_support/logger'

class RenderersTest < ActionController::TestCase
  class XmlRenderable
    def to_xml(options)
      options[:root] ||= "i-am-xml"
      "<#{options[:root]}/>"
    end
  end
  class JsonRenderable
    def as_json(options={})
      hash = { :a => :b, :c => :d, :e => :f }
      hash.except!(*options[:except]) if options[:except]
      hash
    end

    def to_json(options = {})
      super :except => [:c, :e]
    end
  end
  class CsvRenderable
    def to_csv
      "c,s,v"
    end
  end
  class TestController < ActionController::Base

    def render_csv
      render csv: CsvRenderable.new
    end

    def respond_to_mime
      respond_to do |type|
        type.json do
          if params[:serializer_name]
            render json: JsonRenderable.new, serializer_name: params[:serializer_name]
          else
            render json: JsonRenderable.new
          end
        end
        type.js   { render json: 'JS', callback: 'alert' }
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

  setup do
    # enable a logger so that (e.g.) the benchmarking stuff runs, so we can get
    # a more accurate simulation of what happens in "real life".
    @controller.logger = ActiveSupport::Logger.new(nil)
  end

  def test_raises_missing_template_no_renderer
    assert_raise ActionView::MissingTemplate do
      get :respond_to_mime, format: 'csv'
    end
    assert_equal Mime[:csv], @response.content_type
    assert_equal "", @response.body
  end

  def test_respond_to_adding_csv_rendering_via_renderers_add
    ActionController::Renderers.add :csv do |value, options|
      send_data value, type: Mime[:csv]
    end
    ActionController::Renderers.add_serializer :csv do |value, options|
      value.to_csv
    end
    @request.accept = "text/csv"
    get :respond_to_mime, format: 'csv'
    assert_equal Mime[:csv], @response.content_type
    assert_equal "c,s,v", @response.body
  ensure
    ActionController::Renderers.remove :csv
    ActionController::Renderers.remove_serializer :csv
  end

  # FIXME: bundle exec ruby -Ilib:test test/controller/renderers_test.rb--seed 37264
  # RenderersTest#test_render_adding_csv_rendering_via_renderers_add:
  # ActionController::MissingSerializer: No serializer defined for format: There is no 'csv' serializer.
  # Known serializers are [:json, :js, :xml]
  #   rails/actionpack/lib/action_controller/metal/renderers.rb:49:in `block in <module:Renderers>'
  #   rails/actionpack/lib/action_controller/metal/renderers.rb:258:in `yield'
  #   rails/actionpack/lib/action_controller/metal/renderers.rb:258:in `block in _render_to_body_with_renderer'
  #   .rvm/rubies/ruby-2.2.3/lib/ruby/2.2.0/set.rb:283:in `each_key'
  #   .rvm/rubies/ruby-2.2.3/lib/ruby/2.2.0/set.rb:283:in `each'
  #   rails/actionpack/lib/action_controller/metal/renderers.rb:251:in `_render_to_body_with_renderer'
  #   rails/actionpack/lib/action_controller/metal/renderers.rb:247:in `render_to_body'
  #   rails/actionpack/lib/abstract_controller/rendering.rb:25:in `render'
  #   rails/actionpack/lib/action_controller/metal/rendering.rb:36:in `render'
  #   rails/actionpack/lib/action_controller/metal/instrumentation.rb:43:in `block (2 levels) in render'
  #   rails/activesupport/lib/active_support/core_ext/benchmark.rb:12:in `block in ms'
  #   .rvm/rubies/ruby-2.2.3/lib/ruby/2.2.0/benchmark.rb:303:in `realtime'
  #   rails/activesupport/lib/active_support/core_ext/benchmark.rb:12:in `ms'
  #   rails/actionpack/lib/action_controller/metal/instrumentation.rb:43:in `block in render'
  #   rails/actionpack/lib/action_controller/metal/instrumentation.rb:86:in `cleanup_view_runtime'
  #   rails/actionpack/lib/action_controller/metal/instrumentation.rb:42:in `render'
  # test/controller/renderers_test.rb:31:in `render_csv'
  #   rails/actionpack/lib/action_controller/metal/basic_implicit_render.rb:4:in `send_action'
  #   rails/actionpack/lib/abstract_controller/base.rb:183:in `process_action'
  #   rails/actionpack/lib/action_controller/metal/rendering.rb:30:in `process_action'
  #   rails/actionpack/lib/abstract_controller/callbacks.rb:20:in `block in process_action'
  #   rails/activesupport/lib/active_support/callbacks.rb:97:in `__run_callbacks__'
  #   rails/activesupport/lib/active_support/callbacks.rb:750:in `_run_process_action_callbacks'
  #   rails/activesupport/lib/active_support/callbacks.rb:90:in `run_callbacks'
  #   rails/actionpack/lib/abstract_controller/callbacks.rb:19:in `process_action'
  #   rails/actionpack/lib/action_controller/metal/rescue.rb:27:in `process_action'
  #   rails/actionpack/lib/action_controller/metal/instrumentation.rb:31:in `block in process_action'
  #   rails/activesupport/lib/active_support/notifications.rb:164:in `block in instrument'
  #   rails/activesupport/lib/active_support/notifications/instrumenter.rb:21:in `instrument'
  #   rails/activesupport/lib/active_support/notifications.rb:164:in `instrument'
  #   rails/actionpack/lib/action_controller/metal/instrumentation.rb:29:in `process_action'
  #   rails/actionpack/lib/action_controller/metal/params_wrapper.rb:248:in `process_action'
  #   rails/actionpack/lib/abstract_controller/base.rb:128:in `process'
  #   rails/actionview/lib/action_view/rendering.rb:30:in `process'
  #   rails/actionpack/lib/action_controller/metal.rb:190:in `dispatch'
  #   rails/actionpack/lib/action_controller/test_case.rb:531:in `process'
  #   rails/actionpack/lib/action_controller/test_case.rb:624:in `process_with_kwargs'
  #   rails/actionpack/lib/action_controller/test_case.rb:381:in `get'
  # test/controller/renderers_test.rb:94:in `test_render_adding_csv_rendering_via_renderers_add'
  def test_render_adding_csv_rendering_via_renderers_add
    ActionController::Renderers.add :csv do |value, options|
      send_data value, type: Mime[:csv]
    end
    ActionController::Renderers.add_serializer :csv do |value, options|
      value.to_csv
    end
    @request.accept = "text/csv"
    get :render_csv, format: 'csv'
    assert_equal Mime[:csv], @response.content_type
    assert_equal "c,s,v", @response.body
  ensure
    ActionController::Renderers.remove :csv
    ActionController::Renderers.remove_serializer :csv
  end

  def test_missing_serializer
    ActionController::Renderers.add :csv do |value, options|
      send_data value, type: Mime[:csv]
    end
    @request.accept = "text/csv"

    assert_raise ActionController::MissingSerializer do
      get :respond_to_mime, format: 'csv'
    end

    assert_equal Mime[:csv], @response.content_type
    assert_equal "", @response.body
  ensure
    ActionController::Renderers.remove :csv
  end

  def test_replacing_serializer
    default_json_serializer = @controller._serializers[:json]
    get :respond_to_mime, format: 'json'
    assert_equal JsonRenderable.new.to_json, @response.body

    @controller.class.serializing json: ->(json, options) do
      return json if json.is_a?(String)

      json = json.as_json(options) if json.respond_to?(:as_json)
      json = JSON.pretty_generate(json, options)
      json
    end
    get :respond_to_mime, format: 'json'
    assert_equal JSON.pretty_generate(JsonRenderable.new.as_json), @response.body
  ensure
    @controller.class.serializing json: default_json_serializer
  end

  def test_replaced_serializer_is_inherited
    default_json_serializer = @controller._serializers[:json]
    get :respond_to_mime, format: 'json'
    assert_equal JsonRenderable.new.to_json, @response.body

    @controller.class.serializing json: ->(json, options) do
      return json if json.is_a?(String)

      json = json.as_json(options) if json.respond_to?(:as_json)
      json = JSON.pretty_generate(json, options)
      json
    end
    subclass = Class.new(@controller.class)
    assert_equal @controller._serializers[:json], subclass._serializers[:json]
    refute_equal ActionController::Base._serializers[:json], subclass._serializers[:json]
  ensure
    @controller.class.serializing json: default_json_serializer
  end

  def test_serialize_with_serializer_name
    assert_raise ActionController::MissingSerializer do
      get :respond_to_mime, format: 'json', params: { serializer_name: :custom_json }
    end

    ActionController::Renderers.add_serializer :custom_json do |json, options|
      return json if json.is_a?(String)

      json = json.as_json(options) if json.respond_to?(:as_json)
      json = JSON.pretty_generate(json, options)
      json
    end

    get :respond_to_mime, format: 'json', params: { serializer_name: :custom_json }
    assert_equal JSON.pretty_generate(JsonRenderable.new.as_json), @response.body
  ensure
    ActionController::Renderers.remove_serializer(:custom_json)
  end

end
