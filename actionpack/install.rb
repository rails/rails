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

makedirs = %w{ action_controller/assertions action_controller/cgi_ext
               action_controller/session action_controller/support action_controller/support/core_ext 
               action_controller/support/core_ext/hash action_controller/support/core_ext/numeric action_controller/support/core_ext/string
               action_controller/templates action_controller/templates/rescues
               action_controller/templates/scaffolds
               action_view/helpers action_view/vendor action_view/vendor/builder
}


makedirs.each {|f| File::makedirs(File.join($sitedir, *f.split(/\//)))}

# deprecated files that should be removed
# deprecated = %w{ }

# files to install in library path
files = %w-
 action_controller.rb
 action_controller/assertions/action_pack_assertions.rb
 action_controller/assertions/active_record_assertions.rb
 action_controller/base.rb
 action_controller/benchmarking.rb
 action_controller/cgi_ext/cgi_ext.rb
 action_controller/cgi_ext/cgi_methods.rb
 action_controller/cgi_ext/cookie_performance_fix.rb
 action_controller/cgi_ext/raw_post_data_fix.rb
 action_controller/caching.rb
 action_controller/cgi_process.rb
 action_controller/cookies.rb
 action_controller/dependencies.rb
 action_controller/filters.rb
 action_controller/flash.rb
 action_controller/helpers.rb
 action_controller/layout.rb
 action_controller/request.rb
 action_controller/rescue.rb
 action_controller/response.rb
 action_controller/scaffolding.rb
 action_controller/session/active_record_store.rb
 action_controller/session/drb_server.rb
 action_controller/session/drb_store.rb
 action_controller/session/mem_cache_store.rb
 action_controller/session.rb
 action_controller/support/class_inheritable_attributes.rb
 action_controller/support/class_attribute_accessors.rb
 action_controller/support/clean_logger.rb
 action_controller/support/core_ext/hash/keys.rb
 action_controller/support/core_ext/hash.rb
 action_controller/support/core_ext/object_and_class.rb
 action_controller/support/core_ext/numeric/bytes.rb
 action_controller/support/core_ext/numeric/time.rb
 action_controller/support/core_ext/numeric.rb
 action_controller/support/core_ext/string/inflections.rb
 action_controller/support/core_ext/string.rb
 active_record/support/core_ext.rb
 action_controller/support/inflector.rb
 action_controller/support/binding_of_caller.rb
 action_controller/support/breakpoint.rb
 action_controller/support/dependencies.rb
 action_controller/support/misc.rb
 action_controller/support/module_attribute_accessors.rb
 action_controller/templates/rescues/_request_and_response.rhtml
 action_controller/templates/rescues/diagnostics.rhtml
 action_controller/templates/rescues/layout.rhtml
 action_controller/templates/rescues/missing_template.rhtml
 action_controller/templates/rescues/template_error.rhtml
 action_controller/templates/rescues/unknown_action.rhtml
 action_controller/templates/scaffolds/edit.rhtml
 action_controller/templates/scaffolds/layout.rhtml
 action_controller/templates/scaffolds/list.rhtml
 action_controller/templates/scaffolds/new.rhtml
 action_controller/templates/scaffolds/show.rhtml
 action_controller/test_process.rb
 action_controller/url_rewriter.rb
 action_view.rb
 action_view/base.rb
 action_view/helpers/active_record_helper.rb
 action_view/helpers/date_helper.rb
 action_view/helpers/debug_helper.rb
 action_view/helpers/form_helper.rb
 action_view/helpers/form_options_helper.rb
 action_view/helpers/text_helper.rb
 action_view/helpers/tag_helper.rb
 action_view/helpers/url_helper.rb
 action_view/partials.rb
 action_view/template_error.rb
 action_view/vendor/builder.rb
 action_view/vendor/builder/blankslate.rb
 action_view/vendor/builder/xmlbase.rb
 action_view/vendor/builder/xmlevents.rb
 action_view/vendor/builder/xmlmarkup.rb
-

# the acual gruntwork
Dir.chdir("lib")
# File::safe_unlink *deprecated.collect{|f| File.join($sitedir, f.split(/\//))}
files.each {|f| 
  File::install(f, File.join($sitedir, *f.split(/\//)), 0644, true)
}
