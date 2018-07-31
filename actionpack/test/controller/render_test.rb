# frozen_string_literal: true

require "abstract_unit"
require "controller/fake_models"

class TestControllerWithExtraEtags < ActionController::Base
  def self.controller_name; "test"; end
  def self.controller_path; "test"; end

  etag { nil  }
  etag { "ab" }
  etag { :cde }
  etag { [:f] }
  etag { nil  }

  def fresh
    render plain: "stale" if stale?(etag: "123", template: false)
  end

  def array
    render plain: "stale" if stale?(etag: %w(1 2 3), template: false)
  end

  def strong
    render plain: "stale" if stale?(strong_etag: "strong", template: false)
  end

  def with_template
    if stale? template: "test/hello_world"
      render plain: "stale"
    end
  end

  def with_implicit_template
    fresh_when(etag: "123")
  end
end

class ImplicitRenderTestController < ActionController::Base
  def empty_action
  end

  def empty_action_with_template
  end
end

module Namespaced
  class ImplicitRenderTestController < ActionController::Base
    def hello_world
      fresh_when(etag: "abc")
    end
  end
end

class TestController < ActionController::Base
  protect_from_forgery

  before_action :set_variable_for_layout

  class LabellingFormBuilder < ActionView::Helpers::FormBuilder
  end

  layout :determine_layout

  def name
    nil
  end

  private :name
  helper_method :name

  def hello_world
  end

  def conditional_hello
    if stale?(last_modified: Time.now.utc.beginning_of_day, etag: [:foo, 123])
      render action: "hello_world"
    end
  end

  def conditional_hello_with_record
    record = Struct.new(:updated_at, :cache_key).new(Time.now.utc.beginning_of_day, "foo/123")

    if stale?(record)
      render action: "hello_world"
    end
  end

  def dynamic_render
    render params[:id] # => String, AC::Params
  end

  def dynamic_render_permit
    render params[:id].permit(:file)
  end

  def dynamic_render_with_file
    # This is extremely bad, but should be possible to do.
    file = params[:id] # => String, AC::Params
    render file: file
  end

  class Collection
    def initialize(records)
      @records = records
    end

    def maximum(attribute)
      @records.max_by(&attribute).public_send(attribute)
    end
  end

  def conditional_hello_with_collection_of_records
    ts = Time.now.utc.beginning_of_day

    record = Struct.new(:updated_at, :cache_key).new(ts, "foo/123")
    old_record = Struct.new(:updated_at, :cache_key).new(ts - 1.day, "bar/123")

    if stale?(Collection.new([record, old_record]))
      render action: "hello_world"
    end
  end

  def conditional_hello_with_expires_in
    expires_in 60.1.seconds
    render action: "hello_world"
  end

  def conditional_hello_with_expires_in_with_public
    expires_in 1.minute, public: true
    render action: "hello_world"
  end

  def conditional_hello_with_expires_in_with_must_revalidate
    expires_in 1.minute, must_revalidate: true
    render action: "hello_world"
  end

  def conditional_hello_with_expires_in_with_public_and_must_revalidate
    expires_in 1.minute, public: true, must_revalidate: true
    render action: "hello_world"
  end

  def conditional_hello_with_expires_in_with_stale_while_revalidate
    expires_in 1.minute, public: true, stale_while_revalidate: 5.minutes
    render action: "hello_world"
  end

  def conditional_hello_with_expires_in_with_stale_if_error
    expires_in 1.minute, public: true, stale_if_error: 5.minutes
    render action: "hello_world"
  end

  def conditional_hello_with_expires_in_with_public_with_more_keys
    expires_in 1.minute, :public => true, "s-maxage" => 5.hours
    render action: "hello_world"
  end

  def conditional_hello_with_expires_in_with_public_with_more_keys_old_syntax
    expires_in 1.minute, :public => true, :private => nil, "s-maxage" => 5.hours
    render action: "hello_world"
  end

  def conditional_hello_with_expires_now
    expires_now
    render action: "hello_world"
  end

  def conditional_hello_with_cache_control_headers
    response.headers["Cache-Control"] = "no-transform"
    expires_now
    render action: "hello_world"
  end

  def conditional_hello_with_expires_and_confliciting_cache_control_headers
    response.headers["Cache-Control"] = "no-cache, must-revalidate"
    expires_now
    render action: "hello_world"
  end

  def conditional_hello_without_expires_and_confliciting_cache_control_headers
    response.headers["Cache-Control"] = "no-cache, must-revalidate"
    render action: "hello_world"
  end

  def conditional_hello_with_bangs
    render action: "hello_world"
  end
  before_action :handle_last_modified_and_etags, only: :conditional_hello_with_bangs

  def handle_last_modified_and_etags
    fresh_when(last_modified: Time.now.utc.beginning_of_day, etag: [ :foo, 123 ])
  end

  def head_created
    head :created
  end

  def head_created_with_application_json_content_type
    head :created, content_type: "application/json"
  end

  def head_ok_with_image_png_content_type
    head :ok, content_type: "image/png"
  end

  def head_with_location_header
    head :ok, location: "/foo"
  end

  def head_with_location_object
    head :ok, location: Customer.new("david", 1)
  end

  def head_with_symbolic_status
    head params[:status].intern
  end

  def head_with_integer_status
    head params[:status].to_i
  end

  def head_with_string_status
    head params[:status]
  end

  def head_with_custom_header
    head :ok, x_custom_header: "something"
  end

  def head_with_www_authenticate_header
    head :ok, "WWW-Authenticate" => "something"
  end

  def head_with_status_code_first
    head :forbidden, x_custom_header: "something"
  end

  def head_and_return
    head(:ok) && return
    raise "should not reach this line"
  end

  def head_with_no_content
    # Fill in the headers with dummy data to make
    # sure they get removed during the testing
    response.headers["Content-Type"] = "dummy"
    response.headers["Content-Length"] = 42

    head 204
  end

  private

    def set_variable_for_layout
      @variable_for_layout = nil
    end

    def determine_layout
      case action_name
      when "hello_world", "layout_test", "rendering_without_layout",
             "rendering_nothing_on_layout", "render_text_hello_world",
             "render_text_hello_world_with_layout",
             "hello_world_with_layout_false",
             "partial_only", "accessing_params_in_template",
             "accessing_params_in_template_with_layout",
             "render_with_explicit_template",
             "render_with_explicit_string_template",
             "update_page", "update_page_with_instance_variables"

        "layouts/standard"
      when "action_talk_to_layout", "layout_overriding_layout"
        "layouts/talk_from_action"
      when "render_implicit_html_template_from_xhr_request"
        (request.xhr? ? "layouts/xhr" : "layouts/standard")
      end
    end
