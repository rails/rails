# frozen_string_literal: true

# -*- frozen-string-literal: true -*-

require "singleton"
require "active_support/core_ext/string/starts_ends_with"

module Mime
  class Mimes
    include Enumerable

    def initialize
      @mimes = []
      @symbols = nil
    end

    def each
      @mimes.each { |x| yield x }
    end

    def <<(type)
      @mimes << type
      @symbols = nil
    end

    def delete_if
      @mimes.delete_if { |x| yield x }.tap { @symbols = nil }
    end

    def symbols
      @symbols ||= map(&:to_sym)
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

    def fetch(type)
      return type if type.is_a?(Type)
      EXTENSION_LOOKUP.fetch(type.to_s) { |k| yield k }
    end
  end

  # Encapsulates the notion of a MIME type. Can be used at render time, for example, with:
  #
  #   class PostsController < ActionController::Base
  #     def show
  #       @post = Post.find(params[:id])
  #
  #       respond_to do |format|
  #         format.html
  #         format.ics { render body: @post.to_ics, mime_type: Mime::Type.lookup("text/calendar")  }
  #         format.xml { render xml: @post }
  #       end
  #     end
  #   end
  class Type
    attr_reader :symbol

    @register_callbacks = []

    # A simple helper class used in parsing the accept header.
    class AcceptItem #:nodoc:
      attr_accessor :index, :name, :q
      alias :to_s :name

      def initialize(index, name, q = nil)
        @index = index
        @name = name
        q ||= 0.0 if @name == "*/*".freeze # Default wildcard match to end of list.
        @q = ((q || 1.0).to_f * 100).to_i
      end

      def <=>(item)
        result = item.q <=> @q
        result = @index <=> item.index if result == 0
        result
      end
    end

    class AcceptList #:nodoc:
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

            if type.name.ends_with? "+xml"
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
      PARAMETER_SEPARATOR_REGEXP = /;\s*\w+="?\w+"?/

      def register_callback(&block)
        @register_callbacks << block
      end

      def lookup(string)
        LOOKUP[string] || Type.new(string)
      end

      def lookup_by_extension(extension)
        EXTENSION_LOOKUP[extension.to_s]
      end

      # Registers an alias that's not used on MIME type lookup, but can be referenced directly. Especially useful for
      # rendering different HTML versions depending on the user agent, like an iPhone.
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
          accept_header = accept_header.split(PARAMETER_SEPARATOR_REGEXP).first
          parse_trailing_star(accept_header) || [Mime::Type.lookup(accept_header)].compact
        else
          list, index = [], 0
          accept_header.split(",").each do |header|
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

      # For an input of <tt>'text'</tt>, returns <tt>[Mime[:json], Mime[:xml], Mime[:ics],
      # Mime[:html], Mime[:css], Mime[:csv], Mime[:js], Mime[:yaml], Mime[:text]</tt>.
      #
      # For an input of <tt>'application'</tt>, returns <tt>[Mime[:html], Mime[:js],
      # Mime[:xml], Mime[:yaml], Mime[:atom], Mime[:json], Mime[:rss], Mime[:url_encoded_form]</tt>.
      def parse_data_with_trailing_star(type)
        Mime::SET.select { |m| m =~ type }
      end

      # This method is opposite of register method.
      #
      # To unregister a MIME type:
      #
      #   Mime::Type.unregister(:mobile)
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

    def initialize(string, symbol = nil, synonyms = [])
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

    def html?
      symbol == :html || @string =~ /html/
    end

    def all?; false; end

    # TODO Change this to private once we've dropped Ruby 2.2 support.
    # Workaround for Ruby 2.2 "private attribute?" warning.
    protected

      attr_reader :string, :synonyms

    private

      def to_ary; end
      def to_a; end

      def method_missing(method, *args)
        if method.to_s.ends_with? "?"
          method[0..-2].downcase.to_sym == to_sym
        else
          super
        end
      end

      def respond_to_missing?(method, include_private = false)
        (method.to_s.ends_with? "?") || super
      end
  end

  class AllType < Type
    include Singleton

    def initialize
      super "*/*", :all
    end

    def all?; true; end
    def html?; true; end
  end

  # ALL isn't a real MIME type, so we don't register it for lookup with the
  # other concrete types. It's a wildcard match that we use for `respond_to`
  # negotiation internals.
  ALL = AllType.instance

  class NullType
    include Singleton

    def nil?
      true
    end

    def ref; end

    private
      def respond_to_missing?(method, _)
        method.to_s.ends_with? "?"
      end

      def method_missing(method, *args)
        false if method.to_s.ends_with? "?"
      end
  end
end

require "action_dispatch/http/mime_types"
