# frozen_string_literal: true

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

mismatches = []
check_directory = ->(directory, parent) do
  # test/mailers/previews might not exist.
  return unless File.exists?(directory)

  Dir.foreach(directory) do |entry|
    next if entry.start_with?(".")
    next if parent == Object && entry == "concerns"

    abspath = File.join(directory, entry)

    if File.directory?(abspath) || abspath.end_with?(".rb")
      print "."
      cname = File.basename(abspath, ".rb").camelize.to_sym
      if parent.const_defined?(cname, false)
        if File.directory?(abspath)
          check_directory[abspath, parent.const_get(cname)]
        end
      else
        mismatches << [abspath, parent, cname]
      end
    end
  end
end

report = ->() do
  puts
  if mismatches.empty?
    puts "All is good!"
    puts "Please, remember to delete `config.autoloader = :classic` from config/application.rb."
  else
    mismatches.each do |abspath, parent, cname|
      relpath = abspath.sub(%r{\A#{Regexp.escape(Rails.root.to_path)}/}, "")
      cpath = parent == Object ? cname : "#{parent.name}::#{cname}"
      puts "expected #{relpath} to define #{cpath}"
    end
    puts
    puts <<~EOS
      Please revise the reported mismatches. You can normally fix them by adding
      acronyms to config/initializers/inflections.rb or renaming the constants.
    EOS
  end
end

namespace :zeitwerk do
  desc "Checks project structure for Zeitwerk compatibility"
  task check: :environment do
    ensure_classic_mode[]
    eager_load[]

    $stdout.sync = true
    ActiveSupport::Dependencies.autoload_paths.each do |autoload_path|
      check_directory[autoload_path, Object]
    end
    puts

    report[]
  end
end