end

module TemplateModificationHelper
  private
    def modify_template(name)
      path = File.expand_path("../fixtures/#{name}.erb", __dir__)
      original = File.read(path)
      File.write(path, "#{original} Modified!")
      ActionView::LookupContext::DetailsKey.clear
      yield
    ensure
      File.write(path, original)
    end
end

class MetalTestController < ActionController::Metal
  include AbstractController::Rendering
  include ActionView::Rendering
  include ActionController::Rendering

  def accessing_logger_in_template
    render inline: "<%= logger.class %>"
  end
end

class ExpiresInRenderTest < ActionController::TestCase
  tests TestController

  def setup
    super
    ActionController::Base.view_paths.paths.each(&:clear_cache)
  end

  def test_dynamic_render_with_file
    # This is extremely bad, but should be possible to do.
    assert File.exist?(File.expand_path("../../test/abstract_unit.rb", __dir__))
    response = get :dynamic_render_with_file, params: { id: '../\\../test/abstract_unit.rb' }
    assert_equal File.read(File.expand_path("../../test/abstract_unit.rb", __dir__)),
      response.body
  end

  def test_dynamic_render_with_absolute_path
    file = Tempfile.new("name")
    file.write "secrets!"
    file.flush
    assert_raises ActionView::MissingTemplate do
      get :dynamic_render, params: { id: file.path }
    end
  ensure
    file.close
    file.unlink
  end

  def test_dynamic_render
    assert File.exist?(File.expand_path("../../test/abstract_unit.rb", __dir__))
    assert_raises ActionView::MissingTemplate do
      get :dynamic_render, params: { id: '../\\../test/abstract_unit.rb' }
    end
  end

  def test_permitted_dynamic_render_file_hash
    assert File.exist?(File.expand_path("../../test/abstract_unit.rb", __dir__))
    response = get :dynamic_render_permit, params: { id: { file: '../\\../test/abstract_unit.rb' } }
    assert_equal File.read(File.expand_path("../../test/abstract_unit.rb", __dir__)),
      response.body
  end

  def test_dynamic_render_file_hash
    assert_raises ArgumentError do
      get :dynamic_render, params: { id: { file: '../\\../test/abstract_unit.rb' } }
    end
  end

  def test_expires_in_header
    get :conditional_hello_with_expires_in
    assert_equal "max-age=60, private", @response.headers["Cache-Control"]
  end

  def test_expires_in_header_with_public
    get :conditional_hello_with_expires_in_with_public
    assert_equal "max-age=60, public", @response.headers["Cache-Control"]
  end

  def test_expires_in_header_with_must_revalidate
    get :conditional_hello_with_expires_in_with_must_revalidate
    assert_equal "max-age=60, private, must-revalidate", @response.headers["Cache-Control"]
  end

  def test_expires_in_header_with_public_and_must_revalidate
    get :conditional_hello_with_expires_in_with_public_and_must_revalidate
    assert_equal "max-age=60, public, must-revalidate", @response.headers["Cache-Control"]
  end

  def test_expires_in_header_with_stale_while_revalidate
    get :conditional_hello_with_expires_in_with_stale_while_revalidate
    assert_equal "max-age=60, public, stale-while-revalidate=300", @response.headers["Cache-Control"]
  end

  def test_expires_in_header_with_stale_if_error
    get :conditional_hello_with_expires_in_with_stale_if_error
    assert_equal "max-age=60, public, stale-if-error=300", @response.headers["Cache-Control"]
  end

  def test_expires_in_header_with_additional_headers
    get :conditional_hello_with_expires_in_with_public_with_more_keys
    assert_equal "max-age=60, public, s-maxage=18000", @response.headers["Cache-Control"]
  end

  def test_expires_in_old_syntax
    get :conditional_hello_with_expires_in_with_public_with_more_keys_old_syntax
    assert_equal "max-age=60, public, s-maxage=18000", @response.headers["Cache-Control"]
  end

  def test_expires_now
    get :conditional_hello_with_expires_now
    assert_equal "no-cache", @response.headers["Cache-Control"]
  end

  def test_expires_now_with_cache_control_headers
    get :conditional_hello_with_cache_control_headers
    assert_match(/no-cache/, @response.headers["Cache-Control"])
    assert_match(/no-transform/, @response.headers["Cache-Control"])
  end

  def test_expires_now_with_conflicting_cache_control_headers
    get :conditional_hello_with_expires_and_confliciting_cache_control_headers
    assert_equal "no-cache", @response.headers["Cache-Control"]
  end

  def test_no_expires_now_with_conflicting_cache_control_headers
    get :conditional_hello_without_expires_and_confliciting_cache_control_headers
    assert_equal "no-cache", @response.headers["Cache-Control"]
  end

  def test_date_header_when_expires_in
    time = Time.mktime(2011, 10, 30)
    Time.stub :now, time do
      get :conditional_hello_with_expires_in
      assert_equal Time.now.httpdate, @response.headers["Date"]
    end
  end
