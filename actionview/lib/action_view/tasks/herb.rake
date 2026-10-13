# frozen_string_literal: true

namespace :herb do
  desc "Check that the application's HTML+ERB templates compile through Herb"
  task check: :environment do
    require "action_view/herb_checker"

    failures = ActionView::HerbChecker.check(ActionController::Base.view_paths)

    if failures.empty?
      puts "All HTML+ERB templates compile through Herb. All is good!"
    else
      failures.each do |failure|
        puts "#{failure.template.short_identifier}:"
        failure.error.message.strip.lines.first(10).each { |line| puts "  #{line}" }
        puts
      end

      abort "#{failures.size} #{'HTML+ERB template'.pluralize(failures.size)} failed to compile through Herb."
    end
  end
end
