require 'active_support/core_ext/class/attribute'
require 'active_support/deprecation'
require 'action_view/helpers/sanitize_helper/permit_scrubber'
require 'loofah'

module ActionView
  class Sanitizer
    def sanitize(html, options = {})
      raise NotImplementedError, "subclasses must implement"
    end

    def remove_xpaths(html, xpaths)
      html = Loofah.fragment(html) unless html.is_a? Nokogiri::XML::DocumentFragment
      xpaths.each do |xpath|
        html.xpath(xpath).each { |subtree| subtree.remove }
      end
      html.to_s
    end
  end

  class FullSanitizer < Sanitizer
    def sanitize(html, options = {})
      return nil unless html
      return html if html.empty?

      fragment = Loofah.fragment(html)
      remove_xpaths(fragment, %w{./script ./form ./comment()})
      fragment.text
    end
  end

  class LinkSanitizer < Sanitizer
    def initialize
      @strip_tags = %w(a href)
      @link_scrubber = Loofah::Scrubber.new do |node|
        if @strip_tags.include?(node.name)
          node.before node.children
          node.remove
        else
          Loofah::HTML5::Scrub.scrub_attributes(node)
        end
      end
    end

    def sanitize(html, options = {})
      Loofah.scrub_fragment(html, @link_scrubber).to_s
    end
  end

  class WhiteListSanitizer < Sanitizer

    def initialize
      @permit_scrubber = PermitScrubber.new
    end

    def sanitize(html, options = {})
      return nil unless html

      loofah_fragment = Loofah.fragment(html)
      if options[:tags] || options[:attributes]
        @permit_scrubber.tags = options[:tags]
        @permit_scrubber.attributes = options[:attributes]
        loofah_fragment.scrub!(@permit_scrubber)
      else
        remove_xpaths(loofah_fragment, %w{./script ./form ./comment()})
        loofah_fragment.scrub!(:strip)
      end
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

    self.bad_tags = Set.new %w(script form)

    self.allowed_attributes = Loofah::HTML5::WhiteList::ALLOWED_ATTRIBUTES

    self.allowed_css_properties = Loofah::HTML5::WhiteList::ALLOWED_CSS_PROPERTIES

    self.allowed_css_keywords = Loofah::HTML5::WhiteList::ALLOWED_CSS_KEYWORDS

    self.shorthand_css_properties = Loofah::HTML5::WhiteList::SHORTHAND_CSS_PROPERTIES

    self.allowed_protocols = Loofah::HTML5::WhiteList::ALLOWED_PROTOCOLS
  end
end
