require 'abstract_unit'

module AbstractController
  module Testing
    class MyCollector
      include AbstractController::Collector
      attr_accessor :responses

      def initialize
        @responses = []
      end

      def custom(mime, *args, &block)
        @responses << [mime, args, block]
      end
    end

    class TestCollector < ActiveSupport::TestCase
      test "responds to default mime types" do
        collector = MyCollector.new
        assert_respond_to collector, :html
        assert_respond_to collector, :text
      end

      test "does not respond to unknown mime types" do
        collector = MyCollector.new
        assert !collector.respond_to?(:unknown)
      end

      test "register mime types on method missing" do
        AbstractController::Collector.send(:remove_method, :js)
        collector = MyCollector.new
        assert !collector.respond_to?(:js)
        collector.js
        assert_respond_to collector, :js
      end

      test "does not register unknown mime types" do
        collector = MyCollector.new
        assert_raise NameError do
          collector.unknown
        end
      end

      test "generated methods call custom with args received" do
        collector = MyCollector.new
        collector.html
        collector.text(:foo)
        collector.js(:bar) { :baz }
        assert_equal [Mime::HTML, [], nil], collector.responses[0]
        assert_equal [Mime::TEXT, [:foo], nil], collector.responses[1]
        assert_equal [Mime::JS, [:bar]], collector.responses[2][0,2]
        assert_equal :baz, collector.responses[2][2].call
      end
    end
  end
end
