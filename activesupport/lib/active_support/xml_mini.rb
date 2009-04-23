require 'active_support/core_ext/module/delegation'

module ActiveSupport
  # = XmlMini
  #
  # To use the much faster libxml parser:
  #   gem 'libxml-ruby', '=0.9.7'
  #   XmlMini.backend = 'LibXML'
  module XmlMini
    extend self

    attr_reader :backend
    delegate :parse, :to => :backend

    def backend=(name)
      if name.is_a?(Module)
        @backend = name
      else
        require "active_support/xml_mini/#{name.to_s.downcase}.rb"
        @backend = ActiveSupport.const_get("XmlMini_#{name}")
      end
    end

    def with_backend(name)
      old_backend, self.backend = backend, name
      yield
    ensure
      self.backend = old_backend
    end
  end

  XmlMini.backend = 'REXML'
end
