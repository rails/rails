module ActiveRecord
  # Returns the version of the currently loaded ActiveRecord as a string.
  VERSION = File.read(File.expand_path('../../../../RAILS_VERSION', __FILE__)).strip
end
