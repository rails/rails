require "abstract_unit"
require "active_support/key_generator"

class FlashTest < ActionController::TestCase
  class TestController < ActionController::Base
    def set_flash
      flash["that"] = "hello"
      render inline: "hello"
    end

    def set_flash_now
      flash.now["that"] = "hello"
      flash.now["foo"] ||= "bar"
      flash.now["foo"] ||= "err"
      @flashy = flash.now["that"]
      @flash_copy = {}.update flash
      render inline: "hello"
    end

    def attempt_to_use_flash_now
      @flash_copy = {}.update flash
      @flashy = flash["that"]
      render inline: "hello"
    end

    def use_flash
      @flash_copy = {}.update flash
      @flashy = flash["that"]
      render inline: "hello"
    end

    def use_flash_and_keep_it
      @flash_copy = {}.update flash
      @flashy = flash["that"]
      flash.keep
      render inline: "hello"
    end

    def use_flash_and_update_it
      flash.update("this" => "hello again")
      @flash_copy = {}.update flash
      render inline: "hello"
    end

    def use_flash_after_reset_session
      flash["that"] = "hello"
      @flashy_that = flash["that"]
      reset_session
      @flashy_that_reset = flash["that"]
      flash["this"] = "good-bye"
      @flashy_this = flash["this"]
      render inline: "hello"
    end

    # methods for test_sweep_after_halted_action_chain
    before_action :halt_and_redir, only: "filter_halting_action"

    def std_action
      @flash_copy = {}.update(flash)
      head :ok
    end

    def filter_halting_action
      @flash_copy = {}.update(flash)
    end

    def halt_and_redir
      flash["foo"] = "bar"
      redirect_to action: "std_action"
      @flash_copy = {}.update(flash)
    end

    def redirect_with_alert
      redirect_to "/nowhere", alert: "Beware the nowheres!"
    end

    def redirect_with_notice
      redirect_to "/somewhere", notice: "Good luck in the somewheres!"
    end

    def render_with_flash_now_alert
      flash.now.alert = "Beware the nowheres now!"
      render inline: "hello"
    end

    def render_with_flash_now_notice
      flash.now.notice = "Good luck in the somewheres now!"
      render inline: "hello"
    end

    def redirect_with_other_flashes
      redirect_to "/wonderland", flash: { joyride: "Horses!" }
    end

    def redirect_with_foo_flash
      redirect_to "/wonderland", foo: "for great justice"
    end
  end

  tests TestController

  def test_flash
    get :set_flash

    get :use_flash
    assert_equal "hello", @controller.instance_variable_get(:@flash_copy)["that"]
    assert_equal "hello", @controller.instance_variable_get(:@flashy)

    get :use_flash
    assert_nil @controller.instance_variable_get(:@flash_copy)["that"], "On second flash"
  end

  def test_keep_flash
    get :set_flash

    get :use_flash_and_keep_it
    assert_equal "hello", @controller.instance_variable_get(:@flash_copy)["that"]
    assert_equal "hello", @controller.instance_variable_get(:@flashy)

    get :use_flash
    assert_equal "hello", @controller.instance_variable_get(:@flash_copy)["that"], "On second flash"

    get :use_flash
    assert_nil @controller.instance_variable_get(:@flash_copy)["that"], "On third flash"
  end

  def test_flash_now
    get :set_flash_now
    assert_equal "hello", @controller.instance_variable_get(:@flash_copy)["that"]
    assert_equal "bar", @controller.instance_variable_get(:@flash_copy)["foo"]
    assert_equal "hello", @controller.instance_variable_get(:@flashy)

    get :attempt_to_use_flash_now
    assert_nil @controller.instance_variable_get(:@flash_copy)["that"]
    assert_nil @controller.instance_variable_get(:@flash_copy)["foo"]
    assert_nil @controller.instance_variable_get(:@flashy)
  end

  def test_update_flash
    get :set_flash
    get :use_flash_and_update_it
    assert_equal "hello", @controller.instance_variable_get(:@flash_copy)["that"]
    assert_equal "hello again", @controller.instance_variable_get(:@flash_copy)["this"]
    get :use_flash
    assert_nil @controller.instance_variable_get(:@flash_copy)["that"], "On second flash"
    assert_equal "hello again",
      @controller.instance_variable_get(:@flash_copy)["this"], "On second flash"
  end

  def test_flash_after_reset_session
    get :use_flash_after_reset_session
    assert_equal "hello", @controller.instance_variable_get(:@flashy_that)
    assert_equal "good-bye", @controller.instance_variable_get(:@flashy_this)
    assert_nil @controller.instance_variable_get(:@flashy_that_reset)
  end

  def test_does_not_set_the_session_if_the_flash_is_empty
    get :std_action
    assert_nil session["flash"]
  end

  def test_sweep_after_halted_action_chain
    get :std_action
    assert_nil @controller.instance_variable_get(:@flash_copy)["foo"]
    get :filter_halting_action
    assert_equal "bar", @controller.instance_variable_get(:@flash_copy)["foo"]
    get :std_action # follow redirection
    assert_equal "bar", @controller.instance_variable_get(:@flash_copy)["foo"]
    get :std_action
    assert_nil @controller.instance_variable_get(:@flash_copy)["foo"]
  end

  def test_keep_and_discard_return_values
    flash = ActionDispatch::Flash::FlashHash.new
    flash.update(foo: :foo_indeed, bar: :bar_indeed)

    assert_equal(:foo_indeed, flash.discard(:foo)) # valid key passed
    assert_nil flash.discard(:unknown) # non existent key passed
    assert_equal({"foo" => :foo_indeed, "bar" => :bar_indeed}, flash.discard().to_hash) # nothing passed
    assert_equal({"foo" => :foo_indeed, "bar" => :bar_indeed}, flash.discard(nil).to_hash) # nothing passed

    assert_equal(:foo_indeed, flash.keep(:foo)) # valid key passed
    assert_nil flash.keep(:unknown) # non existent key passed
    assert_equal({"foo" => :foo_indeed, "bar" => :bar_indeed}, flash.keep().to_hash) # nothing passed
    assert_equal({"foo" => :foo_indeed, "bar" => :bar_indeed}, flash.keep(nil).to_hash) # nothing passed
  end

  def test_redirect_to_with_alert
    get :redirect_with_alert
    assert_equal "Beware the nowheres!", @controller.send(:flash)[:alert]
  end

  def test_redirect_to_with_notice
    get :redirect_with_notice
    assert_equal "Good luck in the somewheres!", @controller.send(:flash)[:notice]
  end

  def test_render_with_flash_now_alert
    get :render_with_flash_now_alert
    assert_equal "Beware the nowheres now!", @controller.send(:flash)[:alert]
  end

  def test_render_with_flash_now_notice
    get :render_with_flash_now_notice
    assert_equal "Good luck in the somewheres now!", @controller.send(:flash)[:notice]
  end

  def test_redirect_to_with_other_flashes
    get :redirect_with_other_flashes
    assert_equal "Horses!", @controller.send(:flash)[:joyride]
  end

  def test_redirect_to_with_adding_flash_types
    original_controller = @controller
    test_controller_with_flash_type_foo = Class.new(TestController) do
      add_flash_types :foo
    end
    @controller = test_controller_with_flash_type_foo.new
    get :redirect_with_foo_flash
    assert_equal "for great justice", @controller.send(:flash)[:foo]
  ensure
    @controller = original_controller
  end

  def test_add_flash_type_to_subclasses
    test_controller_with_flash_type_foo = Class.new(TestController) do
      add_flash_types :foo
    end
    subclass_controller_with_no_flash_type = Class.new(test_controller_with_flash_type_foo)
    assert subclass_controller_with_no_flash_type._flash_types.include?(:foo)
  end

  def test_does_not_add_flash_type_to_parent_class
    Class.new(TestController) do
      add_flash_types :bar
    end
    assert_not TestController._flash_types.include?(:bar)
  end
