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
        node.remove_attribute(name) if should_remove_attributes?(name)
      end
    else
      Loofah::HTML5::Scrub.scrub_attributes(node)
    end
  end

  def should_skip_node?(node)
    text_or_cdata_node?(node)
  end

  def should_remove_attributes?(name)
    @attributes.exclude?(name)
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

# TargetScrubber - The bizarro PermitScrubber
#
# With PermitScrubber you choose elements you don't want removed,
# with TargetScrubber you choose want you want gone.
#
# +tags=+ and +attributes=+ has the same behavior as PermitScrubber
# except they select what to get rid of.
class TargetScrubber < PermitScrubber
  def allowed_node?(node)
    return super unless @tags
    @tags.exclude?(node.name)
  end

  def should_remove_attributes?(name)
    @attributes.include?(name)
  end
end
