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

makedirs = %w{ active_record/associations active_record/connection_adapters active_record/support active_record/vendor active_record/acts }
makedirs.each {|f| File::makedirs(File.join($sitedir, *f.split(/\//)))}

# deprecated files that should be removed
# deprecated = %w{ }

# files to install in library path
files = %w-
 active_record.rb
 active_record/aggregations.rb
 active_record/associations.rb
 active_record/associations/association_collection.rb
 active_record/associations/has_and_belongs_to_many_association.rb
 active_record/associations/has_many_association.rb
 active_record/base.rb
 active_record/callbacks.rb
 active_record/connection_adapters/abstract_adapter.rb
 active_record/connection_adapters/db2_adapter.rb
 active_record/connection_adapters/mysql_adapter.rb
 active_record/connection_adapters/postgresql_adapter.rb
 active_record/connection_adapters/sqlite_adapter.rb
 active_record/connection_adapters/sqlserver_adapter.rb
 active_record/deprecated_associations.rb
 active_record/fixtures.rb
 active_record/locking.rb
 active_record/observer.rb
 active_record/reflection.rb
 active_record/acts/list.rb
 active_record/acts/tree.rb
 active_record/support/class_attribute_accessors.rb
 active_record/support/class_inheritable_attributes.rb
 active_record/support/clean_logger.rb
 active_record/support/inflector.rb
 active_record/support/misc.rb
 active_record/timestamp.rb
 active_record/transactions.rb
 active_record/validations.rb
 active_record/vendor/mysql.rb
 active_record/vendor/simple.rb
-

# the acual gruntwork
Dir.chdir("lib")
# File::safe_unlink *deprecated.collect{|f| File.join($sitedir, f.split(/\//))}
files.each {|f| 
  File::install(f, File.join($sitedir, *f.split(/\//)), 0644, true)
}
