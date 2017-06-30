require "active_record"
require "active_file/railtie" if defined?(Rails)

module ActiveFile
  extend ActiveSupport::Autoload

  autoload :Blob
end