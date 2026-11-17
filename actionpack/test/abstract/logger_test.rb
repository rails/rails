# frozen_string_literal: true

require "abstract_unit"

module AbstractController
  module Testing
    class LoggerTest < ActiveSupport::TestCase
      class Parent < AbstractController::Base
        include AbstractController::Logger
      end

      class Child < Parent
      end

      test "logger is stored in the controller configuration and inherited" do
        logger = ActiveSupport::Logger.new(nil)
        Parent.logger = logger

        assert_same logger, Parent.logger
        assert_same logger, Parent.config.logger
        assert_same logger, Child.logger
        assert_same logger, Child.new.logger
      ensure
        Parent.logger = nil
      end

      test "reading the logger does not build an instance configuration" do
        controller = Child.new
        controller.logger

        assert_nil controller.instance_variable_get(:@_config)

        controller.logger = ActiveSupport::Logger.new(nil)
        assert_same controller.logger, controller.config.logger
      end

      test "logger assigned on an instance does not leak to the class" do
        # A throwaway subclass: assigning the logger on Child, even to reset
        # it to nil afterwards, would store an explicit value in Child's own
        # configuration that shadows Parent's for the inheritance test.
        controller_class = Class.new(Parent)
        class_logger = ActiveSupport::Logger.new(nil)
        instance_logger = ActiveSupport::Logger.new(nil)
        controller_class.logger = class_logger

        controller = controller_class.new
        controller.logger = instance_logger

        assert_same instance_logger, controller.logger
        assert_same instance_logger, controller.config.logger
        assert_same class_logger, controller_class.logger
        assert_same class_logger, controller_class.new.logger
      end
    end
  end
end
