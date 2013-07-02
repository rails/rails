require 'active_support/core_ext/class/attribute'
require 'active_support/deprecation'
require 'loofah'

module ActionView

  class FullSanitizer
    def sanitize(html, options = {})
      Loofah.fragment(html).text
    end
  end

  class LinkSanitizer
    def initialize
      @link_scrubber = Loofah::Scrubber.new do |node|
        next unless node.name == 'a'
        node.before node.children
        node.remove
      end
    end

    def sanitize(html, options = {})
      Loofah.scrub_fragment(html, @link_scrubber).to_s
    end
  end

  class WhiteListSanitizer
    def sanitize(html, options = {})
      return nil unless html
      validate_options(options)

      loofah_fragment = Loofah.fragment(html)
      loofah_fragment.scrub!(:strip)
      loofah_fragment.xpath("./form").each { |form| form.remove }
      loofah_fragment.to_s
    end

    def sanitize_css(style_string)
      Loofah::HTML5::Scrub.scrub_css style_string
    end

    def protocol_separator
      self.class.protocol_separator
    end

    def protocol_separator=(value)
      self.class.protocol_separator
    end

    def bad_tags
      self.class.bad_tags
    end

    class << self
      def protocol_separator
        ActiveSupport::Deprecation.warn('protocol_separator has been deprecated and has no effect.')
      end

      def protocol_separator=(value)
        self.class.protocol_separator
      end

      def bad_tags
        ActiveSupport::Deprecation.warn('bad_tags has been deprecated and has no effect. You can still affect the tags being sanitized using ActionView::WhiteListSanitizer.bad_tags= which changes the allowed_tags.')
      end

      def bad_tags=(tags)
        allowed_tags.replace(allowed_tags - tags)
      end
    end

    [:uri_attributes, :allowed_attributes,
    :allowed_tags, :allowed_protocols, :allowed_css_properties,
    :allowed_css_keywords, :shorthand_css_properties].each do |attr|
      class_attribute attr, :instance_writer => false

      define_method "#{self}.update_#{attr}" do |arg|
        attr.merge arg
      end
    end

    # Constants are from Loofahs source at lib/loofah/html5/whitelist.rb
    self.uri_attributes = Loofah::HTML5::WhiteList::ATTR_VAL_IS_URI

    self.allowed_tags = Loofah::HTML5::WhiteList::ALLOWED_ELEMENTS

    self.bad_tags = Set.new %w(script)

    self.allowed_attributes = Loofah::HTML5::WhiteList::ALLOWED_ATTRIBUTES

    self.allowed_css_properties = Loofah::HTML5::WhiteList::ALLOWED_CSS_PROPERTIES

    self.allowed_css_keywords = Loofah::HTML5::WhiteList::ALLOWED_CSS_KEYWORDS

    self.shorthand_css_properties = Loofah::HTML5::WhiteList::SHORTHAND_CSS_PROPERTIES

    self.allowed_protocols = Loofah::HTML5::WhiteList::ALLOWED_PROTOCOLS

    protected
      def validate_options(options)
        if options[:tags] && !options[:tags].is_a?(Enumerable)
          raise ArgumentError, "You should pass :tags as an Enumerable"
        end

        if options[:attributes] && !options[:attributes].is_a?(Enumerable)
          raise ArgumentError, "You should pass :attributes as an Enumerable"
        end
      end

      def contains_bad_protocols?(attr_name, value)
        protocol_separator = ':'
        self.uri_attributes.include?(attr_name) &&
        (value =~ /(^[^\/:]*):|(&#0*58)|(&#x70)|(&#x0*3a)|(%|&#37;)3A/i && !self.allowed_protocols.include?(value.split(protocol_separator).first.downcase.strip))
      end
  end
end
