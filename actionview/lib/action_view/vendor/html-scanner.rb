require 'active_support/deprecation'
$LOAD_PATH.unshift "#{File.dirname(__FILE__)}/html-scanner"

ActiveSupport::Deprecation.warn("html-scanner has been deprecated in favor of using Loofah in SanitizeHelper and Rails::Dom::Testing::Assertions.")

module HTML
  extend ActiveSupport::Autoload

  eager_autoload do
    autoload :CDATA, 'html/node'
    autoload :Document, 'html/document'
    autoload :FullSanitizer, 'html/sanitizer'
    autoload :LinkSanitizer, 'html/sanitizer'
    autoload :Node, 'html/node'
    autoload :Sanitizer, 'html/sanitizer'
    autoload :Selector, 'html/selector'
    autoload :Tag, 'html/node'
    autoload :Text, 'html/node'
    autoload :Tokenizer, 'html/tokenizer'
    autoload :Version, 'html/version'
    autoload :WhiteListSanitizer, 'html/sanitizer'
  end
end
