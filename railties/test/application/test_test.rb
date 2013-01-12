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

        class FooTest < ActiveSupport::TestCase
          def test_truth
            assert true
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

        class PostsTest < ActionDispatch::IntegrationTest
          def test_index
            get '/posts'
            assert_response :success
            assert_template "index"
          end
        end
      RUBY

      run_test_file 'integration/posts_test.rb'
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
