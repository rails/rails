module ActiveSupport
  # = XmlMini
  module XmlMini
    extend self
    delegate :parse, :to => :@backend

    def backend=(name)
      require "active_support/xml_mini/#{name.to_s.downcase}.rb"
      @backend = ActiveSupport.const_get("XmlMini_#{name}")
    end
  end

  begin
    gem 'libxml-ruby', '=0.9.4', '=0.9.7'
    XmlMini.backend = 'LibXML'
  rescue Gem::LoadError
    XmlMini.backend = 'REXML'
  end
end
