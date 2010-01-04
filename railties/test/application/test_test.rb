require 'isolation/abstract_unit'

module ApplicationTests
  class TestTest < Test::Unit::TestCase
    include ActiveSupport::Testing::Isolation

    def setup
      build_app
      boot_rails
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

      run_test 'unit/foo_test.rb'
    end

    private
      def run_test(name)
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
