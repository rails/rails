# frozen_string_literal: true

require "abstract_unit"
require "active_support/core_ext/enumerable"

class Map < Hash
  def category
    "<mus>"
  end
end

class CustomEnumerable
  include Enumerable

  def each
    yield "one"
    yield "two"
  end
end

class FormOptionsHelperTest < ActionView::TestCase
  tests ActionView::Helpers::FormOptionsHelper

  silence_warnings do
    Post        = Struct.new("Post", :title, :author_name, :body, :written_on, :category, :origin, :allow_comments) do
                    private
                      def secret
                        "This is super secret: #{author_name} is not the real author of #{title}"
                      end
                  end
    Continent   = Struct.new("Continent", :continent_name, :countries)
    Country     = Struct.new("Country", :country_id, :country_name)
    Album       = Struct.new("Album", :id, :title, :genre)
  end

  class Firm
    include ActiveModel::Validations
    extend ActiveModel::Naming

    attr_accessor :time_zone

    def initialize(time_zone = nil)
      @time_zone = time_zone
    end
  end

  module FakeZones
    FakeZone = Struct.new(:name) do
      def to_s; name; end
      def =~(_re); end
      def match?(_re); end
    end

    module ClassMethods
      def [](id); fake_zones ? fake_zones[id] : super; end
      def all; fake_zones ? fake_zones.values : super; end
      def dummy; :test; end
    end

    def self.prepended(base)
      base.mattr_accessor(:fake_zones)
      class << base
        prepend ClassMethods
      end
    end
  end

  ActiveSupport::TimeZone.prepend FakeZones

  setup do
    ActiveSupport::TimeZone.fake_zones = %w(A B C D E).index_with do |id|
      FakeZones::FakeZone.new(id)
    end

    @fake_timezones = ActiveSupport::TimeZone.all
  end

  teardown do
    ActiveSupport::TimeZone.fake_zones = nil
  end

  def test_collection_options
    assert_dom_equal(
      "<option value=\"&lt;Abe&gt;\">&lt;Abe&gt; went home</option>\n<option value=\"Babe\">Babe went home</option>\n<option value=\"Cabe\">Cabe went home</option>",
      options_from_collection_for_select(dummy_posts, "author_name", "title")
    )
  end

  def test_collection_options_with_private_value_method
    assert_deprecated("Using private methods from view helpers is deprecated (calling private Struct::Post#secret)") {  options_from_collection_for_select(dummy_posts, "secret", "title") }
  end

  def test_collection_options_with_private_text_method
    assert_deprecated("Using private methods from view helpers is deprecated (calling private Struct::Post#secret)") {  options_from_collection_for_select(dummy_posts, "author_name", "secret") }
  end

  def test_collection_options_with_preselected_value
    assert_dom_equal(
      "<option value=\"&lt;Abe&gt;\">&lt;Abe&gt; went home</option>\n<option value=\"Babe\" selected=\"selected\">Babe went home</option>\n<option value=\"Cabe\">Cabe went home</option>",
      options_from_collection_for_select(dummy_posts, "author_name", "title", "Babe")
    )
  end

  def test_collection_options_with_preselected_value_array
    assert_dom_equal(
      "<option value=\"&lt;Abe&gt;\">&lt;Abe&gt; went home</option>\n<option value=\"Babe\" selected=\"selected\">Babe went home</option>\n<option value=\"Cabe\" selected=\"selected\">Cabe went home</option>",
      options_from_collection_for_select(dummy_posts, "author_name", "title", [ "Babe", "Cabe" ])
    )
  end

  def test_collection_options_with_proc_for_selected
    assert_dom_equal(
      "<option value=\"&lt;Abe&gt;\">&lt;Abe&gt; went home</option>\n<option value=\"Babe\" selected=\"selected\">Babe went home</option>\n<option value=\"Cabe\">Cabe went home</option>",
      options_from_collection_for_select(dummy_posts, "author_name", "title", lambda { |p| p.author_name == "Babe" })
    )
  end

  def test_collection_options_with_disabled_value
    assert_dom_equal(
      "<option value=\"&lt;Abe&gt;\">&lt;Abe&gt; went home</option>\n<option value=\"Babe\" disabled=\"disabled\">Babe went home</option>\n<option value=\"Cabe\">Cabe went home</option>",
      options_from_collection_for_select(dummy_posts, "author_name", "title", disabled: "Babe")
    )
  end

  def test_collection_options_with_disabled_array
    assert_dom_equal(
      "<option value=\"&lt;Abe&gt;\">&lt;Abe&gt; went home</option>\n<option value=\"Babe\" disabled=\"disabled\">Babe went home</option>\n<option value=\"Cabe\" disabled=\"disabled\">Cabe went home</option>",
      options_from_collection_for_select(dummy_posts, "author_name", "title", disabled: [ "Babe", "Cabe" ])
    )
  end

  def test_collection_options_with_preselected_and_disabled_value
    assert_dom_equal(
      "<option value=\"&lt;Abe&gt;\">&lt;Abe&gt; went home</option>\n<option value=\"Babe\" disabled=\"disabled\">Babe went home</option>\n<option value=\"Cabe\" selected=\"selected\">Cabe went home</option>",
      options_from_collection_for_select(dummy_posts, "author_name", "title", selected: "Cabe", disabled: "Babe")
    )
  end

  def test_collection_options_with_proc_for_disabled
    assert_dom_equal(
      "<option value=\"&lt;Abe&gt;\">&lt;Abe&gt; went home</option>\n<option value=\"Babe\" disabled=\"disabled\">Babe went home</option>\n<option value=\"Cabe\" disabled=\"disabled\">Cabe went home</option>",
      options_from_collection_for_select(dummy_posts, "author_name", "title", disabled: lambda { |p| %w(Babe Cabe).include?(p.author_name) })
    )
  end

  def test_collection_options_with_proc_for_value_method
    assert_dom_equal(
      "<option value=\"&lt;Abe&gt;\">&lt;Abe&gt; went home</option>\n<option value=\"Babe\">Babe went home</option>\n<option value=\"Cabe\">Cabe went home</option>",
      options_from_collection_for_select(dummy_posts, lambda { |p| p.author_name }, "title")
    )
  end

  def test_collection_options_with_proc_for_text_method
    assert_dom_equal(
      "<option value=\"&lt;Abe&gt;\">&lt;Abe&gt; went home</option>\n<option value=\"Babe\">Babe went home</option>\n<option value=\"Cabe\">Cabe went home</option>",
      options_from_collection_for_select(dummy_posts, "author_name", lambda { |p| p.title })
    )
  end

  def test_collection_options_with_element_attributes
    assert_dom_equal(
      "<option value=\"USA\" class=\"bold\">USA</option>",
      options_from_collection_for_select([[ "USA", "USA", { class: "bold" } ]], :first, :second)
    )
  end

  def test_string_options_for_select
    options = "<option value=\"Denmark\">Denmark</option><option value=\"USA\">USA</option><option value=\"Sweden\">Sweden</option>"
    assert_dom_equal(
      options,
      options_for_select(options)
    )
  end

  def test_array_options_for_select
    assert_dom_equal(
      "<option value=\"&lt;Denmark&gt;\">&lt;Denmark&gt;</option>\n<option value=\"USA\">USA</option>\n<option value=\"Sweden\">Sweden</option>",
      options_for_select([ "<Denmark>", "USA", "Sweden" ])
    )
  end

  def test_array_options_for_select_with_custom_defined_selected
    assert_dom_equal(
      "<option selected=\"selected\" type=\"Coach\" value=\"1\">Richard Bandler</option>\n<option type=\"Coachee\" value=\"1\">Richard Bandler</option>",
      options_for_select([
        ["Richard Bandler", 1, { type: "Coach", selected: "selected" }],
        ["Richard Bandler", 1, { type: "Coachee" }]
      ])
    )
  end

  def test_array_options_for_select_with_custom_defined_disabled
    assert_dom_equal(
      "<option disabled=\"disabled\" type=\"Coach\" value=\"1\">Richard Bandler</option>\n<option type=\"Coachee\" value=\"1\">Richard Bandler</option>",
      options_for_select([
        ["Richard Bandler", 1, { type: "Coach", disabled: "disabled" }],
        ["Richard Bandler", 1, { type: "Coachee" }]
      ])
    )
  end

  def test_array_options_for_select_with_selection
    assert_dom_equal(
      "<option value=\"Denmark\">Denmark</option>\n<option value=\"&lt;USA&gt;\" selected=\"selected\">&lt;USA&gt;</option>\n<option value=\"Sweden\">Sweden</option>",
      options_for_select([ "Denmark", "<USA>", "Sweden" ], "<USA>")
    )
  end

  def test_array_options_for_select_with_selection_array
    assert_dom_equal(
      "<option value=\"Denmark\">Denmark</option>\n<option value=\"&lt;USA&gt;\" selected=\"selected\">&lt;USA&gt;</option>\n<option value=\"Sweden\" selected=\"selected\">Sweden</option>",
      options_for_select([ "Denmark", "<USA>", "Sweden" ], [ "<USA>", "Sweden" ])
    )
  end

  def test_array_options_for_select_with_disabled_value
    assert_dom_equal(
      "<option value=\"Denmark\">Denmark</option>\n<option value=\"&lt;USA&gt;\" disabled=\"disabled\">&lt;USA&gt;</option>\n<option value=\"Sweden\">Sweden</option>",
      options_for_select([ "Denmark", "<USA>", "Sweden" ], disabled: "<USA>")
    )
  end

  def test_array_options_for_select_with_disabled_array
    assert_dom_equal(
      "<option value=\"Denmark\">Denmark</option>\n<option value=\"&lt;USA&gt;\" disabled=\"disabled\">&lt;USA&gt;</option>\n<option value=\"Sweden\" disabled=\"disabled\">Sweden</option>",
      options_for_select([ "Denmark", "<USA>", "Sweden" ], disabled: ["<USA>", "Sweden"])
    )
  end

  def test_array_options_for_select_with_selection_and_disabled_value
    assert_dom_equal(
      "<option value=\"Denmark\" selected=\"selected\">Denmark</option>\n<option value=\"&lt;USA&gt;\" disabled=\"disabled\">&lt;USA&gt;</option>\n<option value=\"Sweden\">Sweden</option>",
      options_for_select([ "Denmark", "<USA>", "Sweden" ], selected: "Denmark", disabled: "<USA>")
    )
  end

  def test_boolean_array_options_for_select_with_selection_and_disabled_value
    assert_dom_equal(
      "<option value=\"true\">true</option>\n<option value=\"false\" selected=\"selected\">false</option>",
      options_for_select([ true, false ], selected: false, disabled: nil)
    )
  end

  def test_range_options_for_select
    assert_dom_equal(
      "<option value=\"1\">1</option>\n<option value=\"2\">2</option>\n<option value=\"3\">3</option>",
      options_for_select(1..3)
    )
  end

  def test_array_options_for_string_include_in_other_string_bug_fix
    assert_dom_equal(
      "<option value=\"ruby\">ruby</option>\n<option value=\"rubyonrails\" selected=\"selected\">rubyonrails</option>",
      options_for_select([ "ruby", "rubyonrails" ], "rubyonrails")
    )
    assert_dom_equal(
      "<option value=\"ruby\" selected=\"selected\">ruby</option>\n<option value=\"rubyonrails\">rubyonrails</option>",
      options_for_select([ "ruby", "rubyonrails" ], "ruby")
    )
    assert_dom_equal(
      %(<option value="ruby" selected="selected">ruby</option>\n<option value="rubyonrails">rubyonrails</option>\n<option value=""></option>),
      options_for_select([ "ruby", "rubyonrails", nil ], "ruby")
    )
  end

  def test_hash_options_for_select
    assert_dom_equal(
      "<option value=\"Dollar\">$</option>\n<option value=\"&lt;Kroner&gt;\">&lt;DKR&gt;</option>",
      options_for_select("$" => "Dollar", "<DKR>" => "<Kroner>").split("\n").join("\n")
    )
    assert_dom_equal(
      "<option value=\"Dollar\" selected=\"selected\">$</option>\n<option value=\"&lt;Kroner&gt;\">&lt;DKR&gt;</option>",
      options_for_select({ "$" => "Dollar", "<DKR>" => "<Kroner>" }, "Dollar").split("\n").join("\n")
    )
    assert_dom_equal(
      "<option value=\"Dollar\" selected=\"selected\">$</option>\n<option value=\"&lt;Kroner&gt;\" selected=\"selected\">&lt;DKR&gt;</option>",
      options_for_select({ "$" => "Dollar", "<DKR>" => "<Kroner>" }, [ "Dollar", "<Kroner>" ]).split("\n").join("\n")
    )
  end

  def test_ducktyped_options_for_select
    quack = Struct.new(:first, :last)
    assert_dom_equal(
      "<option value=\"&lt;Kroner&gt;\">&lt;DKR&gt;</option>\n<option value=\"Dollar\">$</option>",
      options_for_select([quack.new("<DKR>", "<Kroner>"), quack.new("$", "Dollar")])
    )
    assert_dom_equal(
      "<option value=\"&lt;Kroner&gt;\">&lt;DKR&gt;</option>\n<option value=\"Dollar\" selected=\"selected\">$</option>",
      options_for_select([quack.new("<DKR>", "<Kroner>"), quack.new("$", "Dollar")], "Dollar")
    )
    assert_dom_equal(
      "<option value=\"&lt;Kroner&gt;\" selected=\"selected\">&lt;DKR&gt;</option>\n<option value=\"Dollar\" selected=\"selected\">$</option>",
      options_for_select([quack.new("<DKR>", "<Kroner>"), quack.new("$", "Dollar")], ["Dollar", "<Kroner>"])
    )
  end

  def test_collection_options_with_preselected_value_as_string_and_option_value_is_integer
    albums = [ Album.new(1, "first", "rap"), Album.new(2, "second", "pop")]
    assert_dom_equal(
      %(<option selected="selected" value="1">rap</option>\n<option value="2">pop</option>),
      options_from_collection_for_select(albums, "id", "genre", selected: "1")
    )
  end

  def test_collection_options_with_preselected_value_as_integer_and_option_value_is_string
    albums = [ Album.new("1", "first", "rap"), Album.new("2", "second", "pop")]

    assert_dom_equal(
      %(<option selected="selected" value="1">rap</option>\n<option value="2">pop</option>),
      options_from_collection_for_select(albums, "id", "genre", selected: 1)
    )
  end

  def test_collection_options_with_preselected_value_as_string_and_option_value_is_float
    albums = [ Album.new(1.0, "first", "rap"), Album.new(2.0, "second", "pop")]

    assert_dom_equal(
      %(<option value="1.0">rap</option>\n<option value="2.0" selected="selected">pop</option>),
      options_from_collection_for_select(albums, "id", "genre", selected: "2.0")
    )
  end

  def test_collection_options_with_preselected_value_as_nil
    albums = [ Album.new(1.0, "first", "rap"), Album.new(2.0, "second", "pop")]

    assert_dom_equal(
      %(<option value="1.0">rap</option>\n<option value="2.0">pop</option>),
      options_from_collection_for_select(albums, "id", "genre", selected: nil)
    )
  end

  def test_collection_options_with_disabled_value_as_nil
    albums = [ Album.new(1.0, "first", "rap"), Album.new(2.0, "second", "pop")]

    assert_dom_equal(
      %(<option value="1.0">rap</option>\n<option value="2.0">pop</option>),
      options_from_collection_for_select(albums, "id", "genre", disabled: nil)
    )
  end

  def test_collection_options_with_disabled_value_as_array
    albums = [ Album.new(1.0, "first", "rap"), Album.new(2.0, "second", "pop")]

    assert_dom_equal(
      %(<option disabled="disabled" value="1.0">rap</option>\n<option disabled="disabled" value="2.0">pop</option>),
      options_from_collection_for_select(albums, "id", "genre", disabled: ["1.0", 2.0])
    )
  end

  def test_collection_options_with_preselected_values_as_string_array_and_option_value_is_float
    albums = [ Album.new(1.0, "first", "rap"), Album.new(2.0, "second", "pop"), Album.new(3.0, "third", "country") ]

    assert_dom_equal(
      %(<option value="1.0" selected="selected">rap</option>\n<option value="2.0">pop</option>\n<option value="3.0" selected="selected">country</option>),
      options_from_collection_for_select(albums, "id", "genre", ["1.0", "3.0"])
    )
  end

  def test_option_groups_from_collection_for_select
    assert_dom_equal(
      "<optgroup label=\"&lt;Africa&gt;\"><option value=\"&lt;sa&gt;\">&lt;South Africa&gt;</option>\n<option value=\"so\">Somalia</option></optgroup><optgroup label=\"Europe\"><option value=\"dk\" selected=\"selected\">Denmark</option>\n<option value=\"ie\">Ireland</option></optgroup>",
      option_groups_from_collection_for_select(dummy_continents, "countries", "continent_name", "country_id", "country_name", "dk")
    )
  end

  def test_option_groups_from_collection_for_select_with_callable_group_method
    group_proc = Proc.new { |c| c.countries }
    assert_dom_equal(
      "<optgroup label=\"&lt;Africa&gt;\"><option value=\"&lt;sa&gt;\">&lt;South Africa&gt;</option>\n<option value=\"so\">Somalia</option></optgroup><optgroup label=\"Europe\"><option value=\"dk\" selected=\"selected\">Denmark</option>\n<option value=\"ie\">Ireland</option></optgroup>",
      option_groups_from_collection_for_select(dummy_continents, group_proc, "continent_name", "country_id", "country_name", "dk")
    )
  end

  def test_option_groups_from_collection_for_select_with_callable_group_label_method
    label_proc = Proc.new { |c| c.continent_name }
    assert_dom_equal(
      "<optgroup label=\"&lt;Africa&gt;\"><option value=\"&lt;sa&gt;\">&lt;South Africa&gt;</option>\n<option value=\"so\">Somalia</option></optgroup><optgroup label=\"Europe\"><option value=\"dk\" selected=\"selected\">Denmark</option>\n<option value=\"ie\">Ireland</option></optgroup>",
      option_groups_from_collection_for_select(dummy_continents, "countries", label_proc, "country_id", "country_name", "dk")
    )
  end

  def test_option_groups_from_collection_for_select_returns_html_safe_string
    assert_predicate option_groups_from_collection_for_select(dummy_continents, "countries", "continent_name", "country_id", "country_name", "dk"), :html_safe?
  end

  def test_grouped_options_for_select_with_array
    assert_dom_equal(
      "<optgroup label=\"North America\"><option value=\"US\">United States</option>\n<option value=\"Canada\">Canada</option></optgroup><optgroup label=\"Europe\"><option value=\"GB\">Great Britain</option>\n<option value=\"Germany\">Germany</option></optgroup>",
      grouped_options_for_select([
         ["North America",
             [["United States", "US"], "Canada"]],
         ["Europe",
             [["Great Britain", "GB"], "Germany"]]
       ])
    )
  end

  def test_grouped_options_for_select_with_array_and_html_attributes
    assert_dom_equal(
      "<optgroup label=\"North America\" data-foo=\"bar\"><option value=\"US\">United States</option>\n<option value=\"Canada\">Canada</option></optgroup><optgroup label=\"Europe\" disabled=\"disabled\"><option value=\"GB\">Great Britain</option>\n<option value=\"Germany\">Germany</option></optgroup>",
      grouped_options_for_select([
         ["North America", [["United States", "US"], "Canada"], data: { foo: "bar" }],
         ["Europe", [["Great Britain", "GB"], "Germany"], disabled: "disabled"]
       ])
    )
  end

  def test_grouped_options_for_select_with_optional_divider
    assert_dom_equal(
      "<optgroup label=\"----------\"><option value=\"US\">US</option>\n<option value=\"Canada\">Canada</option></optgroup><optgroup label=\"----------\"><option value=\"GB\">GB</option>\n<option value=\"Germany\">Germany</option></optgroup>",

      grouped_options_for_select([["US", "Canada"], ["GB", "Germany"]], nil, divider: "----------")
    )
  end

  def test_grouped_options_for_select_with_selected_and_prompt
    assert_dom_equal(
      "<option value=\"\">Choose a product...</option><optgroup label=\"Hats\"><option value=\"Baseball Cap\">Baseball Cap</option>\n<option selected=\"selected\" value=\"Cowboy Hat\">Cowboy Hat</option></optgroup>",
      grouped_options_for_select([["Hats", ["Baseball Cap", "Cowboy Hat"]]], "Cowboy Hat", prompt: "Choose a product...")
    )
  end

  def test_grouped_options_for_select_with_selected_and_prompt_true
    assert_dom_equal(
      "<option value=\"\">Please select</option><optgroup label=\"Hats\"><option value=\"Baseball Cap\">Baseball Cap</option>\n<option selected=\"selected\" value=\"Cowboy Hat\">Cowboy Hat</option></optgroup>",
      grouped_options_for_select([["Hats", ["Baseball Cap", "Cowboy Hat"]]], "Cowboy Hat", prompt: true)
    )
  end

  def test_grouped_options_for_select_returns_html_safe_string
    assert_predicate grouped_options_for_select([["Hats", ["Baseball Cap", "Cowboy Hat"]]]), :html_safe?
  end

  def test_grouped_options_for_select_with_prompt_returns_html_escaped_string
    assert_dom_equal(
      "<option value=\"\">&lt;Choose One&gt;</option><optgroup label=\"Hats\"><option value=\"Baseball Cap\">Baseball Cap</option>\n<option value=\"Cowboy Hat\">Cowboy Hat</option></optgroup>",
      grouped_options_for_select([["Hats", ["Baseball Cap", "Cowboy Hat"]]], nil, prompt: "<Choose One>"))
  end

  def test_optgroups_with_with_options_with_hash
    assert_dom_equal(
      "<optgroup label=\"North America\"><option value=\"United States\">United States</option>\n<option value=\"Canada\">Canada</option></optgroup><optgroup label=\"Europe\"><option value=\"Denmark\">Denmark</option>\n<option value=\"Germany\">Germany</option></optgroup>",
      grouped_options_for_select("North America" => ["United States", "Canada"], "Europe" => ["Denmark", "Germany"])
    )
  end

  def test_time_zone_options_no_params
    opts = time_zone_options_for_select
    assert_dom_equal "<option value=\"A\">A</option>\n" \
                 "<option value=\"B\">B</option>\n" \
                 "<option value=\"C\">C</option>\n" \
                 "<option value=\"D\">D</option>\n" \
                 "<option value=\"E\">E</option>",
                 opts
  end

  def test_time_zone_options_with_selected
    opts = time_zone_options_for_select("D")
    assert_dom_equal "<option value=\"A\">A</option>\n" \
                 "<option value=\"B\">B</option>\n" \
                 "<option value=\"C\">C</option>\n" \
                 "<option value=\"D\" selected=\"selected\">D</option>\n" \
                 "<option value=\"E\">E</option>",
                 opts
  end

  def test_time_zone_options_with_unknown_selected
    opts = time_zone_options_for_select("K")
    assert_dom_equal "<option value=\"A\">A</option>\n" \
                 "<option value=\"B\">B</option>\n" \
                 "<option value=\"C\">C</option>\n" \
                 "<option value=\"D\">D</option>\n" \
                 "<option value=\"E\">E</option>",
                 opts
  end

  def test_time_zone_options_with_priority_zones
    zones = [ ActiveSupport::TimeZone.new("B"), ActiveSupport::TimeZone.new("E") ]
    opts = time_zone_options_for_select(nil, zones)
    assert_dom_equal "<option value=\"B\">B</option>\n" \
                 "<option value=\"E\">E</option>" \
                 "<option value=\"\" disabled=\"disabled\">-------------</option>\n" \
                 "<option value=\"A\">A</option>\n" \
                 "<option value=\"C\">C</option>\n" \
                 "<option value=\"D\">D</option>",
                 opts
  end

  def test_time_zone_options_with_selected_priority_zones
    zones = [ ActiveSupport::TimeZone.new("B"), ActiveSupport::TimeZone.new("E") ]
    opts = time_zone_options_for_select("E", zones)
    assert_dom_equal "<option value=\"B\">B</option>\n" \
                 "<option value=\"E\" selected=\"selected\">E</option>" \
                 "<option value=\"\" disabled=\"disabled\">-------------</option>\n" \
                 "<option value=\"A\">A</option>\n" \
                 "<option value=\"C\">C</option>\n" \
                 "<option value=\"D\">D</option>",
                 opts
  end

  def test_time_zone_options_with_unselected_priority_zones
    zones = [ ActiveSupport::TimeZone.new("B"), ActiveSupport::TimeZone.new("E") ]
    opts = time_zone_options_for_select("C", zones)
    assert_dom_equal "<option value=\"B\">B</option>\n" \
                 "<option value=\"E\">E</option>" \
                 "<option value=\"\" disabled=\"disabled\">-------------</option>\n" \
                 "<option value=\"A\">A</option>\n" \
                 "<option value=\"C\" selected=\"selected\">C</option>\n" \
                 "<option value=\"D\">D</option>",
                 opts
  end

  def test_time_zone_options_with_priority_zones_does_not_mutate_time_zones
    original_zones = ActiveSupport::TimeZone.all.dup
    zones = [ ActiveSupport::TimeZone.new("B"), ActiveSupport::TimeZone.new("E") ]
    time_zone_options_for_select(nil, zones)
    assert_equal original_zones, ActiveSupport::TimeZone.all
  end

  def test_time_zone_options_returns_html_safe_string
    assert_predicate time_zone_options_for_select, :html_safe?
  end

  def test_select
    @post = Post.new
    @post.category = "<mus>"
    assert_dom_equal(
      "<select id=\"post_category\" name=\"post[category]\"><option value=\"abe\">abe</option>\n<option value=\"&lt;mus&gt;\" selected=\"selected\">&lt;mus&gt;</option>\n<option value=\"hest\">hest</option></select>",
      select("post", "category", %w( abe <mus> hest))
    )
  end

  def test_select_without_multiple
    assert_dom_equal(
      "<select id=\"post_category\" name=\"post[category]\"></select>",
      select(:post, :category, "", {}, { multiple: false })
    )
  end

  def test_required_select_with_default_and_selected_placeholder
    assert_dom_equal(
      ['<select required="required" name="post[category]" id="post_category"><option disabled="disabled" selected="selected" value="">Choose one</option>',
      '<option value="lifestyle">lifestyle</option>',
      '<option value="programming">programming</option>',
      '<option value="spiritual">spiritual</option></select>'].join("\n"),
      select(:post, :category, ["lifestyle", "programming", "spiritual"], { selected: "", disabled: "", prompt: "Choose one" }, { required: true })
    )
  end

  def test_select_with_grouped_collection_as_nested_array
    @post = Post.new

    countries_by_continent = [
      ["<Africa>", [["<South Africa>", "<sa>"], ["Somalia", "so"]]],
      ["Europe",   [["Denmark", "dk"], ["Ireland", "ie"]]],
    ]

    assert_dom_equal(
      [
        '<select id="post_origin" name="post[origin]"><optgroup label="&lt;Africa&gt;"><option value="&lt;sa&gt;">&lt;South Africa&gt;</option>',
        '<option value="so">Somalia</option></optgroup><optgroup label="Europe"><option value="dk">Denmark</option>',
        '<option value="ie">Ireland</option></optgroup></select>',
      ].join("\n"),
      select("post", "origin", countries_by_continent)
    )
  end

  def test_select_with_grouped_collection_as_hash
    @post = Post.new

    countries_by_continent = {
      "<Africa>" => [["<South Africa>", "<sa>"], ["Somalia", "so"]],
      "Europe"   => [["Denmark", "dk"], ["Ireland", "ie"]],
    }

    assert_dom_equal(
      [
        '<select id="post_origin" name="post[origin]"><optgroup label="&lt;Africa&gt;"><option value="&lt;sa&gt;">&lt;South Africa&gt;</option>',
        '<option value="so">Somalia</option></optgroup><optgroup label="Europe"><option value="dk">Denmark</option>',
        '<option value="ie">Ireland</option></optgroup></select>',
      ].join("\n"),
      select("post", "origin", countries_by_continent)
    )
  end

  def test_select_with_boolean_method
    @post = Post.new
    @post.allow_comments = false
    assert_dom_equal(
      "<select id=\"post_allow_comments\" name=\"post[allow_comments]\"><option value=\"true\">true</option>\n<option value=\"false\" selected=\"selected\">false</option></select>",
      select("post", "allow_comments", %w( true false ))
    )
  end

  def test_select_under_fields_for
    @post = Post.new
    @post.category = "<mus>"

    output_buffer = fields_for :post, @post do |f|
      concat f.select(:category, %w( abe <mus> hest))
    end

    assert_dom_equal(
      "<select id=\"post_category\" name=\"post[category]\"><option value=\"abe\">abe</option>\n<option value=\"&lt;mus&gt;\" selected=\"selected\">&lt;mus&gt;</option>\n<option value=\"hest\">hest</option></select>",
      output_buffer
    )
  end

  def test_fields_for_with_record_inherited_from_hash
    map = Map.new

    output_buffer = fields_for :map, map do |f|
      concat f.select(:category, %w( abe <mus> hest))
    end

    assert_dom_equal(
      "<select id=\"map_category\" name=\"map[category]\"><option value=\"abe\">abe</option>\n<option value=\"&lt;mus&gt;\" selected=\"selected\">&lt;mus&gt;</option>\n<option value=\"hest\">hest</option></select>",
      output_buffer
    )
  end

  def test_select_under_fields_for_with_index
    @post = Post.new
    @post.category = "<mus>"

    output_buffer = fields_for :post, @post, index: 108 do |f|
      concat f.select(:category, %w( abe <mus> hest))
    end

    assert_dom_equal(
      "<select id=\"post_108_category\" name=\"post[108][category]\"><option value=\"abe\">abe</option>\n<option value=\"&lt;mus&gt;\" selected=\"selected\">&lt;mus&gt;</option>\n<option value=\"hest\">hest</option></select>",
      output_buffer
    )
  end

  def test_select_under_fields_for_with_auto_index
    @post = Post.new
    @post.category = "<mus>"
    def @post.to_param; 108; end

    output_buffer = fields_for "post[]", @post do |f|
      concat f.select(:category, %w( abe <mus> hest))
    end

    assert_dom_equal(
      "<select id=\"post_108_category\" name=\"post[108][category]\"><option value=\"abe\">abe</option>\n<option value=\"&lt;mus&gt;\" selected=\"selected\">&lt;mus&gt;</option>\n<option value=\"hest\">hest</option></select>",
      output_buffer
    )
  end

  def test_select_under_fields_for_with_string_and_given_prompt
    @post = Post.new
    options = raw("<option value=\"abe\">abe</option><option value=\"mus\">mus</option><option value=\"hest\">hest</option>")

    output_buffer = fields_for :post, @post do |f|
      concat f.select(:category, options, prompt: "The prompt")
    end

    assert_dom_equal(
      "<select id=\"post_category\" name=\"post[category]\"><option value=\"\">The prompt</option>\n#{options}</select>",
      output_buffer
    )
  end

  def test_select_under_fields_for_with_block
    @post = Post.new

    output_buffer = fields_for :post, @post do |f|
      concat(f.select(:category) do
        concat content_tag(:option, "hello world")
      end)
    end

    assert_dom_equal(
      "<select id=\"post_category\" name=\"post[category]\"><option>hello world</option></select>",
      output_buffer
    )
  end

  def test_select_under_fields_for_with_block_without_options
    @post = Post.new

    output_buffer = fields_for :post, @post do |f|
      concat(f.select(:category) { })
    end

    assert_dom_equal(
      "<select id=\"post_category\" name=\"post[category]\"></select>",
      output_buffer
    )
  end

  def test_select_with_multiple_to_add_hidden_input
    output_buffer = select(:post, :category, "", {}, { multiple: true })
    assert_dom_equal(
      "<input type=\"hidden\" name=\"post[category][]\" value=\"\"/><select multiple=\"multiple\" id=\"post_category\" name=\"post[category][]\"></select>",
      output_buffer
    )
  end

  def test_select_with_multiple_and_without_hidden_input
    output_buffer = select(:post, :category, "", { include_hidden: false }, { multiple: true })
    assert_dom_equal(
      "<select multiple=\"multiple\" id=\"post_category\" name=\"post[category][]\"></select>",
      output_buffer
    )
  end

  def test_select_with_multiple_and_with_explicit_name_ending_with_brackets
    output_buffer = select(:post, :category, [], { include_hidden: false }, { multiple: true, name: "post[category][]" })
    assert_dom_equal(
      "<select multiple=\"multiple\" id=\"post_category\" name=\"post[category][]\"></select>",
      output_buffer
    )
  end

  def test_select_with_multiple_and_disabled_to_add_disabled_hidden_input
    output_buffer = select(:post, :category, "", {}, { multiple: true, disabled: true })
    assert_dom_equal(
      "<input disabled=\"disabled\"type=\"hidden\" name=\"post[category][]\" value=\"\"/><select multiple=\"multiple\" disabled=\"disabled\" id=\"post_category\" name=\"post[category][]\"></select>",
      output_buffer
    )
  end

  def test_select_with_blank
    @post = Post.new
    @post.category = "<mus>"
    assert_dom_equal(
      "<select id=\"post_category\" name=\"post[category]\"><option value=\"\" label=\" \"></option>\n<option value=\"abe\">abe</option>\n<option value=\"&lt;mus&gt;\" selected=\"selected\">&lt;mus&gt;</option>\n<option value=\"hest\">hest</option></select>",
      select("post", "category", %w( abe <mus> hest), include_blank: true)
    )
  end

  def test_select_with_include_blank_false_and_required
    @post = Post.new
    @post.category = "<mus>"
    e = assert_raises(ArgumentError) { select("post", "category", %w( abe <mus> hest), { include_blank: false }, { required: "required" }) }
    assert_match(/include_blank cannot be false for a required field./, e.message)
  end

  def test_select_with_blank_as_string
    @post = Post.new
    @post.category = "<mus>"
    assert_dom_equal(
      "<select id=\"post_category\" name=\"post[category]\"><option value=\"\">None</option>\n<option value=\"abe\">abe</option>\n<option value=\"&lt;mus&gt;\" selected=\"selected\">&lt;mus&gt;</option>\n<option value=\"hest\">hest</option></select>",
      select("post", "category", %w( abe <mus> hest), include_blank: "None")
    )
  end

  def test_select_with_blank_as_string_escaped
    @post = Post.new
    @post.category = "<mus>"
    assert_dom_equal(
      "<select id=\"post_category\" name=\"post[category]\"><option value=\"\">&lt;None&gt;</option>\n<option value=\"abe\">abe</option>\n<option value=\"&lt;mus&gt;\" selected=\"selected\">&lt;mus&gt;</option>\n<option value=\"hest\">hest</option></select>",
      select("post", "category", %w( abe <mus> hest), include_blank: "<None>")
    )
  end

  def test_select_with_default_prompt
    @post = Post.new
    @post.category = ""
    assert_dom_equal(
      "<select id=\"post_category\" name=\"post[category]\"><option value=\"\">Please select</option>\n<option value=\"abe\">abe</option>\n<option value=\"&lt;mus&gt;\">&lt;mus&gt;</option>\n<option value=\"hest\">hest</option></select>",
      select("post", "category", %w( abe <mus> hest), prompt: true)
    )
  end

  def test_select_no_prompt_when_select_has_value
    @post = Post.new
    @post.category = "<mus>"
    assert_dom_equal(
      "<select id=\"post_category\" name=\"post[category]\"><option value=\"abe\">abe</option>\n<option value=\"&lt;mus&gt;\" selected=\"selected\">&lt;mus&gt;</option>\n<option value=\"hest\">hest</option></select>",
      select("post", "category", %w( abe <mus> hest), prompt: true)
    )
  end

  def test_select_with_given_prompt
    @post = Post.new
    @post.category = ""
    assert_dom_equal(
      "<select id=\"post_category\" name=\"post[category]\"><option value=\"\">The prompt</option>\n<option value=\"abe\">abe</option>\n<option value=\"&lt;mus&gt;\">&lt;mus&gt;</option>\n<option value=\"hest\">hest</option></select>",
      select("post", "category", %w( abe <mus> hest), prompt: "The prompt")
    )
  end

  def test_select_with_given_prompt_escaped
    @post = Post.new
    assert_dom_equal(
      "<select id=\"post_category\" name=\"post[category]\"><option value=\"\">&lt;The prompt&gt;</option>\n<option value=\"abe\">abe</option>\n<option value=\"&lt;mus&gt;\">&lt;mus&gt;</option>\n<option value=\"hest\">hest</option></select>",
      select("post", "category", %w( abe <mus> hest), prompt: "<The prompt>")
    )
  end

  def test_select_with_prompt_and_blank
    @post = Post.new
    @post.category = ""
    assert_dom_equal(
      "<select id=\"post_category\" name=\"post[category]\"><option value=\"\">Please select</option>\n<option value=\"\" label=\" \"></option>\n<option value=\"abe\">abe</option>\n<option value=\"&lt;mus&gt;\">&lt;mus&gt;</option>\n<option value=\"hest\">hest</option></select>",
      select("post", "category", %w( abe <mus> hest), prompt: true, include_blank: true)
    )
  end

  def test_select_with_empty
    @post = Post.new
    @post.category = ""
    assert_dom_equal(
      "<select id=\"post_category\" name=\"post[category]\"><option value=\"\">Please select</option>\n<option value=\"\" label=\" \"></option>\n</select>",
      select("post", "category", [], prompt: true, include_blank: true)
    )
  end

  def test_select_with_html_options
    @post = Post.new
    @post.category = ""
    assert_dom_equal(
      "<select class=\"disabled\" disabled=\"disabled\" name=\"post[category]\" id=\"post_category\"><option value=\"\">Please select</option>\n<option value=\"\" label=\" \"></option>\n</select>",
      select("post", "category", [], { prompt: true, include_blank: true }, { class: "disabled", disabled: true })
    )
  end

  def test_select_with_nil
    @post = Post.new
    @post.category = "othervalue"
    assert_dom_equal(
      "<select id=\"post_category\" name=\"post[category]\"><option value=\"\"></option>\n<option value=\"othervalue\" selected=\"selected\">othervalue</option></select>",
      select("post", "category", [nil, "othervalue"])
    )
  end

  def test_select_with_nil_as_selected_value
    @post = Post.new
    @post.category = nil
    assert_dom_equal(
      "<select name=\"post[category]\" id=\"post_category\"><option selected=\"selected\" value=\"\">none</option>\n<option value=\"1\">programming</option>\n<option value=\"2\">economics</option></select>",
      select("post", "category", none: nil, programming: 1, economics: 2)
    )
  end

  def test_select_with_nil_and_selected_option_as_nil
    @post = Post.new
    @post.category = nil
    assert_dom_equal(
      "<select name=\"post[category]\" id=\"post_category\"><option value=\"\">none</option>\n<option value=\"1\">programming</option>\n<option value=\"2\">economics</option></select>",
      select("post", "category", { none: nil, programming: 1, economics: 2 }, { selected: nil })
    )
  end

  def test_required_select
    assert_dom_equal(
      %(<select id="post_category" name="post[category]" required="required"><option value="" label=" "></option>\n<option value="abe">abe</option>\n<option value="mus">mus</option>\n<option value="hest">hest</option></select>),
      select("post", "category", %w(abe mus hest), {}, { required: true })
    )
  end

  def test_required_select_with_include_blank_prompt
    assert_dom_equal(
      %(<select id="post_category" name="post[category]" required="required"><option value="">Select one</option>\n<option value="abe">abe</option>\n<option value="mus">mus</option>\n<option value="hest">hest</option></select>),
      select("post", "category", %w(abe mus hest), { include_blank: "Select one" }, { required: true })
    )
  end

  def test_required_select_with_prompt
    assert_dom_equal(
      %(<select id="post_category" name="post[category]" required="required"><option value="">Select one</option>\n<option value="abe">abe</option>\n<option value="mus">mus</option>\n<option value="hest">hest</option></select>),
      select("post", "category", %w(abe mus hest), { prompt: "Select one" }, { required: true })
    )
  end

  def test_required_select_display_size_equals_to_one
    assert_dom_equal(
      %(<select id="post_category" name="post[category]" required="required" size="1"><option value="" label=" "></option>\n<option value="abe">abe</option>\n<option value="mus">mus</option>\n<option value="hest">hest</option></select>),
      select("post", "category", %w(abe mus hest), {}, { required: true, size: 1 })
    )
  end

  def test_required_select_with_display_size_bigger_than_one
    assert_dom_equal(
      %(<select id="post_category" name="post[category]" required="required" size="2"><option value="abe">abe</option>\n<option value="mus">mus</option>\n<option value="hest">hest</option></select>),
      select("post", "category", %w(abe mus hest), {}, { required: true, size: 2 })
    )
  end

  def test_required_select_with_multiple_option
    assert_dom_equal(
      %(<input name="post[category][]" type="hidden" value=""/><select id="post_category" multiple="multiple" name="post[category][]" required="required"><option value="abe">abe</option>\n<option value="mus">mus</option>\n<option value="hest">hest</option></select>),
      select("post", "category", %w(abe mus hest), {}, { required: true, multiple: true })
    )
  end

  def test_select_with_integer
    @post = Post.new
    @post.category = ""
    assert_dom_equal(
      "<select id=\"post_category\" name=\"post[category]\"><option value=\"\">Please select</option>\n<option value=\"\" label=\" \"></option>\n<option value=\"1\">1</option></select>",
      select("post", "category", [1], prompt: true, include_blank: true)
    )
  end

  def test_list_of_lists
    @post = Post.new
    @post.category = ""
    assert_dom_equal(
      "<select id=\"post_category\" name=\"post[category]\"><option value=\"\">Please select</option>\n<option value=\"\" label=\" \"></option>\n<option value=\"number\">Number</option>\n<option value=\"text\">Text</option>\n<option value=\"boolean\">Yes/No</option></select>",
      select("post", "category", [["Number", "number"], ["Text", "text"], ["Yes/No", "boolean"]], prompt: true, include_blank: true)
    )
  end

  def test_select_with_selected_value
    @post = Post.new
    @post.category = "<mus>"
    assert_dom_equal(
      "<select id=\"post_category\" name=\"post[category]\"><option value=\"abe\" selected=\"selected\">abe</option>\n<option value=\"&lt;mus&gt;\">&lt;mus&gt;</option>\n<option value=\"hest\">hest</option></select>",
      select("post", "category", %w( abe <mus> hest ), selected: "abe")
    )
  end

  def test_select_with_index_option
    @album = Album.new
    @album.id = 1

    expected = "<select id=\"album__genre\" name=\"album[][genre]\"><option value=\"rap\">rap</option>\n<option value=\"rock\">rock</option>\n<option value=\"country\">country</option></select>"

    assert_dom_equal(
      expected,
      select("album[]", "genre", %w[rap rock country], {}, { index: nil })
    )
  end

  def test_select_escapes_options
    assert_dom_equal(
      '<select id="post_title" name="post[title]">&lt;script&gt;alert(1)&lt;/script&gt;</select>',
      select("post", "title", "<script>alert(1)</script>")
    )
  end

  def test_select_with_selected_nil
    @post = Post.new
    @post.category = "<mus>"
    assert_dom_equal(
      "<select id=\"post_category\" name=\"post[category]\"><option value=\"abe\">abe</option>\n<option value=\"&lt;mus&gt;\">&lt;mus&gt;</option>\n<option value=\"hest\">hest</option></select>",
      select("post", "category", %w( abe <mus> hest ), selected: nil)
    )
  end

  def test_select_with_disabled_value
    @post = Post.new
    @post.category = "<mus>"
    assert_dom_equal(
      "<select id=\"post_category\" name=\"post[category]\"><option value=\"abe\">abe</option>\n<option value=\"&lt;mus&gt;\" selected=\"selected\">&lt;mus&gt;</option>\n<option value=\"hest\" disabled=\"disabled\">hest</option></select>",
      select("post", "category", %w( abe <mus> hest ), disabled: "hest")
    )
  end

  def test_select_not_existing_method_with_selected_value
    @post = Post.new
    assert_dom_equal(
      "<select id=\"post_locale\" name=\"post[locale]\"><option value=\"en\">en</option>\n<option value=\"ru\" selected=\"selected\">ru</option></select>",
      select("post", "locale", %w( en ru ), selected: "ru")
    )
  end

  def test_select_with_prompt_and_selected_value
    @post = Post.new
    assert_dom_equal(
      "<select id=\"post_category\" name=\"post[category]\"><option value=\"one\">one</option>\n<option selected=\"selected\" value=\"two\">two</option></select>",
      select("post", "category", %w( one two ), selected: "two", prompt: true)
    )
  end

  def test_select_with_disabled_array
    @post = Post.new
    @post.category = "<mus>"
    assert_dom_equal(
      "<select id=\"post_category\" name=\"post[category]\"><option value=\"abe\" disabled=\"disabled\">abe</option>\n<option value=\"&lt;mus&gt;\" selected=\"selected\">&lt;mus&gt;</option>\n<option value=\"hest\" disabled=\"disabled\">hest</option></select>",
      select("post", "category", %w( abe <mus> hest ), disabled: ["hest", "abe"])
    )
  end

  def test_select_with_range
    @post = Post.new
    @post.category = 0
    assert_dom_equal(
      "<select id=\"post_category\" name=\"post[category]\"><option value=\"1\">1</option>\n<option value=\"2\">2</option>\n<option value=\"3\">3</option></select>",
      select("post", "category", 1..3)
    )
  end

  def test_select_with_enumerable
    @post = Post.new
    assert_dom_equal(
      "<select id=\"post_category\" name=\"post[category]\"><option value=\"one\">one</option>\n<option value=\"two\">two</option></select>",
      select("post", "category", CustomEnumerable.new)
    )
  end

  def test_collection_select
    @post = Post.new
    @post.author_name = "Babe"

    assert_dom_equal(
      "<select id=\"post_author_name\" name=\"post[author_name]\"><option value=\"&lt;Abe&gt;\">&lt;Abe&gt;</option>\n<option value=\"Babe\" selected=\"selected\">Babe</option>\n<option value=\"Cabe\">Cabe</option></select>",
      collection_select("post", "author_name", dummy_posts, "author_name", "author_name")
    )
  end

  def test_collection_select_with_grouped_collection_as_nested_array
    @post = Post.new
    @post.origin = "dk"

    assert_dom_equal(
      %Q{<select id="post_origin" name="post[origin]"><optgroup label="&lt;Africa&gt;"><option value="&lt;sa&gt;">&lt;South Africa&gt;</option>\n<option value="so">Somalia</option></optgroup><optgroup label="Europe"><option value="dk" selected="selected">Denmark</option>\n<option value="ie">Ireland</option></optgroup></select>},
      collection_select("post", "origin", dummy_continents.pluck(:continent_name, :countries), :country_id, :country_name)
    )
  end

  def test_collection_select_with_grouped_collection_as_hash
    @post = Post.new
    @post.origin = "dk"

    assert_dom_equal(
      %Q{<select id="post_origin" name="post[origin]"><optgroup label="&lt;Africa&gt;"><option value="&lt;sa&gt;">&lt;South Africa&gt;</option>\n<option value="so">Somalia</option></optgroup><optgroup label="Europe"><option value="dk" selected="selected">Denmark</option>\n<option value="ie">Ireland</option></optgroup></select>},
      collection_select("post", "origin", dummy_continents.pluck(:continent_name, :countries).to_h, :country_id, :country_name)
    )
  end

  def test_collection_select_under_fields_for
    @post = Post.new
    @post.author_name = "Babe"

    output_buffer = fields_for :post, @post do |f|
      concat f.collection_select(:author_name, dummy_posts, :author_name, :author_name)
    end

    assert_dom_equal(
      "<select id=\"post_author_name\" name=\"post[author_name]\"><option value=\"&lt;Abe&gt;\">&lt;Abe&gt;</option>\n<option value=\"Babe\" selected=\"selected\">Babe</option>\n<option value=\"Cabe\">Cabe</option></select>",
      output_buffer
    )
  end

  def test_collection_select_under_fields_for_with_index
    @post = Post.new
    @post.author_name = "Babe"

    output_buffer = fields_for :post, @post, index: 815 do |f|
      concat f.collection_select(:author_name, dummy_posts, :author_name, :author_name)
    end

    assert_dom_equal(
      "<select id=\"post_815_author_name\" name=\"post[815][author_name]\"><option value=\"&lt;Abe&gt;\">&lt;Abe&gt;</option>\n<option value=\"Babe\" selected=\"selected\">Babe</option>\n<option value=\"Cabe\">Cabe</option></select>",
      output_buffer
    )
  end

  def test_collection_select_under_fields_for_with_auto_index
    @post = Post.new
    @post.author_name = "Babe"
    def @post.to_param; 815; end

    output_buffer = fields_for "post[]", @post do |f|
      concat f.collection_select(:author_name, dummy_posts, :author_name, :author_name)
    end

    assert_dom_equal(
      "<select id=\"post_815_author_name\" name=\"post[815][author_name]\"><option value=\"&lt;Abe&gt;\">&lt;Abe&gt;</option>\n<option value=\"Babe\" selected=\"selected\">Babe</option>\n<option value=\"Cabe\">Cabe</option></select>",
      output_buffer
    )
  end

  def test_collection_select_with_blank_and_style
    @post = Post.new
    @post.author_name = "Babe"

    assert_dom_equal(
      "<select id=\"post_author_name\" name=\"post[author_name]\" style=\"width: 200px\"><option value=\"\" label=\" \"></option>\n<option value=\"&lt;Abe&gt;\">&lt;Abe&gt;</option>\n<option value=\"Babe\" selected=\"selected\">Babe</option>\n<option value=\"Cabe\">Cabe</option></select>",
      collection_select("post", "author_name", dummy_posts, "author_name", "author_name", { include_blank: true }, { "style" => "width: 200px" })
    )
  end

  def test_collection_select_with_blank_as_string_and_style
    @post = Post.new
    @post.author_name = "Babe"

    assert_dom_equal(
      "<select id=\"post_author_name\" name=\"post[author_name]\" style=\"width: 200px\"><option value=\"\">No Selection</option>\n<option value=\"&lt;Abe&gt;\">&lt;Abe&gt;</option>\n<option value=\"Babe\" selected=\"selected\">Babe</option>\n<option value=\"Cabe\">Cabe</option></select>",
      collection_select("post", "author_name", dummy_posts, "author_name", "author_name", { include_blank: "No Selection" }, { "style" => "width: 200px" })
    )
  end

  def test_collection_select_with_multiple_option_appends_array_brackets_and_hidden_input
    @post = Post.new
    @post.author_name = "Babe"

    expected = "<input type=\"hidden\" name=\"post[author_name][]\" value=\"\"/><select id=\"post_author_name\" name=\"post[author_name][]\" multiple=\"multiple\"><option value=\"\" label=\" \"></option>\n<option value=\"&lt;Abe&gt;\">&lt;Abe&gt;</option>\n<option value=\"Babe\" selected=\"selected\">Babe</option>\n<option value=\"Cabe\">Cabe</option></select>"

    # Should suffix default name with [].
    assert_dom_equal expected, collection_select("post", "author_name", dummy_posts, "author_name", "author_name", { include_blank: true }, { multiple: true })

    # Shouldn't suffix custom name with [].
    assert_dom_equal expected, collection_select("post", "author_name", dummy_posts, "author_name", "author_name", { include_blank: true, name: "post[author_name][]" }, { multiple: true })
  end

  def test_collection_select_with_blank_and_selected
    @post = Post.new
    @post.author_name = "Babe"

    assert_dom_equal(
      %{<select id="post_author_name" name="post[author_name]"><option value="" label=" "></option>\n<option value="&lt;Abe&gt;" selected="selected">&lt;Abe&gt;</option>\n<option value="Babe">Babe</option>\n<option value="Cabe">Cabe</option></select>},
      collection_select("post", "author_name", dummy_posts, "author_name", "author_name", include_blank: true, selected: "<Abe>")
    )
  end

  def test_collection_select_with_disabled
    @post = Post.new
    @post.author_name = "Babe"

    assert_dom_equal(
      "<select id=\"post_author_name\" name=\"post[author_name]\"><option value=\"&lt;Abe&gt;\">&lt;Abe&gt;</option>\n<option value=\"Babe\" selected=\"selected\">Babe</option>\n<option value=\"Cabe\" disabled=\"disabled\">Cabe</option></select>",
      collection_select("post", "author_name", dummy_posts, "author_name", "author_name", disabled: "Cabe")
    )
  end

  def test_collection_select_with_proc_for_value_method
    @post = Post.new

    assert_dom_equal(
      "<select id=\"post_author_name\" name=\"post[author_name]\"><option value=\"&lt;Abe&gt;\">&lt;Abe&gt; went home</option>\n<option value=\"Babe\">Babe went home</option>\n<option value=\"Cabe\">Cabe went home</option></select>",
      collection_select("post", "author_name", dummy_posts, lambda { |p| p.author_name }, "title")
    )
  end

  def test_collection_select_with_proc_for_text_method
    @post = Post.new

    assert_dom_equal(
      "<select id=\"post_author_name\" name=\"post[author_name]\"><option value=\"&lt;Abe&gt;\">&lt;Abe&gt; went home</option>\n<option value=\"Babe\">Babe went home</option>\n<option value=\"Cabe\">Cabe went home</option></select>",
      collection_select("post", "author_name", dummy_posts, "author_name", lambda { |p| p.title })
    )
  end

  def test_time_zone_select
    @firm = Firm.new("D")
    html = time_zone_select("firm", "time_zone")
    assert_dom_equal "<select id=\"firm_time_zone\" name=\"firm[time_zone]\">" \
                 "<option value=\"A\">A</option>\n" \
                 "<option value=\"B\">B</option>\n" \
                 "<option value=\"C\">C</option>\n" \
                 "<option value=\"D\" selected=\"selected\">D</option>\n" \
                 "<option value=\"E\">E</option>" \
                 "</select>",
                 html
  end

  def test_time_zone_select_under_fields_for
    @firm = Firm.new("D")

    output_buffer = fields_for :firm, @firm do |f|
      concat f.time_zone_select(:time_zone)
    end

    assert_dom_equal(
      "<select id=\"firm_time_zone\" name=\"firm[time_zone]\">" \
      "<option value=\"A\">A</option>\n" \
      "<option value=\"B\">B</option>\n" \
      "<option value=\"C\">C</option>\n" \
      "<option value=\"D\" selected=\"selected\">D</option>\n" \
      "<option value=\"E\">E</option>" \
      "</select>",
      output_buffer
    )
  end

  def test_time_zone_select_under_fields_for_with_index
    @firm = Firm.new("D")

    output_buffer = fields_for :firm, @firm, index: 305 do |f|
      concat f.time_zone_select(:time_zone)
    end

    assert_dom_equal(
      "<select id=\"firm_305_time_zone\" name=\"firm[305][time_zone]\">" \
      "<option value=\"A\">A</option>\n" \
      "<option value=\"B\">B</option>\n" \
      "<option value=\"C\">C</option>\n" \
      "<option value=\"D\" selected=\"selected\">D</option>\n" \
      "<option value=\"E\">E</option>" \
      "</select>",
      output_buffer
    )
  end

  def test_time_zone_select_under_fields_for_with_auto_index
    @firm = Firm.new("D")
    def @firm.to_param; 305; end

    output_buffer = fields_for "firm[]", @firm do |f|
      concat f.time_zone_select(:time_zone)
    end

    assert_dom_equal(
      "<select id=\"firm_305_time_zone\" name=\"firm[305][time_zone]\">" \
      "<option value=\"A\">A</option>\n" \
      "<option value=\"B\">B</option>\n" \
      "<option value=\"C\">C</option>\n" \
      "<option value=\"D\" selected=\"selected\">D</option>\n" \
      "<option value=\"E\">E</option>" \
      "</select>",
      output_buffer
    )
  end

  def test_time_zone_select_with_blank
    @firm = Firm.new("D")
    html = time_zone_select("firm", "time_zone", nil, include_blank: true)
    assert_dom_equal "<select id=\"firm_time_zone\" name=\"firm[time_zone]\">" \
                 "<option value=\"\" label=\" \"></option>\n" \
                 "<option value=\"A\">A</option>\n" \
                 "<option value=\"B\">B</option>\n" \
                 "<option value=\"C\">C</option>\n" \
                 "<option value=\"D\" selected=\"selected\">D</option>\n" \
                 "<option value=\"E\">E</option>" \
                 "</select>",
                 html
  end

  def test_time_zone_select_with_blank_as_string
    @firm = Firm.new("D")
    html = time_zone_select("firm", "time_zone", nil, include_blank: "No Zone")
    assert_dom_equal "<select id=\"firm_time_zone\" name=\"firm[time_zone]\">" \
                 "<option value=\"\">No Zone</option>\n" \
                 "<option value=\"A\">A</option>\n" \
                 "<option value=\"B\">B</option>\n" \
                 "<option value=\"C\">C</option>\n" \
                 "<option value=\"D\" selected=\"selected\">D</option>\n" \
                 "<option value=\"E\">E</option>" \
                 "</select>",
                 html
  end

  def test_time_zone_select_with_style
    @firm = Firm.new("D")
    html = time_zone_select("firm", "time_zone", nil, {},
      { "style" => "color: red" })
    assert_dom_equal "<select id=\"firm_time_zone\" name=\"firm[time_zone]\" style=\"color: red\">" \
                 "<option value=\"A\">A</option>\n" \
                 "<option value=\"B\">B</option>\n" \
                 "<option value=\"C\">C</option>\n" \
                 "<option value=\"D\" selected=\"selected\">D</option>\n" \
                 "<option value=\"E\">E</option>" \
                 "</select>",
                 html
    assert_dom_equal html, time_zone_select("firm", "time_zone", nil, {},
      { style: "color: red" })
  end

  def test_time_zone_select_with_blank_and_style
    @firm = Firm.new("D")
    html = time_zone_select("firm", "time_zone", nil,
      { include_blank: true }, { "style" => "color: red" })
    assert_dom_equal "<select id=\"firm_time_zone\" name=\"firm[time_zone]\" style=\"color: red\">" \
                 "<option value=\"\" label=\" \"></option>\n" \
                 "<option value=\"A\">A</option>\n" \
                 "<option value=\"B\">B</option>\n" \
                 "<option value=\"C\">C</option>\n" \
                 "<option value=\"D\" selected=\"selected\">D</option>\n" \
                 "<option value=\"E\">E</option>" \
                 "</select>",
                 html
    assert_dom_equal html, time_zone_select("firm", "time_zone", nil,
      { include_blank: true }, { style: "color: red" })
  end

  def test_time_zone_select_with_blank_as_string_and_style
    @firm = Firm.new("D")
    html = time_zone_select("firm", "time_zone", nil,
      { include_blank: "No Zone" }, { "style" => "color: red" })
    assert_dom_equal "<select id=\"firm_time_zone\" name=\"firm[time_zone]\" style=\"color: red\">" \
                 "<option value=\"\">No Zone</option>\n" \
                 "<option value=\"A\">A</option>\n" \
                 "<option value=\"B\">B</option>\n" \
                 "<option value=\"C\">C</option>\n" \
                 "<option value=\"D\" selected=\"selected\">D</option>\n" \
                 "<option value=\"E\">E</option>" \
                 "</select>",
                 html
    assert_dom_equal html, time_zone_select("firm", "time_zone", nil,
      { include_blank: "No Zone" }, { style: "color: red" })
  end

  def test_time_zone_select_with_priority_zones
    @firm = Firm.new("D")
    zones = [ ActiveSupport::TimeZone.new("A"), ActiveSupport::TimeZone.new("D") ]
    html = time_zone_select("firm", "time_zone", zones)
    assert_dom_equal "<select id=\"firm_time_zone\" name=\"firm[time_zone]\">" \
                 "<option value=\"A\">A</option>\n" \
                 "<option value=\"D\" selected=\"selected\">D</option>" \
                 "<option value=\"\" disabled=\"disabled\">-------------</option>\n" \
                 "<option value=\"B\">B</option>\n" \
                 "<option value=\"C\">C</option>\n" \
                 "<option value=\"E\">E</option>" \
                 "</select>",
                 html
  end

  def test_time_zone_select_with_priority_zones_as_regexp
    @firm = Firm.new("D")

    @fake_timezones.each do |tz|
      def tz.=~(re); %(A D).include?(name) end
      def tz.match?(re); %(A D).include?(name) end
    end

    html = time_zone_select("firm", "time_zone", /A|D/)
    assert_dom_equal "<select id=\"firm_time_zone\" name=\"firm[time_zone]\">" \
                 "<option value=\"A\">A</option>\n" \
                 "<option value=\"D\" selected=\"selected\">D</option>" \
                 "<option value=\"\" disabled=\"disabled\">-------------</option>\n" \
                 "<option value=\"B\">B</option>\n" \
                 "<option value=\"C\">C</option>\n" \
                 "<option value=\"E\">E</option>" \
                 "</select>",
                 html
  end

  def test_time_zone_select_with_priority_zones_is_not_implemented_with_grep
    @firm = Firm.new("D")

    # `time_zone_select` can't be written with `grep` because Active Support
    # time zones don't support implicit string coercion with `to_str`.
    @fake_timezones.each do |tz|
      def tz.===(zone); raise Exception; end
    end

    html = time_zone_select("firm", "time_zone", /A|D/)
    assert_dom_equal "<select id=\"firm_time_zone\" name=\"firm[time_zone]\">" \
                 "<option value=\"\" disabled=\"disabled\">-------------</option>\n" \
                 "<option value=\"A\">A</option>\n" \
                 "<option value=\"B\">B</option>\n" \
                 "<option value=\"C\">C</option>\n" \
                 "<option value=\"D\" selected=\"selected\">D</option>\n" \
                 "<option value=\"E\">E</option>" \
                 "</select>",
                 html
  end

  def test_time_zone_select_with_priority_zones_and_errors
    @firm = Firm.new("D")
    @firm.extend ActiveModel::Validations
    assert_deprecated { @firm.errors[:time_zone] << "invalid" }
    zones = [ ActiveSupport::TimeZone.new("A"), ActiveSupport::TimeZone.new("D") ]
    html = time_zone_select("firm", "time_zone", zones)
    assert_dom_equal "<div class=\"field_with_errors\">" \
                 "<select id=\"firm_time_zone\" name=\"firm[time_zone]\">" \
                 "<option value=\"A\">A</option>\n" \
                 "<option value=\"D\" selected=\"selected\">D</option>" \
                 "<option value=\"\" disabled=\"disabled\">-------------</option>\n" \
                 "<option value=\"B\">B</option>\n" \
                 "<option value=\"C\">C</option>\n" \
                 "<option value=\"E\">E</option>" \
                 "</select>" \
                 "</div>",
                 html
  end

  def test_time_zone_select_with_default_time_zone_and_nil_value
    @firm = Firm.new()
    @firm.time_zone = nil

    html = time_zone_select("firm", "time_zone", nil, default: "B")
    assert_dom_equal "<select id=\"firm_time_zone\" name=\"firm[time_zone]\">" \
                  "<option value=\"A\">A</option>\n" \
                  "<option value=\"B\" selected=\"selected\">B</option>\n" \
                  "<option value=\"C\">C</option>\n" \
                  "<option value=\"D\">D</option>\n" \
                  "<option value=\"E\">E</option>" \
                  "</select>",
                  html
  end

  def test_time_zone_select_with_default_time_zone_and_value
    @firm = Firm.new("D")

    html = time_zone_select("firm", "time_zone", nil, default: "B")
    assert_dom_equal "<select id=\"firm_time_zone\" name=\"firm[time_zone]\">" \
                  "<option value=\"A\">A</option>\n" \
                  "<option value=\"B\">B</option>\n" \
                  "<option value=\"C\">C</option>\n" \
                  "<option value=\"D\" selected=\"selected\">D</option>\n" \
                  "<option value=\"E\">E</option>" \
                  "</select>",
                  html
  end

  def test_options_for_select_with_element_attributes
    assert_dom_equal(
      "<option value=\"&lt;Denmark&gt;\" class=\"bold\">&lt;Denmark&gt;</option>\n<option value=\"USA\" onclick=\"alert(&#39;Hello World&#39;);\">USA</option>\n<option value=\"Sweden\">Sweden</option>\n<option value=\"Germany\">Germany</option>",
      options_for_select([ [ "<Denmark>", { class: "bold" } ], [ "USA", { onclick: "alert('Hello World');" } ], [ "Sweden" ], "Germany" ])
    )
  end

  def test_options_for_select_with_data_element
    assert_dom_equal(
      "<option value=\"&lt;Denmark&gt;\" data-test=\"bold\">&lt;Denmark&gt;</option>",
      options_for_select([ [ "<Denmark>", { data: { test: "bold" } } ] ])
    )
  end

  def test_options_for_select_with_data_element_with_special_characters
    assert_dom_equal(
      "<option value=\"&lt;Denmark&gt;\" data-test=\"&lt;bold&gt;\">&lt;Denmark&gt;</option>",
      options_for_select([ [ "<Denmark>", { data: { test: "<bold>" } } ] ])
    )
  end

  def test_options_for_select_with_element_attributes_and_selection
    assert_dom_equal(
      "<option value=\"&lt;Denmark&gt;\">&lt;Denmark&gt;</option>\n<option value=\"USA\" class=\"bold\" selected=\"selected\">USA</option>\n<option value=\"Sweden\">Sweden</option>",
      options_for_select([ "<Denmark>", [ "USA", { class: "bold" } ], "Sweden" ], "USA")
    )
  end

  def test_options_for_select_with_element_attributes_and_selection_array
    assert_dom_equal(
      "<option value=\"&lt;Denmark&gt;\">&lt;Denmark&gt;</option>\n<option value=\"USA\" class=\"bold\" selected=\"selected\">USA</option>\n<option value=\"Sweden\" selected=\"selected\">Sweden</option>",
      options_for_select([ "<Denmark>", [ "USA", { class: "bold" } ], "Sweden" ], [ "USA", "Sweden" ])
    )
  end

  def test_options_for_select_with_special_characters
    assert_dom_equal(
      "<option value=\"&lt;Denmark&gt;\" onclick=\"alert(&quot;&lt;code&gt;&quot;)\">&lt;Denmark&gt;</option>",
      options_for_select([ [ "<Denmark>", { onclick: %(alert("<code>")) } ] ])
    )
  end

  def test_option_html_attributes_with_no_array_element
    assert_equal({}, option_html_attributes("foo"))
  end

  def test_option_html_attributes_without_hash
    assert_equal({}, option_html_attributes([ "foo", "bar" ]))
  end

  def test_option_html_attributes_with_single_element_hash
    assert_equal(
      { class: "fancy" },
      option_html_attributes([ "foo", "bar", { class: "fancy" } ])
    )
  end

  def test_option_html_attributes_with_multiple_element_hash
    assert_equal(
      { :class => "fancy", "onclick" => "alert('Hello World');" },
      option_html_attributes([ "foo", "bar", { :class => "fancy", "onclick" => "alert('Hello World');" } ])
    )
  end

  def test_option_html_attributes_with_multiple_hashes
    assert_equal(
      { :class => "fancy", "onclick" => "alert('Hello World');" },
      option_html_attributes([ "foo", "bar", { class: "fancy" }, { "onclick" => "alert('Hello World');" } ])
    )
  end

  def test_option_html_attributes_with_multiple_hashes_does_not_modify_them
    options1 = { class: "fancy" }
    options2 = { onclick: "alert('Hello World');" }
    option_html_attributes([ "foo", "bar", options1, options2 ])

    assert_equal({ class: "fancy" }, options1)
    assert_equal({ onclick: "alert('Hello World');" }, options2)
  end

  def test_grouped_collection_select
    @post = Post.new
    @post.origin = "dk"

    assert_dom_equal(
      %Q{<select id="post_origin" name="post[origin]"><optgroup label="&lt;Africa&gt;"><option value="&lt;sa&gt;">&lt;South Africa&gt;</option>\n<option value="so">Somalia</option></optgroup><optgroup label="Europe"><option value="dk" selected="selected">Denmark</option>\n<option value="ie">Ireland</option></optgroup></select>},
      grouped_collection_select("post", "origin", dummy_continents, :countries, :continent_name, :country_id, :country_name)
    )
  end

  def test_grouped_collection_select_with_selected
    @post = Post.new

    assert_dom_equal(
      %Q{<select id="post_origin" name="post[origin]"><optgroup label="&lt;Africa&gt;"><option value="&lt;sa&gt;">&lt;South Africa&gt;</option>\n<option value="so">Somalia</option></optgroup><optgroup label="Europe"><option value="dk" selected="selected">Denmark</option>\n<option value="ie">Ireland</option></optgroup></select>},
      grouped_collection_select("post", "origin", dummy_continents, :countries, :continent_name, :country_id, :country_name, selected: "dk")
    )
  end

  def test_grouped_collection_select_with_disabled_value
    @post = Post.new

    assert_dom_equal(
      %Q{<select id="post_origin" name="post[origin]"><optgroup label="&lt;Africa&gt;"><option value="&lt;sa&gt;">&lt;South Africa&gt;</option>\n<option value="so">Somalia</option></optgroup><optgroup label="Europe"><option disabled="disabled" value="dk">Denmark</option>\n<option value="ie">Ireland</option></optgroup></select>},
      grouped_collection_select("post", "origin", dummy_continents, :countries, :continent_name, :country_id, :country_name, disabled: "dk")
    )
  end

  def test_grouped_collection_select_under_fields_for
    @post = Post.new
    @post.origin = "dk"

    output_buffer = fields_for :post, @post do |f|
      concat f.grouped_collection_select("origin", dummy_continents, :countries, :continent_name, :country_id, :country_name)
    end

    assert_dom_equal(
      %Q{<select id="post_origin" name="post[origin]"><optgroup label="&lt;Africa&gt;"><option value="&lt;sa&gt;">&lt;South Africa&gt;</option>\n<option value="so">Somalia</option></optgroup><optgroup label="Europe"><option value="dk" selected="selected">Denmark</option>\n<option value="ie">Ireland</option></optgroup></select>},
      output_buffer
    )
  end

  private
    def dummy_posts
      [ Post.new("<Abe> went home", "<Abe>", "To a little house", "shh!"),
        Post.new("Babe went home", "Babe", "To a little house", "shh!"),
        Post.new("Cabe went home", "Cabe", "To a little house", "shh!") ]
    end

    def dummy_continents
      [ Continent.new("<Africa>", [Country.new("<sa>", "<South Africa>"), Country.new("so", "Somalia")]),
        Continent.new("Europe", [Country.new("dk", "Denmark"), Country.new("ie", "Ireland")]) ]
    end
end
