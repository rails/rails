# Fixed includes are always put ahead of the load_path to ensure that it's the files in this Rails package that's used.
# Overwritteable inludes allow newer Active Records and Action Packs to be installed globally (such as through GEMs).

OVERWRITTEABLE_INCLUDES = [] # [ "activerecord", "actionpack" ]
FIXED_INCLUDES = [ 
  "config", "app/models", "app/controllers", "app/helpers", "vendor/railties", "vendor/activerecord/lib", "vendor/actionpack/lib"
]

OVERWRITTEABLE_INCLUDES.each { |dir| $: << "#{File.dirname(__FILE__)}/../../vendor/#{dir}/lib" }
FIXED_INCLUDES.each { |dir| $:.unshift "#{File.dirname(__FILE__)}/../../#{dir}" }
