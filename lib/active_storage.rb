require "active_record"
require "active_storage/engine" if defined?(Rails)

module ActiveStorage
  extend ActiveSupport::Autoload

  autoload :Blob
  autoload :Service
end
