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


class ForceSSLControllerLevelTest < ActionController::TestCase
  tests ForceSSLControllerLevel

  def test_banana_redirects_to_https
    get :banana
    assert_response 301
    assert_equal "https://test.host/force_ssl_controller_level/banana", redirect_to_url
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

class ForceSSLExcludeDevelopmentTest < ActionController::TestCase
  tests ForceSSLControllerLevel

  def setup
    Rails.env.stubs(:development?).returns(false)
  end

  def test_development_environment_not_redirects_to_https
    Rails.env.stubs(:development?).returns(true)
    get :banana
    assert_response 200
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
