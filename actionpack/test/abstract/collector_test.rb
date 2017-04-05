require "abstract_unit"

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
        assert_not_respond_to collector, :unknown
      end

      test "register mime types on method missing" do
        AbstractController::Collector.send(:remove_method, :js)
        begin
          collector = MyCollector.new
          assert_not_respond_to collector, :js
          collector.js
          assert_respond_to collector, :js
        ensure
          unless AbstractController::Collector.method_defined? :js
            AbstractController::Collector.generate_method_for_mime :js
          end
        end
      end

      test "does not register unknown mime types" do
        collector = MyCollector.new
        assert_raise NoMethodError do
          collector.unknown
        end
      end

      test "generated methods call custom with arguments received" do
        collector = MyCollector.new
        collector.html
        collector.text(:foo)
        collector.js(:bar) { :baz }
        assert_equal [Mime[:html], [], nil], collector.responses[0]
        assert_equal [Mime[:text], [:foo], nil], collector.responses[1]
        assert_equal [Mime[:js], [:bar]], collector.responses[2][0, 2]
        assert_equal :baz, collector.responses[2][2].call
      end
    end
  end
end
