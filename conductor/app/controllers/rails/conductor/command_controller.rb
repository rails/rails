# frozen_string_literal: true

class Rails::Conductor::CommandController < Rails::Conductor::BaseController
  private
    def capture_stdout
      original_stdout, $stdout = $stdout, StringIO.new
      yield
      $stdout.string
    ensure
      $stdout = original_stdout
    end
end
