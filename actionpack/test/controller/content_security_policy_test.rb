require 'abstract_unit'


#case 1: Not setting CSP
class ApplicationController < ActionController::Base
end

class PostsController < ApplicationController

  def index
    render :text => "No Content Security Policy setting"
  end
end

class PostsControllerTest < ActionController::TestCase
  tests PostsController

  def setup
    Rails.application.routes.draw do
      get 'index' => 'posts#index'
    end
    @routes = Rails.application.routes
    PostsController.send(:include, @routes.url_helpers)
  end

  def test_no_csp_in_index
    get :index
    assert_response 200
    assert_not response.headers["Content-Security-Policy"]
    assert_not response.headers["Content-Security-Policy-Report-Only"]
  end
end


#case 2: Only setting monitor policy in ApplicationController Level
class ApplicationOneController < ActionController::Base
  content_security_policy.monitor do |csp|
    csp.default_src = :self
    csp.img_src = :self, 'data:'
    csp.font_src = :self, 'data:'
    csp.object_src = :none
    csp.script_src = :self, 'https:', :unsafe_inline
    csp.style_src = :self, 'https:', :unsafe_inline
  end
end

class PostsOneController < ApplicationOneController
  def index
    render :text => "Content Security Policy testing"
  end
end

class PostsOneControllerTest < ActionController::TestCase
  tests PostsOneController
  def setup
    Rails.application.routes.draw do
      get 'index' => 'posts_one#index'
    end
    @routes = Rails.application.routes
    PostsOneController.send(:include, @routes.url_helpers)
  end

  def test_no_enforce_policy_in_index
    get :index
    assert_not response.headers["Content-Security-Policy"]
  end

  def test_monitor_policy_in_index
    get :index
    assert_response 200
    assert_equal "default-src 'self'; img-src 'self' data:; font-src 'self' data:; object-src 'none'; script-src 'self' https: 'unsafe-inline'; style-src 'self' https: 'unsafe-inline'", response.headers["Content-Security-Policy-Report-Only"]
  end
end

#case 3: Only setting policy in Controller Level
# Test Objective: different controllers with different csp setting have different csp policy
class ApplicationTwoController < ActionController::Base
end

class PostsTwoController < ApplicationTwoController
  content_security_policy.monitor do |csp|
    csp.default_src = :self
  end

  def index
    render :text => "Content Security Policy testing"
  end
end

class PostsTwoControllerTest < ActionController::TestCase
  tests PostsTwoController
  def setup
    Rails.application.routes.draw do
      get 'index' => 'posts_two#index'
    end
    @routes = Rails.application.routes
    PostsTwoController.send(:include, @routes.url_helpers)
  end

  def test_no_enforce_policy_in_index
    get :index
    assert_not response.headers["Content-Security-Policy"]
  end

  def test_monitor_policy_in_index
    get :index
    assert_response 200
    assert_equal "default-src 'self'", response.headers["Content-Security-Policy-Report-Only"]
  end
end

class UsersTwoController < ApplicationTwoController
  def index
    render :text => "Content Security Policy testing"
  end
end

class UsersTwoControllerTest < ActionController::TestCase
  tests UsersTwoController
  def setup
    Rails.application.routes.draw do
      get 'index' => 'users_two#index'
    end
    @routes = Rails.application.routes
    UsersTwoController.send(:include, @routes.url_helpers)
  end

  def test_no_policy_in_index
    get :index
    assert_not response.headers["Content-Security-Policy"]
    assert_not response.headers["Content-Security-Policy-Report-Only"]
  end
end

class AvatarsController < ApplicationTwoController
  content_security_policy.enforce.default_src = :self
  content_security_policy.monitor.default_src = :self

  def index
    render :text => "Content Security Policy testing"
  end
end

class AvatarsControllerTest < ActionController::TestCase
  tests AvatarsController
  def setup
    Rails.application.routes.draw do
      get 'index' => 'avatars#index'
    end
    @routes = Rails.application.routes
    AvatarsController.send(:include, @routes.url_helpers)
  end

  def test_enforce_policy_in_index
    get :index
    assert_equal "default-src 'self'", response.headers["Content-Security-Policy"]
  end

  def test_monitor_policy_in_index
    get :index
    assert_equal "default-src 'self'", response.headers["Content-Security-Policy-Report-Only"]
  end
end

#case 4: Only setting policy in Action Level
# Test Objective: Two different actions in same controllers with different csp setting have different csp policy
class ApplicationThreeController < ActionController::Base
end

class PostsThreeController < ApplicationThreeController
  def index
    content_security_policy.enforce do |csp|
      csp.default_src = :self
      csp.script_src = "cdn.example.org"
    end
    content_security_policy.monitor do |csp|
      csp.default_src = :self, 'data:'
      csp.script_src = 'https:'
    end
    render :text => "Content Security Policy testing"
  end

  def new
    content_security_policy.enforce do |csp|
      csp.script_src = "js.example.org"
    end
    content_security_policy.monitor do |csp|
      csp.default_src = :self, 'data:'
      csp.script_src = 'https:',:unsafe_inline,:unsafe_eval
    end
    render :text => "Content Security Policy testing"
  end
