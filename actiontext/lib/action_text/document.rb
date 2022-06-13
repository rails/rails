# frozen_string_literal: true

module ActionText
  module Document
    extend ActiveSupport::Autoload
    extend self

    autoload :Nokogiri

    attr_writer :adapter
    delegate_missing_to :adapter

    def adapter
      @adapter ||= ActionText::Document::Nokogiri
    end
  end
end
