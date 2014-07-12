require 'set'
require 'cgi'
require 'active_support/core_ext/module/attribute_accessors'

module HTML
  class Sanitizer
    def sanitize(text, options = {})
      validate_options(options)
      return text unless sanitizeable?(text)
      tokenize(text, options).join
    end

    def sanitizeable?(text)
      !(text.nil? || text.empty? || !text.index("<"))
    end

  protected
    def tokenize(text, options)
      tokenizer = HTML::Tokenizer.new(text)
      result = []
      while token = tokenizer.next
        node = Node.parse(nil, 0, 0, token, false)
        process_node node, result, options
      end
      result
    end

    def process_node(node, result, options)
      result << node.to_s
    end

    def validate_options(options)
      if options[:tags] && !options[:tags].is_a?(Enumerable)
        raise ArgumentError, "You should pass :tags as an Enumerable"
      end

      if options[:attributes] && !options[:attributes].is_a?(Enumerable)
        raise ArgumentError, "You should pass :attributes as an Enumerable"
      end
    end
  end

  class FullSanitizer < Sanitizer
    def sanitize(text, options = {})
      result = super
      # strip any comments, and if they have a newline at the end (ie. line with
      # only a comment) strip that too
      result = result.gsub(/<!--(.*?)-->[\n]?/m, "") if (result && result =~ /<!--(.*?)-->[\n]?/m)
      # Recurse - handle all dirty nested tags
      result == text ? result : sanitize(result, options)
    end

    def process_node(node, result, options)
      result << node.to_s if node.class == HTML::Text
    end
  end

  class LinkSanitizer < FullSanitizer
    cattr_accessor :included_tags, :instance_writer => false
    self.included_tags = Set.new(%w(a href))

    def sanitizeable?(text)
      !(text.nil? || text.empty? || !((text.index("<a") || text.index("<href")) && text.index(">")))
    end

  protected
    def process_node(node, result, options)
      result << node.to_s unless node.is_a?(HTML::Tag) && included_tags.include?(node.name)
    end
  end

  class WhiteListSanitizer < Sanitizer
    [:protocol_separator, :uri_attributes, :allowed_attributes, :allowed_tags, :allowed_protocols, :bad_tags,
     :allowed_css_properties, :allowed_css_keywords, :shorthand_css_properties].each do |attr|
      class_attribute attr, :instance_writer => false
    end

    # A regular expression of the valid characters used to separate protocols like
    # the ':' in 'http://foo.com'
    self.protocol_separator     = /:|(&#0*58)|(&#x70)|(&#x0*3a)|(%|&#37;)3A/i

    # Specifies a Set of HTML attributes that can have URIs.
    self.uri_attributes         = Set.new(%w(href src cite action longdesc xlink:href lowsrc))

    # Specifies a Set of 'bad' tags that the #sanitize helper will remove completely, as opposed
    # to just escaping harmless tags like &lt;font&gt;
    self.bad_tags               = Set.new(%w(script))

    # Specifies the default Set of tags that the #sanitize helper will allow unscathed.
    self.allowed_tags           = Set.new(%w(strong em b i p code pre tt samp kbd var sub
      sup dfn cite big small address hr br div span h1 h2 h3 h4 h5 h6 ul ol li dl dt dd abbr
      acronym a img blockquote del ins))

    # Specifies the default Set of html attributes that the #sanitize helper will leave
    # in the allowed tag.
    self.allowed_attributes     = Set.new(%w(href src width height alt cite datetime title class name xml:lang abbr))

    # Specifies the default Set of acceptable css properties that #sanitize and #sanitize_css will accept.
    self.allowed_protocols      = Set.new(%w(ed2k ftp http https irc mailto news gopher nntp telnet webcal xmpp callto
      feed svn urn aim rsync tag ssh sftp rtsp afs))

    # Specifies the default Set of acceptable css properties that #sanitize and #sanitize_css will accept.
    self.allowed_css_properties = Set.new(%w(azimuth background-color border-bottom-color border-collapse
      border-color border-left-color border-right-color border-top-color clear color cursor direction display
      elevation float font font-family font-size font-style font-variant font-weight height letter-spacing line-height
      overflow pause pause-after pause-before pitch pitch-range richness speak speak-header speak-numeral speak-punctuation
      speech-rate stress text-align text-decoration text-indent unicode-bidi vertical-align voice-family volume white-space
      width))

    # Specifies the default Set of acceptable css keywords that #sanitize and #sanitize_css will accept.
    self.allowed_css_keywords   = Set.new(%w(auto aqua black block blue bold both bottom brown center
      collapse dashed dotted fuchsia gray green !important italic left lime maroon medium none navy normal
      nowrap olive pointer purple red right solid silver teal top transparent underline white yellow))

    # Specifies the default Set of allowed shorthand css properties for the #sanitize and #sanitize_css helpers.
    self.shorthand_css_properties = Set.new(%w(background border margin padding))

    # Sanitizes a block of css code. Used by #sanitize when it comes across a style attribute
    def sanitize_css(style)
      # disallow urls
      style = style.to_s.gsub(/url\s*\(\s*[^\s)]+?\s*\)\s*/, ' ')

      # gauntlet
      if style !~ /\A([:,;#%.\sa-zA-Z0-9!]|\w-\w|\'[\s\w]+\'|\"[\s\w]+\"|\([\d,\s]+\))*\z/ ||
          style !~ /\A(\s*[-\w]+\s*:\s*[^:;]*(;|$)\s*)*\z/
        return ''
      end

      clean = []
      style.scan(/([-\w]+)\s*:\s*([^:;]*)/) do |prop,val|
        if allowed_css_properties.include?(prop.downcase)
          clean <<  prop + ': ' + val + ';'
        elsif shorthand_css_properties.include?(prop.split('-')[0].downcase)
          unless val.split().any? do |keyword|
            !allowed_css_keywords.include?(keyword) &&
              keyword !~ /\A(#[0-9a-f]+|rgb\(\d+%?,\d*%?,?\d*%?\)?|\d{0,2}\.?\d{0,2}(cm|em|ex|in|mm|pc|pt|px|%|,|\))?)\z/
          end
            clean << prop + ': ' + val + ';'
          end
        end
      end
      clean.join(' ')
    end

  protected
    def tokenize(text, options)
      options[:parent] = []
      options[:attributes] ||= allowed_attributes
      options[:tags]       ||= allowed_tags
      super
    end

    def process_node(node, result, options)
      result << case node
        when HTML::Tag
          if node.closing == :close
            options[:parent].shift
          else
            options[:parent].unshift node.name
          end

          process_attributes_for node, options

          options[:tags].include?(node.name) ? node : nil
        else
          bad_tags.include?(options[:parent].first) ? nil : node.to_s.gsub(/</, "&lt;")
      end
    end

    def process_attributes_for(node, options)
      return unless node.attributes
      node.attributes.keys.each do |attr_name|
        value = node.attributes[attr_name].to_s

        if !options[:attributes].include?(attr_name) || contains_bad_protocols?(attr_name, value)
          node.attributes.delete(attr_name)
        else
          node.attributes[attr_name] = attr_name == 'style' ? sanitize_css(value) : CGI::escapeHTML(CGI::unescapeHTML(value))
        end
      end
    end

    def contains_bad_protocols?(attr_name, value)
      uri_attributes.include?(attr_name) &&
      (value =~ /(^[^\/:]*):|(&#0*58)|(&#x70)|(&#x0*3a)|(%|&#37;)3A/i && !allowed_protocols.include?(value.split(protocol_separator).first.downcase.strip))
    end
  end
end
