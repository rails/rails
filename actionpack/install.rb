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

makedirs = %w{ action_view/helpers action_controller/cgi_ext action_controller/support }
makedirs.each {|f| File::makedirs(File.join($sitedir, *f.split(/\//)))}

# deprecated files that should be removed
# deprecated = %w{ }

# files to install in library path
files = %w-
 action_controller.rb
 action_controller/base.rb
 action_controller/benchmarking.rb
 action_controller/cgi_ext/cgi_ext.rb
 action_controller/cgi_ext/cgi_methods.rb
 action_controller/cgi_ext/drb_database_manager.rb
 action_controller/cgi_ext/drb_sessions.rb
 action_controller/cgi_process.rb
 action_controller/filters.rb
 action_controller/flash.rb
 action_controller/layout.rb
 action_controller/request.rb
 action_controller/rescue.rb
 action_controller/response.rb
 action_controller/scaffolding.rb
 action_controller/support/class_inheritable_attributes.rb
 action_controller/support/class_attribute_accessors.rb
 action_controller/test_process.rb
 action_controller/url_rewriter.rb
 action_view.rb
 action_view/erb_template.rb
 action_view/eruby_template.rb
 action_view/helpers/active_record_helper.rb
 action_view/helpers/date_helper.rb
 action_view/helpers/form_helper.rb
 action_view/helpers/form_options_helper.rb
 action_view/helpers/text_helper.rb
 action_view/helpers/url_helper.rb
-

# the acual gruntwork
Dir.chdir("lib")
# File::safe_unlink *deprecated.collect{|f| File.join($sitedir, f.split(/\//))}
files.each {|f| 
  File::install(f, File.join($sitedir, *f.split(/\//)), 0644, true)
}
