irb = RUBY_PLATFORM =~ /(:?mswin|mingw)/ ? 'irb.bat' : 'irb'

require 'optparse'
options = { :sandbox => false, :irb => irb }
OptionParser.new do |opt|
  opt.banner = "Usage: console [environment] [options]"
  opt.on('-s', '--sandbox', 'Rollback database modifications on exit.') { |v| options[:sandbox] = v }
  opt.on("--irb=[#{irb}]", 'Invoke a different irb.') { |v| options[:irb] = v }
  opt.parse!(ARGV)
end

libs =  " -r irb/completion"
libs << %( -r "#{RAILS_ROOT}/config/environment")
libs << " -r console_app"
libs << " -r console_sandbox" if options[:sandbox]
libs << " -r console_with_helpers"

ENV['RAILS_ENV'] = case ARGV.first
  when "p": "production"
  when "d": "development"
  when "t": "test"
  else
    ARGV.first || ENV['RAILS_ENV'] || 'development'
end

if options[:sandbox]
  puts "Loading #{ENV['RAILS_ENV']} environment in sandbox (Rails #{Rails::VERSION::STRING})"
  puts "Any modifications you make will be rolled back on exit"
else
  puts "Loading #{ENV['RAILS_ENV']} environment (Rails #{Rails::VERSION::STRING})"
end
exec "#{options[:irb]} #{libs} --simple-prompt"
