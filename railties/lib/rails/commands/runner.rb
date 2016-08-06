require "optparse"

options = { environment: (ENV["RAILS_ENV"] || ENV["RACK_ENV"] || "development").dup }
code_or_file = nil
command = "bin/rails runner"

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

  if RbConfig::CONFIG["host_os"] !~ /mswin|mingw/
    opts.separator ""
    opts.separator "You can also use runner as a shebang line for your executables:"
    opts.separator "    -------------------------------------------------------------"
    opts.separator "    #!/usr/bin/env #{File.expand_path(command)}"
    opts.separator ""
    opts.separator "    Product.all.each { |p| p.price *= 2 ; p.save! }"
    opts.separator "    -------------------------------------------------------------"
  end

  opts.order! { |o| code_or_file ||= o } rescue retry
end

ARGV.delete(code_or_file)

ENV["RAILS_ENV"] = options[:environment]

require APP_PATH
Rails.application.require_environment!
Rails.application.load_runner

if code_or_file.nil?
  $stderr.puts "Run '#{command} -h' for help."
  exit 1
elsif File.exist?(code_or_file)
  $0 = code_or_file
  Kernel.load code_or_file
else
  begin
    eval(code_or_file, binding, __FILE__, __LINE__)
  rescue SyntaxError, NameError
    $stderr.puts "Please specify a valid ruby command or the path of a script to run."
    $stderr.puts "Run '#{command} -h' for help."
    exit 1
  end
end
