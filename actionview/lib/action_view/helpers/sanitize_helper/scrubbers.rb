# === PermitScrubber
#
# PermitScrubber allows you to permit only your own tags and/or attributes.
#
# Supplied tags and attributes should be Enumerables
#
# +tags=+
# If this value is set all other elements will be stripped (their inner elements will be kept).
# If not set elements for which HTML5::Scrub.allowed_element? is false will be stripped.
#
# +attributes=+
# Contain an elements allowed attributes.
# If none is set HTML5::Scrub.scrub_attributes implementation will be used.
#
# Subclass PermitScrubber to provide your own definition of
# when a node is allowed and how attributes should be scrubbed.
class PermitScrubber < Loofah::Scrubber
  # :nodoc:
  attr_reader :tags, :attributes

  def tags=(tags)
    @tags = validate!(tags, :tags)
  end

  def attributes=(attributes)
    @attributes = validate!(attributes, :attributes)
  end

  def scrub(node)
    return CONTINUE if should_skip_node?(node)

    unless allowed_node?(node)
      node.before node.children # strip
      node.remove
      return STOP
    end

    scrub_attributes(node)
  end

  protected

  def allowed_node?(node)
    if @tags
      @tags.include?(node.name)
    else
      Loofah::HTML5::Scrub.allowed_element?(node.name)
    end
  end

  def scrub_attributes(node)
    if @attributes
      node.attributes.each do |name, _|
        node.remove_attribute(name) unless @attributes.include?(name)
      end
    else
      Loofah::HTML5::Scrub.scrub_attributes(node)
    end
  end

  def should_skip_node?(node)
    text_or_cdata_node?(node)
  end

  def text_or_cdata_node?(node)
    case node.type
    when Nokogiri::XML::Node::TEXT_NODE, Nokogiri::XML::Node::CDATA_SECTION_NODE
      return true
    end
    false
  end

  def validate!(var, name)
    if var && !var.is_a?(Enumerable)
      raise ArgumentError, "You should pass :#{name} as an Enumerable"
    end
    var
  end
end

# LinkScrubber overrides PermitScrubbers +allowed_node?+ to any nodes
# which names aren't a or href
class LinkScrubber < PermitScrubber
  def initialize
    @strip_tags = %w(a href)
  end

  def allowed_node?(node)
    !@strip_tags.include?(node.name)
  end
end
