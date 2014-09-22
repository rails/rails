require 'optparse'
require 'rbconfig'
require 'open-uri'

options = { environment: (ENV['RAILS_ENV'] || ENV['RACK_ENV'] || "development").dup }
code_or_path = nil

if ARGV.first.nil?
  ARGV.push "-h"
end

ARGV.clone.options do |opts|
  opts.banner = "Usage: rails runner [options] [<'Some.ruby(code)'> | <filename.rb>]"

  opts.separator ""

  opts.on("-e", "--environment=name", String,
          "Specifies the environment for the runner to operate under (test/development/production).",
          "Default: development") { |v| options[:environment] = v }

  opts.separator ""

  opts.on("-h", "--help",
          "Show this help message.") { $stdout.puts opts; exit }

    opts.separator ""
    opts.separator "Examples: "

    opts.separator "    rails runner 'puts Rails.env'"
    opts.separator "        This runs the code `puts Rails.env` after loading the app"
    opts.separator ""
    opts.separator "    rails runner path/to/filename.rb"
    opts.separator "        This runs the Ruby file located at `path/to/filename.rb` after loading the app"
    opts.separator ""
    opts.separator "    rails runner URL"
    opts.separator "        This runs the contents of the URL after loading the app"

  if RbConfig::CONFIG['host_os'] !~ /mswin|mingw/
    opts.separator ""
    opts.separator "You can also use runner as a shebang line for your executables:"
    opts.separator "    -------------------------------------------------------------"
    opts.separator "    #!/usr/bin/env #{File.expand_path($0)} runner"
    opts.separator ""
    opts.separator "    Product.all.each { |p| p.price *= 2 ; p.save! }"
    opts.separator "    -------------------------------------------------------------"
  end

  opts.order! { |o| code_or_path ||= o } rescue retry
end

ARGV.delete(code_or_path)

ENV["RAILS_ENV"] = options[:environment]

require APP_PATH
Rails.application.require_environment!
Rails.application.load_runner

if code_or_path.nil?
  $stderr.puts "Run '#{$0} -h' for help."
  exit 1
elsif code_or_path =~ %r{^https?\://}
  open(code_or_path) do |io|
    eval(io.read, binding, __FILE__, __LINE__)
  end
elsif File.exist?(code_or_path)
  $0 = code_or_path
  Kernel.load code_or_path
else
  eval(code_or_path, binding, __FILE__, __LINE__)
end
