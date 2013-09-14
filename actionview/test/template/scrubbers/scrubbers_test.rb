require 'loofah'
require 'abstract_unit'

class ScrubberTest < ActionView::TestCase
  protected

    def assert_scrubbed(html, expected = html)
      output = Loofah.scrub_fragment(html, @scrubber).to_s
      assert_equal expected, output
    end

    def assert_node_skipped(text)
      node = to_node(text)
      assert_equal Loofah::Scrubber::CONTINUE, @scrubber.scrub(node)
    end

    def to_node(text)
      Loofah.fragment(text).children.first
    end

    def scrub_expectations(text, &expectations)
      @scrubber.instance_eval(&expectations)
      @scrubber.scrub to_node(text)
    end
end

class PermitScrubberTest < ScrubberTest

  def setup
    @scrubber = PermitScrubber.new
  end

  def test_responds_to_scrub
    assert @scrubber.respond_to?(:scrub)
  end

  def test_default_scrub_behavior
    assert_scrubbed '<tag>hello</tag>', 'hello'
  end

  def test_default_attributes_removal_behavior
    assert_scrubbed '<p cooler="hello">hello</p>', '<p>hello</p>'
  end

  def test_leaves_supplied_tags
    @scrubber.tags = %w(a)
    assert_scrubbed '<a>hello</a>'
  end

  def test_leaves_only_supplied_tags
    html = '<tag>leave me <span>now</span></tag>'
    @scrubber.tags = %w(tag)
    assert_scrubbed html, '<tag>leave me now</tag>'
  end

  def test_leaves_only_supplied_tags_nested
    html = '<tag>leave <em>me <span>now</span></em></tag>'
    @scrubber.tags = %w(tag)
    assert_scrubbed html, '<tag>leave me now</tag>'
  end

  def test_leaves_supplied_attributes
    @scrubber.attributes = %w(cooler)
    assert_scrubbed '<a cooler="hello"></a>'
  end

  def test_leaves_only_supplied_attributes
    @scrubber.attributes = %w(cooler)
    assert_scrubbed '<a cooler="hello" b="c" d="e"></a>', '<a cooler="hello"></a>'
  end

  def test_leaves_supplied_tags_and_attributes
    @scrubber.tags = %w(tag)
    @scrubber.attributes = %w(cooler)
    assert_scrubbed '<tag cooler="hello"></tag>'
  end

  def test_leaves_only_supplied_tags_and_attributes
    @scrubber.tags = %w(tag)
    @scrubber.attributes = %w(cooler)
    html = '<a></a><tag href=""></tag><tag cooler=""></tag>'
    assert_scrubbed html, '<tag></tag><tag cooler=""></tag>'
  end

  def test_leaves_text
    assert_scrubbed('some text')
  end

  def test_skips_text_nodes
    assert_node_skipped 'some text'
  end

  def test_tags_accessor_validation
    e = assert_raise(ArgumentError) do
      @scrubber.tags = 'tag'
    end

    assert_equal "You should pass :tags as an Enumerable", e.message
    assert_nil @scrubber.tags, "Tags should be nil when validation fails"
  end

  def test_attributes_accessor_validation
    e = assert_raise(ArgumentError) do
      @scrubber.attributes = 'cooler'
    end

    assert_equal "You should pass :attributes as an Enumerable", e.message
    assert_nil @scrubber.attributes, "Attributes should be nil when validation fails"
  end

  def test_scrub_uses_public_api
    @scrubber.tags = %w(tag)
    @scrubber.attributes = %w(cooler)

    scrub_expectations '<p id="hello">some text</p>' do
      expects(skip_node?: false)
      expects(allowed_node?: false)

      expects(:scrub_node)

      expects(scrub_attribute?: false)
    end
  end

  def test_keep_node_returns_false_node_will_be_stripped
    scrub_expectations '<p>normally p tags are kept<p>' do
      stubs(keep_node?: false)
      expects(:scrub_node)
    end
  end

  def test_skip_node_returns_false_node_will_be_stripped
    scrub_expectations 'normally text nodes are skipped' do
      stubs(skip_node?: false)
      expects(keep_node?: true)
    end
  end

  def test_stripping_of_normally_skipped_and_kept_node
    scrub_expectations 'text is skipped by default' do
      stubs(skip_node?: false, keep_node?: false)
      expects(:scrub_node)
      expects(:scrub_attributes) # expected since scrub_node doesn't return STOP
    end
  end

  def test_attributes_are_scrubbed_for_kept_node
    scrub_expectations 'text is kept, but normally skipped' do
      stubs(skip_node?: false)
      expects(:scrub_attributes)
    end
  end

  def test_scrubbing_of_empty_node
    scrubbing = scrub_expectations '' do
      expects(skip_node?: true)
    end

    assert_equal Loofah::Scrubber::CONTINUE, scrubbing
  end

  def test_scrub_returns_stop_if_scrub_node_does
    scrubbing = scrub_expectations '<script>free me</script>' do
      stubs(scrub_node: Loofah::Scrubber::STOP)
      expects(:scrub_attributes).never
    end

    assert_equal Loofah::Scrubber::STOP, scrubbing
  end
end

class TargetScrubberTest < ScrubberTest
  def setup
    @scrubber = TargetScrubber.new
  end

  def test_targeting_tags_removes_only_them
    @scrubber.tags = %w(a h1)
    html = '<script></script><a></a><h1></h1>'
    assert_scrubbed html, '<script></script>'
  end

  def test_targeting_tags_removes_only_them_nested
    @scrubber.tags = %w(a)
    html = '<tag><a><tag><a></a></tag></a></tag>'
    assert_scrubbed html, '<tag><tag></tag></tag>'
  end

  def test_targeting_attributes_removes_only_them
    @scrubber.attributes = %w(class id)
    html = '<a class="a" id="b" onclick="c"></a>'
    assert_scrubbed html, '<a onclick="c"></a>'
  end

  def test_targeting_tags_and_attributes_removes_only_them
    @scrubber.tags = %w(tag)
    @scrubber.attributes = %w(remove)
    html = '<tag remove="" other=""></tag><a remove="" other=""></a>'
    assert_scrubbed html, '<a other=""></a>'
  end
end