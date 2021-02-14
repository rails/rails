# frozen_string_literal: true

require "isolation/abstract_unit"

module ApplicationTests
  module RakeTests
    class HelpTest < ActiveSupport::TestCase
      include ActiveSupport::Testing::Isolation

      def setup
        build_app
      end

      def teardown
        teardown_app
      end

      test "help arguments describe rake tasks" do
        task_description = <<~DESC
          rails db:migrate
              Migrate the database (options: VERSION=x, VERBOSE=false, SCOPE=blog).
        DESC
        Dir.chdir(app_path) do
          output = rails "db:migrate", "-h"
          assert_match task_description, output
        end
      end
    end
  end
end
