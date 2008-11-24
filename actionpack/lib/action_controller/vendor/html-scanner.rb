$LOAD_PATH << "#{File.dirname(__FILE__)}/html-scanner"

module HTML
  autoload :Document, 'html/document'
  autoload :Sanitizer, 'html/sanitizer'
  autoload :FullSanitizer, 'html/sanitizer'
  autoload :LinkSanitizer, 'html/sanitizer'
  autoload :WhiteListSanitizer, 'html/sanitizer'
end
