# frozen_string_literal: true

require "abstract_unit"

ActionController::Base.helpers_path = File.expand_path("../fixtures/helpers", __dir__)

module Fun
  class GamesController < ActionController::Base
    def render_hello_world
      render inline: "hello: <%= stratego %>"
    end
  end

  class PdfController < ActionController::Base
    def test
      render inline: "test: <%= foobar %>"
    end
  end
end

class AllHelpersController < ActionController::Base
  helper :all
end

module ImpressiveLibrary
  extend ActiveSupport::Concern
  included do
    helper_method :useful_function
  end

  def useful_function() end
end

ActionController::Base.include(ImpressiveLibrary)

class JustMeController < ActionController::Base
  clear_helpers

  def flash
    render inline: "<h1><%= notice %></h1>"
  end

  def lib
    render inline: "<%= useful_function %>"
  end
end

class MeTooController < JustMeController
end

class HelpersPathsController < ActionController::Base
  paths = ["helpers2_pack", "helpers1_pack"].map do |path|
    File.join(File.expand_path("../fixtures", __dir__), path)
  end

  self.helpers_path = paths
  ActionPackTestSuiteUtils.require_helpers(helpers_path)

  helper :all

  def index
    render inline: "<%= conflicting_helper %>"
  end
end

class HelpersTypoController < ActionController::Base
  self.helpers_path = File.expand_path("../fixtures/helpers_typo", __dir__)
  ActionPackTestSuiteUtils.require_helpers(helpers_path)
end

module LocalAbcHelper
  def a() end
  def b() end
  def c() end
end

class HelperPathsTest < ActiveSupport::TestCase
  def test_helpers_paths_priority
    responses = HelpersPathsController.action(:index).call(ActionController::TestRequest::DEFAULT_ENV.dup)

    # helpers1_pack was given as a second path, so pack1_helper should be
    # included as the second one
    assert_equal "pack1", responses.last.body
  end
end

class HelpersTypoControllerTest < ActiveSupport::TestCase
  def test_helper_typo_error_message
    e = assert_raise(NameError) { HelpersTypoController.helper "admin/users" }
    assert_includes e.message, "uninitialized constant Admin::UsersHelper"
    assert_includes e.message, "Did you mean?  Admin::UsersHelpeR"
  end
end

