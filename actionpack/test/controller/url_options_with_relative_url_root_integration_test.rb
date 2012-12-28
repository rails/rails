require 'abstract_unit'

# Test classes copied and modified from actionpack/test/controller/integration_test.rb::UrlOptionsIntegrationTest
class UrlOptionsWithRelativeUrlRootIntegrationTest < ActionDispatch::IntegrationTest
  class FooController < ActionController::Base
    def index
      render :text => "foo#index"
    end

    def show
      render :text => "foo#show"
    end

    def edit
      render :text => "foo#show"
    end
  end

  class BarController < ActionController::Base
    def default_url_options
      { :host => "relbar.com" }
    end

    def index
      render :text => "foo#index"
    end
  end

  def self.routes
    @routes ||= ActionDispatch::Routing::RouteSet.new
  end

  def self.config
    @config = ActiveSupport::InheritableOptions.new(ActionController::Base.config).tap do |config|
      config.relative_url_root = '/context'
      config
    end
  end

  def self.call(env)
    routes.call(env)
  end

  def app
    self.class
  end

  routes.draw do
    default_url_options :host => "relfoo.com"

    scope :module => "url_options_with_relative_url_root_integration_test" do
      get "/foo" => "foo#index", :as => :rel_foos
      get "/foo/:id" => "foo#show", :as => :rel_foo
      get "/foo/:id/edit" => "foo#edit", :as => :rel_edit_foo
      get "/bar" => "bar#index", :as => :rel_bars
    end
  end

  test "session uses default url options from routes with relative url root" do
    assert_equal "http://relfoo.com/context/foo", rel_foos_url
  end

  test "current host overrides default url options from routes with relative url root" do
    get "/foo"
    assert_response :success
    assert_equal "http://www.example.com/context/foo", rel_foos_url
  end

  test "controller can override default url options from request with relative url root" do
    get "/bar"
    assert_response :success
    assert_equal "http://relbar.com/context/foo", rel_foos_url
  end

  test "test can override default url options with relative url root" do
    # Setting default_url_options here bleeds over into other tests,
    # so resetting to the original here.
    orig_default_host = default_url_options[:host]
    default_url_options[:host] = "relfoobar.com"
    assert_equal "http://relfoobar.com/context/foo", rel_foos_url

    get "/bar"
    assert_response :success
    assert_equal "http://relfoobar.com/context/foo", rel_foos_url
    orig_default_host.nil? ? default_url_options.delete(:host) : default_url_options[:host] = orig_default_host
  end

  test "current request path parameters are recalled" do
    get "/foo/1"
    assert_response :success
    assert_equal "/context/foo/1/edit", url_for(:action => 'edit', :only_path => true)
  end
end