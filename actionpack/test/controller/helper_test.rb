require 'abstract_unit'

ActionController::Base.helpers_dir = File.dirname(__FILE__) + '/../fixtures/helpers'

class TestController < ActionController::Base
  attr_accessor :delegate_attr
  def delegate_method() end
  def rescue_action(e) raise end
end

module Fun
  class GamesController < ActionController::Base
    def render_hello_world
      render :inline => "hello: <%= stratego %>"
    end

    def rescue_action(e) raise end
  end

  class PdfController < ActionController::Base
    def test
      render :inline => "test: <%= foobar %>"
    end

    def rescue_action(e) raise end
  end
end

class ApplicationController < ActionController::Base
  helper :all
end

module LocalAbcHelper
  def a() end
  def b() end
  def c() end
end

class HelperTest < Test::Unit::TestCase
  def setup
    # Increment symbol counter.
    @symbol = (@@counter ||= 'A0').succ!.dup

    # Generate new controller class.
    controller_class_name = "Helper#{@symbol}Controller"
    eval("class #{controller_class_name} < TestController; end")
    @controller_class = self.class.const_get(controller_class_name)

    # Set default test helper.
    self.test_helper = LocalAbcHelper
  end
  
  def test_deprecated_helper
    assert_equal expected_helper_methods, missing_methods
    assert_nothing_raised { @controller_class.helper TestHelper }
    assert_equal [], missing_methods
  end

  def test_declare_helper
    require 'abc_helper'
    self.test_helper = AbcHelper
    assert_equal expected_helper_methods, missing_methods
    assert_nothing_raised { @controller_class.helper :abc }
    assert_equal [], missing_methods
  end

  def test_declare_missing_helper
    assert_equal expected_helper_methods, missing_methods
    assert_raise(MissingSourceFile) { @controller_class.helper :missing }
  end

  def test_declare_missing_file_from_helper
    require 'broken_helper'
  rescue LoadError => e
    assert_nil(/\bbroken_helper\b/.match(e.to_s)[1])
  end

  def test_helper_block
    assert_nothing_raised {
      @controller_class.helper { def block_helper_method; end }
    }
    assert master_helper_methods.include?('block_helper_method')
  end

  def test_helper_block_include
    assert_equal expected_helper_methods, missing_methods
    assert_nothing_raised {
      @controller_class.helper { include HelperTest::TestHelper }
    }
    assert [], missing_methods
  end

  def test_helper_method
    assert_nothing_raised { @controller_class.helper_method :delegate_method }
    assert master_helper_methods.include?('delegate_method')
  end

  def test_helper_attr
    assert_nothing_raised { @controller_class.helper_attr :delegate_attr }
    assert master_helper_methods.include?('delegate_attr')
    assert master_helper_methods.include?('delegate_attr=')
  end

  def test_helper_for_nested_controller
    request  = ActionController::TestRequest.new
    response = ActionController::TestResponse.new
    request.action = 'render_hello_world'

    assert_equal 'hello: Iz guuut!', Fun::GamesController.process(request, response).body
  end

  def test_helper_for_acronym_controller
    request  = ActionController::TestRequest.new
    response = ActionController::TestResponse.new
    request.action = 'test'

    assert_equal 'test: baz', Fun::PdfController.process(request, response).body
  end

  def test_all_helpers
    methods = ApplicationController.master_helper_module.instance_methods.map(&:to_s)

    # abc_helper.rb
    assert methods.include?('bare_a')

    # fun/games_helper.rb
    assert methods.include?('stratego')

    # fun/pdf_helper.rb
    assert methods.include?('foobar')
  end

  def test_all_helpers_with_alternate_helper_dir
    @controller_class.helpers_dir = File.dirname(__FILE__) + '/../fixtures/alternate_helpers'

    # Reload helpers
    @controller_class.master_helper_module = Module.new
    @controller_class.helper :all

    # helpers/abc_helper.rb should not be included
    assert !master_helper_methods.include?('bare_a')

    # alternate_helpers/foo_helper.rb
    assert master_helper_methods.include?('baz')
  end

  def test_helper_proxy
    methods = ApplicationController.helpers.methods.map(&:to_s)

    # ActionView
    assert methods.include?('pluralize')

    # abc_helper.rb
    assert methods.include?('bare_a')

    # fun/games_helper.rb
    assert methods.include?('stratego')

    # fun/pdf_helper.rb
    assert methods.include?('foobar')
  end

  private
    def expected_helper_methods
      TestHelper.instance_methods.map(&:to_s)
    end

    def master_helper_methods
      @controller_class.master_helper_module.instance_methods.map(&:to_s)
    end

    def missing_methods
      expected_helper_methods - master_helper_methods
    end

    def test_helper=(helper_module)
      silence_warnings { self.class.const_set('TestHelper', helper_module) }
    end
end


class IsolatedHelpersTest < Test::Unit::TestCase
  class A < ActionController::Base
    def index
      render :inline => '<%= shout %>'
    end

    def rescue_action(e) raise end
  end

  class B < A
    helper { def shout; 'B' end }

    def index
      render :inline => '<%= shout %>'
    end
  end

  class C < A
    helper { def shout; 'C' end }

    def index
      render :inline => '<%= shout %>'
    end
  end

  def setup
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    @request.action = 'index'
  end

  def test_helper_in_a
    assert_raise(NameError) { A.process(@request, @response) }
  end

  def test_helper_in_b
    assert_equal 'B', B.process(@request, @response).body
  end

  def test_helper_in_c
    assert_equal 'C', C.process(@request, @response).body
  end
end
