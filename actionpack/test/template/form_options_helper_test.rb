require File.dirname(__FILE__) + '/../abstract_unit'

class MockTimeZone
  attr_reader :name

  def initialize( name )
    @name = name
  end

  def self.all
    [ "A", "B", "C", "D", "E" ].map { |s| new s }
  end

  def ==( z )
    z && @name == z.name
  end

  def to_s
    @name
  end
end

ActionView::Helpers::FormOptionsHelper::TimeZone = MockTimeZone

class FormOptionsHelperTest < Test::Unit::TestCase
  include ActionView::Helpers::FormHelper
  include ActionView::Helpers::FormOptionsHelper

  silence_warnings do
    Post      = Struct.new('Post', :title, :author_name, :body, :secret, :written_on, :category, :origin)
    Continent = Struct.new('Continent', :continent_name, :countries)
    Country   = Struct.new('Country', :country_id, :country_name)
    Firm      = Struct.new('Firm', :time_zone)
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
      options_for_select({ "$" => "Dollar", "<DKR>" => "<Kroner>" })
    )
    assert_dom_equal(
      "<option value=\"&lt;Kroner&gt;\">&lt;DKR&gt;</option>\n<option value=\"Dollar\" selected=\"selected\">$</option>",
      options_for_select({ "$" => "Dollar", "<DKR>" => "<Kroner>" }, "Dollar")
    )
    assert_dom_equal(
      "<option value=\"&lt;Kroner&gt;\" selected=\"selected\">&lt;DKR&gt;</option>\n<option value=\"Dollar\" selected=\"selected\">$</option>",
      options_for_select({ "$" => "Dollar", "<DKR>" => "<Kroner>" }, [ "Dollar", "<Kroner>" ])
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

  def test_html_option_groups_from_collection
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
    zones = [ TimeZone.new( "B" ), TimeZone.new( "E" ) ]
    opts = time_zone_options_for_select( nil, zones )
    assert_dom_equal "<option value=\"B\">B</option>\n" +
                 "<option value=\"E\">E</option>" +
                 "<option value=\"\">-------------</option>\n" +
                 "<option value=\"A\">A</option>\n" +
                 "<option value=\"C\">C</option>\n" +
                 "<option value=\"D\">D</option>",
                 opts
  end

  def test_time_zone_options_with_selected_priority_zones
    zones = [ TimeZone.new( "B" ), TimeZone.new( "E" ) ]
    opts = time_zone_options_for_select( "E", zones )
    assert_dom_equal "<option value=\"B\">B</option>\n" +
                 "<option value=\"E\" selected=\"selected\">E</option>" +
                 "<option value=\"\">-------------</option>\n" +
                 "<option value=\"A\">A</option>\n" +
                 "<option value=\"C\">C</option>\n" +
                 "<option value=\"D\">D</option>",
                 opts
  end

  def test_time_zone_options_with_unselected_priority_zones
    zones = [ TimeZone.new( "B" ), TimeZone.new( "E" ) ]
    opts = time_zone_options_for_select( "C", zones )
    assert_dom_equal "<option value=\"B\">B</option>\n" +
                 "<option value=\"E\">E</option>" +
                 "<option value=\"\">-------------</option>\n" +
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

  def test_country_select
    @post = Post.new
    @post.origin = "Denmark"
    assert_dom_equal(
      "<select id=\"post_origin\" name=\"post[origin]\"><option value=\"Afghanistan\">Afghanistan</option>\n<option value=\"Albania\">Albania</option>\n<option value=\"Algeria\">Algeria</option>\n<option value=\"American Samoa\">American Samoa</option>\n<option value=\"Andorra\">Andorra</option>\n<option value=\"Angola\">Angola</option>\n<option value=\"Anguilla\">Anguilla</option>\n<option value=\"Antarctica\">Antarctica</option>\n<option value=\"Antigua And Barbuda\">Antigua And Barbuda</option>\n<option value=\"Argentina\">Argentina</option>\n<option value=\"Armenia\">Armenia</option>\n<option value=\"Aruba\">Aruba</option>\n<option value=\"Australia\">Australia</option>\n<option value=\"Austria\">Austria</option>\n<option value=\"Azerbaijan\">Azerbaijan</option>\n<option value=\"Bahamas\">Bahamas</option>\n<option value=\"Bahrain\">Bahrain</option>\n<option value=\"Bangladesh\">Bangladesh</option>\n<option value=\"Barbados\">Barbados</option>\n<option value=\"Belarus\">Belarus</option>\n<option value=\"Belgium\">Belgium</option>\n<option value=\"Belize\">Belize</option>\n<option value=\"Benin\">Benin</option>\n<option value=\"Bermuda\">Bermuda</option>\n<option value=\"Bhutan\">Bhutan</option>\n<option value=\"Bolivia\">Bolivia</option>\n<option value=\"Bosnia and Herzegowina\">Bosnia and Herzegowina</option>\n<option value=\"Botswana\">Botswana</option>\n<option value=\"Bouvet Island\">Bouvet Island</option>\n<option value=\"Brazil\">Brazil</option>\n<option value=\"British Indian Ocean Territory\">British Indian Ocean Territory</option>\n<option value=\"Brunei Darussalam\">Brunei Darussalam</option>\n<option value=\"Bulgaria\">Bulgaria</option>\n<option value=\"Burkina Faso\">Burkina Faso</option>\n<option value=\"Burma\">Burma</option>\n<option value=\"Burundi\">Burundi</option>\n<option value=\"Cambodia\">Cambodia</option>\n<option value=\"Cameroon\">Cameroon</option>\n<option value=\"Canada\">Canada</option>\n<option value=\"Cape Verde\">Cape Verde</option>\n<option value=\"Cayman Islands\">Cayman Islands</option>\n<option value=\"Central African Republic\">Central African Republic</option>\n<option value=\"Chad\">Chad</option>\n<option value=\"Chile\">Chile</option>\n<option value=\"China\">China</option>\n<option value=\"Christmas Island\">Christmas Island</option>\n<option value=\"Cocos (Keeling) Islands\">Cocos (Keeling) Islands</option>\n<option value=\"Colombia\">Colombia</option>\n<option value=\"Comoros\">Comoros</option>\n<option value=\"Congo\">Congo</option>\n<option value=\"Congo, the Democratic Republic of the\">Congo, the Democratic Republic of the</option>\n<option value=\"Cook Islands\">Cook Islands</option>\n<option value=\"Costa Rica\">Costa Rica</option>\n<option value=\"Cote d'Ivoire\">Cote d'Ivoire</option>\n<option value=\"Croatia\">Croatia</option>\n<option value=\"Cuba\">Cuba</option>\n<option value=\"Cyprus\">Cyprus</option>\n<option value=\"Czech Republic\">Czech Republic</option>\n<option value=\"Denmark\" selected=\"selected\">Denmark</option>\n<option value=\"Djibouti\">Djibouti</option>\n<option value=\"Dominica\">Dominica</option>\n<option value=\"Dominican Republic\">Dominican Republic</option>\n<option value=\"East Timor\">East Timor</option>\n<option value=\"Ecuador\">Ecuador</option>\n<option value=\"Egypt\">Egypt</option>\n<option value=\"El Salvador\">El Salvador</option>\n<option value=\"England\">England" +
      "</option>\n<option value=\"Equatorial Guinea\">Equatorial Guinea</option>\n<option value=\"Eritrea\">Eritrea</option>\n<option value=\"Espana\">Espana</option>\n<option value=\"Estonia\">Estonia</option>\n<option value=\"Ethiopia\">Ethiopia</option>\n<option value=\"Falkland Islands\">Falkland Islands</option>\n<option value=\"Faroe Islands\">Faroe Islands</option>\n<option value=\"Fiji\">Fiji</option>\n<option value=\"Finland\">Finland</option>\n<option value=\"France\">France</option>\n<option value=\"French Guiana\">French Guiana</option>\n<option value=\"French Polynesia\">French Polynesia</option>\n<option value=\"French Southern Territories\">French Southern Territories</option>\n<option value=\"Gabon\">Gabon</option>\n<option value=\"Gambia\">Gambia</option>\n<option value=\"Georgia\">Georgia</option>\n<option value=\"Germany\">Germany</option>\n<option value=\"Ghana\">Ghana</option>\n<option value=\"Gibraltar\">Gibraltar</option>\n<option value=\"Great Britain\">Great Britain</option>\n<option value=\"Greece\">Greece</option>\n<option value=\"Greenland\">Greenland</option>\n<option value=\"Grenada\">Grenada</option>\n<option value=\"Guadeloupe\">Guadeloupe</option>\n<option value=\"Guam\">Guam</option>\n<option value=\"Guatemala\">Guatemala</option>\n<option value=\"Guinea\">Guinea</option>\n<option value=\"Guinea-Bissau\">Guinea-Bissau</option>\n<option value=\"Guyana\">Guyana</option>\n<option value=\"Haiti\">Haiti</option>\n<option value=\"Heard and Mc Donald Islands\">Heard and Mc Donald Islands</option>\n<option value=\"Honduras\">Honduras</option>\n<option value=\"Hong Kong\">Hong Kong</option>\n<option value=\"Hungary\">Hungary</option>\n<option value=\"Iceland\">Iceland</option>\n<option value=\"India\">India</option>\n<option value=\"Indonesia\">Indonesia</option>\n<option value=\"Ireland\">Ireland</option>\n<option value=\"Israel\">Israel</option>\n<option value=\"Italy\">Italy</option>\n<option value=\"Iran\">Iran</option>\n<option value=\"Iraq\">Iraq</option>\n<option value=\"Jamaica\">Jamaica</option>\n<option value=\"Japan\">Japan</option>\n<option value=\"Jordan\">Jordan</option>\n<option value=\"Kazakhstan\">Kazakhstan</option>\n<option value=\"Kenya\">Kenya</option>\n<option value=\"Kiribati\">Kiribati</option>\n<option value=\"Korea, Republic of\">Korea, Republic of</option>\n<option value=\"Korea (South)\">Korea (South)</option>\n<option value=\"Kuwait\">Kuwait</option>\n<option value=\"Kyrgyzstan\">Kyrgyzstan</option>\n<option value=\"Lao People's Democratic Republic\">Lao People's Democratic Republic</option>\n<option value=\"Latvia\">Latvia</option>\n<option value=\"Lebanon\">Lebanon</option>\n<option value=\"Lesotho\">Lesotho</option>\n<option value=\"Liberia\">Liberia</option>\n<option value=\"Liechtenstein\">Liechtenstein</option>\n<option value=\"Lithuania\">Lithuania</option>\n<option value=\"Luxembourg\">Luxembourg</option>\n<option value=\"Macau\">Macau</option>\n<option value=\"Macedonia\">Macedonia</option>\n<option value=\"Madagascar\">Madagascar</option>\n<option value=\"Malawi\">Malawi</option>\n<option value=\"Malaysia\">Malaysia</option>\n<option value=\"Maldives\">Maldives</option>\n<option value=\"Mali\">Mali</option>\n<option value=\"Malta\">Malta</option>\n<option value=\"Marshall Islands\">Marshall Islands</option>\n<option value=\"Martinique\">Martinique</option>\n<option value=\"Mauritania\">Mauritania</option>\n<option value=\"Mauritius\">Mauritius</option>\n<option value=\"Mayotte\">Mayotte</option>\n<option value=\"Mexico\">Mexico</option>\n<option value=\"Micronesia, Federated States of\">Micronesia, Federated States of</option>\n<option value=\"Moldova, Republic of\">Moldova, Republic of</option>\n<option value=\"Monaco\">Monaco</option>\n<option value=\"Mongolia\">Mongolia</option>\n<option value=\"Montserrat\">Montserrat</option>\n<option value=\"Morocco\">Morocco</option>\n<option value=\"Mozambique\">Mozambique</option>\n<option value=\"Myanmar\">Myanmar</option>\n<option value=\"Namibia\">Namibia</option>\n<option value=\"Nauru\">Nauru</option>\n<option value=\"Nepal\">Nepal</option>\n<option value=\"Netherlands\">Netherlands</option>\n<option value=\"Netherlands Antilles\">Netherlands Antilles</option>\n<option value=\"New Caledonia\">New Caledonia</option>" +
      "\n<option value=\"New Zealand\">New Zealand</option>\n<option value=\"Nicaragua\">Nicaragua</option>\n<option value=\"Niger\">Niger</option>\n<option value=\"Nigeria\">Nigeria</option>\n<option value=\"Niue\">Niue</option>\n<option value=\"Norfolk Island\">Norfolk Island</option>\n<option value=\"Northern Ireland\">Northern Ireland</option>\n<option value=\"Northern Mariana Islands\">Northern Mariana Islands</option>\n<option value=\"Norway\">Norway</option>\n<option value=\"Oman\">Oman</option>\n<option value=\"Pakistan\">Pakistan</option>\n<option value=\"Palau\">Palau</option>\n<option value=\"Panama\">Panama</option>\n<option value=\"Papua New Guinea\">Papua New Guinea</option>\n<option value=\"Paraguay\">Paraguay</option>\n<option value=\"Peru\">Peru</option>\n<option value=\"Philippines\">Philippines</option>\n<option value=\"Pitcairn\">Pitcairn</option>\n<option value=\"Poland\">Poland</option>\n<option value=\"Portugal\">Portugal</option>\n<option value=\"Puerto Rico\">Puerto Rico</option>\n<option value=\"Qatar\">Qatar</option>\n<option value=\"Reunion\">Reunion</option>\n<option value=\"Romania\">Romania</option>\n<option value=\"Russia\">Russia</option>\n<option value=\"Rwanda\">Rwanda</option>\n<option value=\"Saint Kitts and Nevis\">Saint Kitts and Nevis</option>\n<option value=\"Saint Lucia\">Saint Lucia</option>\n<option value=\"Saint Vincent and the Grenadines\">Saint Vincent and the Grenadines</option>\n<option value=\"Samoa (Independent)\">Samoa (Independent)</option>\n<option value=\"San Marino\">San Marino</option>\n<option value=\"Sao Tome and Principe\">Sao Tome and Principe</option>\n<option value=\"Saudi Arabia\">Saudi Arabia</option>\n<option value=\"Scotland\">Scotland</option>\n<option value=\"Senegal\">Senegal</option>\n<option value=\"Serbia and Montenegro\">Serbia and Montenegro</option>\n<option value=\"Seychelles\">Seychelles</option>\n<option value=\"Sierra Leone\">Sierra Leone</option>\n<option value=\"Singapore\">Singapore</option>\n<option value=\"Slovakia\">Slovakia</option>\n<option value=\"Slovenia\">Slovenia</option>\n<option value=\"Solomon Islands\">Solomon Islands</option>\n<option value=\"Somalia\">Somalia</option>\n<option value=\"South Africa\">South Africa</option>\n<option value=\"South Georgia and the South Sandwich Islands\">South Georgia and the South Sandwich Islands</option>\n<option value=\"South Korea\">South Korea</option>\n<option value=\"Spain\">Spain</option>\n<option value=\"Sri Lanka\">Sri Lanka</option>\n<option value=\"St. Helena\">St. Helena</option>\n<option value=\"St. Pierre and Miquelon\">St. Pierre and Miquelon</option>\n<option value=\"Suriname\">Suriname</option>\n<option value=\"Svalbard and Jan Mayen Islands\">Svalbard and Jan Mayen Islands</option>\n<option value=\"Swaziland\">Swaziland</option>\n<option value=\"Sweden\">Sweden</option>\n<option value=\"Switzerland\">Switzerland</option>\n<option value=\"Taiwan\">Taiwan</option>\n<option value=\"Tajikistan\">Tajikistan</option>\n<option value=\"Tanzania\">Tanzania</option>\n<option value=\"Thailand\">Thailand</option>\n<option value=\"Togo\">Togo</option>\n<option value=\"Tokelau\">Tokelau</option>\n<option value=\"Tonga\">Tonga</option>\n<option value=\"Trinidad\">Trinidad</option>\n<option value=\"Trinidad and Tobago\">Trinidad and Tobago</option>\n<option value=\"Tunisia\">Tunisia</option>\n<option value=\"Turkey\">Turkey</option>\n<option value=\"Turkmenistan\">" +
      "Turkmenistan</option>\n<option value=\"Turks and Caicos Islands\">Turks and Caicos Islands</option>\n<option value=\"Tuvalu\">Tuvalu</option>\n<option value=\"Uganda\">Uganda</option>\n<option value=\"Ukraine\">Ukraine</option>\n<option value=\"United Arab Emirates\">United Arab Emirates</option>\n<option value=\"United Kingdom\">United Kingdom</option>\n<option value=\"United States\">United States</option>\n<option value=\"United States Minor Outlying Islands\">United States Minor Outlying Islands</option>\n<option value=\"Uruguay\">Uruguay</option>\n<option value=\"Uzbekistan\">Uzbekistan</option>\n<option value=\"Vanuatu\">Vanuatu</option>\n<option value=\"Vatican City State (Holy See)\">Vatican City State (Holy See)</option>\n<option value=\"Venezuela\">Venezuela</option>\n<option value=\"Viet Nam\">Viet Nam</option>\n<option value=\"Virgin Islands (British)\">Virgin Islands (British)</option>\n<option value=\"Virgin Islands (U.S.)\">Virgin Islands (U.S.)</option>\n<option value=\"Wales\">Wales</option>\n<option value=\"Wallis and Futuna Islands\">Wallis and Futuna Islands</option>\n<option value=\"Western Sahara\">Western Sahara</option>\n<option value=\"Yemen\">Yemen</option>\n<option value=\"Zambia\">Zambia</option>\n<option value=\"Zimbabwe\">Zimbabwe</option></select>",
      country_select("post", "origin")
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

  def test_time_zone_select_with_priority_zones
    @firm = Firm.new("D")
    zones = [ TimeZone.new("A"), TimeZone.new("D") ]
    html = time_zone_select("firm", "time_zone", zones )
    assert_dom_equal "<select id=\"firm_time_zone\" name=\"firm[time_zone]\">" +
                 "<option value=\"A\">A</option>\n" +
                 "<option value=\"D\" selected=\"selected\">D</option>" +
                 "<option value=\"\">-------------</option>\n" +
                 "<option value=\"B\">B</option>\n" +
                 "<option value=\"C\">C</option>\n" +
                 "<option value=\"E\">E</option>" +
                 "</select>",
                 html
  end
end
