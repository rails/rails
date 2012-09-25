require 'isolation/abstract_unit'

module ApplicationTests
  class TestTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation

    def setup
      build_app
      boot_rails
    end

    def teardown
      teardown_app
    end

    test "truth" do
      app_file 'test/unit/foo_test.rb', <<-RUBY
        require 'test_helper'

        describe "Foo" do
          it "tests truth" do
            true.must_equal true
          end
        end
      RUBY

      run_test_file 'unit/foo_test.rb'
    end

    test "integration test" do
      controller 'posts', <<-RUBY
        class PostsController < ActionController::Base
        end
      RUBY

      app_file 'app/views/posts/index.html.erb', <<-HTML
        Posts#index
      HTML

      app_file 'test/integration/posts_test.rb', <<-RUBY
        require 'test_helper'
        # MiniTest::Spec.register_spec_type(/Controller$/, ActionController::TestCase)

        describe PostsController do
          it "tests the index" do
            get :index
            response.must_be :success?
          end
        end
      RUBY

      run_test_file 'integration/posts_test.rb'
    end

    test "integration test with nested describe blocks" do
      controller 'posts', <<-RUBY
        class PostsController < ActionController::Base
        end
      RUBY

      app_file 'app/views/posts/index.html.erb', <<-HTML
        Posts#index
      HTML

      app_file 'test/integration/posts_test_with_describes.rb', <<-RUBY
        require 'test_helper'
        # MiniTest::Spec.register_spec_type(/Controller$/, ActionController::TestCase)

        describe PostsController do
          describe "index" do
            it "responds successfully" do
              get :index
              response.must_be :success?
            end
          end
        end
      RUBY

      run_test_file 'integration/posts_test_with_describes.rb'
    end

    private
      def run_test_file(name)
        result = ruby '-Itest', "#{app_path}/test/#{name}"
        assert_equal 0, $?.to_i, result
      end

      def ruby(*args)
        Dir.chdir(app_path) do
          `RUBYLIB='#{$:.join(':')}' #{Gem.ruby} #{args.join(' ')}`
        end
      end
  end
end