end

class LastModifiedRenderTest < ActionController::TestCase
  tests TestController

  def setup
    super
    @last_modified = Time.now.utc.beginning_of_day.httpdate
  end

  def test_responds_with_last_modified
    get :conditional_hello
    assert_equal @last_modified, @response.headers["Last-Modified"]
  end

  def test_request_not_modified
    @request.if_modified_since = @last_modified
    get :conditional_hello
    assert_equal 304, @response.status.to_i
    assert_predicate @response.body, :blank?
    assert_equal @last_modified, @response.headers["Last-Modified"]
  end

  def test_request_not_modified_but_etag_differs
    @request.if_modified_since = @last_modified
    @request.if_none_match = '"234"'
    get :conditional_hello
    assert_response :success
  end

  def test_request_modified
    @request.if_modified_since = "Thu, 16 Jul 2008 00:00:00 GMT"
    get :conditional_hello
    assert_equal 200, @response.status.to_i
    assert_predicate @response.body, :present?
    assert_equal @last_modified, @response.headers["Last-Modified"]
  end

  def test_responds_with_last_modified_with_record
    get :conditional_hello_with_record
    assert_equal @last_modified, @response.headers["Last-Modified"]
  end

  def test_request_not_modified_with_record
    @request.if_modified_since = @last_modified
    get :conditional_hello_with_record
    assert_equal 304, @response.status.to_i
    assert_predicate @response.body, :blank?
    assert_not_nil @response.etag
    assert_equal @last_modified, @response.headers["Last-Modified"]
  end

  def test_request_not_modified_but_etag_differs_with_record
    @request.if_modified_since = @last_modified
    @request.if_none_match = '"234"'
    get :conditional_hello_with_record
    assert_response :success
  end

  def test_request_modified_with_record
    @request.if_modified_since = "Thu, 16 Jul 2008 00:00:00 GMT"
    get :conditional_hello_with_record
    assert_equal 200, @response.status.to_i
    assert_predicate @response.body, :present?
    assert_equal @last_modified, @response.headers["Last-Modified"]
  end

  def test_responds_with_last_modified_with_collection_of_records
    get :conditional_hello_with_collection_of_records
    assert_equal @last_modified, @response.headers["Last-Modified"]
  end

  def test_request_not_modified_with_collection_of_records
    @request.if_modified_since = @last_modified
    get :conditional_hello_with_collection_of_records
    assert_equal 304, @response.status.to_i
    assert_predicate @response.body, :blank?
    assert_equal @last_modified, @response.headers["Last-Modified"]
  end

  def test_request_not_modified_but_etag_differs_with_collection_of_records
    @request.if_modified_since = @last_modified
    @request.if_none_match = '"234"'
    get :conditional_hello_with_collection_of_records
    assert_response :success
  end

  def test_request_modified_with_collection_of_records
    @request.if_modified_since = "Thu, 16 Jul 2008 00:00:00 GMT"
    get :conditional_hello_with_collection_of_records
    assert_equal 200, @response.status.to_i
    assert_predicate @response.body, :present?
    assert_equal @last_modified, @response.headers["Last-Modified"]
  end

  def test_request_with_bang_gets_last_modified
    get :conditional_hello_with_bangs
    assert_equal @last_modified, @response.headers["Last-Modified"]
    assert_response :success
  end

  def test_request_with_bang_obeys_last_modified
    @request.if_modified_since = @last_modified
    get :conditional_hello_with_bangs
    assert_response :not_modified
  end

  def test_last_modified_works_with_less_than_too
    @request.if_modified_since = 5.years.ago.httpdate
    get :conditional_hello_with_bangs
    assert_response :success
  end
