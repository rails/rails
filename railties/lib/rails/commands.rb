commands = Dir["#{File.dirname(__FILE__)}/commands/*.rb"].collect { |file_path| File.basename(file_path).split(".").first }

if commands.include?(ARGV.first)
  require "#{File.dirname(__FILE__)}/commands/#{ARGV.shift}"
else
  puts <<-USAGE
The 'run' provides a unified access point for all the default Rails' commands.
  
Usage: ./script/run <command> [OPTIONS]

Examples:
  ./script/run generate controller Admin
  ./script/run process reaper

USAGE
  puts "Choose: #{commands.join(", ")}"
end