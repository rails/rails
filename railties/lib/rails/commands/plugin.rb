if ARGV.first != "new"
  ARGV[0] = "--help"
else
  ARGV.shift
  unless ARGV.delete("--no-rc")
    customrc = ARGV.index{ |x| x.include?("--rc=") }
    railsrc = if customrc
                File.expand_path(ARGV.delete_at(customrc).gsub(/--rc=/, ""))
              else
                File.join(File.expand_path("~"), ".railsrc")
              end
    if File.exist?(railsrc)
      extra_args_string = File.read(railsrc)
      extra_args = extra_args_string.split(/\n+/).flat_map(&:split)
      puts "Using #{extra_args.join(" ")} from #{railsrc}"
      ARGV.insert(1, *extra_args)
    end
  end
end

require "rails/generators"
require "rails/generators/rails/plugin/plugin_generator"
Rails::Generators::PluginGenerator.start
