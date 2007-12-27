unless defined?(Mongrel)
  abort "PROBLEM: Mongrel is not available on your system (or not in your path)"
end

require 'rails/mongrel_server/commands'

GemPlugin::Manager.instance.load "rails::mongrel" => GemPlugin::INCLUDE, "rails" => GemPlugin::EXCLUDE

case ARGV[0] ||= 'start'
when 'start', 'stop', 'restart'
  ARGV[0] = "rails::mongrelserver::#{ARGV[0]}"
end

if not Mongrel::Command::Registry.instance.run ARGV
  exit 1
end
