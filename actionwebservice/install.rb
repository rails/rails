require 'rbconfig'
require 'find'
require 'ftools'

include Config

# this was adapted from rdoc's install.rb by way of Log4r

$sitedir = CONFIG["sitelibdir"]
unless $sitedir
  version = CONFIG["MAJOR"] + "." + CONFIG["MINOR"]
  $libdir = File.join(CONFIG["libdir"], "ruby", version)
  $sitedir = $:.find {|x| x =~ /site_ruby/ }
  if !$sitedir
    $sitedir = File.join($libdir, "site_ruby")
  elsif $sitedir !~ Regexp.quote(version)
    $sitedir = File.join($sitedir, version)
  end
end

# the acual gruntwork
Dir.chdir("lib")

Find.find("action_web_service", "action_web_service.rb") { |f|
  if f[-3..-1] == ".rb"
    File::install(f, File.join($sitedir, *f.split(/\//)), 0644, true)
  else
    File::makedirs(File.join($sitedir, *f.split(/\//)))
  end
}
