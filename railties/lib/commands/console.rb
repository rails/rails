require 'optparse'

options = { :sandbox => false }
OptionParser.new do |opt|
  opt.banner = "Usage: console [environment] [options]"
  opt.on('-s', '--sandbox', 'Rollback database modifications on exit.') { |v| options[:sandbox] = v }
  opt.on("--debugger", 'Enable ruby-debugging for the console.') { |v| options[:debugger] = v }
  opt.parse!(ARGV)
end

require 'irb'
require "irb/completion"
require "#{RAILS_ROOT}/config/environment"
require "console_app"
require "console_sandbox" if options[:sandbox]
require "console_with_helpers"

if options[:debugger]
  begin
    require 'ruby-debug'
    puts "=> Debugger enabled"
  rescue Exception
    puts "You need to install ruby-debug to run the console in debugging mode. With gems, use 'gem install ruby-debug'"
    exit
  end
end

ENV['RAILS_ENV'] = case ARGV.first
  when "p"; "production"
  when "d"; "development"
  when "t"; "test"
  else
    ARGV.first || ENV['RAILS_ENV'] || 'development'
end

if options[:sandbox]
  puts "Loading #{ENV['RAILS_ENV']} environment in sandbox (Rails #{Rails.version})"
  puts "Any modifications you make will be rolled back on exit"
else
  puts "Loading #{ENV['RAILS_ENV']} environment (Rails #{Rails.version})"
end

ARGV.replace(["--simple-prompt"])
IRB.start
