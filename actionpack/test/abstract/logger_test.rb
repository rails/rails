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

      test "logger assigned on an instance does not leak to the class" do
        class_logger = ActiveSupport::Logger.new(nil)
        instance_logger = ActiveSupport::Logger.new(nil)
        Child.logger = class_logger

        child = Child.new
        child.logger = instance_logger

        assert_same instance_logger, child.logger
        assert_same instance_logger, child.config.logger
        assert_same class_logger, Child.logger
        assert_same class_logger, Child.new.logger
      ensure
        Child.logger = nil
      end
    end
  end
end
