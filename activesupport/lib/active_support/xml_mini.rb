# = XmlMini
module ActiveSupport
  module XmlMini
    extend self

    CONTENT_KEY = '__content__'.freeze

    # Hook the correct parser into XmlMini
    def hook_parser
      begin
        require 'xml/libxml' unless defined? LibXML
        require "active_support/xml_mini/libxml.rb"
      rescue MissingSourceFile => e
        require "active_support/xml_mini/rexml.rb"
      end
    end

    hook_parser

  end
end