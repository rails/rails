# frozen_string_literal: true

require 'test_helper'

class ActionText::PlainTextConversionTest < ActiveSupport::TestCase
  test '<p> tags are separated by two new lines' do
    assert_converted_to(
      "Hello world!\n\nHow are you?",
      '<p>Hello world!</p><p>How are you?</p>'
    )
  end

  test '<blockquote> tags are separated by two new lines' do
    assert_converted_to(
      "“Hello world!”\n\n“How are you?”",
      '<blockquote>Hello world!</blockquote><blockquote>How are you?</blockquote>'
    )
  end

  test '<ol> tags are separated by two new lines' do
    assert_converted_to(
      "Hello world!\n\n1. list1\n\n1. list2\n\nHow are you?",
      '<p>Hello world!</p><ol><li>list1</li></ol><ol><li>list2</li></ol><p>How are you?</p>'
    )
  end

  test '<ul> tags are separated by two new lines' do
    assert_converted_to(
      "Hello world!\n\n• list1\n\n• list2\n\nHow are you?",
      '<p>Hello world!</p><ul><li>list1</li></ul><ul><li>list2</li></ul><p>How are you?</p>'
    )
  end

  test '<h1> tags are separated by two new lines' do
    assert_converted_to(
      "Hello world!\n\nHow are you?",
      '<h1>Hello world!</h1><div>How are you?</div>'
    )
  end

  test '<li> tags are separated by one new line' do
    assert_converted_to(
      "• one\n• two\n• three",
      '<ul><li>one</li><li>two</li><li>three</li></ul>'
    )
  end

  test '<li> tags without a parent list' do
    assert_converted_to(
      "• one\n• two\n• three",
      '<li>one</li><li>two</li><li>three</li>'
    )
  end

  test '<br> tags are separated by one new line' do
    assert_converted_to(
      "Hello world!\none\ntwo\nthree",
      '<p>Hello world!<br>one<br>two<br>three</p>'
    )
  end

  test '<div> tags are separated by one new line' do
    assert_converted_to(
      "Hello world!\nHow are you?",
      '<div>Hello world!</div><div>How are you?</div>'
    )
  end

  test '<figcaption> tags are converted to their plain-text representation' do
    assert_converted_to(
      'Hello world! [A condor in the mountain]',
      'Hello world! <figcaption>A condor in the mountain</figcaption>'
    )
  end

  test '<action-text-attachment> tags are converted to their plain-text representation' do
    assert_converted_to(
      'Hello world! [Cat]',
      'Hello world! <action-text-attachment url="http://example.com/cat.jpg" content-type="image" caption="Cat"></action-text-attachment>'
    )
  end

  test 'deeply nested tags are converted' do
    assert_converted_to(
      "Hello world!\nHow are you?",
      ActionText::Fragment.wrap('<div>Hello world!</div><div></div>').tap do |fragment|
        node = fragment.source.children.last
        1_000.times do
          child = node.clone
          child.parent = node
          node = child
        end
        node.inner_html = 'How are you?'
      end
    )
  end

  test 'preserves non-linebreak whitespace after text' do
    assert_converted_to(
      'Hello world!',
      '<div><strong>Hello </strong>world!</div>'
    )
  end

  test 'preserves trailing linebreaks after text' do
    assert_converted_to(
      "Hello\nHow are you?",
      '<strong>Hello<br></strong>How are you?'
    )
  end

  private
    def assert_converted_to(plain_text, html)
      assert_equal plain_text, ActionText::Content.new(html).to_plain_text
    end
end