end

class PostsThreeControllerTest < ActionController::TestCase
  tests PostsThreeController
  def setup
    Rails.application.routes.draw do
      get 'index' => 'posts_three#index'
      get 'new' => 'posts_three#new'
    end
    @routes = Rails.application.routes
    PostsThreeController.send(:include, @routes.url_helpers)
  end

  def test_enforce_policy_in_index
    get :index
    assert_response 200
    assert_equal "default-src 'self'; script-src cdn.example.org", response.headers["Content-Security-Policy"]
  end

  def test_monitor_policy_in_index
    get :index
    assert_response 200
    assert_equal "default-src 'self' data:; script-src https:", response.headers["Content-Security-Policy-Report-Only"]
  end

  def test_enforce_policy_in_new
    get :new
    assert_response 200
    assert_equal "script-src js.example.org", response.headers["Content-Security-Policy"]
  end

  def test_monitor_policy_in_new
    get :new
    assert_response 200
    assert_equal "default-src 'self' data:; script-src https: 'unsafe-inline' 'unsafe-eval'", response.headers["Content-Security-Policy-Report-Only"]
  end
end

#case 5: Setting policy in all three Level
# Test Objective: low level copy the policy from the top level and modify the policy through add_, remove_, set_, methods.
class ApplicationFourController < ActionController::Base
  content_security_policy.enforce do |csp|
    csp.default_src = :self
    csp.img_src = :self, 'data:'
    csp.font_src = :self, 'data:'
    csp.object_src = :none
    csp.script_src = :self, 'https:', :unsafe_inline
    csp.style_src = :self, 'https:', :unsafe_inline
  end

  content_security_policy.monitor do |csp|
    csp.default_src = :self
    csp.img_src = :self, 'data:'
    csp.font_src = :self, 'data:'
    csp.object_src = :none
    csp.script_src = :self, 'https:', :unsafe_inline
    csp.style_src = :self, 'https:', :unsafe_inline
  end
end

class PostsFourController < ApplicationFourController
  content_security_policy.enforce do |csp|
    csp.add_img_src 'imgs.example.org'
    csp.add_font_src 'fonts.example.org'
    csp.add_script_src :unsafe_eval
  end

  def index
    content_security_policy.enforce do |csp|
      csp.remove_script_src :unsafe_eval, :unsafe_inline
      csp.remove_style_src :unsafe_inline
    end
    content_security_policy.monitor do |csp|
      csp.default_src = :self, 'data:'
      csp.script_src = 'https:'
    end
    render :text => "Content Security Policy testing"
  end

  def new
    content_security_policy.enforce do |csp|
      csp.add_script_src "js.example.org"
    end
    render :text => "Content Security Policy testing"
  end
end

class PostsFourControllerTest < ActionController::TestCase
  tests PostsFourController
  def setup
    Rails.application.routes.draw do
      get 'index' => 'posts_four#index'
      get 'new' => 'posts_four#new'
    end
    @routes = Rails.application.routes
    PostsFourController.send(:include, @routes.url_helpers)
  end

  def test_enforce_policy_in_index
    get :index
    assert_response 200
    assert_equal "default-src 'self'; img-src 'self' data: imgs.example.org; font-src 'self' data: fonts.example.org; object-src 'none'; script-src 'self' https:; style-src 'self' https:", response.headers["Content-Security-Policy"]
  end

  def test_monitor_policy_in_index
    get :index
    assert_response 200
    assert_equal "default-src 'self' data:; img-src 'self' data:; font-src 'self' data:; object-src 'none'; script-src https:; style-src 'self' https: 'unsafe-inline'", response.headers["Content-Security-Policy-Report-Only"]
  end

  def test_enforce_policy_in_new
    get :new
    assert_response 200
    assert_equal "default-src 'self'; img-src 'self' data: imgs.example.org; font-src 'self' data: fonts.example.org; object-src 'none'; script-src 'self' https: 'unsafe-inline' 'unsafe-eval' js.example.org; style-src 'self' https: 'unsafe-inline'", response.headers["Content-Security-Policy"]
  end
end

#case 6: Test controller inherited from an existed controller
# Test Objective: The SubController will get all the policy inherited from the SuperController
class PostsFiveController < PostsFourController
  content_security_policy.enforce do |csp|
    csp.remove_img_src 'imgs.example.org'
    csp.remove_font_src 'fonts.example.org'
    csp.remove_script_src :unsafe_eval
  end

  def index
    render :text => "Content Security Policy testing"
  end
end

class PostsFiveControllerTest < ActionController::TestCase
  tests PostsFiveController
  def setup
    Rails.application.routes.draw do
      get 'index' => 'posts_five#index'
    end
    @routes = Rails.application.routes
    PostsFiveController.send(:include, @routes.url_helpers)
  end

  def test_enforce_policy_in_index
    get :index
    assert_response 200
    assert_equal "default-src 'self'; img-src 'self' data:; font-src 'self' data:; object-src 'none'; script-src 'self' https: 'unsafe-inline'; style-src 'self' https: 'unsafe-inline'",  response.headers["Content-Security-Policy"]
  end
end