end

class EtagRenderTest < ActionController::TestCase
  tests TestControllerWithExtraEtags
  include TemplateModificationHelper

  def test_strong_etag
    @request.if_none_match = strong_etag(["strong", "ab", :cde, [:f]])
    get :strong
    assert_response :not_modified

    @request.if_none_match = "*"
    get :strong
    assert_response :not_modified

    @request.if_none_match = '"strong"'
    get :strong
    assert_response :ok

    @request.if_none_match = weak_etag(["strong", "ab", :cde, [:f]])
    get :strong
    assert_response :ok
  end

  def test_multiple_etags
    @request.if_none_match = weak_etag(["123", "ab", :cde, [:f]])
    get :fresh
    assert_response :not_modified

    @request.if_none_match = %("nomatch")
    get :fresh
    assert_response :success
  end

  def test_array
    @request.if_none_match = weak_etag([%w(1 2 3), "ab", :cde, [:f]])
    get :array
    assert_response :not_modified

    @request.if_none_match = %("nomatch")
    get :array
    assert_response :success
  end

  def test_etag_reflects_template_digest
    get :with_template
    assert_response :ok
    assert_not_nil etag = @response.etag

    request.if_none_match = etag
    get :with_template
    assert_response :not_modified

    modify_template("test/hello_world") do
      request.if_none_match = etag
      get :with_template
      assert_response :ok
      assert_not_equal etag, @response.etag
    end
  end

  def test_etag_reflects_implicit_template_digest
    get :with_implicit_template
    assert_response :ok
    assert_not_nil etag = @response.etag

    request.if_none_match = etag
    get :with_implicit_template
    assert_response :not_modified

    modify_template("test/with_implicit_template") do
      request.if_none_match = etag
      get :with_implicit_template
      assert_response :ok
      assert_not_equal etag, @response.etag
    end
  end

  private
    def weak_etag(record)
      "W/#{strong_etag record}"
    end

    def strong_etag(record)
      %("#{ActiveSupport::Digest.hexdigest(ActiveSupport::Cache.expand_cache_key(record))}")
    end
