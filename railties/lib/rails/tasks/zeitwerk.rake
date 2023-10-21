# frozen_string_literal: true

require "rails/zeitwerk_checker"

report_unchecked = ->(unchecked) do
  puts
  puts <<~EOS
    WARNING: The following directories will only be checked if you configure
    them to be eager loaded:
  EOS
  puts

  unchecked.each { |dir| puts "  #{dir}" }
  puts

  puts <<~EOS
    You may verify them manually, or add them to config.eager_load_paths
    in config/application.rb and run zeitwerk:check again.
  EOS
  puts
end

namespace :zeitwerk do
  desc "Check project structure for Zeitwerk compatibility"
  task check: :environment do
    puts "Hold on, I am eager loading the application."

    begin
      unchecked = Rails::ZeitwerkChecker.check
    rescue Zeitwerk::NameError => e
      abort e.message.sub(/#{Regexp.escape(Rails.root.to_s)}./, "")
    end

    if unchecked.empty?
      puts "All is good!"
    else
      report_unchecked[unchecked]
      puts "Otherwise, all is good!"
    end
  end
end
