# frozen_string_literal: true

indent = " " * 2

ensure_classic_mode = ->() do
  if Rails.autoloaders.zeitwerk_enabled?
    abort <<~EOS
      Please, enable temporarily :classic mode:

        # config/application.rb
        config.autoloader = :classic

      and try again. When all is good, you can delete that line.
    EOS
  end
end

eager_load = ->() do
  Rails.configuration.eager_load_namespaces.each(&:eager_load!)
end

check_directory = ->(directory, parent, mismatches) do
  # test/mailers/previews might not exist.
  return unless File.exist?(directory)

  Dir.foreach(directory) do |entry|
    next if entry.start_with?(".")
    next if parent == Object && entry == "concerns"

    abspath = File.join(directory, entry)

    if File.directory?(abspath) || abspath.end_with?(".rb")
      print "."
      cname = File.basename(abspath, ".rb").camelize.to_sym
      if parent.const_defined?(cname, false)
        if File.directory?(abspath)
          check_directory[abspath, parent.const_get(cname), mismatches]
        end
      else
        mismatches << [abspath, parent, cname]
      end
    end
  end
end

report_mismatches = ->(mismatches) do
  puts
  rails_root_prefix_re = %r{\A#{Regexp.escape(Rails.root.to_path)}/}
  mismatches.each do |abspath, parent, cname|
    relpath = abspath.sub(rails_root_prefix_re, "")
    cpath = parent == Object ? cname : "#{parent.name}::#{cname}"
    puts indent + "Mismatch: Expected #{relpath} to define #{cpath}"
  end
  puts

  puts <<~EOS
    Please revise the reported mismatches. You can normally fix them by adding
    acronyms to config/initializers/inflections.rb or renaming the constants.
  EOS
end

report_not_checked = ->(not_checked) do
  puts
  puts <<~EOS
    WARNING: The files in these directories cannot be checked because they
    are not eager loaded:
  EOS
  puts

  not_checked.each { |dir| puts indent + dir }
  puts

  puts <<~EOS
    You may verify them manually, or add them to config.eager_load_paths
    in config/application.rb and run zeitwerk:check again.
  EOS
end

report = ->(mismatches, not_checked) do
  puts
  if mismatches.empty? && not_checked.empty?
    puts "All is good!"
    puts "Please, remember to delete `config.autoloader = :classic` from config/application.rb."
  else
    report_mismatches[mismatches]   if mismatches.any?
    report_not_checked[not_checked] if not_checked.any?
  end
end

namespace :zeitwerk do
  desc "Checks project structure for Zeitwerk compatibility"
  task check: :environment do
    ensure_classic_mode[]
    eager_load[]

    eager_load_paths = Rails.configuration.eager_load_namespaces.map do |eln|
      eln.config.eager_load_paths if eln.respond_to?(:config)
    end.compact.flatten

    mismatches = []

    $stdout.sync = true
    eager_load_paths.each do |eager_load_path|
      check_directory[eager_load_path, Object, mismatches]
    end

    not_checked = ActiveSupport::Dependencies.autoload_paths - eager_load_paths
    not_checked.select! { |dir| Dir.exist?(dir) }
    not_checked.reject! { |dir| Dir.empty?(dir) }

    report[mismatches, not_checked]
  end
end