end

class NamespacedEtagRenderTest < ActionController::TestCase
  tests Namespaced::ImplicitRenderTestController
  include TemplateModificationHelper

  def test_etag_reflects_template_digest
    get :hello_world
    assert_response :ok
    assert_not_nil etag = @response.etag

    request.if_none_match = etag
    get :hello_world
    assert_response :not_modified

    modify_template("namespaced/implicit_render_test/hello_world") do
      request.if_none_match = etag
      get :hello_world
      assert_response :ok
      assert_not_equal etag, @response.etag
    end
  end
end

class MetalRenderTest < ActionController::TestCase
  tests MetalTestController

  def test_access_to_logger_in_view
    get :accessing_logger_in_template
    assert_equal "NilClass", @response.body
  end
end

class ActionControllerRenderTest < ActionController::TestCase
  class MinimalController < ActionController::Metal
    include AbstractController::Rendering
    include ActionController::Rendering
  end

  def test_direct_render_to_string_with_body
    mc = MinimalController.new
    assert_equal "Hello world!", mc.render_to_string(body: ["Hello world!"])
  end
end

class ActionControllerBaseRenderTest < ActionController::TestCase
  def test_direct_render_to_string
    ac = ActionController::Base.new()
    assert_equal "Hello world!", ac.render_to_string(template: "test/hello_world")
  end
end

class ImplicitRenderTest < ActionController::TestCase
  tests ImplicitRenderTestController

  def test_implicit_no_content_response_as_browser
    assert_raises(ActionController::MissingExactTemplate) do
      get :empty_action
    end
  end

  def test_implicit_no_content_response_as_xhr
    get :empty_action, xhr: true
    assert_response :no_content
  end

  def test_implicit_success_response_with_right_format
    get :empty_action_with_template
    assert_equal "<h1>Empty action rendered this implicitly.</h1>\n", @response.body
    assert_response :success
  end

  def test_implicit_unknown_format_response
    assert_raises(ActionController::UnknownFormat) do
      get :empty_action_with_template, format: "json"
    end
  end
end

