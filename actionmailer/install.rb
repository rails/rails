require 'rbconfig'
require 'find'
require 'ftools'

include Config

# this was adapted from rdoc's install.rb by ways of Log4r

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

makedirs = %w{ action_mailer/vendor action_mailer/vendor/text action_mailer/vendor/tmail }
makedirs.each {|f| File::makedirs(File.join($sitedir, *f.split(/\//)))}

# deprecated files that should be removed
# deprecated = %w{ }

# files to install in library path
files = %w-
 action_mailer.rb
 action_mailer/base.rb
 action_mailer/mail_helper.rb
 action_mailer/vendor/text/format.rb
 action_mailer/vendor/tmail.rb
 action_mailer/vendor/tmail/address.rb
 action_mailer/vendor/tmail/base64.rb
 action_mailer/vendor/tmail/config.rb
 action_mailer/vendor/tmail/encode.rb
 action_mailer/vendor/tmail/facade.rb
 action_mailer/vendor/tmail/header.rb
 action_mailer/vendor/tmail/info.rb
 action_mailer/vendor/tmail/loader.rb
 action_mailer/vendor/tmail/mail.rb
 action_mailer/vendor/tmail/mailbox.rb
 action_mailer/vendor/tmail/mbox.rb
 action_mailer/vendor/tmail/net.rb
 action_mailer/vendor/tmail/obsolete.rb
 action_mailer/vendor/tmail/parser.rb
 action_mailer/vendor/tmail/port.rb
 action_mailer/vendor/tmail/scanner.rb
 action_mailer/vendor/tmail/scanner_r.rb
 action_mailer/vendor/tmail/stringio.rb
 action_mailer/vendor/tmail/tmail.rb
 action_mailer/vendor/tmail/utils.rb
-

# the acual gruntwork
Dir.chdir("lib")
# File::safe_unlink *deprecated.collect{|f| File.join($sitedir, f.split(/\//))}
files.each {|f| 
  File::install(f, File.join($sitedir, *f.split(/\//)), 0644, true)
}
