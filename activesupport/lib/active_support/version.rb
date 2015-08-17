module ActiveSupport
  # Returns the version of the currently loaded ActiveSupport as a string.
  VERSION = File.read(File.expand_path('../../../../RAILS_VERSION', __FILE__)).strip
end
