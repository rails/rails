require 'optparse'

options = { :environment => "development" }

ARGV.options do |opts|
  script_name = File.basename($0)
  opts.banner = "Usage: runner 'puts Person.find(1).name' [options]"

  opts.separator ""

  opts.on("-e", "--environment=name", String,
          "Specifies the environment for the runner to operate under (test/development/production).",
          "Default: development") { |options[:environment]| }

  opts.separator ""

  opts.on("-h", "--help",
          "Show this help message.") { puts opts; exit }

  opts.parse!
end

if defined?(RAILS_ENV)
  RAILS_ENV.replace(options[:environment])
else
  ENV["RAILS_ENV"] = options[:environment]
end

require RAILS_ROOT + '/config/environment'
eval(ARGV.first)
