require 'test/unit'
require File.dirname(__FILE__) + '/../../lib/action_view/helpers/form_options_helper'

class Continent
	def initialize(p_name, p_countries)	@continent_name = p_name; @countries = p_countries;	end
	def continent_name() @continent_name; end
	def countries() @countries; end
end

class Country
	def initialize(id, name) @id = id; @name = name end
	def country_id() @id; end
	def country_name() @name; end
end


class FormOptionsHelperTest < Test::Unit::TestCase
  include ActionView::Helpers::FormOptionsHelper

  Post = Struct.new("Post", :title, :author_name, :body, :secret, :written_on)
  
  def test_collection_options
    @posts = [
      Post.new("Abe went home", "Abe", "To a little house", "shh!"),
      Post.new("Babe went home", "Babe", "To a little house", "shh!"),
      Post.new("Cabe went home", "Cabe", "To a little house", "shh!")
    ]

    assert_equal(
      "<option value=\"Abe\">Abe went home</option>\n<option value=\"Babe\">Babe went home</option>\n<option value=\"Cabe\">Cabe went home</option>",
      options_from_collection_for_select(@posts, "author_name", "title")
    )
  end

  
  def test_collection_options_with_preselected_value
    @posts = [
      Post.new("Abe went home", "Abe", "To a little house", "shh!"),
      Post.new("Babe went home", "Babe", "To a little house", "shh!"),
      Post.new("Cabe went home", "Cabe", "To a little house", "shh!")
    ]

    assert_equal(
      "<option value=\"Abe\">Abe went home</option>\n<option value=\"Babe\" selected>Babe went home</option>\n<option value=\"Cabe\">Cabe went home</option>",
      options_from_collection_for_select(@posts, "author_name", "title", "Babe")
    )
  end

  def test_array_options_for_select
    assert_equal(
      "<option>Denmark</option>\n<option>USA</option>\n<option>Sweden</option>", 
      options_for_select([ "Denmark", "USA", "Sweden" ])
    )
  end

  def test_array_options_for_select_with_selection
    assert_equal(
      "<option>Denmark</option>\n<option selected>USA</option>\n<option>Sweden</option>", 
      options_for_select([ "Denmark", "USA", "Sweden" ], "USA")
    )
  end

  def test_hash_options_for_select
    assert_equal(
      "<option value=\"Kroner\">DKR</option>\n<option value=\"Dollar\">$</option>", 
      options_for_select({ "$" => "Dollar", "DKR" => "Kroner" })
    )
  end

  def test_hash_options_for_select_with_selection
    assert_equal(
      "<option value=\"Kroner\">DKR</option>\n<option value=\"Dollar\" selected>$</option>", 
      options_for_select({ "$" => "Dollar", "DKR" => "Kroner" }, "Dollar")
    )
  end

  def test_html_option_groups_from_collection
    @continents = [
      Continent.new("Africa", [Country.new("sa", "South Africa"), Country.new("so", "Somalia")] ),
      Continent.new("Europe", [Country.new("dk", "Denmark"), Country.new("ie", "Ireland")] )
    ]	

    assert_equal(
      "<optgroup label=\"Africa\"><option value=\"sa\">South Africa</option>\n<option value=\"so\">Somalia</option></optgroup><optgroup label=\"Europe\"><option value=\"dk\" selected>Denmark</option>\n<option value=\"ie\">Ireland</option></optgroup>",
      option_groups_from_collection_for_select(@continents, "countries", "continent_name", "country_id", "country_name", "dk")
    )
  end
end