class HelperTest < ActiveSupport::TestCase
  class TestController < ActionController::Base
    attr_accessor :delegate_attr
    def delegate_method() end
    def delegate_method_arg(arg); arg; end
    def delegate_method_kwarg(hi:); hi; end
    def method_that_raises
      raise "an error occurred"
    end
  end

  def setup
    # Increment symbol counter.
    @symbol = (@@counter ||= "A0").succ.dup

    # Generate new controller class.
    @controller_class = Class.new(TestController)

    # Set default test helper.
    self.test_helper = LocalAbcHelper
  end

  def test_helper
    assert_equal expected_helper_methods, missing_methods
    assert_nothing_raised { @controller_class.helper TestHelper }
    assert_equal [], missing_methods
  end

  def test_helper_method
    assert_nothing_raised { @controller_class.helper_method :delegate_method }
    assert_includes master_helper_methods, :delegate_method
  end

  def test_helper_method_arg
    assert_nothing_raised { @controller_class.helper_method :delegate_method_arg }
    assert_equal({ hi: :there }, @controller_class.new.helpers.delegate_method_arg({ hi: :there }))
  end

  def test_helper_method_arg_does_not_call_to_hash
    assert_nothing_raised { @controller_class.helper_method :delegate_method_arg }

    my_class = Class.new do
      def to_hash
        { hi: :there }
      end
    end.new

    assert_equal(my_class, @controller_class.new.helpers.delegate_method_arg(my_class))
  end

  def test_helper_method_kwarg
    assert_nothing_raised { @controller_class.helper_method :delegate_method_kwarg }

    assert_equal(:there, @controller_class.new.helpers.delegate_method_kwarg(hi: :there))
  end

  def test_helper_method_with_error_has_correct_backgrace
    @controller_class.helper_method :method_that_raises
    expected_backtrace_pattern = "#{__FILE__}:#{__LINE__ - 1}"

    error = assert_raises(RuntimeError) do
      @controller_class.new.helpers.method_that_raises
    end
    assert_not_nil error.backtrace.find { |line| line.include?(expected_backtrace_pattern) }
  end

  def test_helper_attr
    assert_nothing_raised { @controller_class.helper_attr :delegate_attr }
    assert_includes master_helper_methods, :delegate_attr
    assert_includes master_helper_methods, :delegate_attr=
  end

  def call_controller(klass, action)
    klass.action(action).call(ActionController::TestRequest::DEFAULT_ENV.dup)
  end

  def test_helper_for_nested_controller
    assert_equal "hello: Iz guuut!",
      call_controller(Fun::GamesController, "render_hello_world").last.body
  end

  def test_helper_for_acronym_controller
    assert_equal "test: baz", call_controller(Fun::PdfController, "test").last.body
  end

  def test_default_helpers_only
    assert_equal %w[JustMeHelper], JustMeController._helpers.ancestors.reject(&:anonymous?).map(&:to_s)
    assert_equal %w[MeTooController::HelperMethods MeTooHelper JustMeHelper], MeTooController._helpers.ancestors.reject(&:anonymous?).map(&:to_s)
  end

  def test_base_helper_methods_after_clear_helpers
    assert_nothing_raised do
      call_controller(JustMeController, "flash")
    end
  end

  def test_lib_helper_methods_after_clear_helpers
    assert_nothing_raised do
      call_controller(JustMeController, "lib")
    end
  end

  def test_all_helpers
    methods = AllHelpersController._helpers.instance_methods

    # abc_helper.rb
    assert_includes methods, :bare_a

    # fun/games_helper.rb
    assert_includes methods, :stratego

    # fun/pdf_helper.rb
    assert_includes methods, :foobar
  end

  def test_all_helpers_with_alternate_helper_dir
    @controller_class.helpers_path = File.expand_path("../fixtures/alternate_helpers", __dir__)
    ActionPackTestSuiteUtils.require_helpers(@controller_class.helpers_path)

    # Reload helpers
    @controller_class._helpers = Module.new
    @controller_class.helper :all

    # helpers/abc_helper.rb should not be included
    assert_not_includes master_helper_methods, :bare_a

    # alternate_helpers/foo_helper.rb
    assert_includes master_helper_methods, :baz
  end

  def test_helper_proxy
    methods = AllHelpersController.helpers.methods

    # Action View
    assert_includes methods, :pluralize

    # abc_helper.rb
    assert_includes methods, :bare_a

    # fun/games_helper.rb
    assert_includes methods, :stratego

    # fun/pdf_helper.rb
    assert_includes methods, :foobar
  end

  def test_helper_proxy_in_instance
    methods = AllHelpersController.new.helpers.methods

    # Action View
    assert_includes methods, :pluralize

    # abc_helper.rb
    assert_includes methods, :bare_a

    # fun/games_helper.rb
    assert_includes methods, :stratego

    # fun/pdf_helper.rb
    assert_includes methods, :foobar
  end

  def test_helper_proxy_config
    AllHelpersController.config.my_var = "smth"

    assert_equal "smth", AllHelpersController.helpers.config.my_var
  end

  private
    def expected_helper_methods
      TestHelper.instance_methods
    end

    def master_helper_methods
      @controller_class._helpers.instance_methods
    end

    def missing_methods
      expected_helper_methods - master_helper_methods
    end

    def test_helper=(helper_module)
      silence_warnings { self.class.const_set("TestHelper", helper_module) }
    end
end

class IsolatedHelpersTest < ActionController::TestCase
  class A < ActionController::Base
    def index
      render inline: "<%= shout %>"
    end
  end

  class B < A
    helper { def shout; "B" end }

    def index
      render inline: "<%= shout %>"
    end
  end

  class C < A
    helper { def shout; "C" end }

    def index
      render inline: "<%= shout %>"
    end
  end

  def call_controller(klass, action)
    klass.action(action).call(@request.env)
  end

  def setup
    super
    @request.action = "index"
  end

  def test_helper_in_a
    assert_raise(ActionView::Template::Error) { call_controller(A, "index") }
  end

  def test_helper_in_b
    assert_equal "B", call_controller(B, "index").last.body
  end

  def test_helper_in_c
    assert_equal "C", call_controller(C, "index").last.body
  end
end
