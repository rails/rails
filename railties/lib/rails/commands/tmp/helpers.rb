# frozen_string_literal: true

module Rails
  module Command
    module Tmp # :nodoc:
      module Helpers
        private
          def clear_tmp_dir(dir)
            Rails::Command.application_root.glob("tmp/#{dir}/[^.]*").each(&:rmtree)
          end

          def create_tmp_dir(dir)
            Rails::Command.application_root.join("tmp", dir).mkpath
          end
      end
    end
  end
end
