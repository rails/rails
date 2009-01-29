require 'abstract_unit'
require 'tzinfo'

TZInfo::Timezone.cattr_reader :loaded_zones

uses_mocha "FormOptionsHelperTest" do
  class FormOptionsHelperTest < ActionView::TestCase
    tests ActionView::Helpers::FormOptionsHelper

    silence_warnings do
      Post        = Struct.new('Post', :title, :author_name, :body, :secret, :written_on, :category, :origin)
      Continent   = Struct.new('Continent', :continent_name, :countries)
      Country     = Struct.new('Country', :country_id, :country_name)
      Firm        = Struct.new('Firm', :time_zone)
      Album       = Struct.new('Album', :id, :title, :genre)
    end

    def setup
      @fake_timezones = %w(A B C D E).inject([]) do |zones, id|
        tz = TZInfo::Timezone.loaded_zones[id] = stub(:name => id, :to_s => id)
        ActiveSupport::TimeZone.stubs(:[]).with(id).returns(tz)
        zones << tz
      end
      ActiveSupport::TimeZone.stubs(:all).returns(@fake_timezones)
    end

    def test_collection_options
      @posts = [
        Post.new("<Abe> went home", "<Abe>", "To a little house", "shh!"),
        Post.new("Babe went home", "Babe", "To a little house", "shh!"),
        Post.new("Cabe went home", "Cabe", "To a little house", "shh!")
      ]

      assert_dom_equal(
        "<option value=\"&lt;Abe&gt;\">&lt;Abe&gt; went home</option>\n<option value=\"Babe\">Babe went home</option>\n<option value=\"Cabe\">Cabe went home</option>",
        options_from_collection_for_select(@posts, "author_name", "title")
      )
    end


    def test_collection_options_with_preselected_value
      @posts = [
        Post.new("<Abe> went home", "<Abe>", "To a little house", "shh!"),
        Post.new("Babe went home", "Babe", "To a little house", "shh!"),
        Post.new("Cabe went home", "Cabe", "To a little house", "shh!")
      ]

      assert_dom_equal(
        "<option value=\"&lt;Abe&gt;\">&lt;Abe&gt; went home</option>\n<option value=\"Babe\" selected=\"selected\">Babe went home</option>\n<option value=\"Cabe\">Cabe went home</option>",
        options_from_collection_for_select(@posts, "author_name", "title", "Babe")
      )
    end

    def test_collection_options_with_preselected_value_array
        @posts = [
          Post.new("<Abe> went home", "<Abe>", "To a little house", "shh!"),
          Post.new("Babe went home", "Babe", "To a little house", "shh!"),
          Post.new("Cabe went home", "Cabe", "To a little house", "shh!")
        ]

        assert_dom_equal(
          "<option value=\"&lt;Abe&gt;\">&lt;Abe&gt; went home</option>\n<option value=\"Babe\" selected=\"selected\">Babe went home</option>\n<option value=\"Cabe\" selected=\"selected\">Cabe went home</option>",
          options_from_collection_for_select(@posts, "author_name", "title", [ "Babe", "Cabe" ])
        )
    end

    def test_array_options_for_select
      assert_dom_equal(
        "<option value=\"&lt;Denmark&gt;\">&lt;Denmark&gt;</option>\n<option value=\"USA\">USA</option>\n<option value=\"Sweden\">Sweden</option>",
        options_for_select([ "<Denmark>", "USA", "Sweden" ])
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
        "<option value=\"&lt;Kroner&gt;\">&lt;DKR&gt;</option>\n<option value=\"Dollar\">$</option>",
        options_for_select("$" => "Dollar", "<DKR>" => "<Kroner>").split("\n").sort.join("\n")
      )
      assert_dom_equal(
        "<option value=\"&lt;Kroner&gt;\">&lt;DKR&gt;</option>\n<option value=\"Dollar\" selected=\"selected\">$</option>",
        options_for_select({ "$" => "Dollar", "<DKR>" => "<Kroner>" }, "Dollar").split("\n").sort.join("\n")
      )
      assert_dom_equal(
        "<option value=\"&lt;Kroner&gt;\" selected=\"selected\">&lt;DKR&gt;</option>\n<option value=\"Dollar\" selected=\"selected\">$</option>",
        options_for_select({ "$" => "Dollar", "<DKR>" => "<Kroner>" }, [ "Dollar", "<Kroner>" ]).split("\n").sort.join("\n")
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

    def test_option_groups_from_collection_for_select
      @continents = [
        Continent.new("<Africa>", [Country.new("<sa>", "<South Africa>"), Country.new("so", "Somalia")] ),
        Continent.new("Europe", [Country.new("dk", "Denmark"), Country.new("ie", "Ireland")] )
      ]

      assert_dom_equal(
        "<optgroup label=\"&lt;Africa&gt;\"><option value=\"&lt;sa&gt;\">&lt;South Africa&gt;</option>\n<option value=\"so\">Somalia</option></optgroup><optgroup label=\"Europe\"><option value=\"dk\" selected=\"selected\">Denmark</option>\n<option value=\"ie\">Ireland</option></optgroup>",
        option_groups_from_collection_for_select(@continents, "countries", "continent_name", "country_id", "country_name", "dk")
      )
    end

    def test_grouped_options_for_select_with_array
      assert_dom_equal(
        "<optgroup label=\"North America\"><option value=\"US\">United States</option>\n<option value=\"Canada\">Canada</option></optgroup><optgroup label=\"Europe\"><option value=\"GB\">Great Britain</option>\n<option value=\"Germany\">Germany</option></optgroup>",
        grouped_options_for_select([
           ["North America",
               [['United States','US'],"Canada"]],
           ["Europe",
               [["Great Britain","GB"], "Germany"]]
         ])
      )
    end

    def test_grouped_options_for_select_with_selected_and_prompt
      assert_dom_equal(
          "<option value=\"\">Choose a product...</option><optgroup label=\"Hats\"><option value=\"Baseball Cap\">Baseball Cap</option>\n<option selected=\"selected\" value=\"Cowboy Hat\">Cowboy Hat</option></optgroup>",
          grouped_options_for_select([["Hats", ["Baseball Cap","Cowboy Hat"]]], "Cowboy Hat", "Choose a product...")
      )
    end

    def test_optgroups_with_with_options_with_hash
      assert_dom_equal(
         "<optgroup label=\"Europe\"><option value=\"Denmark\">Denmark</option>\n<option value=\"Germany\">Germany</option></optgroup><optgroup label=\"North America\"><option value=\"United States\">United States</option>\n<option value=\"Canada\">Canada</option></optgroup>",
         grouped_options_for_select({'North America' => ['United States','Canada'], 'Europe' => ['Denmark','Germany']})
      )
    end

    def test_time_zone_options_no_parms
      opts = time_zone_options_for_select
      assert_dom_equal "<option value=\"A\">A</option>\n" +
                   "<option value=\"B\">B</option>\n" +
                   "<option value=\"C\">C</option>\n" +
                   "<option value=\"D\">D</option>\n" +
                   "<option value=\"E\">E</option>",
                   opts
    end

    def test_time_zone_options_with_selected
      opts = time_zone_options_for_select( "D" )
      assert_dom_equal "<option value=\"A\">A</option>\n" +
                   "<option value=\"B\">B</option>\n" +
                   "<option value=\"C\">C</option>\n" +
                   "<option value=\"D\" selected=\"selected\">D</option>\n" +
                   "<option value=\"E\">E</option>",
                   opts
    end

    def test_time_zone_options_with_unknown_selected
      opts = time_zone_options_for_select( "K" )
      assert_dom_equal "<option value=\"A\">A</option>\n" +
                   "<option value=\"B\">B</option>\n" +
                   "<option value=\"C\">C</option>\n" +
                   "<option value=\"D\">D</option>\n" +
                   "<option value=\"E\">E</option>",
                   opts
    end

    def test_time_zone_options_with_priority_zones
      zones = [ ActiveSupport::TimeZone.new( "B" ), ActiveSupport::TimeZone.new( "E" ) ]
      opts = time_zone_options_for_select( nil, zones )
      assert_dom_equal "<option value=\"B\">B</option>\n" +
                   "<option value=\"E\">E</option>" +
                   "<option value=\"\" disabled=\"disabled\">-------------</option>\n" +
                   "<option value=\"A\">A</option>\n" +
                   "<option value=\"C\">C</option>\n" +
                   "<option value=\"D\">D</option>",
                   opts
    end

    def test_time_zone_options_with_selected_priority_zones
      zones = [ ActiveSupport::TimeZone.new( "B" ), ActiveSupport::TimeZone.new( "E" ) ]
      opts = time_zone_options_for_select( "E", zones )
      assert_dom_equal "<option value=\"B\">B</option>\n" +
                   "<option value=\"E\" selected=\"selected\">E</option>" +
                   "<option value=\"\" disabled=\"disabled\">-------------</option>\n" +
                   "<option value=\"A\">A</option>\n" +
                   "<option value=\"C\">C</option>\n" +
                   "<option value=\"D\">D</option>",
                   opts
    end

    def test_time_zone_options_with_unselected_priority_zones
      zones = [ ActiveSupport::TimeZone.new( "B" ), ActiveSupport::TimeZone.new( "E" ) ]
      opts = time_zone_options_for_select( "C", zones )
      assert_dom_equal "<option value=\"B\">B</option>\n" +
                   "<option value=\"E\">E</option>" +
                   "<option value=\"\" disabled=\"disabled\">-------------</option>\n" +
                   "<option value=\"A\">A</option>\n" +
                   "<option value=\"C\" selected=\"selected\">C</option>\n" +
                   "<option value=\"D\">D</option>",
                   opts
    end

    def test_select
      @post = Post.new
      @post.category = "<mus>"
      assert_dom_equal(
        "<select id=\"post_category\" name=\"post[category]\"><option value=\"abe\">abe</option>\n<option value=\"&lt;mus&gt;\" selected=\"selected\">&lt;mus&gt;</option>\n<option value=\"hest\">hest</option></select>",
        select("post", "category", %w( abe <mus> hest))
      )
    end

    def test_select_under_fields_for
      @post = Post.new
      @post.category = "<mus>"

      fields_for :post, @post do |f|
        concat f.select(:category, %w( abe <mus> hest))
      end
    
      assert_dom_equal(
        "<select id=\"post_category\" name=\"post[category]\"><option value=\"abe\">abe</option>\n<option value=\"&lt;mus&gt;\" selected=\"selected\">&lt;mus&gt;</option>\n<option value=\"hest\">hest</option></select>",
        output_buffer
      )
    end

    def test_select_under_fields_for_with_index
      @post = Post.new
      @post.category = "<mus>"

      fields_for :post, @post, :index => 108 do |f|
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

      fields_for "post[]", @post do |f|
        concat f.select(:category, %w( abe <mus> hest))
      end

      assert_dom_equal(
        "<select id=\"post_108_category\" name=\"post[108][category]\"><option value=\"abe\">abe</option>\n<option value=\"&lt;mus&gt;\" selected=\"selected\">&lt;mus&gt;</option>\n<option value=\"hest\">hest</option></select>",
        output_buffer
      )
    end

    def test_select_with_blank
      @post = Post.new
      @post.category = "<mus>"
      assert_dom_equal(
        "<select id=\"post_category\" name=\"post[category]\"><option value=\"\"></option>\n<option value=\"abe\">abe</option>\n<option value=\"&lt;mus&gt;\" selected=\"selected\">&lt;mus&gt;</option>\n<option value=\"hest\">hest</option></select>",
        select("post", "category", %w( abe <mus> hest), :include_blank => true)
      )
    end

    def test_select_with_blank_as_string
      @post = Post.new
      @post.category = "<mus>"
      assert_dom_equal(
        "<select id=\"post_category\" name=\"post[category]\"><option value=\"\">None</option>\n<option value=\"abe\">abe</option>\n<option value=\"&lt;mus&gt;\" selected=\"selected\">&lt;mus&gt;</option>\n<option value=\"hest\">hest</option></select>",
        select("post", "category", %w( abe <mus> hest), :include_blank => 'None')
      )
    end

    def test_select_with_default_prompt
      @post = Post.new
      @post.category = ""
      assert_dom_equal(
        "<select id=\"post_category\" name=\"post[category]\"><option value=\"\">Please select</option>\n<option value=\"abe\">abe</option>\n<option value=\"&lt;mus&gt;\">&lt;mus&gt;</option>\n<option value=\"hest\">hest</option></select>",
        select("post", "category", %w( abe <mus> hest), :prompt => true)
      )
    end

    def test_select_no_prompt_when_select_has_value
      @post = Post.new
      @post.category = "<mus>"
      assert_dom_equal(
        "<select id=\"post_category\" name=\"post[category]\"><option value=\"abe\">abe</option>\n<option value=\"&lt;mus&gt;\" selected=\"selected\">&lt;mus&gt;</option>\n<option value=\"hest\">hest</option></select>",
        select("post", "category", %w( abe <mus> hest), :prompt => true)
      )
    end

    def test_select_with_given_prompt
      @post = Post.new
      @post.category = ""
      assert_dom_equal(
        "<select id=\"post_category\" name=\"post[category]\"><option value=\"\">The prompt</option>\n<option value=\"abe\">abe</option>\n<option value=\"&lt;mus&gt;\">&lt;mus&gt;</option>\n<option value=\"hest\">hest</option></select>",
        select("post", "category", %w( abe <mus> hest), :prompt => 'The prompt')
      )
    end

    def test_select_with_prompt_and_blank
      @post = Post.new
      @post.category = ""
      assert_dom_equal(
        "<select id=\"post_category\" name=\"post[category]\"><option value=\"\">Please select</option>\n<option value=\"\"></option>\n<option value=\"abe\">abe</option>\n<option value=\"&lt;mus&gt;\">&lt;mus&gt;</option>\n<option value=\"hest\">hest</option></select>",
        select("post", "category", %w( abe <mus> hest), :prompt => true, :include_blank => true)
      )
    end

    def test_select_with_selected_value
      @post = Post.new
      @post.category = "<mus>"
      assert_dom_equal(
        "<select id=\"post_category\" name=\"post[category]\"><option value=\"abe\" selected=\"selected\">abe</option>\n<option value=\"&lt;mus&gt;\">&lt;mus&gt;</option>\n<option value=\"hest\">hest</option></select>",
        select("post", "category", %w( abe <mus> hest ), :selected => 'abe')
      )
    end
  
    def test_select_with_index_option
      @album = Album.new
      @album.id = 1
    
      expected = "<select id=\"album__genre\" name=\"album[][genre]\"><option value=\"rap\">rap</option>\n<option value=\"rock\">rock</option>\n<option value=\"country\">country</option></select>"    

      assert_dom_equal(
        expected, 
        select("album[]", "genre", %w[rap rock country], {}, { :index => nil })
      )
    end

    def test_select_with_selected_nil
      @post = Post.new
      @post.category = "<mus>"
      assert_dom_equal(
        "<select id=\"post_category\" name=\"post[category]\"><option value=\"abe\">abe</option>\n<option value=\"&lt;mus&gt;\">&lt;mus&gt;</option>\n<option value=\"hest\">hest</option></select>",
        select("post", "category", %w( abe <mus> hest ), :selected => nil)
      )
    end

    def test_collection_select
      @posts = [
        Post.new("<Abe> went home", "<Abe>", "To a little house", "shh!"),
        Post.new("Babe went home", "Babe", "To a little house", "shh!"),
        Post.new("Cabe went home", "Cabe", "To a little house", "shh!")
      ]

      @post = Post.new
      @post.author_name = "Babe"

      assert_dom_equal(
        "<select id=\"post_author_name\" name=\"post[author_name]\"><option value=\"&lt;Abe&gt;\">&lt;Abe&gt;</option>\n<option value=\"Babe\" selected=\"selected\">Babe</option>\n<option value=\"Cabe\">Cabe</option></select>",
        collection_select("post", "author_name", @posts, "author_name", "author_name")
      )
    end

    def test_collection_select_under_fields_for
      @posts = [
        Post.new("<Abe> went home", "<Abe>", "To a little house", "shh!"),
        Post.new("Babe went home", "Babe", "To a little house", "shh!"),
        Post.new("Cabe went home", "Cabe", "To a little house", "shh!")
      ]

      @post = Post.new
      @post.author_name = "Babe"

      fields_for :post, @post do |f|
        concat f.collection_select(:author_name, @posts, :author_name, :author_name)
      end
    
      assert_dom_equal(
        "<select id=\"post_author_name\" name=\"post[author_name]\"><option value=\"&lt;Abe&gt;\">&lt;Abe&gt;</option>\n<option value=\"Babe\" selected=\"selected\">Babe</option>\n<option value=\"Cabe\">Cabe</option></select>",
        output_buffer
      )
    end

    def test_collection_select_under_fields_for_with_index
      @posts = [
        Post.new("<Abe> went home", "<Abe>", "To a little house", "shh!"),
        Post.new("Babe went home", "Babe", "To a little house", "shh!"),
        Post.new("Cabe went home", "Cabe", "To a little house", "shh!")
      ]

      @post = Post.new
      @post.author_name = "Babe"

      fields_for :post, @post, :index => 815 do |f|
        concat f.collection_select(:author_name, @posts, :author_name, :author_name)
      end

      assert_dom_equal(
        "<select id=\"post_815_author_name\" name=\"post[815][author_name]\"><option value=\"&lt;Abe&gt;\">&lt;Abe&gt;</option>\n<option value=\"Babe\" selected=\"selected\">Babe</option>\n<option value=\"Cabe\">Cabe</option></select>",
        output_buffer
      )
    end

    def test_collection_select_under_fields_for_with_auto_index
      @posts = [
        Post.new("<Abe> went home", "<Abe>", "To a little house", "shh!"),
        Post.new("Babe went home", "Babe", "To a little house", "shh!"),
        Post.new("Cabe went home", "Cabe", "To a little house", "shh!")
      ]

      @post = Post.new
      @post.author_name = "Babe"
      def @post.to_param; 815; end

      fields_for "post[]", @post do |f|
        concat f.collection_select(:author_name, @posts, :author_name, :author_name)
      end

      assert_dom_equal(
        "<select id=\"post_815_author_name\" name=\"post[815][author_name]\"><option value=\"&lt;Abe&gt;\">&lt;Abe&gt;</option>\n<option value=\"Babe\" selected=\"selected\">Babe</option>\n<option value=\"Cabe\">Cabe</option></select>",
        output_buffer
      )
    end

    def test_collection_select_with_blank_and_style
      @posts = [
        Post.new("<Abe> went home", "<Abe>", "To a little house", "shh!"),
        Post.new("Babe went home", "Babe", "To a little house", "shh!"),
        Post.new("Cabe went home", "Cabe", "To a little house", "shh!")
      ]

      @post = Post.new
      @post.author_name = "Babe"

      assert_dom_equal(
        "<select id=\"post_author_name\" name=\"post[author_name]\" style=\"width: 200px\"><option value=\"\"></option>\n<option value=\"&lt;Abe&gt;\">&lt;Abe&gt;</option>\n<option value=\"Babe\" selected=\"selected\">Babe</option>\n<option value=\"Cabe\">Cabe</option></select>",
        collection_select("post", "author_name", @posts, "author_name", "author_name", { :include_blank => true }, "style" => "width: 200px")
      )
    end

    def test_collection_select_with_blank_as_string_and_style
      @posts = [
        Post.new("<Abe> went home", "<Abe>", "To a little house", "shh!"),
        Post.new("Babe went home", "Babe", "To a little house", "shh!"),
        Post.new("Cabe went home", "Cabe", "To a little house", "shh!")
      ]

      @post = Post.new
      @post.author_name = "Babe"

      assert_dom_equal(
        "<select id=\"post_author_name\" name=\"post[author_name]\" style=\"width: 200px\"><option value=\"\">No Selection</option>\n<option value=\"&lt;Abe&gt;\">&lt;Abe&gt;</option>\n<option value=\"Babe\" selected=\"selected\">Babe</option>\n<option value=\"Cabe\">Cabe</option></select>",
        collection_select("post", "author_name", @posts, "author_name", "author_name", { :include_blank => 'No Selection' }, "style" => "width: 200px")
      )
    end

    def test_collection_select_with_multiple_option_appends_array_brackets
      @posts = [
        Post.new("<Abe> went home", "<Abe>", "To a little house", "shh!"),
        Post.new("Babe went home", "Babe", "To a little house", "shh!"),
        Post.new("Cabe went home", "Cabe", "To a little house", "shh!")
      ]

      @post = Post.new
      @post.author_name = "Babe"

      expected = "<select id=\"post_author_name\" name=\"post[author_name][]\" multiple=\"multiple\"><option value=\"\"></option>\n<option value=\"&lt;Abe&gt;\">&lt;Abe&gt;</option>\n<option value=\"Babe\" selected=\"selected\">Babe</option>\n<option value=\"Cabe\">Cabe</option></select>"

      # Should suffix default name with [].
      assert_dom_equal expected, collection_select("post", "author_name", @posts, "author_name", "author_name", { :include_blank => true }, :multiple => true)

      # Shouldn't suffix custom name with [].
      assert_dom_equal expected, collection_select("post", "author_name", @posts, "author_name", "author_name", { :include_blank => true, :name => 'post[author_name][]' }, :multiple => true)
    end

    def test_collection_select_with_blank_and_selected
      @posts = [
        Post.new("<Abe> went home", "<Abe>", "To a little house", "shh!"),
        Post.new("Babe went home", "Babe", "To a little house", "shh!"),
        Post.new("Cabe went home", "Cabe", "To a little house", "shh!")
      ]

      @post = Post.new
      @post.author_name = "Babe"

      assert_dom_equal(
        %{<select id="post_author_name" name="post[author_name]"><option value=""></option>\n<option value="&lt;Abe&gt;" selected="selected">&lt;Abe&gt;</option>\n<option value="Babe">Babe</option>\n<option value="Cabe">Cabe</option></select>},
        collection_select("post", "author_name", @posts, "author_name", "author_name", {:include_blank => true, :selected => "<Abe>"})
      )
    end

    def test_time_zone_select
      @firm = Firm.new("D")
      html = time_zone_select( "firm", "time_zone" )
      assert_dom_equal "<select id=\"firm_time_zone\" name=\"firm[time_zone]\">" +
                   "<option value=\"A\">A</option>\n" +
                   "<option value=\"B\">B</option>\n" +
                   "<option value=\"C\">C</option>\n" +
                   "<option value=\"D\" selected=\"selected\">D</option>\n" +
                   "<option value=\"E\">E</option>" +
                   "</select>",
                   html
    end

    def test_time_zone_select_under_fields_for
      @firm = Firm.new("D")

      fields_for :firm, @firm do |f|
        concat f.time_zone_select(:time_zone)
      end
    
      assert_dom_equal(
        "<select id=\"firm_time_zone\" name=\"firm[time_zone]\">" +
        "<option value=\"A\">A</option>\n" +
        "<option value=\"B\">B</option>\n" +
        "<option value=\"C\">C</option>\n" +
        "<option value=\"D\" selected=\"selected\">D</option>\n" +
        "<option value=\"E\">E</option>" +
        "</select>",
        output_buffer
      )
    end

    def test_time_zone_select_under_fields_for_with_index
      @firm = Firm.new("D")

      fields_for :firm, @firm, :index => 305 do |f|
        concat f.time_zone_select(:time_zone)
      end

      assert_dom_equal(
        "<select id=\"firm_305_time_zone\" name=\"firm[305][time_zone]\">" +
        "<option value=\"A\">A</option>\n" +
        "<option value=\"B\">B</option>\n" +
        "<option value=\"C\">C</option>\n" +
        "<option value=\"D\" selected=\"selected\">D</option>\n" +
        "<option value=\"E\">E</option>" +
        "</select>",
        output_buffer
      )
    end

    def test_time_zone_select_under_fields_for_with_auto_index
      @firm = Firm.new("D")
      def @firm.to_param; 305; end

      fields_for "firm[]", @firm do |f|
        concat f.time_zone_select(:time_zone)
      end

      assert_dom_equal(
        "<select id=\"firm_305_time_zone\" name=\"firm[305][time_zone]\">" +
        "<option value=\"A\">A</option>\n" +
        "<option value=\"B\">B</option>\n" +
        "<option value=\"C\">C</option>\n" +
        "<option value=\"D\" selected=\"selected\">D</option>\n" +
        "<option value=\"E\">E</option>" +
        "</select>",
        output_buffer
      )
    end

    def test_time_zone_select_with_blank
      @firm = Firm.new("D")
      html = time_zone_select("firm", "time_zone", nil, :include_blank => true)
      assert_dom_equal "<select id=\"firm_time_zone\" name=\"firm[time_zone]\">" +
                   "<option value=\"\"></option>\n" +
                   "<option value=\"A\">A</option>\n" +
                   "<option value=\"B\">B</option>\n" +
                   "<option value=\"C\">C</option>\n" +
                   "<option value=\"D\" selected=\"selected\">D</option>\n" +
                   "<option value=\"E\">E</option>" +
                   "</select>",
                   html
    end

    def test_time_zone_select_with_blank_as_string
      @firm = Firm.new("D")
      html = time_zone_select("firm", "time_zone", nil, :include_blank => 'No Zone')
      assert_dom_equal "<select id=\"firm_time_zone\" name=\"firm[time_zone]\">" +
                   "<option value=\"\">No Zone</option>\n" +
                   "<option value=\"A\">A</option>\n" +
                   "<option value=\"B\">B</option>\n" +
                   "<option value=\"C\">C</option>\n" +
                   "<option value=\"D\" selected=\"selected\">D</option>\n" +
                   "<option value=\"E\">E</option>" +
                   "</select>",
                   html
    end

    def test_time_zone_select_with_style
      @firm = Firm.new("D")
      html = time_zone_select("firm", "time_zone", nil, {},
        "style" => "color: red")
      assert_dom_equal "<select id=\"firm_time_zone\" name=\"firm[time_zone]\" style=\"color: red\">" +
                   "<option value=\"A\">A</option>\n" +
                   "<option value=\"B\">B</option>\n" +
                   "<option value=\"C\">C</option>\n" +
                   "<option value=\"D\" selected=\"selected\">D</option>\n" +
                   "<option value=\"E\">E</option>" +
                   "</select>",
                   html
      assert_dom_equal html, time_zone_select("firm", "time_zone", nil, {},
        :style => "color: red")
    end

    def test_time_zone_select_with_blank_and_style
      @firm = Firm.new("D")
      html = time_zone_select("firm", "time_zone", nil,
        { :include_blank => true }, "style" => "color: red")
      assert_dom_equal "<select id=\"firm_time_zone\" name=\"firm[time_zone]\" style=\"color: red\">" +
                   "<option value=\"\"></option>\n" +
                   "<option value=\"A\">A</option>\n" +
                   "<option value=\"B\">B</option>\n" +
                   "<option value=\"C\">C</option>\n" +
                   "<option value=\"D\" selected=\"selected\">D</option>\n" +
                   "<option value=\"E\">E</option>" +
                   "</select>",
                   html
      assert_dom_equal html, time_zone_select("firm", "time_zone", nil,
        { :include_blank => true }, :style => "color: red")
    end

    def test_time_zone_select_with_blank_as_string_and_style
      @firm = Firm.new("D")
      html = time_zone_select("firm", "time_zone", nil,
        { :include_blank => 'No Zone' }, "style" => "color: red")
      assert_dom_equal "<select id=\"firm_time_zone\" name=\"firm[time_zone]\" style=\"color: red\">" +
                   "<option value=\"\">No Zone</option>\n" +
                   "<option value=\"A\">A</option>\n" +
                   "<option value=\"B\">B</option>\n" +
                   "<option value=\"C\">C</option>\n" +
                   "<option value=\"D\" selected=\"selected\">D</option>\n" +
                   "<option value=\"E\">E</option>" +
                   "</select>",
                   html
      assert_dom_equal html, time_zone_select("firm", "time_zone", nil,
        { :include_blank => 'No Zone' }, :style => "color: red")
    end

    def test_time_zone_select_with_priority_zones
      @firm = Firm.new("D")
      zones = [ ActiveSupport::TimeZone.new("A"), ActiveSupport::TimeZone.new("D") ]
      html = time_zone_select("firm", "time_zone", zones )
      assert_dom_equal "<select id=\"firm_time_zone\" name=\"firm[time_zone]\">" +
                   "<option value=\"A\">A</option>\n" +
                   "<option value=\"D\" selected=\"selected\">D</option>" +
                   "<option value=\"\" disabled=\"disabled\">-------------</option>\n" +
                   "<option value=\"B\">B</option>\n" +
                   "<option value=\"C\">C</option>\n" +
                   "<option value=\"E\">E</option>" +
                   "</select>",
                   html
    end

    def test_time_zone_select_with_priority_zones_as_regexp
      @firm = Firm.new("D")
      @fake_timezones.each_with_index do |tz, i|
        tz.stubs(:=~).returns(i.zero? || i == 3)
      end

      html = time_zone_select("firm", "time_zone", /A|D/)
      assert_dom_equal "<select id=\"firm_time_zone\" name=\"firm[time_zone]\">" +
                   "<option value=\"A\">A</option>\n" +
                   "<option value=\"D\" selected=\"selected\">D</option>" +
                   "<option value=\"\" disabled=\"disabled\">-------------</option>\n" +
                   "<option value=\"B\">B</option>\n" +
                   "<option value=\"C\">C</option>\n" +
                   "<option value=\"E\">E</option>" +
                   "</select>",
                   html
    end

    def test_time_zone_select_with_default_time_zone_and_nil_value
       @firm = Firm.new()
       @firm.time_zone = nil
        html = time_zone_select( "firm", "time_zone", nil, :default => 'B' )
        assert_dom_equal "<select id=\"firm_time_zone\" name=\"firm[time_zone]\">" +
                     "<option value=\"A\">A</option>\n" +
                     "<option value=\"B\" selected=\"selected\">B</option>\n" +
                     "<option value=\"C\">C</option>\n" +
                     "<option value=\"D\">D</option>\n" +
                     "<option value=\"E\">E</option>" +
                     "</select>",
                     html
    end

    def test_time_zone_select_with_default_time_zone_and_value
       @firm = Firm.new('D')
        html = time_zone_select( "firm", "time_zone", nil, :default => 'B' )
        assert_dom_equal "<select id=\"firm_time_zone\" name=\"firm[time_zone]\">" +
                     "<option value=\"A\">A</option>\n" +
                     "<option value=\"B\">B</option>\n" +
                     "<option value=\"C\">C</option>\n" +
                     "<option value=\"D\" selected=\"selected\">D</option>\n" +
                     "<option value=\"E\">E</option>" +
                     "</select>",
                     html
    end

  end
end
