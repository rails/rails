# frozen_string_literal: true

require "isolation/abstract_unit"

module ApplicationTests
  module RakeTests
    class FrameworkTest < ActiveSupport::TestCase
      include ActiveSupport::Testing::Isolation

      def setup
        build_app
        reset_environment_configs
      end

      def teardown
        teardown_app
      end

      def load_tasks
        require "rake"
        require "rdoc/task"
        require "rake/testtask"

        Rails.application.load_tasks
      end

      test "requiring the rake task should not define method .app_generator on Object" do
        require "#{app_path}/config/environment"

        load_tasks

        assert_raise NameError do
          Object.method(:app_generator)
        end
      end

      test "requiring the rake task should not define method .invoke_from_app_generator on Object" do
        require "#{app_path}/config/environment"

        load_tasks

        assert_raise NameError do
          Object.method(:invoke_from_app_generator)
        end
      end
    end
  end
end
