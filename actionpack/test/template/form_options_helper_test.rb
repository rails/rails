require 'test/unit'
require File.dirname(__FILE__) + '/../../lib/action_view/helpers/form_options_helper'

class FormOptionsHelperTest < Test::Unit::TestCase
  include ActionView::Helpers::FormOptionsHelper

  old_verbose, $VERBOSE = $VERBOSE, nil
  Post      = Struct.new('Post', :title, :author_name, :body, :secret, :written_on, :category, :origin)
  Continent = Struct.new('Continent', :continent_name, :countries)
  Country   = Struct.new('Country', :country_id, :country_name)
  $VERBOSE = old_verbose

  def test_collection_options
    @posts = [
      Post.new("<Abe> went home", "<Abe>", "To a little house", "shh!"),
      Post.new("Babe went home", "Babe", "To a little house", "shh!"),
      Post.new("Cabe went home", "Cabe", "To a little house", "shh!")
    ]

    assert_equal(
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

    assert_equal(
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

      assert_equal(
        "<option value=\"&lt;Abe&gt;\">&lt;Abe&gt; went home</option>\n<option value=\"Babe\" selected=\"selected\">Babe went home</option>\n<option value=\"Cabe\" selected=\"selected\">Cabe went home</option>",
        options_from_collection_for_select(@posts, "author_name", "title", [ "Babe", "Cabe" ])
      )
  end

  def test_array_options_for_select
    assert_equal(
      "<option>&lt;Denmark&gt;</option>\n<option>USA</option>\n<option>Sweden</option>", 
      options_for_select([ "<Denmark>", "USA", "Sweden" ])
    )
  end

  def test_array_options_for_select_with_selection
    assert_equal(
      "<option>Denmark</option>\n<option selected=\"selected\">&lt;USA&gt;</option>\n<option>Sweden</option>", 
      options_for_select([ "Denmark", "<USA>", "Sweden" ], "<USA>")
    )
  end

  def test_array_options_for_select_with_selection_array
      assert_equal(
        "<option>Denmark</option>\n<option selected=\"selected\">&lt;USA&gt;</option>\n<option selected=\"selected\">Sweden</option>",
        options_for_select([ "Denmark", "<USA>", "Sweden" ], [ "<USA>", "Sweden" ])
      )
  end

  def test_hash_options_for_select
    assert_equal(
      "<option value=\"&lt;Kroner&gt;\">&lt;DKR&gt;</option>\n<option value=\"Dollar\">$</option>", 
      options_for_select({ "$" => "Dollar", "<DKR>" => "<Kroner>" })
    )
  end

  def test_hash_options_for_select_with_selection
    assert_equal(
      "<option value=\"&lt;Kroner&gt;\">&lt;DKR&gt;</option>\n<option value=\"Dollar\" selected=\"selected\">$</option>", 
      options_for_select({ "$" => "Dollar", "<DKR>" => "<Kroner>" }, "Dollar")
    )
  end

  def test_hash_options_for_select_with_selection
    assert_equal(
      "<option value=\"&lt;Kroner&gt;\" selected=\"selected\">&lt;DKR&gt;</option>\n<option value=\"Dollar\" selected=\"selected\">$</option>", 
      options_for_select({ "$" => "Dollar", "<DKR>" => "<Kroner>" }, [ "Dollar", "<Kroner>" ])
    )
  end

  def test_html_option_groups_from_collection
    @continents = [
      Continent.new("<Africa>", [Country.new("<sa>", "<South Africa>"), Country.new("so", "Somalia")] ),
      Continent.new("Europe", [Country.new("dk", "Denmark"), Country.new("ie", "Ireland")] )
    ]

    assert_equal(
      "<optgroup label=\"&lt;Africa&gt;\"><option value=\"&lt;sa&gt;\">&lt;South Africa&gt;</option>\n<option value=\"so\">Somalia</option></optgroup><optgroup label=\"Europe\"><option value=\"dk\" selected=\"selected\">Denmark</option>\n<option value=\"ie\">Ireland</option></optgroup>",
      option_groups_from_collection_for_select(@continents, "countries", "continent_name", "country_id", "country_name", "dk")
    )
  end

  def test_select
    @post = Post.new
    @post.category = "<mus>"
    assert_equal(
      "<select id=\"post_category\" name=\"post[category]\"><option>abe</option>\n<option selected=\"selected\">&lt;mus&gt;</option>\n<option>hest</option></select>", 
      select("post", "category", %w( abe <mus> hest))
    )
  end

  def test_select_with_blank
    @post = Post.new
    @post.category = "<mus>"
    assert_equal(
      "<select id=\"post_category\" name=\"post[category]\"><option></option>\n<option>abe</option>\n<option selected=\"selected\">&lt;mus&gt;</option>\n<option>hest</option></select>", 
      select("post", "category", %w( abe <mus> hest), :include_blank => true)
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

    assert_equal(
      "<select id=\"post_author_name\" name=\"post[author_name]\"><option value=\"&lt;Abe&gt;\">&lt;Abe&gt;</option>\n<option value=\"Babe\" selected=\"selected\">Babe</option>\n<option value=\"Cabe\">Cabe</option></select>", 
      collection_select("post", "author_name", @posts, "author_name", "author_name")
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

    assert_equal(
      "<select id=\"post_author_name\" name=\"post[author_name]\" style=\"width: 200px\"><option></option>\n<option value=\"&lt;Abe&gt;\">&lt;Abe&gt;</option>\n<option value=\"Babe\" selected=\"selected\">Babe</option>\n<option value=\"Cabe\">Cabe</option></select>", 
      collection_select("post", "author_name", @posts, "author_name", "author_name", { :include_blank => true }, "style" => "width: 200px")
    )
  end

  def test_country_select
    @post = Post.new
    @post.origin = "Denmark"
    assert_equal(
      "<select id=\"post_origin\" name=\"post[origin]\"><option>Albania</option>\n<option>Algeria</option>\n<option>American Samoa</option>\n<option>Andorra</option>\n<option>Angola</option>\n<option>Anguilla</option>\n<option>Antarctica</option>\n<option>Antigua And Barbuda</option>\n<option>Argentina</option>\n<option>Armenia</option>\n<option>Aruba</option>\n<option>Australia</option>\n<option>Austria</option>\n<option>Azerbaijan</option>\n<option>Bahamas</option>\n<option>Bahrain</option>\n<option>Bangladesh</option>\n<option>Barbados</option>\n<option>Belarus</option>\n<option>Belgium</option>\n<option>Belize</option>\n<option>Benin</option>\n<option>Bermuda</option>\n<option>Bhutan</option>\n<option>Bolivia</option>\n<option>Bosnia and Herzegowina</option>\n<option>Botswana</option>\n<option>Bouvet Island</option>\n<option>Brazil</option>\n<option>British Indian Ocean Territory</option>\n<option>Brunei Darussalam</option>\n<option>Bulgaria</option>\n<option>Burkina Faso</option>\n<option>Burma</option>\n<option>Burundi</option>\n<option>Cambodia</option>\n<option>Cameroon</option>\n<option>Canada</option>\n<option>Cape Verde</option>\n<option>Cayman Islands</option>\n<option>Central African Republic</option>\n<option>Chad</option>\n<option>Chile</option>\n<option>China</option>\n<option>Christmas Island</option>\n<option>Cocos (Keeling) Islands</option>\n<option>Colombia</option>\n<option>Comoros</option>\n<option>Congo</option>\n<option>Congo, the Democratic Republic of the</option>\n<option>Cook Islands</option>\n<option>Costa Rica</option>\n<option>Cote d'Ivoire</option>\n<option>Croatia</option>\n<option>Cyprus</option>\n<option>Czech Republic</option>\n<option selected=\"selected\">Denmark</option>\n<option>Djibouti</option>\n<option>Dominica</option>\n<option>Dominican Republic</option>\n<option>East Timor</option>\n<option>Ecuador</option>\n<option>Egypt</option>\n<option>El Salvador</option>\n<option>England</option>\n<option>Equatorial Guinea</option>\n<option>Eritrea</option>\n<option>Espana</option>\n<option>Estonia</option>\n<option>Ethiopia</option>\n<option>Falkland Islands</option>\n<option>Faroe Islands</option>\n<option>Fiji</option>\n<option>Finland</option>\n<option>France</option>\n<option>French Guiana</option>\n<option>French Polynesia</option>\n<option>French Southern Territories</option>\n<option>Gabon</option>\n<option>Gambia</option>\n<option>Georgia</option>\n<option>Germany</option>\n<option>Ghana</option>\n<option>Gibraltar</option>\n<option>Great Britain</option>\n<option>Greece</option>\n<option>Greenland</option>\n<option>Grenada</option>\n<option>Guadeloupe</option>\n<option>Guam</option>\n<option>Guatemala</option>\n<option>Guinea</option>\n<option>Guinea-Bissau</option>\n<option>Guyana</option>\n<option>Haiti</option>\n<option>Heard and Mc Donald Islands</option>\n<option>Honduras</option>\n<option>Hong Kong</option>\n<option>Hungary</option>\n<option>Iceland</option>\n<option>India</option>\n<option>Indonesia</option>\n<option>Ireland</option>\n<option>Israel</option>\n<option>Italy</option>\n<option>Jamaica</option>\n<option>Japan</option>\n<option>Jordan</option>\n<option>Kazakhstan</option>\n<option>Kenya</option>\n<option>Kiribati</option>\n<option>Korea, Republic of</option>\n<option>Korea (South)</option>\n<option>Kuwait</option>\n<option>Kyrgyzstan</option>\n<option>Lao People's Democratic Republic</option>\n<option>Latvia</option>\n<option>Lebanon</option>\n<option>Lesotho</option>\n<option>Liberia</option>\n<option>Liechtenstein</option>\n<option>Lithuania</option>\n<option>Luxembourg</option>\n<option>Macau</option>\n<option>Macedonia</option>\n<option>Madagascar</option>\n<option>Malawi</option>\n<option>Malaysia</option>\n<option>Maldives</option>\n<option>Mali</option>\n<option>Malta</option>\n<option>Marshall Islands</option>\n<option>Martinique</option>\n<option>Mauritania</option>\n<option>Mauritius</option>\n<option>Mayotte</option>\n<option>Mexico</option>\n<option>Micronesia, Federated States of</option>\n<option>Moldova, Republic of</option>\n<option>Monaco</option>\n<option>Mongolia</option>\n<option>Montserrat</option>\n<option>Morocco</option>\n<option>Mozambique</option>\n<option>Myanmar</option>\n<option>Namibia</option>\n<option>Nauru</option>\n<option>Nepal</option>\n<option>Netherlands</option>\n<option>Netherlands Antilles</option>\n<option>New Caledonia</option>\n<option>New Zealand</option>\n<option>Nicaragua</option>\n<option>Niger</option>\n<option>Nigeria</option>\n<option>Niue</option>\n<option>Norfolk Island</option>\n<option>Northern Ireland</option>\n<option>Northern Mariana Islands</option>\n<option>Norway</option>\n<option>Oman</option>\n<option>Pakistan</option>\n<option>Palau</option>\n<option>Panama</option>\n<option>Papua New Guinea</option>\n<option>Paraguay</option>\n<option>Peru</option>\n<option>Philippines</option>\n<option>Pitcairn</option>\n<option>Poland</option>\n<option>Portugal</option>\n<option>Puerto Rico</option>\n<option>Qatar</option>\n<option>Reunion</option>\n<option>Romania</option>\n<option>Russia</option>\n<option>Rwanda</option>\n<option>Saint Kitts and Nevis</option>\n<option>Saint Lucia</option>\n<option>Saint Vincent and the Grenadines</option>\n<option>Samoa (Independent)</option>\n<option>San Marino</option>\n<option>Sao Tome and Principe</option>\n<option>Saudi Arabia</option>\n<option>Scotland</option>\n<option>Senegal</option>\n<option>Seychelles</option>\n<option>Sierra Leone</option>\n<option>Singapore</option>\n<option>Slovakia</option>\n<option>Slovenia</option>\n<option>Solomon Islands</option>\n<option>Somalia</option>\n<option>South Africa</option>\n<option>South Georgia and the South Sandwich Islands</option>\n<option>South Korea</option>\n<option>Spain</option>\n<option>Sri Lanka</option>\n<option>St. Helena</option>\n<option>St. Pierre and Miquelon</option>\n<option>Suriname</option>\n<option>Svalbard and Jan Mayen Islands</option>\n<option>Swaziland</option>\n<option>Sweden</option>\n<option>Switzerland</option>\n<option>Taiwan</option>\n<option>Tajikistan</option>\n<option>Tanzania</option>\n<option>Thailand</option>\n<option>Togo</option>\n<option>Tokelau</option>\n<option>Tonga</option>\n<option>Trinidad</option>\n<option>Trinidad and Tobago</option>\n<option>Tunisia</option>\n<option>Turkey</option>\n<option>Turkmenistan</option>\n<option>Turks and Caicos Islands</option>\n<option>Tuvalu</option>\n<option>Uganda</option>\n<option>Ukraine</option>\n<option>United Arab Emirates</option>\n<option>United Kingdom</option>\n<option>United States</option>\n<option>United States Minor Outlying Islands</option>\n<option>Uruguay</option>\n<option>Uzbekistan</option>\n<option>Vanuatu</option>\n<option>Vatican City State (Holy See)</option>\n<option>Venezuela</option>\n<option>Viet Nam</option>\n<option>Virgin Islands (British)</option>\n<option>Virgin Islands (U.S.)</option>\n<option>Wales</option>\n<option>Wallis and Futuna Islands</option>\n<option>Western Sahara</option>\n<option>Yemen</option>\n<option>Zambia</option>\n<option>Zimbabwe</option></select>",
      country_select("post", "origin")
    )
  end
end