class HeadRenderTest < ActionController::TestCase
  tests TestController

  def setup
    @request.host = "www.nextangle.com"
  end

  def test_head_created
    post :head_created
    assert_predicate @response.body, :blank?
    assert_response :created
  end

  def test_head_created_with_application_json_content_type
    post :head_created_with_application_json_content_type
    assert_predicate @response.body, :blank?
    assert_equal "application/json", @response.header["Content-Type"]
    assert_response :created
  end

  def test_head_ok_with_image_png_content_type
    post :head_ok_with_image_png_content_type
    assert_predicate @response.body, :blank?
    assert_equal "image/png", @response.header["Content-Type"]
    assert_response :ok
  end

  def test_head_with_location_header
    get :head_with_location_header
    assert_predicate @response.body, :blank?
    assert_equal "/foo", @response.headers["Location"]
    assert_response :ok
  end

  def test_head_with_location_object
    with_routing do |set|
      set.draw do
        resources :customers

        ActiveSupport::Deprecation.silence do
          get ":controller/:action"
        end
      end

      get :head_with_location_object
      assert_predicate @response.body, :blank?
      assert_equal "http://www.nextangle.com/customers/1", @response.headers["Location"]
      assert_response :ok
    end
  end

  def test_head_with_custom_header
    get :head_with_custom_header
    assert_predicate @response.body, :blank?
    assert_equal "something", @response.headers["X-Custom-Header"]
    assert_response :ok
  end

  def test_head_with_www_authenticate_header
    get :head_with_www_authenticate_header
    assert_predicate @response.body, :blank?
    assert_equal "something", @response.headers["WWW-Authenticate"]
    assert_response :ok
  end

  def test_head_with_symbolic_status
    get :head_with_symbolic_status, params: { status: "ok" }
    assert_equal 200, @response.status
    assert_response :ok

    get :head_with_symbolic_status, params: { status: "not_found" }
    assert_equal 404, @response.status
    assert_response :not_found

    get :head_with_symbolic_status, params: { status: "no_content" }
    assert_equal 204, @response.status
    assert_not_includes @response.headers, "Content-Length"
    assert_response :no_content

    Rack::Utils::SYMBOL_TO_STATUS_CODE.each do |status, code|
      get :head_with_symbolic_status, params: { status: status.to_s }
      assert_equal code, @response.response_code
      assert_response status
    end
  end

  def test_head_with_integer_status
    Rack::Utils::HTTP_STATUS_CODES.each do |code, message|
      get :head_with_integer_status, params: { status: code.to_s }
      assert_equal message, @response.message
    end
  end

  def test_head_with_no_content
    get :head_with_no_content

    assert_equal 204, @response.status
    assert_nil @response.headers["Content-Type"]
    assert_nil @response.headers["Content-Length"]
  end

  def test_head_with_string_status
    get :head_with_string_status, params: { status: "404 Eat Dirt" }
    assert_equal 404, @response.response_code
    assert_equal "Not Found", @response.message
    assert_response :not_found
  end

  def test_head_with_status_code_first
    get :head_with_status_code_first
    assert_equal 403, @response.response_code
    assert_equal "Forbidden", @response.message
    assert_equal "something", @response.headers["X-Custom-Header"]
    assert_response :forbidden
  end

  def test_head_returns_truthy_value
    assert_nothing_raised do
      get :head_and_return
    end
  end
end

class HttpCacheForeverTest < ActionController::TestCase
  class HttpCacheForeverController < ActionController::Base
    def cache_me_forever
      http_cache_forever(public: params[:public]) do
        render plain: "hello"
      end
    end
  end

  tests HttpCacheForeverController

  def test_cache_with_public
    get :cache_me_forever, params: { public: true }
    assert_response :ok
    assert_equal "max-age=#{100.years}, public", @response.headers["Cache-Control"]
    assert_not_nil @response.etag
    assert_predicate @response, :weak_etag?
  end

  def test_cache_with_private
    get :cache_me_forever
    assert_response :ok
    assert_equal "max-age=#{100.years}, private", @response.headers["Cache-Control"]
    assert_not_nil @response.etag
    assert_predicate @response, :weak_etag?
  end

  def test_cache_response_code_with_if_modified_since
    get :cache_me_forever
    assert_response :ok

    @request.if_modified_since = @response.headers["Last-Modified"]
    get :cache_me_forever
    assert_response :not_modified
  end

  def test_cache_response_code_with_etag
    get :cache_me_forever
    assert_response :ok

    @request.if_none_match = @response.etag
    get :cache_me_forever
    assert_response :not_modified
  end
end
