require "active_support/dependencies/autoload"

module ActiveSupport
  extend ActiveSupport::Autoload

  autoload :BacktraceCleaner
  autoload :Base64
  autoload :BasicObject
  autoload :Benchmarkable
  autoload :BufferedLogger
  autoload :Cache
  autoload :Callbacks
  autoload :Concern
  autoload :Configurable
  autoload :DeprecatedCallbacks
  autoload :Deprecation
  autoload :Gzip
  autoload :Inflector
  autoload :Memoizable
  autoload :MessageEncryptor
  autoload :MessageVerifier
  autoload :Multibyte
  autoload :OptionMerger
  autoload :OrderedHash
  autoload :OrderedOptions
  autoload :Notifications
  autoload :Rescuable
  autoload :SecureRandom
  autoload :StringInquirer
  autoload :XmlMini
end
