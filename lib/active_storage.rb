require "active_record"
require "active_storage/engine"

module ActiveStorage
  extend ActiveSupport::Autoload

  autoload :Blob
  autoload :Service
end
