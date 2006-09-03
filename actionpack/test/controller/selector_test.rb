#--
# Copyright (c) 2006 Assaf Arkin (http://labnotes.org)
# Under MIT and/or CC By license.
#++

require File.dirname(__FILE__) + '/../abstract_unit'
require File.dirname(__FILE__) + '/fake_controllers'

class SelectorTest < Test::Unit::TestCase
  #
  # Basic selector: element, id, class, attributes.
  #

  def test_element
    parse(%Q{<div id="1"></div><p></p><div id="2"></div>})
    # Match element by name.
    select("div")
    assert_equal 2, @matches.size
    assert_equal "1", @matches[0].attributes["id"]
    assert_equal "2", @matches[1].attributes["id"]
    # Not case sensitive.
    select("DIV")
    assert_equal 2, @matches.size
    assert_equal "1", @matches[0].attributes["id"]
    assert_equal "2", @matches[1].attributes["id"]
    # Universal match (all elements).
    select("*")
    assert_equal 3, @matches.size
    assert_equal "1", @matches[0].attributes["id"]
    assert_equal nil, @matches[1].attributes["id"]
    assert_equal "2", @matches[2].attributes["id"]
  end


  def test_identifier
    parse(%Q{<div id="1"></div><p></p><div id="2"></div>})
    # Match element by ID.
    select("div#1")
    assert_equal 1, @matches.size
    assert_equal "1", @matches[0].attributes["id"]
    # Match element by ID, substitute value.
    select("div#?", 2)
    assert_equal 1, @matches.size
    assert_equal "2", @matches[0].attributes["id"]
    # Element name does not match ID.
    select("p#?", 2)
    assert_equal 0, @matches.size
    # Use regular expression.
    select("#?", /\d/)
    assert_equal 2, @matches.size
  end


  def test_class_name
    parse(%Q{<div id="1" class=" foo "></div><p id="2" class=" foo bar "></p><div id="3" class="bar"></div>})
    # Match element with specified class.
    select("div.foo")
    assert_equal 1, @matches.size
    assert_equal "1", @matches[0].attributes["id"]
    # Match any element with specified class.
    select("*.foo")
    assert_equal 2, @matches.size
    assert_equal "1", @matches[0].attributes["id"]
    assert_equal "2", @matches[1].attributes["id"]
    # Match elements with other class.
    select("*.bar")
    assert_equal 2, @matches.size
    assert_equal "2", @matches[0].attributes["id"]
    assert_equal "3", @matches[1].attributes["id"]
    # Match only element with both class names.
    select("*.bar.foo")
    assert_equal 1, @matches.size
    assert_equal "2", @matches[0].attributes["id"]
  end


  def test_attribute
    parse(%Q{<div id="1"></div><p id="2" title="" bar="foo"></p><div id="3" title="foo"></div>})
    # Match element with attribute.
    select("div[title]")
    assert_equal 1, @matches.size
    assert_equal "3", @matches[0].attributes["id"]
    # Match any element with attribute.
    select("*[title]")
    assert_equal 2, @matches.size
    assert_equal "2", @matches[0].attributes["id"]
    assert_equal "3", @matches[1].attributes["id"]
    # Match alement with attribute value.
    select("*[title=foo]")
    assert_equal 1, @matches.size
    assert_equal "3", @matches[0].attributes["id"]
    # Match alement with attribute and attribute value.
    select("[bar=foo][title]")
    assert_equal 1, @matches.size
    assert_equal "2", @matches[0].attributes["id"]
    # Not case sensitive.
    select("[BAR=foo][TiTle]")
    assert_equal 1, @matches.size
    assert_equal "2", @matches[0].attributes["id"]
  end


  def test_attribute_quoted
    parse(%Q{<div id="1" title="foo"></div><div id="2" title="bar"></div><div id="3" title="  bar  "></div>})
    # Match without quotes.
    select("[title = bar]")
    assert_equal 1, @matches.size
    assert_equal "2", @matches[0].attributes["id"]
    # Match with single quotes.
    select("[title = 'bar' ]")
    assert_equal 1, @matches.size
    assert_equal "2", @matches[0].attributes["id"]
    # Match with double quotes.
    select("[title = \"bar\" ]")
    assert_equal 1, @matches.size
    assert_equal "2", @matches[0].attributes["id"]
    # Match with spaces.
    select("[title = \"  bar  \" ]")
    assert_equal 1, @matches.size
    assert_equal "3", @matches[0].attributes["id"]
  end


  def test_attribute_equality
    parse(%Q{<div id="1" title="foo bar"></div><div id="2" title="barbaz"></div>})
    # Match (fail) complete value.
    select("[title=bar]")
    assert_equal 0, @matches.size
    # Match space-separate word.
    select("[title~=foo]")
    assert_equal 1, @matches.size
    assert_equal "1", @matches[0].attributes["id"]
    select("[title~=bar]")
    assert_equal 1, @matches.size
    assert_equal "1", @matches[0].attributes["id"]
    # Match beginning of value.
    select("[title^=ba]")
    assert_equal 1, @matches.size
    assert_equal "2", @matches[0].attributes["id"]
    # Match end of value.
    select("[title$=ar]")
    assert_equal 1, @matches.size
    assert_equal "1", @matches[0].attributes["id"]
    # Match text in value.
    select("[title*=bar]")
    assert_equal 2, @matches.size
    assert_equal "1", @matches[0].attributes["id"]
    assert_equal "2", @matches[1].attributes["id"]
    # Match first space separated word.
    select("[title|=foo]")
    assert_equal 1, @matches.size
    assert_equal "1", @matches[0].attributes["id"]
    select("[title|=bar]")
    assert_equal 0, @matches.size
  end


  #
  # Selector composition: groups, sibling, children
  #


  def test_selector_group
    parse(%Q{<h1 id="1"></h1><h2 id="2"></h2><h3 id="3"></h3>})
    # Simple group selector.
    select("h1,h3")
    assert_equal 2, @matches.size
    assert_equal "1", @matches[0].attributes["id"]
    assert_equal "3", @matches[1].attributes["id"]
    select("h1 , h3")
    assert_equal 2, @matches.size
    assert_equal "1", @matches[0].attributes["id"]
    assert_equal "3", @matches[1].attributes["id"]
    # Complex group selector.
    parse(%Q{<h1 id="1"><a href="foo"></a></h1><h2 id="2"><a href="bar"></a></h2><h3 id="2"><a href="baz"></a></h3>})
    select("h1 a, h3 a")
    assert_equal 2, @matches.size
    assert_equal "foo", @matches[0].attributes["href"]
    assert_equal "baz", @matches[1].attributes["href"]
    # And now for the three selector challange.
    parse(%Q{<h1 id="1"><a href="foo"></a></h1><h2 id="2"><a href="bar"></a></h2><h3 id="2"><a href="baz"></a></h3>})
    select("h1 a, h2 a, h3 a")
    assert_equal 3, @matches.size
    assert_equal "foo", @matches[0].attributes["href"]
    assert_equal "bar", @matches[1].attributes["href"]
    assert_equal "baz", @matches[2].attributes["href"]
  end


  def test_sibling_selector
    parse(%Q{<h1 id="1"></h1><h2 id="2"></h2><h3 id="3"></h3>})
    # Test next sibling.
    select("h1+*")
    assert_equal 1, @matches.size
    assert_equal "2", @matches[0].attributes["id"]
    select("h1+h2")
    assert_equal 1, @matches.size
    assert_equal "2", @matches[0].attributes["id"]
    select("h1+h3")
    assert_equal 0, @matches.size
    select("*+h3")
    assert_equal 1, @matches.size
    assert_equal "3", @matches[0].attributes["id"]
    # Test any sibling.
    select("h1~*")
    assert_equal 2, @matches.size
    assert_equal "2", @matches[0].attributes["id"]
    assert_equal "3", @matches[1].attributes["id"]
    select("h2~*")
    assert_equal 1, @matches.size
    assert_equal "3", @matches[0].attributes["id"]
  end


  def test_children_selector
    parse(%Q{<div><p id="1"><span id="2"></span></p></div><div><p id="3"><span id="4" class="foo"></span></p></div>})
    # Test child selector.
    select("div>p")
    assert_equal 2, @matches.size
    assert_equal "1", @matches[0].attributes["id"]
    assert_equal "3", @matches[1].attributes["id"]
    select("div>span")
    assert_equal 0, @matches.size
    select("div>p#3")
    assert_equal 1, @matches.size
    assert_equal "3", @matches[0].attributes["id"]
    select("div>p>span")
    assert_equal 2, @matches.size
    assert_equal "2", @matches[0].attributes["id"]
    assert_equal "4", @matches[1].attributes["id"]
    # Test descendant selector.
    select("div p")
    assert_equal 2, @matches.size
    assert_equal "1", @matches[0].attributes["id"]
    assert_equal "3", @matches[1].attributes["id"]
    select("div span")
    assert_equal 2, @matches.size
    assert_equal "2", @matches[0].attributes["id"]
    assert_equal "4", @matches[1].attributes["id"]
    select("div *#3")
    assert_equal 1, @matches.size
    assert_equal "3", @matches[0].attributes["id"]
    select("div *#4")
    assert_equal 1, @matches.size
    assert_equal "4", @matches[0].attributes["id"]
    # This is here because it failed before when whitespaces
    # were not properly stripped.
    select("div .foo")
    assert_equal 1, @matches.size
    assert_equal "4", @matches[0].attributes["id"]
  end


  #
  # Pseudo selectors: root, nth-child, empty, content, etc
  #


  def test_root_selector
    parse(%Q{<div id="1"><div id="2"></div></div>})
    # Can only find element if it's root.
    select(":root")
    assert_equal 1, @matches.size
    assert_equal "1", @matches[0].attributes["id"]
    select("#1:root")
    assert_equal 1, @matches.size
    assert_equal "1", @matches[0].attributes["id"]
    select("#2:root")
    assert_equal 0, @matches.size
    # Opposite for nth-child.
    select("#1:nth-child(1)")
    assert_equal 0, @matches.size
  end


  def test_nth_child_odd_even
    parse(%Q{<table><tr id="1"></tr><tr id="2"></tr><tr id="3"></tr><tr id="4"></tr></table>})
    # Test odd nth children.
    select("tr:nth-child(odd)")
    assert_equal 2, @matches.size
    assert_equal "1", @matches[0].attributes["id"]
    assert_equal "3", @matches[1].attributes["id"]
    # Test even nth children.
    select("tr:nth-child(even)")
    assert_equal 2, @matches.size
    assert_equal "2", @matches[0].attributes["id"]
    assert_equal "4", @matches[1].attributes["id"]
  end


  def test_nth_child_a_is_zero
    parse(%Q{<table><tr id="1"></tr><tr id="2"></tr><tr id="3"></tr><tr id="4"></tr></table>})
    # Test the third child.
    select("tr:nth-child(0n+3)")
    assert_equal 1, @matches.size
    assert_equal "3", @matches[0].attributes["id"]
    # Same but an can be omitted when zero.
    select("tr:nth-child(3)")
    assert_equal 1, @matches.size
    assert_equal "3", @matches[0].attributes["id"]
    # Second element (but not every second element).
    select("tr:nth-child(0n+2)")
    assert_equal 1, @matches.size
    assert_equal "2", @matches[0].attributes["id"]
    # Before first and past last returns nothing.:
    assert_raises(ArgumentError) { select("tr:nth-child(-1)") }
    select("tr:nth-child(0)")
    assert_equal 0, @matches.size
    select("tr:nth-child(5)")
    assert_equal 0, @matches.size
  end


  def test_nth_child_a_is_one
    parse(%Q{<table><tr id="1"></tr><tr id="2"></tr><tr id="3"></tr><tr id="4"></tr></table>})
    # a is group of one, pick every element in group.
    select("tr:nth-child(1n+0)")
    assert_equal 4, @matches.size
    # Same but a can be omitted when one.
    select("tr:nth-child(n+0)")
    assert_equal 4, @matches.size
    # Same but b can be omitted when zero.
    select("tr:nth-child(n)")
    assert_equal 4, @matches.size
  end


  def test_nth_child_b_is_zero
    parse(%Q{<table><tr id="1"></tr><tr id="2"></tr><tr id="3"></tr><tr id="4"></tr></table>})
    # If b is zero, pick the n-th element (here each one).
    select("tr:nth-child(n+0)")
    assert_equal 4, @matches.size
    # If b is zero, pick the n-th element (here every second).
    select("tr:nth-child(2n+0)")
    assert_equal 2, @matches.size
    assert_equal "1", @matches[0].attributes["id"]
    assert_equal "3", @matches[1].attributes["id"]
    # If a and b are both zero, no element selected.
    select("tr:nth-child(0n+0)")
    assert_equal 0, @matches.size
    select("tr:nth-child(0)")
    assert_equal 0, @matches.size
  end


  def test_nth_child_a_is_negative
    parse(%Q{<table><tr id="1"></tr><tr id="2"></tr><tr id="3"></tr><tr id="4"></tr></table>})
    # Since a is -1, picks the first three elements.
    select("tr:nth-child(-n+3)")
    assert_equal 3, @matches.size
    assert_equal "1", @matches[0].attributes["id"]
    assert_equal "2", @matches[1].attributes["id"]
    assert_equal "3", @matches[2].attributes["id"]
    # Since a is -2, picks the first in every second of first four elements.
    select("tr:nth-child(-2n+3)")
    assert_equal 2, @matches.size
    assert_equal "1", @matches[0].attributes["id"]
    assert_equal "3", @matches[1].attributes["id"]
    # Since a is -2, picks the first in every second of first three elements.
    select("tr:nth-child(-2n+2)")
    assert_equal 1, @matches.size
    assert_equal "1", @matches[0].attributes["id"]
  end


  def test_nth_child_b_is_negative
    parse(%Q{<table><tr id="1"></tr><tr id="2"></tr><tr id="3"></tr><tr id="4"></tr></table>})
    # Select last of four.
    select("tr:nth-child(4n-1)")
    assert_equal 1, @matches.size
    assert_equal "4", @matches[0].attributes["id"]
    # Select first of four.
    select("tr:nth-child(4n-4)")
    assert_equal 1, @matches.size
    assert_equal "1", @matches[0].attributes["id"]
    # Select last of every second.
    select("tr:nth-child(2n-1)")
    assert_equal 2, @matches.size
    assert_equal "2", @matches[0].attributes["id"]
    assert_equal "4", @matches[1].attributes["id"]
    # Select nothing since an+b always < 0
    select("tr:nth-child(-1n-1)")
    assert_equal 0, @matches.size
  end


  def test_nth_child_substitution_values
    parse(%Q{<table><tr id="1"></tr><tr id="2"></tr><tr id="3"></tr><tr id="4"></tr></table>})
    # Test with ?n?.
    select("tr:nth-child(?n?)", 2, 1)
    assert_equal 2, @matches.size
    assert_equal "1", @matches[0].attributes["id"]
    assert_equal "3", @matches[1].attributes["id"]
    select("tr:nth-child(?n?)", 2, 2)
    assert_equal 2, @matches.size
    assert_equal "2", @matches[0].attributes["id"]
    assert_equal "4", @matches[1].attributes["id"]
    select("tr:nth-child(?n?)", 4, 2)
    assert_equal 1, @matches.size
    assert_equal "2", @matches[0].attributes["id"]
    # Test with ? (b only).
    select("tr:nth-child(?)", 3)
    assert_equal 1, @matches.size
    assert_equal "3", @matches[0].attributes["id"]
    select("tr:nth-child(?)", 5)
    assert_equal 0, @matches.size
  end


  def test_nth_last_child
    parse(%Q{<table><tr id="1"></tr><tr id="2"></tr><tr id="3"></tr><tr id="4"></tr></table>})
    # Last two elements.
    select("tr:nth-last-child(-n+2)")
    assert_equal 2, @matches.size
    assert_equal "3", @matches[0].attributes["id"]
    assert_equal "4", @matches[1].attributes["id"]
    # All old elements counting from last one.
    select("tr:nth-last-child(odd)")
    assert_equal 2, @matches.size
    assert_equal "2", @matches[0].attributes["id"]
    assert_equal "4", @matches[1].attributes["id"]
  end


  def test_nth_of_type
    parse(%Q{<table><thead></thead><tr id="1"></tr><tr id="2"></tr><tr id="3"></tr><tr id="4"></tr></table>})
    # First two elements.
    select("tr:nth-of-type(-n+2)")
    assert_equal 2, @matches.size
    assert_equal "1", @matches[0].attributes["id"]
    assert_equal "2", @matches[1].attributes["id"]
    # All old elements counting from last one.
    select("tr:nth-last-of-type(odd)")
    assert_equal 2, @matches.size
    assert_equal "2", @matches[0].attributes["id"]
    assert_equal "4", @matches[1].attributes["id"]
  end

  
  def test_first_and_last
    parse(%Q{<table><thead></thead><tr id="1"></tr><tr id="2"></tr><tr id="3"></tr><tr id="4"></tr></table>})
    # First child.
    select("tr:first-child")
    assert_equal 0, @matches.size
    select(":first-child")
    assert_equal 1, @matches.size
    assert_equal "thead", @matches[0].name
    # First of type.
    select("tr:first-of-type")
    assert_equal 1, @matches.size
    assert_equal "1", @matches[0].attributes["id"]
    select("thead:first-of-type")
    assert_equal 1, @matches.size
    assert_equal "thead", @matches[0].name
    select("div:first-of-type")
    assert_equal 0, @matches.size
    # Last child.
    select("tr:last-child")
    assert_equal 1, @matches.size
    assert_equal "4", @matches[0].attributes["id"]
    # Last of type.
    select("tr:last-of-type")
    assert_equal 1, @matches.size
    assert_equal "4", @matches[0].attributes["id"]
    select("thead:last-of-type")
    assert_equal 1, @matches.size
    assert_equal "thead", @matches[0].name
    select("div:last-of-type")
    assert_equal 0, @matches.size
  end


  def test_first_and_last
    # Only child.
    parse(%Q{<table><tr></tr></table>})
    select("table:only-child")
    assert_equal 0, @matches.size
    select("tr:only-child")
    assert_equal 1, @matches.size
    assert_equal "tr", @matches[0].name
    parse(%Q{<table><tr></tr><tr></tr></table>})
    select("tr:only-child")
    assert_equal 0, @matches.size
    # Only of type.
    parse(%Q{<table><thead></thead><tr></tr><tr></tr></table>})
    select("thead:only-of-type")
    assert_equal 1, @matches.size
    assert_equal "thead", @matches[0].name
    select("td:only-of-type")
    assert_equal 0, @matches.size
  end


  def test_empty
    parse(%Q{<table><tr></tr></table>})
    select("table:empty")
    assert_equal 0, @matches.size
    select("tr:empty")
    assert_equal 1, @matches.size
    parse(%Q{<div> </div>})
    select("div:empty")
    assert_equal 1, @matches.size
  end

  
  def test_content
    parse(%Q{<div> </div>})
    select("div:content()")
    assert_equal 1, @matches.size
    parse(%Q{<div>something </div>})
    select("div:content()")
    assert_equal 0, @matches.size
    select("div:content(something)")
    assert_equal 1, @matches.size
    select("div:content( 'something' )")
    assert_equal 1, @matches.size
    select("div:content( \"something\" )")
    assert_equal 1, @matches.size
    select("div:content(?)", "something")
    assert_equal 1, @matches.size
    select("div:content(?)", /something/)
    assert_equal 1, @matches.size
  end


  #
  # Test negation.
  #


  def test_element_negation
    parse(%Q{<p></p><div></div>})
    select("*")
    assert_equal 2, @matches.size
    select("*:not(p)")
    assert_equal 1, @matches.size
    assert_equal "div", @matches[0].name
    select("*:not(div)")
    assert_equal 1, @matches.size
    assert_equal "p", @matches[0].name
    select("*:not(span)")
    assert_equal 2, @matches.size
  end


  def test_id_negation
    parse(%Q{<p id="1"></p><p id="2"></p>})
    select("p")
    assert_equal 2, @matches.size
    select(":not(#1)")
    assert_equal 1, @matches.size
    assert_equal "2", @matches[0].attributes["id"]
    select(":not(#2)")
    assert_equal 1, @matches.size
    assert_equal "1", @matches[0].attributes["id"]
  end


  def test_class_name_negation
    parse(%Q{<p class="foo"></p><p class="bar"></p>})
    select("p")
    assert_equal 2, @matches.size
    select(":not(.foo)")
    assert_equal 1, @matches.size
    assert_equal "bar", @matches[0].attributes["class"]
    select(":not(.bar)")
    assert_equal 1, @matches.size
    assert_equal "foo", @matches[0].attributes["class"]
  end


  def test_attribute_negation
    parse(%Q{<p title="foo"></p><p title="bar"></p>})
    select("p")
    assert_equal 2, @matches.size
    select(":not([title=foo])")
    assert_equal 1, @matches.size
    assert_equal "bar", @matches[0].attributes["title"]
    select(":not([title=bar])")
    assert_equal 1, @matches.size
    assert_equal "foo", @matches[0].attributes["title"]
  end

  
  def test_pseudo_class_negation
    parse(%Q{<div><p id="1"></p><p id="2"></p></div>})
    select("p")
    assert_equal 2, @matches.size
    select("p:not(:first-child)")
    assert_equal 1, @matches.size
    assert_equal "2", @matches[0].attributes["id"]
    select("p:not(:nth-child(2))")
    assert_equal 1, @matches.size
    assert_equal "1", @matches[0].attributes["id"]
  end
  

  def test_negation_details
    parse(%Q{<p id="1"></p><p id="2"></p><p id="3"></p>})
    assert_raises(ArgumentError) { select(":not(") }
    assert_raises(ArgumentError) { select(":not(:not())") }
    select("p:not(#1):not(#3)")
    assert_equal 1, @matches.size
    assert_equal "2", @matches[0].attributes["id"]
  end


  def test_select_from_element
    parse(%Q{<div><p id="1"></p><p id="2"></p></div>})
    select("div")
    @matches = @matches[0].select("p")
    assert_equal 2, @matches.size
    assert_equal "1", @matches[0].attributes["id"]
    assert_equal "2", @matches[1].attributes["id"]
  end


protected

  def parse(html)
    @html = HTML::Document.new(html).root
  end

  def select(*selector)
    @matches = HTML.selector(*selector).select(@html)
  end

end
