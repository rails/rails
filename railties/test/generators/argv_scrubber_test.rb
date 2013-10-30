require 'active_support/test_case'
require 'active_support/testing/autorun'
require 'rails/generators/rails/app/app_generator'

module Rails
  module Generators
    class ARGVScrubberTest < ActiveSupport::TestCase
      def test_version
        ['-v', '--version'].each do |str|
          scrubber = ARGVScrubber.new [str]
          output    = nil
          exit_code = nil
          scrubber.extend(Module.new {
            define_method(:puts) { |str| output = str }
            define_method(:exit) { |code| exit_code = code }
          })
          scrubber.prepare
          assert_equal "Rails #{Rails::VERSION::STRING}", output
          assert_equal 0, exit_code
        end
      end

      def test_prepare_returns_args
        scrubber = ARGVScrubber.new ['hi mom']
        args = scrubber.prepare
        assert_equal '--help', args.first
      end

      def test_no_mutations
        scrubber = ARGVScrubber.new ['hi mom'].freeze
        args = scrubber.prepare
        assert_equal '--help', args.first
      end
    end
  end
end
