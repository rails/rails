require 'abstract_unit'

module ActionView
  class TestCase
    module ATestHelper
    end

    module AnotherTestHelper
      def from_another_helper
        'Howdy!'
      end
    end

    module ASharedTestHelper
      def from_shared_helper
        'Holla!'
      end
    end
    helper ASharedTestHelper

    module SharedTests
      def self.included(test_case)
        test_case.class_eval do
          test "helpers defined on ActionView::TestCase are available" do
            assert test_case.ancestors.include?(ASharedTestHelper)
            assert_equal 'Holla!', from_shared_helper
          end
        end
      end
    end

    class GeneralViewTest < ActionView::TestCase
      include SharedTests
      test_case = self

      test "works without testing a helper module" do
        assert_equal 'Eloy', render('developers/developer', :developer => stub(:name => 'Eloy'))
      end

      test "can render a layout with block" do
        assert_equal "Before (ChrisCruft)\n!\nAfter",
                      render(:layout => "test/layout_for_partial", :locals => {:name => "ChrisCruft"}) {"!"}
      end

      helper AnotherTestHelper
      test "additional helper classes can be specified as in a controller" do
        assert test_case.ancestors.include?(AnotherTestHelper)
        assert_equal 'Howdy!', from_another_helper
      end
    end

    class ClassMethodsTest < ActionView::TestCase
      include SharedTests
      test_case = self

      tests ATestHelper
      test "tests the specified helper module" do
        assert_equal ATestHelper, test_case.helper_class
        assert test_case.ancestors.include?(ATestHelper)
      end

      helper AnotherTestHelper
      test "additional helper classes can be specified as in a controller" do
        assert test_case.ancestors.include?(AnotherTestHelper)
        assert_equal 'Howdy!', from_another_helper

        test_case.helper_class.module_eval do
          def render_from_helper
            from_another_helper
          end
        end
        assert_equal 'Howdy!', render(:partial => 'test/from_helper')
      end
    end

    class ATestHelperTest < ActionView::TestCase
      include SharedTests
      test_case = self

      test "inflects the name of the helper module to test from the test case class" do
        assert_equal ATestHelper, test_case.helper_class
        assert test_case.ancestors.include?(ATestHelper)
      end

      test "a configured test controller is available" do
        assert_kind_of ActionController::Base, controller
        assert_equal '', controller.controller_path
      end

      test "helper class that is being tested is always included in view instance" do
        self.class.helper_class.module_eval do
          def render_from_helper
            render :partial => 'customer', :collection => @customers
          end
        end

        TestController.stubs(:controller_path).returns('test')

        @customers = [stub(:name => 'Eloy'), stub(:name => 'Manfred')]
        assert_match /Hello: EloyHello: Manfred/, render(:partial => 'test/from_helper')
      end

      test "no additional helpers should shared across test cases" do
        assert !test_case.ancestors.include?(AnotherTestHelper)
        assert_raise(NoMethodError) { send :from_another_helper }
      end

      test "is able to use routes" do
        controller.request.assign_parameters('foo', 'index')
        assert_equal '/foo', url_for
        assert_equal '/bar', url_for(:controller => 'bar')
      end

      test "is able to use named routes" do
        with_routing do |set|
          set.draw { |map| map.resources :contents }
          assert_equal 'http://test.host/contents/new', new_content_url
          assert_equal 'http://test.host/contents/1',   content_url(:id => 1)
        end
      end

      test "named routes can be used from helper included in view" do
        with_routing do |set|
          set.draw { |map| map.resources :contents }
          master_helper_module.module_eval do
            def render_from_helper
              new_content_url
            end
          end

          assert_equal 'http://test.host/contents/new', render(:partial => 'test/from_helper')
        end
      end

      test "is able to render partials with local variables" do
        assert_equal 'Eloy', render('developers/developer', :developer => stub(:name => 'Eloy'))
        assert_equal 'Eloy', render(:partial => 'developers/developer',
                                    :locals => { :developer => stub(:name => 'Eloy') })
      end

      test "is able to render partials from templates and also use instance variables" do
        TestController.stubs(:controller_path).returns('test')

        @customers = [stub(:name => 'Eloy'), stub(:name => 'Manfred')]
        assert_match /Hello: EloyHello: Manfred/, render(:file => 'test/list')
      end

      test "is able to make methods available to the view" do
        master_helper_module.module_eval do
          def render_from_helper; from_test_case end
        end
        assert_equal 'Word!', render(:partial => 'test/from_helper')
      end

      def from_test_case; 'Word!'; end
      helper_method :from_test_case
    end

    class AssertionsTest < ActionView::TestCase
      def render_from_helper
        form_tag('/foo') do
          concat render(:text => '<ul><li>foo</li></ul>')
        end
      end
      helper_method :render_from_helper

      test "uses the output_buffer for assert_select" do
        render(:partial => 'test/from_helper')

        assert_select 'form' do
          assert_select 'li', :text => 'foo'
        end
      end
    end
  end
end