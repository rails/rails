require 'abstract_unit'

module ActiveSupport
  module Testing
    class PerformanceTest < ActiveSupport::TestCase
      begin
        require 'active_support/testing/performance'
        HAVE_RUBYPROF = true
      rescue LoadError
        HAVE_RUBYPROF = false
      end

      def setup
        skip "no rubyprof" unless HAVE_RUBYPROF
      end

      def test_amount_format
        amount_metric = ActiveSupport::Testing::Performance::Metrics[:amount].new
        assert_equal "0", amount_metric.format(0)
        assert_equal "1", amount_metric.format(1.23)
        assert_equal "40,000,000", amount_metric.format(40000000)
      end

      def test_time_format
        time_metric = ActiveSupport::Testing::Performance::Metrics[:time].new
        assert_equal "0 ms", time_metric.format(0)
        assert_equal "40 ms", time_metric.format(0.04)
        assert_equal "41 ms", time_metric.format(0.0415)
        assert_equal "1.23 sec", time_metric.format(1.23)
        assert_equal "40000.00 sec", time_metric.format(40000)
        assert_equal "-5000 ms", time_metric.format(-5)
      end

      def test_space_format
        space_metric = ActiveSupport::Testing::Performance::Metrics[:digital_information_unit].new
        assert_equal "0 Bytes", space_metric.format(0)
        assert_equal "0 Bytes", space_metric.format(0.4)
        assert_equal "1 Byte", space_metric.format(1.23)
        assert_equal "123 Bytes", space_metric.format(123)
        assert_equal "123 Bytes", space_metric.format(123.45)
        assert_equal "12 KB", space_metric.format(12345)
        assert_equal "1.2 MB", space_metric.format(1234567)
        assert_equal "9.3 GB", space_metric.format(10**10)
        assert_equal "91 TB", space_metric.format(10**14)
        assert_equal "910000 TB", space_metric.format(10**18)
      end

      def test_environment_format_without_rails
        metric = ActiveSupport::Testing::Performance::Metrics[:time].new
        benchmarker = ActiveSupport::Testing::Performance::Benchmarker.new(self, metric)
        assert_equal "#{RUBY_ENGINE}-#{RUBY_VERSION}.#{RUBY_PATCHLEVEL},#{RUBY_PLATFORM}", benchmarker.environment
      end

      def test_environment_format_with_rails
        rails, version = Module.new, Module.new
        version.const_set :STRING, "4.0.0"
        rails.const_set :VERSION, version
        Object.const_set :Rails, rails

        metric = ActiveSupport::Testing::Performance::Metrics[:time].new
        benchmarker = ActiveSupport::Testing::Performance::Benchmarker.new(self, metric)
        assert_equal "rails-4.0.0,#{RUBY_ENGINE}-#{RUBY_VERSION}.#{RUBY_PATCHLEVEL},#{RUBY_PLATFORM}", benchmarker.environment
      ensure
        Object.send :remove_const, :Rails
      end
    end
  end
end
