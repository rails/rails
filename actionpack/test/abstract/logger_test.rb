# frozen_string_literal: true

require "abstract_unit"

module AbstractController
  module Testing
    class LoggerTest < ActiveSupport::TestCase
      setup do
        @parent = Class.new(AbstractController::Base) { include AbstractController::Logger }
        @child = Class.new(@parent)
        @logger = ActiveSupport::Logger.new(nil)
      end

      test "logger is nil until set" do
        assert_nil @parent.logger
        assert_nil @parent.new.logger
      end

      test "class logger is read from config and inherited" do
        @parent.logger = @logger

        assert_same @logger, @parent.logger
        assert_same @logger, @parent.config.logger
        assert_same @logger, @child.logger
      end

      test "class logger set through config is read" do
        @parent.config.logger = @logger
        assert_same @logger, @child.logger

        other = ActiveSupport::Logger.new(nil)
        @child.config[:logger] = other
        assert_same other, @child.logger
        assert_same @logger, @parent.logger
      end

      test "subclass logger does not change the parent logger" do
        @parent.logger = @logger
        other = ActiveSupport::Logger.new(nil)
        @child.logger = other

        assert_same other, @child.logger
        assert_same @logger, @parent.logger
      end

      test "instance logger defaults to the class logger, including later changes" do
        controller = @child.new
        assert_nil controller.logger

        @parent.logger = @logger
        assert_same @logger, controller.logger

        other = ActiveSupport::Logger.new(nil)
        @child.logger = other
        assert_same other, controller.logger
      end

      test "instance logger can be set without changing the class logger" do
        @parent.logger = @logger
        controller = @parent.new
        other = ActiveSupport::Logger.new(nil)
        controller.logger = other

        assert_same other, controller.logger
        assert_same other, controller.config.logger
        assert_same @logger, @parent.logger
        assert_same @logger, @parent.new.logger
      end
    end
  end
end
