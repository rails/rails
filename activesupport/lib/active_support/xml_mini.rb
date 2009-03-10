module ActiveSupport
  # = XmlMini
  #
  # To use the much faster libxml parser:
  #   gem 'libxml-ruby', '=0.9.7'
  #   XmlMini.backend = 'LibXML'
  module XmlMini
    extend self
    delegate :parse, :to => :@backend

    def backend=(name)
      require "active_support/xml_mini/#{name.to_s.downcase}.rb"
      @backend = ActiveSupport.const_get("XmlMini_#{name}")
    end
  end

  XmlMini.backend = 'REXML'
end
