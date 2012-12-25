require 'abstract_unit'

class ForceSSLController < ActionController::Base
  def banana
    render :text => "monkey"
  end

  def cheeseburger
    render :text => "sikachu"
  end
end

class ForceSSLControllerLevel < ForceSSLController
  force_ssl
end

class ForceSSLCustomDomain < ForceSSLController
  force_ssl :host => "secure.test.host"
end

class ForceSSLOnlyAction < ForceSSLController
  force_ssl :only => :cheeseburger
end

class ForceSSLExceptAction < ForceSSLController
  force_ssl :except => :banana
end

class ForceSSLIfCondition < ForceSSLController
  force_ssl :if => :use_force_ssl?

  def use_force_ssl?
    action_name == 'cheeseburger'
  end
end

class ForceSSLFlash < ForceSSLController
  force_ssl :except => [:banana, :set_flash, :use_flash]

  def set_flash
    flash["that"] = "hello"
    redirect_to '/force_ssl_flash/cheeseburger'
  end

  def use_flash
    @flash_copy = {}.update flash
    @flashy = flash["that"]
    render :inline => "hello"
  end
end

class RedirectToSSL < ForceSSLController
  def banana
    force_ssl_redirect || render(:text => 'monkey')
  end
  def cheeseburger
    force_ssl_redirect('secure.cheeseburger.host') || render(:text => 'ihaz')
  end
end

class ForceSSLControllerLevelTest < ActionController::TestCase
  tests ForceSSLControllerLevel

  def test_banana_redirects_to_https
    get :banana
    assert_response 301
    assert_equal "https://test.host/force_ssl_controller_level/banana", redirect_to_url
  end

  def test_banana_redirects_to_https_with_extra_params
    get :banana, :token => "secret"
    assert_response 301
    assert_equal "https://test.host/force_ssl_controller_level/banana?token=secret", redirect_to_url
  end

  def test_cheeseburger_redirects_to_https
    get :cheeseburger
    assert_response 301
    assert_equal "https://test.host/force_ssl_controller_level/cheeseburger", redirect_to_url
  end
end

class ForceSSLCustomDomainTest < ActionController::TestCase
  tests ForceSSLCustomDomain

  def test_banana_redirects_to_https_with_custom_host
    get :banana
    assert_response 301
    assert_equal "https://secure.test.host/force_ssl_custom_domain/banana", redirect_to_url
  end

  def test_cheeseburger_redirects_to_https_with_custom_host
    get :cheeseburger
    assert_response 301
    assert_equal "https://secure.test.host/force_ssl_custom_domain/cheeseburger", redirect_to_url
  end
end

class ForceSSLOnlyActionTest < ActionController::TestCase
  tests ForceSSLOnlyAction

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
  tests ForceSSLExceptAction

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
  tests ForceSSLIfCondition

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
  tests ForceSSLFlash

  def test_cheeseburger_redirects_to_https
    get :set_flash
    assert_response 302
    assert_equal "http://test.host/force_ssl_flash/cheeseburger", redirect_to_url

    get :cheeseburger
    assert_response 301
    assert_equal "https://test.host/force_ssl_flash/cheeseburger", redirect_to_url

    get :use_flash
    assert_equal "hello", assigns["flash_copy"]["that"]
    assert_equal "hello", assigns["flashy"]
  end
end

class RedirectToSSLTest < ActionController::TestCase
  tests RedirectToSSL
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

  def test_banana_does_not_redirect_if_already_https
    request.env['HTTPS'] = 'on'
    get :cheeseburger
    assert_response 200
    assert_equal 'ihaz', response.body
  end
end