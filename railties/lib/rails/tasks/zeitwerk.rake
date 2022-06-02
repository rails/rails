# frozen_string_literal: true

eager_load = ->() do
  puts "Hold on, I am eager loading the application."
  Zeitwerk::Loader.eager_load_all
end

report_not_checked = ->(not_checked) do
  puts
  puts <<~EOS
    WARNING: The following directories will only be checked if you configure
    them to be eager loaded:
  EOS
  puts

  not_checked.each { |dir| puts "  #{dir}" }
  puts

  puts <<~EOS
    You may verify them manually, or add them to config.eager_load_paths
    in config/application.rb and run zeitwerk:check again.
  EOS
  puts
end

report = ->(not_checked) do
  if not_checked.any?
    report_not_checked[not_checked]
    puts "Otherwise, all is good!"
  else
    puts "All is good!"
  end
end

namespace :zeitwerk do
  desc "Checks project structure for Zeitwerk compatibility"
  task check: :environment do
    begin
      eager_load[]
    rescue NameError => e
      if e.message =~ /expected file .*? to define constant [\w:]+/
        abort $&.sub(/expected file #{Regexp.escape(Rails.root.to_s)}./, "expected file ")
      else
        raise
      end
    end

    require "active_support/core_ext/object/try"
    eager_load_paths = Rails.configuration.eager_load_namespaces.filter_map do |eln|
      # Quick regression fix for 6.0.3 to support namespaces that do not have
      # eager load paths, like the recently added i18n. I'll rewrite this task.
      eln.try(:config).try(:eager_load_paths)
    end.flatten

    not_checked = ActiveSupport::Dependencies.autoload_paths - eager_load_paths
    not_checked.select! { |dir| Dir.exist?(dir) }
    not_checked.reject! { |dir| Dir.empty?(dir) }

    report[not_checked]
  end
end
