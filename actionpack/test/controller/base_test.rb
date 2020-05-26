# frozen_string_literal: true

require "abstract_unit"
require "active_support/logger"
require "controller/fake_models"

# Provide some controller to run the tests on.
module Submodule
  class ContainedEmptyController < ActionController::Base
  end
end

class EmptyController < ActionController::Base
end

class SimpleController < ActionController::Base
  def hello
    self.response_body = "hello"
  end
end

class NonEmptyController < ActionController::Base
  def public_action
    head :ok
  end
end

class DefaultUrlOptionsController < ActionController::Base
  def from_view
    render inline: "<%= #{params[:route]} %>"
  end

  def default_url_options
    { host: "www.override.com", action: "new", locale: "en" }
  end
end

class OptionalDefaultUrlOptionsController < ActionController::Base
  def show
    head :ok
  end

  def default_url_options
    { format: "atom", id: "default-id" }
  end
end

class UrlOptionsController < ActionController::Base
  def from_view
    render inline: "<%= #{params[:route]} %>"
  end

  def url_options
    super.merge(host: "www.override.com")
  end
end

class RecordIdentifierIncludedController < ActionController::Base
  include ActionView::RecordIdentifier
end

class ActionMissingController < ActionController::Base
  def action_missing(action)
    render plain: "Response for #{action}"
  end
end

class ControllerClassTests < ActiveSupport::TestCase
  def test_controller_path
    assert_equal "empty", EmptyController.controller_path
    assert_equal EmptyController.controller_path, EmptyController.new.controller_path
    assert_equal "submodule/contained_empty", Submodule::ContainedEmptyController.controller_path
    assert_equal Submodule::ContainedEmptyController.controller_path, Submodule::ContainedEmptyController.new.controller_path
  end

  def test_controller_name
    assert_equal "empty", EmptyController.controller_name
    assert_equal "contained_empty", Submodule::ContainedEmptyController.controller_name
  end

  def test_no_deprecation_when_action_view_record_identifier_is_included
    record = Comment.new
    record.save

    dom_id = nil
    assert_not_deprecated do
      dom_id = RecordIdentifierIncludedController.new.dom_id(record)
    end

    assert_equal "comment_1", dom_id

    dom_class = nil
    assert_not_deprecated do
      dom_class = RecordIdentifierIncludedController.new.dom_class(record)
    end
    assert_equal "comment", dom_class
  end
end

