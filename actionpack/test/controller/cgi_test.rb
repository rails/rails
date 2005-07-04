$:.unshift File.dirname(__FILE__) + "/../../lib"

require 'test/unit'
require 'action_controller/cgi_ext/cgi_methods'
require 'stringio'

class MockUploadedFile < StringIO
  def content_type
    "img/jpeg"
  end

  def original_filename
    "my_file.doc"
  end
end

class CGITest < Test::Unit::TestCase
  def setup
    @query_string = "action=create_customer&full_name=David%20Heinemeier%20Hansson&customerId=1"
    @query_string_with_nil = "action=create_customer&full_name="
    @query_string_with_array = "action=create_customer&selected[]=1&selected[]=2&selected[]=3"
    @query_string_with_amps  = "action=create_customer&name=Don%27t+%26+Does"
    @query_string_with_multiple_of_same_name = 
      "action=update_order&full_name=Lau%20Taarnskov&products=4&products=2&products=3"
    @query_string_with_many_equal = "action=create_customer&full_name=abc=def=ghi"
    @query_string_without_equal = "action"
  end

  def test_query_string
    assert_equal(
      { "action" => "create_customer", "full_name" => "David Heinemeier Hansson", "customerId" => "1"},
      CGIMethods.parse_query_parameters(@query_string)
    )
  end
  
  def test_deep_query_string
    assert_equal({'x' => {'y' => {'z' => '10'}}}, CGIMethods.parse_query_parameters('x[y][z]=10'))
  end
  
  def test_deep_query_string_with_array
    assert_equal({'x' => {'y' => {'z' => ['10']}}}, CGIMethods.parse_query_parameters('x[y][z][]=10'))
    assert_equal({'x' => {'y' => {'z' => ['10', '5']}}}, CGIMethods.parse_query_parameters('x[y][z][]=10&x[y][z][]=5'))
  end
  
  def test_query_string_with_nil
    assert_equal(
      { "action" => "create_customer", "full_name" => nil},
      CGIMethods.parse_query_parameters(@query_string_with_nil)
    )
  end

  def test_query_string_with_array
    assert_equal(
      { "action" => "create_customer", "selected" => ["1", "2", "3"]},
      CGIMethods.parse_query_parameters(@query_string_with_array)
    )
  end

  def test_query_string_with_amps
    assert_equal(
      { "action" => "create_customer", "name" => "Don't & Does"},
      CGIMethods.parse_query_parameters(@query_string_with_amps)
    )    
  end
  
  def test_query_string_with_many_equal
    assert_equal(
      { "action" => "create_customer", "full_name" => "abc=def=ghi"},
      CGIMethods.parse_query_parameters(@query_string_with_many_equal)
    )    
  end
  
  def test_query_string_without_equal
    assert_equal(
      { "action" => nil },
      CGIMethods.parse_query_parameters(@query_string_without_equal)
    )    
  end
  
  def test_parse_params
    input = {
      "customers[boston][first][name]" => [ "David" ],
      "customers[boston][first][url]" => [ "http://David" ],
      "customers[boston][second][name]" => [ "Allan" ],
      "customers[boston][second][url]" => [ "http://Allan" ],
      "something_else" => [ "blah" ],
      "something_nil" => [ nil ],
      "something_empty" => [ "" ],
      "products[first]" => [ "Apple Computer" ],
      "products[second]" => [ "Pc" ]
    }
    
    expected_output =  {
      "customers" => {
        "boston" => {
          "first" => {
            "name" => "David",
            "url" => "http://David"
          },
          "second" => {
            "name" => "Allan",
            "url" => "http://Allan"
          }
        }
      },
      "something_else" => "blah",
      "something_empty" => "",
      "something_nil" => "",
      "products" => {
        "first" => "Apple Computer",
        "second" => "Pc"
      }
    }

    assert_equal expected_output, CGIMethods.parse_request_parameters(input)
  end
  
  def test_parse_params_from_multipart_upload
    mock_file = MockUploadedFile.new
  
    input = {
      "something" => [ StringIO.new("") ],
      "array_of_stringios" => [[ StringIO.new("One"), StringIO.new("Two") ]],
      "mixed_types_array" => [[ StringIO.new("Three"), "NotStringIO" ]],
      "mixed_types_as_checkboxes[strings][nested]" => [[ mock_file, "String", StringIO.new("StringIO")]],
      "products[string]" => [ StringIO.new("Apple Computer") ],
      "products[file]" => [ mock_file ]
    }
    
    expected_output =  {
      "something" => "",
      "array_of_stringios" => ["One", "Two"],
      "mixed_types_array" => [ "Three", "NotStringIO" ],
      "mixed_types_as_checkboxes" => {
         "strings"=> {
            "nested"=>[ mock_file, "String", "StringIO" ]
         },
      },
      "products"  => {
        "string"  => "Apple Computer",
        "file"    => mock_file
      }
    }

    assert_equal expected_output, CGIMethods.parse_request_parameters(input)
  end
  
  def test_parse_params_with_file
    input = {
      "customers[boston][first][name]" => [ "David" ],
      "something_else" => [ "blah" ],
      "logo" => [ File.new(File.dirname(__FILE__) + "/cgi_test.rb").path ]
    }
    
    expected_output = {
      "customers" => {
        "boston" => {
          "first" => {
            "name" => "David"
          }
        }
      },
      "something_else" => "blah",
      "logo" => File.new(File.dirname(__FILE__) + "/cgi_test.rb").path,
    }

    assert_equal expected_output, CGIMethods.parse_request_parameters(input)
  end

  def test_parse_params_with_array
    input = { "selected[]" =>  [ "1", "2", "3" ] }

    expected_output = { "selected" => [ "1", "2", "3" ] }

    assert_equal expected_output, CGIMethods.parse_request_parameters(input)
  end

  def test_parse_params_with_non_alphanumeric_name
    input     = { "a/b[c]" =>  %w(d) }
    expected  = { "a/b" => { "c" => "d" }}
    assert_equal expected, CGIMethods.parse_request_parameters(input)
  end

  def test_parse_params_with_single_brackets_in_middle
    input     = { "a/b[c]d" =>  %w(e) }
    expected  = { "a/b[c]d" => "e" }
    assert_equal expected, CGIMethods.parse_request_parameters(input)
  end

  def test_parse_params_with_separated_brackets
    input     = { "a/b@[c]d[e]" =>  %w(f) }
    expected  = { "a/b@" => { "c]d[e" => "f" }}
    assert_equal expected, CGIMethods.parse_request_parameters(input)
  end

  def test_parse_params_with_separated_brackets_and_array
    input     = { "a/b@[c]d[e][]" =>  %w(f) }
    expected  = { "a/b@" => { "c]d[e" => ["f"] }}
    assert_equal expected , CGIMethods.parse_request_parameters(input)
  end

  def test_parse_params_with_unmatched_brackets_and_array
    input     = { "a/b@[c][d[e][]" =>  %w(f) }
    expected  = { "a/b@" => { "c" => { "d[e" => ["f"] }}}
    assert_equal expected, CGIMethods.parse_request_parameters(input)
  end
end

