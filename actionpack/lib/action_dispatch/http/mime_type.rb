# frozen_string_literal: true

# :markup: markdown

require "singleton"

module Mime
  class Mimes
    attr_reader :symbols

    include Enumerable

    def initialize
      @mimes = []
      @symbols = []
      @symbols_set = Set.new
    end

    def each(&block)
      @mimes.each(&block)
    end

    def <<(type)
      @mimes << type
      sym_type = type.to_sym
      @symbols << sym_type
      @symbols_set << sym_type
    end

    def delete_if
      @mimes.delete_if do |x|
        if yield x
          sym_type = x.to_sym
          @symbols.delete(sym_type)
          @symbols_set.delete(sym_type)
          true
        end
      end
    end

    def valid_symbols?(symbols) # :nodoc
      symbols.all? { |s| @symbols_set.include?(s) }
    end
  end

  SET              = Mimes.new
  EXTENSION_LOOKUP = {}
  LOOKUP           = {}

  class << self
    def [](type)
      return type if type.is_a?(Type)
      Type.lookup_by_extension(type)
    end

    def symbols
      SET.symbols
    end

    def valid_symbols?(symbols) # :nodoc:
      SET.valid_symbols?(symbols)
    end

    def fetch(type, &block)
      return type if type.is_a?(Type)
      EXTENSION_LOOKUP.fetch(type.to_s, &block)
    end
  end

  # Encapsulates the notion of a MIME type. Can be used at render time, for
  # example, with:
  #
  #     class PostsController < ActionController::Base
  #       def show
  #         @post = Post.find(params[:id])
  #
  #         respond_to do |format|
  #           format.html
  #           format.ics { render body: @post.to_ics, mime_type: Mime::Type.lookup("text/calendar")  }
  #           format.xml { render xml: @post }
  #         end
  #       end
  #     end
  class Type
    attr_reader :symbol

    @register_callbacks = []

    # A simple helper class used in parsing the accept header.
    class AcceptItem # :nodoc:
      attr_accessor :index, :name, :q
      alias :to_s :name

      def initialize(index, name, q = nil)
        @index = index
        @name = name
        q ||= 0.0 if @name == "*/*" # Default wildcard match to end of list.
        @q = ((q || 1.0).to_f * 100).to_i
      end

      def <=>(item)
        result = item.q <=> @q
        result = @index <=> item.index if result == 0
        result
      end
    end

    class AcceptList # :nodoc:
      def self.sort!(list)
        list.sort!

        text_xml_idx = find_item_by_name list, "text/xml"
        app_xml_idx = find_item_by_name list, Mime[:xml].to_s

        # Take care of the broken text/xml entry by renaming or deleting it.
        if text_xml_idx && app_xml_idx
          app_xml = list[app_xml_idx]
          text_xml = list[text_xml_idx]

          app_xml.q = [text_xml.q, app_xml.q].max # Set the q value to the max of the two.
          if app_xml_idx > text_xml_idx  # Make sure app_xml is ahead of text_xml in the list.
            list[app_xml_idx], list[text_xml_idx] = text_xml, app_xml
            app_xml_idx, text_xml_idx = text_xml_idx, app_xml_idx
          end
          list.delete_at(text_xml_idx)  # Delete text_xml from the list.
        elsif text_xml_idx
          list[text_xml_idx].name = Mime[:xml].to_s
        end

        # Look for more specific XML-based types and sort them ahead of app/xml.
        if app_xml_idx
          app_xml = list[app_xml_idx]
          idx = app_xml_idx

          while idx < list.length
            type = list[idx]
            break if type.q < app_xml.q

            if type.name.end_with? "+xml"
              list[app_xml_idx], list[idx] = list[idx], app_xml
              app_xml_idx = idx
            end
            idx += 1
          end
        end

        list.map! { |i| Mime::Type.lookup(i.name) }.uniq!
        list
      end

      def self.find_item_by_name(array, name)
        array.index { |item| item.name == name }
      end
    end

    class << self
      TRAILING_STAR_REGEXP = /^(text|application)\/\*/
      # all media-type parameters need to be before the q-parameter
      # https://www.rfc-editor.org/rfc/rfc7231#section-5.3.2
      PARAMETER_SEPARATOR_REGEXP = /;\s*q="?/
      ACCEPT_HEADER_REGEXP = /[^,\s"](?:[^,"]|"[^"]*")*/

      def register_callback(&block)
        @register_callbacks << block
      end

      def lookup(string)
        return LOOKUP[string] if LOOKUP.key?(string)

        # fallback to the media-type without parameters if it was not found
        string = string.split(";", 2)[0]&.rstrip
        LOOKUP[string] || Type.new(string)
      end

      def lookup_by_extension(extension)
        EXTENSION_LOOKUP[extension.to_s]
      end

      # Registers an alias that's not used on MIME type lookup, but can be referenced
      # directly. Especially useful for rendering different HTML versions depending on
      # the user agent, like an iPhone.
      def register_alias(string, symbol, extension_synonyms = [])
        register(string, symbol, [], extension_synonyms, true)
      end

      def register(string, symbol, mime_type_synonyms = [], extension_synonyms = [], skip_lookup = false)
        new_mime = Type.new(string, symbol, mime_type_synonyms)

        SET << new_mime

        ([string] + mime_type_synonyms).each { |str| LOOKUP[str] = new_mime } unless skip_lookup
        ([symbol] + extension_synonyms).each { |ext| EXTENSION_LOOKUP[ext.to_s] = new_mime }

        @register_callbacks.each do |callback|
          callback.call(new_mime)
        end
        new_mime
      end

      def parse(accept_header)
        if !accept_header.include?(",")
          if (index = accept_header.index(PARAMETER_SEPARATOR_REGEXP))
            accept_header = accept_header[0, index].strip
          end
          return [] if accept_header.blank?
          parse_trailing_star(accept_header) || Array(Mime::Type.lookup(accept_header))
        else
          list, index = [], 0
          accept_header.scan(ACCEPT_HEADER_REGEXP).each do |header|
            params, q = header.split(PARAMETER_SEPARATOR_REGEXP)

            next unless params
            params.strip!
            next if params.empty?

            params = parse_trailing_star(params) || [params]

            params.each do |m|
              list << AcceptItem.new(index, m.to_s, q)
              index += 1
            end
          end
          AcceptList.sort! list
        end
      end

      def parse_trailing_star(accept_header)
        parse_data_with_trailing_star($1) if accept_header =~ TRAILING_STAR_REGEXP
      end

      # For an input of `'text'`, returns `[Mime[:json], Mime[:xml], Mime[:ics],
      # Mime[:html], Mime[:css], Mime[:csv], Mime[:js], Mime[:yaml], Mime[:text]]`.
      #
      # For an input of `'application'`, returns `[Mime[:html], Mime[:js], Mime[:xml],
      # Mime[:yaml], Mime[:atom], Mime[:json], Mime[:rss], Mime[:url_encoded_form]]`.
      def parse_data_with_trailing_star(type)
        Mime::SET.select { |m| m.match?(type) }
      end

      # This method is opposite of register method.
      #
      # To unregister a MIME type:
      #
      #     Mime::Type.unregister(:mobile)
      def unregister(symbol)
        symbol = symbol.downcase
        if mime = Mime[symbol]
          SET.delete_if { |v| v.eql?(mime) }
          LOOKUP.delete_if { |_, v| v.eql?(mime) }
          EXTENSION_LOOKUP.delete_if { |_, v| v.eql?(mime) }
        end
      end
    end

    attr_reader :hash

    MIME_NAME = "[a-zA-Z0-9][a-zA-Z0-9#{Regexp.escape('!#$&-^_.+')}]{0,126}"
    MIME_PARAMETER_VALUE = "(?:#{MIME_NAME}|\"[^\"\r\\\\]*\")"
    MIME_PARAMETER = "\s*;\s*#{MIME_NAME}(?:=#{MIME_PARAMETER_VALUE})?"
    MIME_REGEXP = /\A(?:\*\/\*|#{MIME_NAME}\/(?:\*|#{MIME_NAME})(?>#{MIME_PARAMETER})*\s*)\z/

    class InvalidMimeType < StandardError; end

    def initialize(string, symbol = nil, synonyms = [])
      unless MIME_REGEXP.match?(string)
        raise InvalidMimeType, "#{string.inspect} is not a valid MIME type"
      end
      @symbol, @synonyms = symbol, synonyms
      @string = string
      @hash = [@string, @synonyms, @symbol].hash
    end

    def to_s
      @string
    end

    def to_str
      to_s
    end

    def to_sym
      @symbol
    end

    def ref
      symbol || to_s
    end

    def ===(list)
      if list.is_a?(Array)
        (@synonyms + [ self ]).any? { |synonym| list.include?(synonym) }
      else
        super
      end
    end

    def ==(mime_type)
      return false unless mime_type
      (@synonyms + [ self ]).any? do |synonym|
        synonym.to_s == mime_type.to_s || synonym.to_sym == mime_type.to_sym
      end
    end

    def eql?(other)
      super || (self.class == other.class &&
                @string    == other.string &&
                @synonyms  == other.synonyms &&
                @symbol    == other.symbol)
    end

    def =~(mime_type)
      return false unless mime_type
      regexp = Regexp.new(Regexp.quote(mime_type.to_s))
      @synonyms.any? { |synonym| synonym.to_s =~ regexp } || @string =~ regexp
    end

    def match?(mime_type)
      return false unless mime_type
      regexp = Regexp.new(Regexp.quote(mime_type.to_s))
      @synonyms.any? { |synonym| synonym.to_s.match?(regexp) } || @string.match?(regexp)
    end

    def html?
      (symbol == :html) || @string.include?("html")
    end

    def all?; false; end

    protected
      attr_reader :string, :synonyms

    private
      def to_ary; end
      def to_a; end

      def method_missing(method, ...)
        if method.end_with?("?")
          method[0..-2].downcase.to_sym == to_sym
        else
          super
        end
      end

      def respond_to_missing?(method, include_private = false)
        method.end_with?("?") || super
      end
  end

  class AllType < Type
    include Singleton

    def initialize
      super "*/*", nil
    end

    def all?; true; end
    def html?; true; end
  end

  # ALL isn't a real MIME type, so we don't register it for lookup with the other
  # concrete types. It's a wildcard match that we use for `respond_to` negotiation
  # internals.
  ALL = AllType.instance

  class NullType
    include Singleton

    def nil?
      true
    end

    def to_s
      ""
    end

    def ref; end

    private
      def respond_to_missing?(method, _)
        method.end_with?("?")
      end

      def method_missing(method, ...)
        false if method.end_with?("?")
      end
  end
end

require "action_dispatch/http/mime_types"
