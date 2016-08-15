require "abstract_unit"

class ForceSSLController < ActionController::Base
  def banana
    render plain: "monkey"
  end

  def cheeseburger
    render plain: "sikachu"
  end
end

class ForceSSLControllerLevel < ForceSSLController
  force_ssl
end

class ForceSSLCustomOptions < ForceSSLController
  force_ssl host: "secure.example.com", only: :redirect_host
  force_ssl port: 8443, only: :redirect_port
  force_ssl subdomain: "secure", only: :redirect_subdomain
  force_ssl domain: "secure.com", only: :redirect_domain
  force_ssl path: "/foo", only: :redirect_path
  force_ssl status: :found, only: :redirect_status
  force_ssl flash: { message: "Foo, Bar!" }, only: :redirect_flash
  force_ssl alert: "Foo, Bar!", only: :redirect_alert
  force_ssl notice: "Foo, Bar!", only: :redirect_notice

  def force_ssl_action
    render plain: action_name
  end

  alias_method :redirect_host, :force_ssl_action
  alias_method :redirect_port, :force_ssl_action
  alias_method :redirect_subdomain, :force_ssl_action
  alias_method :redirect_domain, :force_ssl_action
  alias_method :redirect_path, :force_ssl_action
  alias_method :redirect_status, :force_ssl_action
  alias_method :redirect_flash, :force_ssl_action
  alias_method :redirect_alert, :force_ssl_action
  alias_method :redirect_notice, :force_ssl_action

  def use_flash
    render plain: flash[:message]
  end

  def use_alert
    render plain: flash[:alert]
  end

  def use_notice
    render plain: flash[:notice]
  end
end

class ForceSSLOnlyAction < ForceSSLController
  force_ssl only: :cheeseburger
end

class ForceSSLExceptAction < ForceSSLController
  force_ssl except: :banana
end

class ForceSSLIfCondition < ForceSSLController
  force_ssl if: :use_force_ssl?

  def use_force_ssl?
    action_name == "cheeseburger"
  end
end

class ForceSSLFlash < ForceSSLController
  force_ssl except: [:banana, :set_flash, :use_flash]

  def set_flash
    flash["that"] = "hello"
    redirect_to "/force_ssl_flash/cheeseburger"
  end

  def use_flash
    @flash_copy = {}.update flash
    @flashy = flash["that"]
    render inline: "hello"
  end
end

class RedirectToSSL < ForceSSLController
  def banana
    force_ssl_redirect || render(plain: "monkey")
  end
  def cheeseburger
    force_ssl_redirect("secure.cheeseburger.host") || render(plain: "ihaz")
  end
end

class ForceSSLControllerLevelTest < ActionController::TestCase
  def test_banana_redirects_to_https
    get :banana
    assert_response 301
    assert_equal "https://test.host/force_ssl_controller_level/banana", redirect_to_url
  end

  def test_banana_redirects_to_https_with_extra_params
    get :banana, params: { token: "secret" }
    assert_response 301
    assert_equal "https://test.host/force_ssl_controller_level/banana?token=secret", redirect_to_url
  end

  def test_cheeseburger_redirects_to_https
    get :cheeseburger
    assert_response 301
    assert_equal "https://test.host/force_ssl_controller_level/cheeseburger", redirect_to_url
  end
end

class ForceSSLCustomOptionsTest < ActionController::TestCase
  def setup
    @request.env["HTTP_HOST"] = "www.example.com:80"
  end

  def test_redirect_to_custom_host
    get :redirect_host
    assert_response 301
    assert_equal "https://secure.example.com/force_ssl_custom_options/redirect_host", redirect_to_url
  end

  def test_redirect_to_custom_port
    get :redirect_port
    assert_response 301
    assert_equal "https://www.example.com:8443/force_ssl_custom_options/redirect_port", redirect_to_url
  end

  def test_redirect_to_custom_subdomain
    get :redirect_subdomain
    assert_response 301
    assert_equal "https://secure.example.com/force_ssl_custom_options/redirect_subdomain", redirect_to_url
  end

  def test_redirect_to_custom_domain
    get :redirect_domain
    assert_response 301
    assert_equal "https://www.secure.com/force_ssl_custom_options/redirect_domain", redirect_to_url
  end

  def test_redirect_to_custom_path
    get :redirect_path
    assert_response 301
    assert_equal "https://www.example.com/foo", redirect_to_url
  end

  def test_redirect_to_custom_status
    get :redirect_status
    assert_response 302
    assert_equal "https://www.example.com/force_ssl_custom_options/redirect_status", redirect_to_url
  end

  def test_redirect_to_custom_flash
    get :redirect_flash
    assert_response 301
    assert_equal "https://www.example.com/force_ssl_custom_options/redirect_flash", redirect_to_url

    get :use_flash
    assert_response 200
    assert_equal "Foo, Bar!", @response.body
  end

  def test_redirect_to_custom_alert
    get :redirect_alert
    assert_response 301
    assert_equal "https://www.example.com/force_ssl_custom_options/redirect_alert", redirect_to_url

    get :use_alert
    assert_response 200
    assert_equal "Foo, Bar!", @response.body
  end

  def test_redirect_to_custom_notice
    get :redirect_notice
    assert_response 301
    assert_equal "https://www.example.com/force_ssl_custom_options/redirect_notice", redirect_to_url

    get :use_notice
    assert_response 200
    assert_equal "Foo, Bar!", @response.body
  end