end

class FlashIntegrationTest < ActionDispatch::IntegrationTest
  SessionKey = "_myapp_session"
  Generator  = ActiveSupport::LegacyKeyGenerator.new("b3c631c314c0bbca50c1b2843150fe33")

  class TestController < ActionController::Base
    add_flash_types :bar

    def set_flash
      flash["that"] = "hello"
      head :ok
    end

    def set_flash_now
      flash.now["that"] = "hello"
      head :ok
    end

    def use_flash
      render inline: "flash: #{flash["that"]}"
    end

    def set_bar
      flash[:bar] = "for great justice"
      head :ok
    end
  end

  def test_flash
    with_test_route_set do
      get "/set_flash"
      assert_response :success
      assert_equal "hello", @request.flash["that"]

      get "/use_flash"
      assert_response :success
      assert_equal "flash: hello", @response.body
    end
  end

  def test_just_using_flash_does_not_stream_a_cookie_back
    with_test_route_set do
      get "/use_flash"
      assert_response :success
      assert_nil @response.headers["Set-Cookie"]
      assert_equal "flash: ", @response.body
    end
  end

  def test_setting_flash_does_not_raise_in_following_requests
    with_test_route_set do
      env = { "action_dispatch.request.flash_hash" => ActionDispatch::Flash::FlashHash.new }
      get "/set_flash", env: env
      get "/set_flash", env: env
    end
  end

  def test_setting_flash_now_does_not_raise_in_following_requests
    with_test_route_set do
      env = { "action_dispatch.request.flash_hash" => ActionDispatch::Flash::FlashHash.new }
      get "/set_flash_now", env: env
      get "/set_flash_now", env: env
    end
  end

  def test_added_flash_types_method
    with_test_route_set do
      get "/set_bar"
      assert_response :success
      assert_equal "for great justice", @controller.bar
    end
  end

  private

    # Overwrite get to send SessionSecret in env hash
    def get(path, *args)
      args[0] ||= {}
      args[0][:env] ||= {}
      args[0][:env]["action_dispatch.key_generator"] ||= Generator
      super(path, *args)
    end

    def with_test_route_set
      with_routing do |set|
        set.draw do
          ActiveSupport::Deprecation.silence do
            get ":action", to: FlashIntegrationTest::TestController
          end
        end

        @app = self.class.build_app(set) do |middleware|
          middleware.use ActionDispatch::Session::CookieStore, key: SessionKey
          middleware.use ActionDispatch::Flash
          middleware.delete ActionDispatch::ShowExceptions
        end

        yield
      end
    end
end
