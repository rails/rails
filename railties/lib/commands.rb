commands = Dir["#{File.dirname(__FILE__)}/commands/*.rb"].collect { |file_path| File.basename(file_path).split(".").first }

if commands.include?(ARGV.first)
  require "#{File.dirname(__FILE__)}/commands/#{ARGV.shift}"
else
  puts "Choose: #{commands.join(", ")}"
end