end

class ForceSSLOnlyActionTest < ActionController::TestCase
  def test_banana_not_redirects_to_https
    get :banana
    assert_response 200
  end

  def test_cheeseburger_redirects_to_https
    get :cheeseburger
    assert_response 301
    assert_equal "https://test.host/force_ssl_only_action/cheeseburger", redirect_to_url
  end
end

class ForceSSLExceptActionTest < ActionController::TestCase
  def test_banana_not_redirects_to_https
    get :banana
    assert_response 200
  end

  def test_cheeseburger_redirects_to_https
    get :cheeseburger
    assert_response 301
    assert_equal "https://test.host/force_ssl_except_action/cheeseburger", redirect_to_url
  end
end

class ForceSSLIfConditionTest < ActionController::TestCase
  def test_banana_not_redirects_to_https
    get :banana
    assert_response 200
  end

  def test_cheeseburger_redirects_to_https
    get :cheeseburger
    assert_response 301
    assert_equal "https://test.host/force_ssl_if_condition/cheeseburger", redirect_to_url
  end
end

class ForceSSLFlashTest < ActionController::TestCase
  def test_cheeseburger_redirects_to_https
    get :set_flash
    assert_response 302
    assert_equal "http://test.host/force_ssl_flash/cheeseburger", redirect_to_url

    # FIXME: AC::TestCase#build_request_uri doesn't build a new uri if PATH_INFO exists
    @request.env.delete("PATH_INFO")

    get :cheeseburger
    assert_response 301
    assert_equal "https://test.host/force_ssl_flash/cheeseburger", redirect_to_url

    # FIXME: AC::TestCase#build_request_uri doesn't build a new uri if PATH_INFO exists
    @request.env.delete("PATH_INFO")

    get :use_flash
    assert_equal "hello", @controller.instance_variable_get("@flash_copy")["that"]
    assert_equal "hello", @controller.instance_variable_get("@flashy")
  end
end

class ForceSSLDuplicateRoutesTest < ActionController::TestCase
  tests ForceSSLControllerLevel

  def test_force_ssl_redirects_to_same_path
    with_routing do |set|
      set.draw do
        get "/foo", to: "force_ssl_controller_level#banana"
        get "/bar", to: "force_ssl_controller_level#banana"
      end

      @request.env["PATH_INFO"] = "/bar"

      get :banana
      assert_response 301
      assert_equal "https://test.host/bar", redirect_to_url
    end
  end
end

class ForceSSLFormatTest < ActionController::TestCase
  tests ForceSSLControllerLevel

  def test_force_ssl_redirects_to_same_format
    with_routing do |set|
      set.draw do
        get "/foo", to: "force_ssl_controller_level#banana"
      end

      get :banana, format: :json
      assert_response 301
      assert_equal "https://test.host/foo.json", redirect_to_url
    end
  end
end

class ForceSSLOptionalSegmentsTest < ActionController::TestCase
  tests ForceSSLControllerLevel

  def test_force_ssl_redirects_to_same_format
    with_routing do |set|
      set.draw do
        scope "(:locale)" do
          defaults locale: "en" do
            get "/foo", to: "force_ssl_controller_level#banana"
          end
        end
      end

      @request.env["PATH_INFO"] = "/en/foo"
      get :banana, params: { locale: "en" }
      assert_equal "en",  @controller.params[:locale]
      assert_response 301
      assert_equal "https://test.host/en/foo", redirect_to_url
    end
  end
end

class RedirectToSSLTest < ActionController::TestCase
  def test_banana_redirects_to_https_if_not_https
    get :banana
    assert_response 301
    assert_equal "https://test.host/redirect_to_ssl/banana", redirect_to_url
  end

  def test_cheeseburgers_redirects_to_https_with_new_host_if_not_https
    get :cheeseburger
    assert_response 301
    assert_equal "https://secure.cheeseburger.host/redirect_to_ssl/cheeseburger", redirect_to_url
  end

  def test_cheeseburgers_does_not_redirect_if_already_https
    request.env["HTTPS"] = "on"
    get :cheeseburger
    assert_response 200
    assert_equal "ihaz", response.body
  end
end

class ForceSSLControllerLevelTest < ActionController::TestCase
  def test_no_redirect_websocket_ssl_request
    request.env["rack.url_scheme"] = "wss"
    request.env["Upgrade"] = "websocket"
    get :cheeseburger
    assert_response 200
  end
end
