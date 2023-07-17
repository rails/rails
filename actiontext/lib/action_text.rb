# frozen_string_literal: true

require "active_support"
require "active_support/rails"

require "action_text/version"
require "action_text/deprecator"

require "nokogiri"

# :markup: markdown
# :include: actiontext/README.md
module ActionText
  extend ActiveSupport::Autoload

  autoload :Attachable
  autoload :AttachmentGallery
  autoload :Attachment
  autoload :Attribute
  autoload :Content
  autoload :Encryption
  autoload :Fragment
  autoload :FixtureSet
  autoload :HtmlConversion
  autoload :PlainTextConversion
  autoload :Rendering
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

  class << self
    def html_document_class
      return @html_document_class if defined?(@html_document_class)
      @html_document_class =
        defined?(Nokogiri::HTML5) ? Nokogiri::HTML5::Document : Nokogiri::HTML4::Document
    end

    def html_document_fragment_class
      return @html_document_fragment_class if defined?(@html_document_fragment_class)
      @html_document_fragment_class =
        defined?(Nokogiri::HTML5) ? Nokogiri::HTML5::DocumentFragment : Nokogiri::HTML4::DocumentFragment
    end
  end
end
