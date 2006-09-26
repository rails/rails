require 'optparse'

options = { :environment => (ENV['RAILS_ENV'] || "development").dup }

ARGV.clone.options do |opts|
  script_name = File.basename($0)
  opts.banner = "Usage: #{$0} [options] ('Some.ruby(code)' or a filename)"

  opts.separator ""

  opts.on("-e", "--environment=name", String,
          "Specifies the environment for the runner to operate under (test/development/production).",
          "Default: development") { |v| options[:environment] = v }

  opts.separator ""

  opts.on("-h", "--help",
          "Show this help message.") { $stderr.puts opts; exit }

  if RUBY_PLATFORM !~ /mswin/
    opts.separator ""
    opts.separator "You can also use runner as a shebang line for your scripts like this:"
    opts.separator "-------------------------------------------------------------"
    opts.separator "#!/usr/bin/env #{File.expand_path($0)}"
    opts.separator ""
    opts.separator "Product.find(:all).each { |p| p.price *= 2 ; p.save! }"
    opts.separator "-------------------------------------------------------------"
  end

  opts.parse! rescue retry
end

ENV["RAILS_ENV"] = options[:environment]
RAILS_ENV.replace(options[:environment]) if defined?(RAILS_ENV)

require RAILS_ROOT + '/config/environment'

if ARGV.empty?
  $stderr.puts "Run '#{$0} -h' for help."
  exit 1
elsif File.exists?(ARGV.first)
  eval(File.read(ARGV.shift))
else
  eval(ARGV.first)
end
