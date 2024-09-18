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

report_autoloads_on_boot = ->(autoloads) do
  puts
  puts <<~EOS
    WARNING: The following autoload constants were loaded during
    the boot process:
  EOS
  puts

  autoloads.each { |constant| puts "  #{constant}" }
  puts

  puts <<~EOS
    SUMMARY: #{autoloads.count} autoload constants eagerly loaded during boot.
  EOS
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

  namespace :check do
    task boot: :environment do
      begin
        autoloads_on_boot = Rails::ZeitwerkChecker.check_boot
      rescue Zeitwerk::NameError => e
        abort e.message.sub(/#{Regexp.escape(Rails.root.to_s)}./, "")
      end

      if autoloads_on_boot.empty?
        puts "All is good!"
      else
        report_autoloads_on_boot[autoloads_on_boot]
      end
    end
  end
end
