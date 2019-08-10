# frozen_string_literal: true

ensure_zeitwerk_mode = ->() do
  unless Rails.autoloaders.zeitwerk_enabled?
    abort "Please, enable :zeitwerk mode in config/application.rb and try again."
  end
end

eager_load = ->() do
  puts "Hold on, I am eager loading the application."
  Zeitwerk::Loader.eager_load_all
end

report_not_checked = ->(not_checked) do
  puts
  puts <<~EOS
    WARNING: The files in these directories cannot be checked because they
    are not eager loaded:
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
    ensure_zeitwerk_mode[]

    begin
      eager_load[]
    rescue NameError => e
      if e.message =~ /expected file .*? to define constant \S+/
        abort $&.sub(/#{Regexp.escape(Rails.root.to_s)}./, "")
      else
        raise
      end
    end

    eager_load_paths = Rails.configuration.eager_load_namespaces.map do |eln|
      eln.config.eager_load_paths if eln.respond_to?(:config)
    end.compact.flatten

    not_checked = ActiveSupport::Dependencies.autoload_paths - eager_load_paths
    not_checked.select! { |dir| Dir.exist?(dir) }
    not_checked.reject! { |dir| Dir.empty?(dir) }

    report[not_checked]
  end
end