class ControllerInstanceTests < ActiveSupport::TestCase
  def setup
    @empty = EmptyController.new
    @empty.set_request!(ActionDispatch::Request.empty)
    @empty.set_response!(EmptyController.make_response!(@empty.request))
    @contained = Submodule::ContainedEmptyController.new
    @empty_controllers = [@empty, @contained]
  end

  def test_performed?
    assert_not_predicate @empty, :performed?
    @empty.response_body = ["sweet"]
    assert_predicate @empty, :performed?
  end

  def test_action_methods
    @empty_controllers.each do |c|
      assert_equal Set.new, c.class.action_methods, "#{c.controller_path} should be empty!"
    end
  end

  def test_temporary_anonymous_controllers
    name = "ExamplesController"
    klass = Class.new(ActionController::Base)
    Object.const_set(name, klass)

    controller = klass.new
    assert_equal "examples", controller.controller_path
  end

  def test_response_has_default_headers
    original_default_headers = ActionDispatch::Response.default_headers

    ActionDispatch::Response.default_headers = {
      "X-Frame-Options" => "DENY",
      "X-Content-Type-Options" => "nosniff",
      "X-XSS-Protection" => "1;"
    }

    response_headers = SimpleController.action("hello").call(
      "REQUEST_METHOD" => "GET",
      "rack.input" => -> { }
    )[1]

    assert response_headers.key?("X-Frame-Options")
    assert response_headers.key?("X-Content-Type-Options")
    assert response_headers.key?("X-XSS-Protection")
  ensure
    ActionDispatch::Response.default_headers = original_default_headers
  end

  def test_inspect
    assert_match(/#<EmptyController:0x[0-9a-f]+>/, @empty.inspect)
  end
end

class PerformActionTest < ActionController::TestCase
  def use_controller(controller_class)
    @controller = controller_class.new

    # enable a logger so that (e.g.) the benchmarking stuff runs, so we can get
    # a more accurate simulation of what happens in "real life".
    @controller.logger = ActiveSupport::Logger.new(nil)

    @request.host = "www.nextangle.com"
  end

  def test_process_should_be_precise
    use_controller EmptyController
    exception = assert_raise AbstractController::ActionNotFound do
      get :non_existent
    end
    assert_equal "The action 'non_existent' could not be found for EmptyController", exception.message
  end

  if defined?(DidYouMean) && DidYouMean.respond_to?(:correct_error)
    def test_exceptions_have_suggestions_for_fix
      use_controller SimpleController
      exception = assert_raise AbstractController::ActionNotFound do
        get :non_existent
      end
      assert_match "Did you mean?", exception.message
    end
  end

  def test_action_missing_should_work
    use_controller ActionMissingController
    get :arbitrary_action
    assert_equal "Response for arbitrary_action", @response.body
  end
end

class UrlOptionsTest < ActionController::TestCase
  tests UrlOptionsController

  def setup
    super
    @request.host = "www.example.com"
  end

  def test_url_for_query_params_included
    rs = ActionDispatch::Routing::RouteSet.new
    rs.draw do
      get "home" => "pages#home"
    end

    options = {
      action: "home",
      controller: "pages",
      only_path: true,
      params: { "token" => "secret" }
    }

    assert_equal "/home?token=secret", rs.url_for(options)
  end

  def test_url_options_override
    with_routing do |set|
      set.draw do
        get "from_view", to: "url_options#from_view", as: :from_view

        ActiveSupport::Deprecation.silence do
          get ":controller/:action"
        end
      end

      get :from_view, params: { route: "from_view_url" }

      assert_equal "http://www.override.com/from_view", @response.body
      assert_equal "http://www.override.com/from_view", @controller.send(:from_view_url)
      assert_equal "http://www.override.com/default_url_options/index", @controller.url_for(controller: "default_url_options")
    end
  end

  def test_url_helpers_does_not_become_actions
    with_routing do |set|
      set.draw do
        get "account/overview"
      end

      assert_not_includes @controller.class.action_methods, "account_overview_path"
    end
  end
end

class DefaultUrlOptionsTest < ActionController::TestCase
  tests DefaultUrlOptionsController

  def setup
    super
    @request.host = "www.example.com"
  end

  def test_default_url_options_override
    with_routing do |set|
      set.draw do
        get "from_view", to: "default_url_options#from_view", as: :from_view

        ActiveSupport::Deprecation.silence do
          get ":controller/:action"
        end
      end

      get :from_view, params: { route: "from_view_url" }

      assert_equal "http://www.override.com/from_view?locale=en", @response.body
      assert_equal "http://www.override.com/from_view?locale=en", @controller.send(:from_view_url)
      assert_equal "http://www.override.com/default_url_options/new?locale=en", @controller.url_for(controller: "default_url_options")
    end
  end

  def test_default_url_options_are_used_in_non_positional_parameters
    with_routing do |set|
      set.draw do
        scope("/:locale") do
          resources :descriptions
        end

        ActiveSupport::Deprecation.silence do
          get ":controller/:action"
        end
      end

      get :from_view, params: { route: "description_path(1)" }

      assert_equal "/en/descriptions/1", @response.body
      assert_equal "/en/descriptions", @controller.send(:descriptions_path)
      assert_equal "/pl/descriptions", @controller.send(:descriptions_path, "pl")
      assert_equal "/pl/descriptions", @controller.send(:descriptions_path, locale: "pl")
      assert_equal "/pl/descriptions.xml", @controller.send(:descriptions_path, "pl", "xml")
      assert_equal "/en/descriptions.xml", @controller.send(:descriptions_path, format: "xml")
      assert_equal "/en/descriptions/1", @controller.send(:description_path, 1)
      assert_equal "/pl/descriptions/1", @controller.send(:description_path, "pl", 1)
      assert_equal "/pl/descriptions/1", @controller.send(:description_path, 1, locale: "pl")
      assert_equal "/pl/descriptions/1.xml", @controller.send(:description_path, "pl", 1, "xml")
      assert_equal "/en/descriptions/1.xml", @controller.send(:description_path, 1, format: "xml")
    end
  end
end

class OptionalDefaultUrlOptionsControllerTest < ActionController::TestCase
  def test_default_url_options_override_missing_positional_arguments
    with_routing do |set|
      set.draw do
        get "/things/:id(.:format)" => "things#show", :as => :thing
      end
      assert_equal "/things/1.atom", thing_path("1")
      assert_equal "/things/default-id.atom", thing_path
    end
  end
end

class EmptyUrlOptionsTest < ActionController::TestCase
  tests NonEmptyController

  def setup
    super
    @request.host = "www.example.com"
  end

  def test_ensure_url_for_works_as_expected_when_called_with_no_options_if_default_url_options_is_not_set
    get :public_action
    assert_equal "http://www.example.com/non_empty/public_action", @controller.url_for
  end

  def test_named_routes_with_path_without_doing_a_request_first
    @controller = EmptyController.new
    @controller.request = @request

    with_routing do |set|
      set.draw do
        resources :things
      end

      assert_equal "/things", @controller.send(:things_path)
    end
  end
end
