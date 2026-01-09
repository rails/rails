# frozen_string_literal: true

require "test_helper"
require "active_support/testing/stream"

class BugReportTemplatesTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::Stream

  templates = Dir.glob("bug_report_templates/*.rb")
  templates.each do |file|
    test "#{file} can be executed " do
      success = silence_stream($stdout) do
        Bundler.unbundled_system(Gem.ruby, "-w", file) ||
          puts("+++ 💥 FAILED (exit #{$?.exitstatus})")
      end
      assert success
    end
  end
end
