require 'set'
require 'singleton'
require 'active_support/core_ext/module/attribute_accessors'
require 'active_support/core_ext/string/starts_ends_with'

module Mime
  class Mimes < Array
    def symbols
      @symbols ||= map { |m| m.to_sym }
    end

    %w(<< concat shift unshift push pop []= clear compact! collect!
    delete delete_at delete_if flatten! map! insert reject! reverse!
    replace slice! sort! uniq!).each do |method|
      module_eval <<-CODE, __FILE__, __LINE__ + 1
        def #{method}(*)
          @symbols = nil
          super
        end
      CODE
    end
  end

  SET              = Mimes.new
  EXTENSION_LOOKUP = {}
  LOOKUP           = Hash.new { |h, k| h[k] = Type.new(k) unless k.blank? }

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

  # Encapsulates the notion of a mime type. Can be used at render time, for example, with:
  #
  #   class PostsController < ActionController::Base
  #     def show
  #       @post = Post.find(params[:id])
  #
  #       respond_to do |format|
  #         format.html
  #         format.ics { render text: post.to_ics, mime_type: Mime::Type["text/calendar"]  }
  #         format.xml { render xml: @people }
  #       end
  #     end
  #   end
  class Type
    @@html_types = Set.new [:html, :all]
    cattr_reader :html_types

    attr_reader :symbol

    @register_callbacks = []

    # A simple helper class used in parsing the accept header
    class AcceptItem #:nodoc:
      attr_accessor :type, :subtype, :parameters, :index

      def initialize(type, subtype, parameters, index)
        @type, @subtype = type, subtype
        @parameters = parameters
        parameters['q'] == 0.001 if type == '*' and subtype == '*' # This is for historical reasons, its necessity should be re-evaluated
        @index = index
      end

      def name
        type + '/' + subtype
      end
      alias_method :to_s, :name

      def <=>(item)
        result = type_wildcard <=> item.type_wildcard
        result = subtype_wildcard <=> item.subtype_wildcard if result == 0
        result = item.parameters['q'] <=> parameters['q'] if result == 0
        result = item.xml_extension <=> xml_extension if result == 0
        result = index <=> item.index if result == 0
        result
      end

      # We don't include parameters here yet, the rest of the stack isn't ready for that
      def ==(item)
        name == item.to_s
      end

      def type_wildcard
        @type == '*' ? 1 : -1
      end

      def subtype_wildcard
        @subtype == '*' ? 1 : -1
      end

      def xml_extension
        @subtype.include?('+xml') ? 1 : -1
      end
    end

    class << self
      ACCEPT_HEADER_REGEXP = /(\S+="(?:\\"|.)*?"[^\s,]*|\S+=[^\s,]+|[^\s;,]+[^,]*)/
      ACCEPT_PARAMETER_REGEXP = /([^\s;=,]+)=("(?:\\"|.)*?"|[^;]+)/

      def register_callback(&block)
        @register_callbacks << block
      end

      def lookup(string)
        LOOKUP[string]
      end

      def lookup_by_extension(extension)
        EXTENSION_LOOKUP[extension.to_s]
      end

      # Registers an alias that's not used on mime type lookup, but can be referenced directly. Especially useful for
      # rendering different HTML versions depending on the user agent, like an iPhone.
      def register_alias(string, symbol, extension_synonyms = [])
        register(string, symbol, [], extension_synonyms, true)
      end

      def register(string, symbol, mime_type_synonyms = [], extension_synonyms = [], skip_lookup = false)
        Mime.const_set(symbol.upcase, Type.new(string, symbol, mime_type_synonyms))

        new_mime = Mime.const_get(symbol.upcase)
        SET << new_mime

        ([string] + mime_type_synonyms).each { |str| LOOKUP[str] = SET.last } unless skip_lookup
        ([symbol] + extension_synonyms).each { |ext| EXTENSION_LOOKUP[ext.to_s] = SET.last }

        @register_callbacks.each do |callback|
          callback.call(new_mime)
        end
      end

      def parse(accept_header)
        # Only use the complex regexp if the header contains quoted tokens
        accepts = if accept_header.include?('"')
          accept_header.scan(ACCEPT_HEADER_REGEXP).map(&:first)
        else
          accept_header.split(/,\s*/)
        end

        accepts = accepts.map { |accept|
          # Set default quality
          params = {'q' => 1.0}

          # Split into type and following parameters
          name, accept_params = accept.split(';', 2)

          next if name.blank?

          # Correct a standard wildcard truncation
          name = '*/*' if name == '*' or name == '*.*'

          if accept_params
            # Only use a complex regexp if the parameters contain quoted tokens
            accept_params = if accept_params.include?('"')
              accept_params.scan(ACCEPT_PARAMETER_REGEXP)
            else
              accept_params.split(';').map { |a| a.split('=') }
            end

            accept_params.each { |(key, val)|
              next if val.nil?
              key.strip!
              val = if key == 'q'
                val.to_f
              elsif val[0] == '"' and val[-1] == '"'
                val[1..-2].gsub(/\\(.)/, "\\1")
              else
                val
              end
              params[key] = val
            }
          end
          type, subtype = name.split('/')
          [type, subtype, params]
        }.reject { |type, subtype, parameters|
          type.blank? || subtype.blank?
        }.each_with_index.map { |(type, subtype, parameters), index|
          AcceptItem.new(type, subtype, parameters, index)
        }.sort.map { |item|
          if item.type_wildcard != 1 && item.subtype_wildcard == 1
            Mime::SET.select { |m| m =~ item.type }
          else
            Mime::Type.lookup(item.name)
          end
        }.flatten.uniq
        accepts.empty? ? [Mime::HTML] : accepts
      end


      # This method is opposite of register method.
      #
      # Usage:
      #
      #   Mime::Type.unregister(:mobile)
      def unregister(symbol)
        symbol = symbol.upcase
        mime = Mime.const_get(symbol)
        Mime.instance_eval { remove_const(symbol) }

        SET.delete_if { |v| v.eql?(mime) }
        LOOKUP.delete_if { |_,v| v.eql?(mime) }
        EXTENSION_LOOKUP.delete_if { |_,v| v.eql?(mime) }
      end
    end

    def initialize(string, symbol = nil, synonyms = [])
      @symbol, @synonyms = symbol, synonyms
      @string = string
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
      to_sym || to_s
    end

    def ===(list)
      if list.is_a?(Array)
        (@synonyms + [ self ]).any? { |synonym| list.include?(synonym) }
      else
        super
      end
    end

    def ==(mime_type)
      return false if mime_type.blank?
      (@synonyms + [ self ]).any? do |synonym|
        synonym.to_s == mime_type.to_s || synonym.to_sym == mime_type.to_sym
      end
    end

    def =~(mime_type)
      return false if mime_type.blank?
      regexp = Regexp.new(Regexp.quote(mime_type.to_s))
      (@synonyms + [ self ]).any? do |synonym|
        synonym.to_s =~ regexp
      end
    end

    def html?
      @@html_types.include?(to_sym) || @string =~ /html/
    end


    private

    def to_ary; end
    def to_a; end

    def method_missing(method, *args)
      if method.to_s.ends_with? '?'
        method[0..-2].downcase.to_sym == to_sym
      else
        super
      end
    end

    def respond_to_missing?(method, include_private = false) #:nodoc:
      method.to_s.ends_with? '?'
    end
  end

  class NullType
    include Singleton

    def nil?
      true
    end

    def ref; end

    def respond_to_missing?(method, include_private = false)
      method.to_s.ends_with? '?'
    end

    private
    def method_missing(method, *args)
      false if method.to_s.ends_with? '?'
    end
  end
end

require 'action_dispatch/http/mime_types'
