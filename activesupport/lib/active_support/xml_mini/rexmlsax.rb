# frozen_string_literal: true

begin
  require "rexml/parsers/sax2parser"
  require "rexml/sax2listener"
rescue LoadError => e
  warn "You don't have rexml installed in your application. Please add it to your Gemfile and run bundle install"
  raise e
end

require "active_support/core_ext/object/blank"
require "stringio"

module ActiveSupport
  module XmlMini_REXMLSAX # :nodoc:
    extend self

    # Class that will build the hash while the XML document
    # is being parsed using SAX events.
    class HashBuilder
      include REXML::SAX2Listener

      CONTENT_KEY = "__content__"
      HASH_SIZE_KEY = "__hash_size__"

      attr_reader :hash

      def current_hash
        @hash_stack.last
      end

      def start_document
        @hash = {}
        @hash_stack = [@hash]
      end

      def end_document
        raise "Parse stack not empty!" if @hash_stack.size > 1
      end

      def start_element(uri, localname, name, attrs = {})
        new_hash = { CONTENT_KEY => +"" }.merge!(Hash[attrs])
        new_hash[HASH_SIZE_KEY] = new_hash.size + 1

        case current_hash[name]
        when Array then current_hash[name] << new_hash
        when Hash  then current_hash[name] = [current_hash[name], new_hash]
        when nil   then current_hash[name] = new_hash
        end

        @hash_stack.push(new_hash)
      end

      def end_element(uri, localname, name)
        if current_hash.length > current_hash.delete(HASH_SIZE_KEY) && current_hash[CONTENT_KEY].blank? || current_hash[CONTENT_KEY] == ""
          current_hash.delete(CONTENT_KEY)
        end
        @hash_stack.pop
      end

      def characters(string)
        current_hash[CONTENT_KEY] << string unless current_hash[CONTENT_KEY].nil?
      end

      alias_method :cdata, :characters
    end

    attr_accessor :document_class
    self.document_class = HashBuilder

    # Parse an XML Document string or IO into a simple hash.
    # data::
    #   XML Document string or IO to parse
    def parse(data)
      if !data.respond_to?(:read)
        data = StringIO.new(data || "")
      end

      if data.eof?
        {}
      else
        document = document_class.new
        parser = REXML::Parsers::SAX2Parser.new(data)
        parser.listen(document)
        parser.parse
        document.hash
      end
    end
  end
end
