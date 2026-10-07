# frozen_string_literal: true

require "test_helper"
require "active_support/testing/stream"

class BugReportTemplatesTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::Stream

  templates = Dir.glob("bug_report_templates/*.rb")
  templates.each do |file|
    test "#{file} can be executed " do
      case file
      when "bug_report_templates/action_mailbox.rb", "bug_report_templates/active_storage.rb"
        skip "activesupport-8.1.3.1 has a compatiblity issue with json 3.0.0"
      end

      success = silence_stream($stdout) do
        Bundler.unbundled_system(Gem.ruby, "-w", file) ||
          puts("+++ 💥 FAILED (exit #{$?.exitstatus})")
      end
      assert success
    end
  end
end
