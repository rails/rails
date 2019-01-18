# frozen_string_literal: true

require "rails/generators"
require "rails/generators/rails/db/system/change/change_generator"

module Rails
  module Command
    module Db
      module System
        class ChangeCommand < Base # :nodoc:
          class_option :to, desc: "The database system to switch to."

          def perform
            Rails::Generators::Db::System::ChangeGenerator.start
          end
        end
      end
    end
  end
end
