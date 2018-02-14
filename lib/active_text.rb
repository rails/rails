require "active_record"
require "active_text/engine"
require "nokogiri"

module ActiveText
  extend ActiveSupport::Autoload

  mattr_accessor(:renderer)

  autoload :Attachable
  autoload :Attachment
  autoload :Attribute
  autoload :Content
  autoload :Fragment
  autoload :HtmlConversion
  autoload :PlainTextConversion
  autoload :Serialization
  autoload :TrixAttachment

  module Attachables
    extend ActiveSupport::Autoload

    autoload :ContentAttachment
    autoload :MissingAttachable
    autoload :RemoteImage
  end

  module Attachments
    extend ActiveSupport::Autoload

    autoload :Caching
    autoload :Minification
    autoload :TrixConversion
  end
end
