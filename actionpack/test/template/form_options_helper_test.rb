require 'abstract_unit'

TZInfo::Timezone.cattr_reader :loaded_zones

uses_mocha "FormOptionsHelperTest" do
  class FormOptionsHelperTest < ActionView::TestCase
    tests ActionView::Helpers::FormOptionsHelper

    silence_warnings do
      Post      = Struct.new('Post', :title, :author_name, :body, :secret, :written_on, :category, :origin)
      Continent = Struct.new('Continent', :continent_name, :countries)
      Country   = Struct.new('Country', :country_id, :country_name)
      Firm      = Struct.new('Firm', :time_zone)
      Album     = Struct.new('Album', :id, :title, :genre)
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

      _erbout = ''

      fields_for :post, @post do |f|
        _erbout.concat f.select(:category, %w( abe <mus> hest))
      end

      assert_dom_equal(
        "<select id=\"post_category\" name=\"post[category]\"><option value=\"abe\">abe</option>\n<option value=\"&lt;mus&gt;\" selected=\"selected\">&lt;mus&gt;</option>\n<option value=\"hest\">hest</option></select>",
        _erbout
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

      _erbout = ''

      fields_for :post, @post do |f|
        _erbout.concat f.collection_select(:author_name, @posts, :author_name, :author_name)
      end

      assert_dom_equal(
        "<select id=\"post_author_name\" name=\"post[author_name]\"><option value=\"&lt;Abe&gt;\">&lt;Abe&gt;</option>\n<option value=\"Babe\" selected=\"selected\">Babe</option>\n<option value=\"Cabe\">Cabe</option></select>",
        _erbout
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

    def test_country_select
      @post = Post.new
      @post.origin = "Denmark"
      expected_select = <<-COUNTRIES
<select id="post_origin" name="post[origin]"><option value="Afghanistan">Afghanistan</option>
<option value="Aland Islands">Aland Islands</option>
<option value="Albania">Albania</option>
<option value="Algeria">Algeria</option>
<option value="American Samoa">American Samoa</option>
<option value="Andorra">Andorra</option>
<option value="Angola">Angola</option>
<option value="Anguilla">Anguilla</option>
<option value="Antarctica">Antarctica</option>
<option value="Antigua And Barbuda">Antigua And Barbuda</option>
<option value="Argentina">Argentina</option>
<option value="Armenia">Armenia</option>
<option value="Aruba">Aruba</option>
<option value="Australia">Australia</option>
<option value="Austria">Austria</option>
<option value="Azerbaijan">Azerbaijan</option>
<option value="Bahamas">Bahamas</option>
<option value="Bahrain">Bahrain</option>
<option value="Bangladesh">Bangladesh</option>
<option value="Barbados">Barbados</option>
<option value="Belarus">Belarus</option>
<option value="Belgium">Belgium</option>
<option value="Belize">Belize</option>
<option value="Benin">Benin</option>
<option value="Bermuda">Bermuda</option>
<option value="Bhutan">Bhutan</option>
<option value="Bolivia">Bolivia</option>
<option value="Bosnia and Herzegowina">Bosnia and Herzegowina</option>
<option value="Botswana">Botswana</option>
<option value="Bouvet Island">Bouvet Island</option>
<option value="Brazil">Brazil</option>
<option value="British Indian Ocean Territory">British Indian Ocean Territory</option>
<option value="Brunei Darussalam">Brunei Darussalam</option>
<option value="Bulgaria">Bulgaria</option>
<option value="Burkina Faso">Burkina Faso</option>
<option value="Burundi">Burundi</option>
<option value="Cambodia">Cambodia</option>
<option value="Cameroon">Cameroon</option>
<option value="Canada">Canada</option>
<option value="Cape Verde">Cape Verde</option>
<option value="Cayman Islands">Cayman Islands</option>
<option value="Central African Republic">Central African Republic</option>
<option value="Chad">Chad</option>
<option value="Chile">Chile</option>
<option value="China">China</option>
<option value="Christmas Island">Christmas Island</option>
<option value="Cocos (Keeling) Islands">Cocos (Keeling) Islands</option>
<option value="Colombia">Colombia</option>
<option value="Comoros">Comoros</option>
<option value="Congo">Congo</option>
<option value="Congo, the Democratic Republic of the">Congo, the Democratic Republic of the</option>
<option value="Cook Islands">Cook Islands</option>
<option value="Costa Rica">Costa Rica</option>
<option value="Cote d'Ivoire">Cote d'Ivoire</option>
<option value="Croatia">Croatia</option>
<option value="Cuba">Cuba</option>
<option value="Cyprus">Cyprus</option>
<option value="Czech Republic">Czech Republic</option>
<option selected="selected" value="Denmark">Denmark</option>
<option value="Djibouti">Djibouti</option>
<option value="Dominica">Dominica</option>
<option value="Dominican Republic">Dominican Republic</option>
<option value="Ecuador">Ecuador</option>
<option value="Egypt">Egypt</option>
<option value="El Salvador">El Salvador</option>
<option value="Equatorial Guinea">Equatorial Guinea</option>
<option value="Eritrea">Eritrea</option>
<option value="Estonia">Estonia</option>
<option value="Ethiopia">Ethiopia</option>
<option value="Falkland Islands (Malvinas)">Falkland Islands (Malvinas)</option>
<option value="Faroe Islands">Faroe Islands</option>
<option value="Fiji">Fiji</option>
<option value="Finland">Finland</option>
<option value="France">France</option>
<option value="French Guiana">French Guiana</option>
<option value="French Polynesia">French Polynesia</option>
<option value="French Southern Territories">French Southern Territories</option>
<option value="Gabon">Gabon</option>
<option value="Gambia">Gambia</option>
<option value="Georgia">Georgia</option>
<option value="Germany">Germany</option>
<option value="Ghana">Ghana</option>
<option value="Gibraltar">Gibraltar</option>
<option value="Greece">Greece</option>
<option value="Greenland">Greenland</option>
<option value="Grenada">Grenada</option>
<option value="Guadeloupe">Guadeloupe</option>
<option value="Guam">Guam</option>
<option value="Guatemala">Guatemala</option>
<option value="Guernsey">Guernsey</option>
<option value="Guinea">Guinea</option>
<option value="Guinea-Bissau">Guinea-Bissau</option>
<option value="Guyana">Guyana</option>
<option value="Haiti">Haiti</option>
<option value="Heard and McDonald Islands">Heard and McDonald Islands</option>
<option value="Holy See (Vatican City State)">Holy See (Vatican City State)</option>
<option value="Honduras">Honduras</option>
<option value="Hong Kong">Hong Kong</option>
<option value="Hungary">Hungary</option>
<option value="Iceland">Iceland</option>
<option value="India">India</option>
<option value="Indonesia">Indonesia</option>
<option value="Iran, Islamic Republic of">Iran, Islamic Republic of</option>
<option value="Iraq">Iraq</option>
<option value="Ireland">Ireland</option>
<option value="Isle of Man">Isle of Man</option>
<option value="Israel">Israel</option>
<option value="Italy">Italy</option>
<option value="Jamaica">Jamaica</option>
<option value="Japan">Japan</option>
<option value="Jersey">Jersey</option>
<option value="Jordan">Jordan</option>
<option value="Kazakhstan">Kazakhstan</option>
<option value="Kenya">Kenya</option>
<option value="Kiribati">Kiribati</option>
<option value="Korea, Democratic People's Republic of">Korea, Democratic People's Republic of</option>
<option value="Korea, Republic of">Korea, Republic of</option>
<option value="Kuwait">Kuwait</option>
<option value="Kyrgyzstan">Kyrgyzstan</option>
<option value="Lao People's Democratic Republic">Lao People's Democratic Republic</option>
<option value="Latvia">Latvia</option>
<option value="Lebanon">Lebanon</option>
<option value="Lesotho">Lesotho</option>
<option value="Liberia">Liberia</option>
<option value="Libyan Arab Jamahiriya">Libyan Arab Jamahiriya</option>
<option value="Liechtenstein">Liechtenstein</option>
<option value="Lithuania">Lithuania</option>
<option value="Luxembourg">Luxembourg</option>
<option value="Macao">Macao</option>
<option value="Macedonia, The Former Yugoslav Republic Of">Macedonia, The Former Yugoslav Republic Of</option>
<option value="Madagascar">Madagascar</option>
<option value="Malawi">Malawi</option>
<option value="Malaysia">Malaysia</option>
<option value="Maldives">Maldives</option>
<option value="Mali">Mali</option>
<option value="Malta">Malta</option>
<option value="Marshall Islands">Marshall Islands</option>
<option value="Martinique">Martinique</option>
<option value="Mauritania">Mauritania</option>
<option value="Mauritius">Mauritius</option>
<option value="Mayotte">Mayotte</option>
<option value="Mexico">Mexico</option>
<option value="Micronesia, Federated States of">Micronesia, Federated States of</option>
<option value="Moldova, Republic of">Moldova, Republic of</option>
<option value="Monaco">Monaco</option>
<option value="Mongolia">Mongolia</option>
<option value="Montenegro">Montenegro</option>
<option value="Montserrat">Montserrat</option>
<option value="Morocco">Morocco</option>
<option value="Mozambique">Mozambique</option>
<option value="Myanmar">Myanmar</option>
<option value="Namibia">Namibia</option>
<option value="Nauru">Nauru</option>
<option value="Nepal">Nepal</option>
<option value="Netherlands">Netherlands</option>
<option value="Netherlands Antilles">Netherlands Antilles</option>
<option value="New Caledonia">New Caledonia</option>
<option value="New Zealand">New Zealand</option>
<option value="Nicaragua">Nicaragua</option>
<option value="Niger">Niger</option>
<option value="Nigeria">Nigeria</option>
<option value="Niue">Niue</option>
<option value="Norfolk Island">Norfolk Island</option>
<option value="Northern Mariana Islands">Northern Mariana Islands</option>
<option value="Norway">Norway</option>
<option value="Oman">Oman</option>
<option value="Pakistan">Pakistan</option>
<option value="Palau">Palau</option>
<option value="Palestinian Territory, Occupied">Palestinian Territory, Occupied</option>
<option value="Panama">Panama</option>
<option value="Papua New Guinea">Papua New Guinea</option>
<option value="Paraguay">Paraguay</option>
<option value="Peru">Peru</option>
<option value="Philippines">Philippines</option>
<option value="Pitcairn">Pitcairn</option>
<option value="Poland">Poland</option>
<option value="Portugal">Portugal</option>
<option value="Puerto Rico">Puerto Rico</option>
<option value="Qatar">Qatar</option>
<option value="Reunion">Reunion</option>
<option value="Romania">Romania</option>
<option value="Russian Federation">Russian Federation</option>
<option value="Rwanda">Rwanda</option>
<option value="Saint Barthelemy">Saint Barthelemy</option>
<option value="Saint Helena">Saint Helena</option>
<option value="Saint Kitts and Nevis">Saint Kitts and Nevis</option>
<option value="Saint Lucia">Saint Lucia</option>
<option value="Saint Pierre and Miquelon">Saint Pierre and Miquelon</option>
<option value="Saint Vincent and the Grenadines">Saint Vincent and the Grenadines</option>
<option value="Samoa">Samoa</option>
<option value="San Marino">San Marino</option>
<option value="Sao Tome and Principe">Sao Tome and Principe</option>
<option value="Saudi Arabia">Saudi Arabia</option>
<option value="Senegal">Senegal</option>
<option value="Serbia">Serbia</option>
<option value="Seychelles">Seychelles</option>
<option value="Sierra Leone">Sierra Leone</option>
<option value="Singapore">Singapore</option>
<option value="Slovakia">Slovakia</option>
<option value="Slovenia">Slovenia</option>
<option value="Solomon Islands">Solomon Islands</option>
<option value="Somalia">Somalia</option>
<option value="South Africa">South Africa</option>
<option value="South Georgia and the South Sandwich Islands">South Georgia and the South Sandwich Islands</option>
<option value="Spain">Spain</option>
<option value="Sri Lanka">Sri Lanka</option>
<option value="Sudan">Sudan</option>
<option value="Suriname">Suriname</option>
<option value="Svalbard and Jan Mayen">Svalbard and Jan Mayen</option>
<option value="Swaziland">Swaziland</option>
<option value="Sweden">Sweden</option>
<option value="Switzerland">Switzerland</option>
<option value="Syrian Arab Republic">Syrian Arab Republic</option>
<option value="Taiwan, Province of China">Taiwan, Province of China</option>
<option value="Tajikistan">Tajikistan</option>
<option value="Tanzania, United Republic of">Tanzania, United Republic of</option>
<option value="Thailand">Thailand</option>
<option value="Timor-Leste">Timor-Leste</option>
<option value="Togo">Togo</option>
<option value="Tokelau">Tokelau</option>
<option value="Tonga">Tonga</option>
<option value="Trinidad and Tobago">Trinidad and Tobago</option>
<option value="Tunisia">Tunisia</option>
<option value="Turkey">Turkey</option>
<option value="Turkmenistan">Turkmenistan</option>
<option value="Turks and Caicos Islands">Turks and Caicos Islands</option>
<option value="Tuvalu">Tuvalu</option>
<option value="Uganda">Uganda</option>
<option value="Ukraine">Ukraine</option>
<option value="United Arab Emirates">United Arab Emirates</option>
<option value="United Kingdom">United Kingdom</option>
<option value="United States">United States</option>
<option value="United States Minor Outlying Islands">United States Minor Outlying Islands</option>
<option value="Uruguay">Uruguay</option>
<option value="Uzbekistan">Uzbekistan</option>
<option value="Vanuatu">Vanuatu</option>
<option value="Venezuela">Venezuela</option>
<option value="Viet Nam">Viet Nam</option>
<option value="Virgin Islands, British">Virgin Islands, British</option>
<option value="Virgin Islands, U.S.">Virgin Islands, U.S.</option>
<option value="Wallis and Futuna">Wallis and Futuna</option>
<option value="Western Sahara">Western Sahara</option>
<option value="Yemen">Yemen</option>
<option value="Zambia">Zambia</option>
<option value="Zimbabwe">Zimbabwe</option></select>
  COUNTRIES
      assert_deprecated 'list-of-countries' do
        assert_dom_equal(expected_select[0..-2], country_select("post", "origin"))
      end
    end

    def test_country_select_with_priority_countries
      @post = Post.new
      @post.origin = "Denmark"
      expected_select = <<-COUNTRIES
<select id="post_origin" name="post[origin]"><option value="New Zealand">New Zealand</option>
<option value="Nicaragua">Nicaragua</option><option value="" disabled="disabled">-------------</option>
<option value="Afghanistan">Afghanistan</option>
<option value="Aland Islands">Aland Islands</option>
<option value="Albania">Albania</option>
<option value="Algeria">Algeria</option>
<option value="American Samoa">American Samoa</option>
<option value="Andorra">Andorra</option>
<option value="Angola">Angola</option>
<option value="Anguilla">Anguilla</option>
<option value="Antarctica">Antarctica</option>
<option value="Antigua And Barbuda">Antigua And Barbuda</option>
<option value="Argentina">Argentina</option>
<option value="Armenia">Armenia</option>
<option value="Aruba">Aruba</option>
<option value="Australia">Australia</option>
<option value="Austria">Austria</option>
<option value="Azerbaijan">Azerbaijan</option>
<option value="Bahamas">Bahamas</option>
<option value="Bahrain">Bahrain</option>
<option value="Bangladesh">Bangladesh</option>
<option value="Barbados">Barbados</option>
<option value="Belarus">Belarus</option>
<option value="Belgium">Belgium</option>
<option value="Belize">Belize</option>
<option value="Benin">Benin</option>
<option value="Bermuda">Bermuda</option>
<option value="Bhutan">Bhutan</option>
<option value="Bolivia">Bolivia</option>
<option value="Bosnia and Herzegowina">Bosnia and Herzegowina</option>
<option value="Botswana">Botswana</option>
<option value="Bouvet Island">Bouvet Island</option>
<option value="Brazil">Brazil</option>
<option value="British Indian Ocean Territory">British Indian Ocean Territory</option>
<option value="Brunei Darussalam">Brunei Darussalam</option>
<option value="Bulgaria">Bulgaria</option>
<option value="Burkina Faso">Burkina Faso</option>
<option value="Burundi">Burundi</option>
<option value="Cambodia">Cambodia</option>
<option value="Cameroon">Cameroon</option>
<option value="Canada">Canada</option>
<option value="Cape Verde">Cape Verde</option>
<option value="Cayman Islands">Cayman Islands</option>
<option value="Central African Republic">Central African Republic</option>
<option value="Chad">Chad</option>
<option value="Chile">Chile</option>
<option value="China">China</option>
<option value="Christmas Island">Christmas Island</option>
<option value="Cocos (Keeling) Islands">Cocos (Keeling) Islands</option>
<option value="Colombia">Colombia</option>
<option value="Comoros">Comoros</option>
<option value="Congo">Congo</option>
<option value="Congo, the Democratic Republic of the">Congo, the Democratic Republic of the</option>
<option value="Cook Islands">Cook Islands</option>
<option value="Costa Rica">Costa Rica</option>
<option value="Cote d'Ivoire">Cote d'Ivoire</option>
<option value="Croatia">Croatia</option>
<option value="Cuba">Cuba</option>
<option value="Cyprus">Cyprus</option>
<option value="Czech Republic">Czech Republic</option>
<option selected="selected" value="Denmark">Denmark</option>
<option value="Djibouti">Djibouti</option>
<option value="Dominica">Dominica</option>
<option value="Dominican Republic">Dominican Republic</option>
<option value="Ecuador">Ecuador</option>
<option value="Egypt">Egypt</option>
<option value="El Salvador">El Salvador</option>
<option value="Equatorial Guinea">Equatorial Guinea</option>
<option value="Eritrea">Eritrea</option>
<option value="Estonia">Estonia</option>
<option value="Ethiopia">Ethiopia</option>
<option value="Falkland Islands (Malvinas)">Falkland Islands (Malvinas)</option>
<option value="Faroe Islands">Faroe Islands</option>
<option value="Fiji">Fiji</option>
<option value="Finland">Finland</option>
<option value="France">France</option>
<option value="French Guiana">French Guiana</option>
<option value="French Polynesia">French Polynesia</option>
<option value="French Southern Territories">French Southern Territories</option>
<option value="Gabon">Gabon</option>
<option value="Gambia">Gambia</option>
<option value="Georgia">Georgia</option>
<option value="Germany">Germany</option>
<option value="Ghana">Ghana</option>
<option value="Gibraltar">Gibraltar</option>
<option value="Greece">Greece</option>
<option value="Greenland">Greenland</option>
<option value="Grenada">Grenada</option>
<option value="Guadeloupe">Guadeloupe</option>
<option value="Guam">Guam</option>
<option value="Guatemala">Guatemala</option>
<option value="Guernsey">Guernsey</option>
<option value="Guinea">Guinea</option>
<option value="Guinea-Bissau">Guinea-Bissau</option>
<option value="Guyana">Guyana</option>
<option value="Haiti">Haiti</option>
<option value="Heard and McDonald Islands">Heard and McDonald Islands</option>
<option value="Holy See (Vatican City State)">Holy See (Vatican City State)</option>
<option value="Honduras">Honduras</option>
<option value="Hong Kong">Hong Kong</option>
<option value="Hungary">Hungary</option>
<option value="Iceland">Iceland</option>
<option value="India">India</option>
<option value="Indonesia">Indonesia</option>
<option value="Iran, Islamic Republic of">Iran, Islamic Republic of</option>
<option value="Iraq">Iraq</option>
<option value="Ireland">Ireland</option>
<option value="Isle of Man">Isle of Man</option>
<option value="Israel">Israel</option>
<option value="Italy">Italy</option>
<option value="Jamaica">Jamaica</option>
<option value="Japan">Japan</option>
<option value="Jersey">Jersey</option>
<option value="Jordan">Jordan</option>
<option value="Kazakhstan">Kazakhstan</option>
<option value="Kenya">Kenya</option>
<option value="Kiribati">Kiribati</option>
<option value="Korea, Democratic People's Republic of">Korea, Democratic People's Republic of</option>
<option value="Korea, Republic of">Korea, Republic of</option>
<option value="Kuwait">Kuwait</option>
<option value="Kyrgyzstan">Kyrgyzstan</option>
<option value="Lao People's Democratic Republic">Lao People's Democratic Republic</option>
<option value="Latvia">Latvia</option>
<option value="Lebanon">Lebanon</option>
<option value="Lesotho">Lesotho</option>
<option value="Liberia">Liberia</option>
<option value="Libyan Arab Jamahiriya">Libyan Arab Jamahiriya</option>
<option value="Liechtenstein">Liechtenstein</option>
<option value="Lithuania">Lithuania</option>
<option value="Luxembourg">Luxembourg</option>
<option value="Macao">Macao</option>
<option value="Macedonia, The Former Yugoslav Republic Of">Macedonia, The Former Yugoslav Republic Of</option>
<option value="Madagascar">Madagascar</option>
<option value="Malawi">Malawi</option>
<option value="Malaysia">Malaysia</option>
<option value="Maldives">Maldives</option>
<option value="Mali">Mali</option>
<option value="Malta">Malta</option>
<option value="Marshall Islands">Marshall Islands</option>
<option value="Martinique">Martinique</option>
<option value="Mauritania">Mauritania</option>
<option value="Mauritius">Mauritius</option>
<option value="Mayotte">Mayotte</option>
<option value="Mexico">Mexico</option>
<option value="Micronesia, Federated States of">Micronesia, Federated States of</option>
<option value="Moldova, Republic of">Moldova, Republic of</option>
<option value="Monaco">Monaco</option>
<option value="Mongolia">Mongolia</option>
<option value="Montenegro">Montenegro</option>
<option value="Montserrat">Montserrat</option>
<option value="Morocco">Morocco</option>
<option value="Mozambique">Mozambique</option>
<option value="Myanmar">Myanmar</option>
<option value="Namibia">Namibia</option>
<option value="Nauru">Nauru</option>
<option value="Nepal">Nepal</option>
<option value="Netherlands">Netherlands</option>
<option value="Netherlands Antilles">Netherlands Antilles</option>
<option value="New Caledonia">New Caledonia</option>
<option value="New Zealand">New Zealand</option>
<option value="Nicaragua">Nicaragua</option>
<option value="Niger">Niger</option>
<option value="Nigeria">Nigeria</option>
<option value="Niue">Niue</option>
<option value="Norfolk Island">Norfolk Island</option>
<option value="Northern Mariana Islands">Northern Mariana Islands</option>
<option value="Norway">Norway</option>
<option value="Oman">Oman</option>
<option value="Pakistan">Pakistan</option>
<option value="Palau">Palau</option>
<option value="Palestinian Territory, Occupied">Palestinian Territory, Occupied</option>
<option value="Panama">Panama</option>
<option value="Papua New Guinea">Papua New Guinea</option>
<option value="Paraguay">Paraguay</option>
<option value="Peru">Peru</option>
<option value="Philippines">Philippines</option>
<option value="Pitcairn">Pitcairn</option>
<option value="Poland">Poland</option>
<option value="Portugal">Portugal</option>
<option value="Puerto Rico">Puerto Rico</option>
<option value="Qatar">Qatar</option>
<option value="Reunion">Reunion</option>
<option value="Romania">Romania</option>
<option value="Russian Federation">Russian Federation</option>
<option value="Rwanda">Rwanda</option>
<option value="Saint Barthelemy">Saint Barthelemy</option>
<option value="Saint Helena">Saint Helena</option>
<option value="Saint Kitts and Nevis">Saint Kitts and Nevis</option>
<option value="Saint Lucia">Saint Lucia</option>
<option value="Saint Pierre and Miquelon">Saint Pierre and Miquelon</option>
<option value="Saint Vincent and the Grenadines">Saint Vincent and the Grenadines</option>
<option value="Samoa">Samoa</option>
<option value="San Marino">San Marino</option>
<option value="Sao Tome and Principe">Sao Tome and Principe</option>
<option value="Saudi Arabia">Saudi Arabia</option>
<option value="Senegal">Senegal</option>
<option value="Serbia">Serbia</option>
<option value="Seychelles">Seychelles</option>
<option value="Sierra Leone">Sierra Leone</option>
<option value="Singapore">Singapore</option>
<option value="Slovakia">Slovakia</option>
<option value="Slovenia">Slovenia</option>
<option value="Solomon Islands">Solomon Islands</option>
<option value="Somalia">Somalia</option>
<option value="South Africa">South Africa</option>
<option value="South Georgia and the South Sandwich Islands">South Georgia and the South Sandwich Islands</option>
<option value="Spain">Spain</option>
<option value="Sri Lanka">Sri Lanka</option>
<option value="Sudan">Sudan</option>
<option value="Suriname">Suriname</option>
<option value="Svalbard and Jan Mayen">Svalbard and Jan Mayen</option>
<option value="Swaziland">Swaziland</option>
<option value="Sweden">Sweden</option>
<option value="Switzerland">Switzerland</option>
<option value="Syrian Arab Republic">Syrian Arab Republic</option>
<option value="Taiwan, Province of China">Taiwan, Province of China</option>
<option value="Tajikistan">Tajikistan</option>
<option value="Tanzania, United Republic of">Tanzania, United Republic of</option>
<option value="Thailand">Thailand</option>
<option value="Timor-Leste">Timor-Leste</option>
<option value="Togo">Togo</option>
<option value="Tokelau">Tokelau</option>
<option value="Tonga">Tonga</option>
<option value="Trinidad and Tobago">Trinidad and Tobago</option>
<option value="Tunisia">Tunisia</option>
<option value="Turkey">Turkey</option>
<option value="Turkmenistan">Turkmenistan</option>
<option value="Turks and Caicos Islands">Turks and Caicos Islands</option>
<option value="Tuvalu">Tuvalu</option>
<option value="Uganda">Uganda</option>
<option value="Ukraine">Ukraine</option>
<option value="United Arab Emirates">United Arab Emirates</option>
<option value="United Kingdom">United Kingdom</option>
<option value="United States">United States</option>
<option value="United States Minor Outlying Islands">United States Minor Outlying Islands</option>
<option value="Uruguay">Uruguay</option>
<option value="Uzbekistan">Uzbekistan</option>
<option value="Vanuatu">Vanuatu</option>
<option value="Venezuela">Venezuela</option>
<option value="Viet Nam">Viet Nam</option>
<option value="Virgin Islands, British">Virgin Islands, British</option>
<option value="Virgin Islands, U.S.">Virgin Islands, U.S.</option>
<option value="Wallis and Futuna">Wallis and Futuna</option>
<option value="Western Sahara">Western Sahara</option>
<option value="Yemen">Yemen</option>
<option value="Zambia">Zambia</option>
<option value="Zimbabwe">Zimbabwe</option></select>
  COUNTRIES
      assert_deprecated 'list-of-countries' do
        assert_dom_equal(expected_select[0..-2], country_select("post", "origin", ["New Zealand", "Nicaragua"]))
      end
    end

    def test_country_select_with_selected_priority_country
      @post = Post.new
      @post.origin = "New Zealand"
      expected_select = <<-COUNTRIES
<select id="post_origin" name="post[origin]"><option selected="selected" value="New Zealand">New Zealand</option>
<option value="Nicaragua">Nicaragua</option><option value="" disabled="disabled">-------------</option>
<option value="Afghanistan">Afghanistan</option>
<option value="Aland Islands">Aland Islands</option>
<option value="Albania">Albania</option>
<option value="Algeria">Algeria</option>
<option value="American Samoa">American Samoa</option>
<option value="Andorra">Andorra</option>
<option value="Angola">Angola</option>
<option value="Anguilla">Anguilla</option>
<option value="Antarctica">Antarctica</option>
<option value="Antigua And Barbuda">Antigua And Barbuda</option>
<option value="Argentina">Argentina</option>
<option value="Armenia">Armenia</option>
<option value="Aruba">Aruba</option>
<option value="Australia">Australia</option>
<option value="Austria">Austria</option>
<option value="Azerbaijan">Azerbaijan</option>
<option value="Bahamas">Bahamas</option>
<option value="Bahrain">Bahrain</option>
<option value="Bangladesh">Bangladesh</option>
<option value="Barbados">Barbados</option>
<option value="Belarus">Belarus</option>
<option value="Belgium">Belgium</option>
<option value="Belize">Belize</option>
<option value="Benin">Benin</option>
<option value="Bermuda">Bermuda</option>
<option value="Bhutan">Bhutan</option>
<option value="Bolivia">Bolivia</option>
<option value="Bosnia and Herzegowina">Bosnia and Herzegowina</option>
<option value="Botswana">Botswana</option>
<option value="Bouvet Island">Bouvet Island</option>
<option value="Brazil">Brazil</option>
<option value="British Indian Ocean Territory">British Indian Ocean Territory</option>
<option value="Brunei Darussalam">Brunei Darussalam</option>
<option value="Bulgaria">Bulgaria</option>
<option value="Burkina Faso">Burkina Faso</option>
<option value="Burundi">Burundi</option>
<option value="Cambodia">Cambodia</option>
<option value="Cameroon">Cameroon</option>
<option value="Canada">Canada</option>
<option value="Cape Verde">Cape Verde</option>
<option value="Cayman Islands">Cayman Islands</option>
<option value="Central African Republic">Central African Republic</option>
<option value="Chad">Chad</option>
<option value="Chile">Chile</option>
<option value="China">China</option>
<option value="Christmas Island">Christmas Island</option>
<option value="Cocos (Keeling) Islands">Cocos (Keeling) Islands</option>
<option value="Colombia">Colombia</option>
<option value="Comoros">Comoros</option>
<option value="Congo">Congo</option>
<option value="Congo, the Democratic Republic of the">Congo, the Democratic Republic of the</option>
<option value="Cook Islands">Cook Islands</option>
<option value="Costa Rica">Costa Rica</option>
<option value="Cote d'Ivoire">Cote d'Ivoire</option>
<option value="Croatia">Croatia</option>
<option value="Cuba">Cuba</option>
<option value="Cyprus">Cyprus</option>
<option value="Czech Republic">Czech Republic</option>
<option value="Denmark">Denmark</option>
<option value="Djibouti">Djibouti</option>
<option value="Dominica">Dominica</option>
<option value="Dominican Republic">Dominican Republic</option>
<option value="Ecuador">Ecuador</option>
<option value="Egypt">Egypt</option>
<option value="El Salvador">El Salvador</option>
<option value="Equatorial Guinea">Equatorial Guinea</option>
<option value="Eritrea">Eritrea</option>
<option value="Estonia">Estonia</option>
<option value="Ethiopia">Ethiopia</option>
<option value="Falkland Islands (Malvinas)">Falkland Islands (Malvinas)</option>
<option value="Faroe Islands">Faroe Islands</option>
<option value="Fiji">Fiji</option>
<option value="Finland">Finland</option>
<option value="France">France</option>
<option value="French Guiana">French Guiana</option>
<option value="French Polynesia">French Polynesia</option>
<option value="French Southern Territories">French Southern Territories</option>
<option value="Gabon">Gabon</option>
<option value="Gambia">Gambia</option>
<option value="Georgia">Georgia</option>
<option value="Germany">Germany</option>
<option value="Ghana">Ghana</option>
<option value="Gibraltar">Gibraltar</option>
<option value="Greece">Greece</option>
<option value="Greenland">Greenland</option>
<option value="Grenada">Grenada</option>
<option value="Guadeloupe">Guadeloupe</option>
<option value="Guam">Guam</option>
<option value="Guatemala">Guatemala</option>
<option value="Guernsey">Guernsey</option>
<option value="Guinea">Guinea</option>
<option value="Guinea-Bissau">Guinea-Bissau</option>
<option value="Guyana">Guyana</option>
<option value="Haiti">Haiti</option>
<option value="Heard and McDonald Islands">Heard and McDonald Islands</option>
<option value="Holy See (Vatican City State)">Holy See (Vatican City State)</option>
<option value="Honduras">Honduras</option>
<option value="Hong Kong">Hong Kong</option>
<option value="Hungary">Hungary</option>
<option value="Iceland">Iceland</option>
<option value="India">India</option>
<option value="Indonesia">Indonesia</option>
<option value="Iran, Islamic Republic of">Iran, Islamic Republic of</option>
<option value="Iraq">Iraq</option>
<option value="Ireland">Ireland</option>
<option value="Isle of Man">Isle of Man</option>
<option value="Israel">Israel</option>
<option value="Italy">Italy</option>
<option value="Jamaica">Jamaica</option>
<option value="Japan">Japan</option>
<option value="Jersey">Jersey</option>
<option value="Jordan">Jordan</option>
<option value="Kazakhstan">Kazakhstan</option>
<option value="Kenya">Kenya</option>
<option value="Kiribati">Kiribati</option>
<option value="Korea, Democratic People's Republic of">Korea, Democratic People's Republic of</option>
<option value="Korea, Republic of">Korea, Republic of</option>
<option value="Kuwait">Kuwait</option>
<option value="Kyrgyzstan">Kyrgyzstan</option>
<option value="Lao People's Democratic Republic">Lao People's Democratic Republic</option>
<option value="Latvia">Latvia</option>
<option value="Lebanon">Lebanon</option>
<option value="Lesotho">Lesotho</option>
<option value="Liberia">Liberia</option>
<option value="Libyan Arab Jamahiriya">Libyan Arab Jamahiriya</option>
<option value="Liechtenstein">Liechtenstein</option>
<option value="Lithuania">Lithuania</option>
<option value="Luxembourg">Luxembourg</option>
<option value="Macao">Macao</option>
<option value="Macedonia, The Former Yugoslav Republic Of">Macedonia, The Former Yugoslav Republic Of</option>
<option value="Madagascar">Madagascar</option>
<option value="Malawi">Malawi</option>
<option value="Malaysia">Malaysia</option>
<option value="Maldives">Maldives</option>
<option value="Mali">Mali</option>
<option value="Malta">Malta</option>
<option value="Marshall Islands">Marshall Islands</option>
<option value="Martinique">Martinique</option>
<option value="Mauritania">Mauritania</option>
<option value="Mauritius">Mauritius</option>
<option value="Mayotte">Mayotte</option>
<option value="Mexico">Mexico</option>
<option value="Micronesia, Federated States of">Micronesia, Federated States of</option>
<option value="Moldova, Republic of">Moldova, Republic of</option>
<option value="Monaco">Monaco</option>
<option value="Mongolia">Mongolia</option>
<option value="Montenegro">Montenegro</option>
<option value="Montserrat">Montserrat</option>
<option value="Morocco">Morocco</option>
<option value="Mozambique">Mozambique</option>
<option value="Myanmar">Myanmar</option>
<option value="Namibia">Namibia</option>
<option value="Nauru">Nauru</option>
<option value="Nepal">Nepal</option>
<option value="Netherlands">Netherlands</option>
<option value="Netherlands Antilles">Netherlands Antilles</option>
<option value="New Caledonia">New Caledonia</option>
<option selected="selected" value="New Zealand">New Zealand</option>
<option value="Nicaragua">Nicaragua</option>
<option value="Niger">Niger</option>
<option value="Nigeria">Nigeria</option>
<option value="Niue">Niue</option>
<option value="Norfolk Island">Norfolk Island</option>
<option value="Northern Mariana Islands">Northern Mariana Islands</option>
<option value="Norway">Norway</option>
<option value="Oman">Oman</option>
<option value="Pakistan">Pakistan</option>
<option value="Palau">Palau</option>
<option value="Palestinian Territory, Occupied">Palestinian Territory, Occupied</option>
<option value="Panama">Panama</option>
<option value="Papua New Guinea">Papua New Guinea</option>
<option value="Paraguay">Paraguay</option>
<option value="Peru">Peru</option>
<option value="Philippines">Philippines</option>
<option value="Pitcairn">Pitcairn</option>
<option value="Poland">Poland</option>
<option value="Portugal">Portugal</option>
<option value="Puerto Rico">Puerto Rico</option>
<option value="Qatar">Qatar</option>
<option value="Reunion">Reunion</option>
<option value="Romania">Romania</option>
<option value="Russian Federation">Russian Federation</option>
<option value="Rwanda">Rwanda</option>
<option value="Saint Barthelemy">Saint Barthelemy</option>
<option value="Saint Helena">Saint Helena</option>
<option value="Saint Kitts and Nevis">Saint Kitts and Nevis</option>
<option value="Saint Lucia">Saint Lucia</option>
<option value="Saint Pierre and Miquelon">Saint Pierre and Miquelon</option>
<option value="Saint Vincent and the Grenadines">Saint Vincent and the Grenadines</option>
<option value="Samoa">Samoa</option>
<option value="San Marino">San Marino</option>
<option value="Sao Tome and Principe">Sao Tome and Principe</option>
<option value="Saudi Arabia">Saudi Arabia</option>
<option value="Senegal">Senegal</option>
<option value="Serbia">Serbia</option>
<option value="Seychelles">Seychelles</option>
<option value="Sierra Leone">Sierra Leone</option>
<option value="Singapore">Singapore</option>
<option value="Slovakia">Slovakia</option>
<option value="Slovenia">Slovenia</option>
<option value="Solomon Islands">Solomon Islands</option>
<option value="Somalia">Somalia</option>
<option value="South Africa">South Africa</option>
<option value="South Georgia and the South Sandwich Islands">South Georgia and the South Sandwich Islands</option>
<option value="Spain">Spain</option>
<option value="Sri Lanka">Sri Lanka</option>
<option value="Sudan">Sudan</option>
<option value="Suriname">Suriname</option>
<option value="Svalbard and Jan Mayen">Svalbard and Jan Mayen</option>
<option value="Swaziland">Swaziland</option>
<option value="Sweden">Sweden</option>
<option value="Switzerland">Switzerland</option>
<option value="Syrian Arab Republic">Syrian Arab Republic</option>
<option value="Taiwan, Province of China">Taiwan, Province of China</option>
<option value="Tajikistan">Tajikistan</option>
<option value="Tanzania, United Republic of">Tanzania, United Republic of</option>
<option value="Thailand">Thailand</option>
<option value="Timor-Leste">Timor-Leste</option>
<option value="Togo">Togo</option>
<option value="Tokelau">Tokelau</option>
<option value="Tonga">Tonga</option>
<option value="Trinidad and Tobago">Trinidad and Tobago</option>
<option value="Tunisia">Tunisia</option>
<option value="Turkey">Turkey</option>
<option value="Turkmenistan">Turkmenistan</option>
<option value="Turks and Caicos Islands">Turks and Caicos Islands</option>
<option value="Tuvalu">Tuvalu</option>
<option value="Uganda">Uganda</option>
<option value="Ukraine">Ukraine</option>
<option value="United Arab Emirates">United Arab Emirates</option>
<option value="United Kingdom">United Kingdom</option>
<option value="United States">United States</option>
<option value="United States Minor Outlying Islands">United States Minor Outlying Islands</option>
<option value="Uruguay">Uruguay</option>
<option value="Uzbekistan">Uzbekistan</option>
<option value="Vanuatu">Vanuatu</option>
<option value="Venezuela">Venezuela</option>
<option value="Viet Nam">Viet Nam</option>
<option value="Virgin Islands, British">Virgin Islands, British</option>
<option value="Virgin Islands, U.S.">Virgin Islands, U.S.</option>
<option value="Wallis and Futuna">Wallis and Futuna</option>
<option value="Western Sahara">Western Sahara</option>
<option value="Yemen">Yemen</option>
<option value="Zambia">Zambia</option>
<option value="Zimbabwe">Zimbabwe</option></select>
  COUNTRIES
      assert_deprecated 'list-of-countries' do
        assert_dom_equal(expected_select[0..-2], country_select("post", "origin", ["New Zealand", "Nicaragua"]))
      end
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

      _erbout = ''

      fields_for :firm, @firm do |f|
        _erbout.concat f.time_zone_select(:time_zone)
      end

      assert_dom_equal(
        "<select id=\"firm_time_zone\" name=\"firm[time_zone]\">" +
        "<option value=\"A\">A</option>\n" +
        "<option value=\"B\">B</option>\n" +
        "<option value=\"C\">C</option>\n" +
        "<option value=\"D\" selected=\"selected\">D</option>\n" +
        "<option value=\"E\">E</option>" +
        "</select>",
        _erbout
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
