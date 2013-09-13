require 'loofah'
require 'abstract_unit'

class PermitScrubberTest < ActionView::TestCase

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

  protected
    def assert_scrubbed(html, expected = html)
      output = Loofah.scrub_fragment(html, @scrubber).to_s
      assert_equal expected, output
    end

    def assert_node_skipped(text)
      node = Loofah.fragment(text).children.first
      assert_equal Loofah::Scrubber::CONTINUE, @scrubber.scrub(node)
    end
end