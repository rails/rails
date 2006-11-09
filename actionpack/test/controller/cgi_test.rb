require File.dirname(__FILE__) + '/../abstract_unit'
require 'action_controller/cgi_process'
require 'action_controller/cgi_ext/cgi_ext'


require 'stringio'

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
    @query_string_with_many_ampersands =
      "&action=create_customer&&&full_name=David%20Heinemeier%20Hansson"
    @query_string_with_empty_key = "action=create_customer&full_name=David%20Heinemeier%20Hansson&=Save"
  end

  def test_query_string
    assert_equal(
      { "action" => "create_customer", "full_name" => "David Heinemeier Hansson", "customerId" => "1"},
      CGIMethods.parse_query_parameters(@query_string)
    )
  end
  
  def test_deep_query_string
    expected = {'x' => {'y' => {'z' => '10'}}}
    assert_equal(expected, CGIMethods.parse_query_parameters('x[y][z]=10'))
  end
  
  def test_deep_query_string_with_array
    assert_equal({'x' => {'y' => {'z' => ['10']}}}, CGIMethods.parse_query_parameters('x[y][z][]=10'))
    assert_equal({'x' => {'y' => {'z' => ['10', '5']}}}, CGIMethods.parse_query_parameters('x[y][z][]=10&x[y][z][]=5'))
  end

  def test_deep_query_string_with_array_of_hash
    assert_equal({'x' => {'y' => [{'z' => '10'}]}}, CGIMethods.parse_query_parameters('x[y][][z]=10'))
    assert_equal({'x' => {'y' => [{'z' => '10', 'w' => '10'}]}}, CGIMethods.parse_query_parameters('x[y][][z]=10&x[y][][w]=10'))
  end

  def test_deep_query_string_with_array_of_hashes_with_one_pair
    assert_equal({'x' => {'y' => [{'z' => '10'}, {'z' => '20'}]}}, CGIMethods.parse_query_parameters('x[y][][z]=10&x[y][][z]=20'))
    assert_equal("10", CGIMethods.parse_query_parameters('x[y][][z]=10&x[y][][z]=20')["x"]["y"].first["z"])
    assert_equal("10", CGIMethods.parse_query_parameters('x[y][][z]=10&x[y][][z]=20').with_indifferent_access[:x][:y].first[:z])
  end
  
  def test_request_hash_parsing
    query = {
      "note[viewers][viewer][][type]" => ["User", "Group"],
      "note[viewers][viewer][][id]"   => ["1", "2"]
    }

    expected = { "note" => { "viewers"=>{"viewer"=>[{ "id"=>"1", "type"=>"User"}, {"type"=>"Group", "id"=>"2"} ]} } }

    assert_equal(expected, CGIMethods.parse_request_parameters(query))
  end
  
  def test_deep_query_string_with_array_of_hashes_with_multiple_pairs
    assert_equal(
      {'x' => {'y' => [{'z' => '10', 'w' => 'a'}, {'z' => '20', 'w' => 'b'}]}}, 
      CGIMethods.parse_query_parameters('x[y][][z]=10&x[y][][w]=a&x[y][][z]=20&x[y][][w]=b')
    )
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
  
  def test_query_string_with_empty_key
    assert_equal(
      { "action" => "create_customer", "full_name" => "David Heinemeier Hansson" },
      CGIMethods.parse_query_parameters(@query_string_with_empty_key)
    )
  end

  def test_query_string_with_many_ampersands
    assert_equal(
      { "action" => "create_customer", "full_name" => "David Heinemeier Hansson"},
      CGIMethods.parse_query_parameters(@query_string_with_many_ampersands)
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
      "products[second]" => [ "Pc" ],
      "" => [ 'Save' ]
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
    mockup = Struct.new(:content_type, :original_filename, :read, :rewind)
    file = mockup.new('img/jpeg', 'foo.jpg')
    ie_file = mockup.new('img/jpeg', 'c:\\Documents and Settings\\foo\\Desktop\\bar.jpg')
    non_file_text_part = mockup.new('text/plain', '', 'abc')
  
    input = {
      "something" => [ StringIO.new("") ],
      "array_of_stringios" => [[ StringIO.new("One"), StringIO.new("Two") ]],
      "mixed_types_array" => [[ StringIO.new("Three"), "NotStringIO" ]],
      "mixed_types_as_checkboxes[strings][nested]" => [[ file, "String", StringIO.new("StringIO")]],
      "ie_mixed_types_as_checkboxes[strings][nested]" => [[ ie_file, "String", StringIO.new("StringIO")]],
      "products[string]" => [ StringIO.new("Apple Computer") ],
      "products[file]" => [ file ],
      "ie_products[string]" => [ StringIO.new("Microsoft") ],
      "ie_products[file]" => [ ie_file ],
      "text_part" => [non_file_text_part]
    }

    expected_output =  {
      "something" => "",
      "array_of_stringios" => ["One", "Two"],
      "mixed_types_array" => [ "Three", "NotStringIO" ],
      "mixed_types_as_checkboxes" => {
         "strings" => {
            "nested" => [ file, "String", "StringIO" ]
         },
      },
      "ie_mixed_types_as_checkboxes" => {
         "strings" => {
            "nested" => [ ie_file, "String", "StringIO" ]
         },
      },
      "products" => {
        "string" => "Apple Computer",
        "file" => file
      },
      "ie_products" => {
        "string" => "Microsoft",
        "file" => ie_file
      },
      "text_part" => "abc"
    }

    params = CGIMethods.parse_request_parameters(input)
    assert_equal expected_output, params

    # Lone filenames are preserved.
    assert_equal 'foo.jpg', params['mixed_types_as_checkboxes']['strings']['nested'].first.original_filename
    assert_equal 'foo.jpg', params['products']['file'].original_filename

    # But full Windows paths are reduced to their basename.
    assert_equal 'bar.jpg', params['ie_mixed_types_as_checkboxes']['strings']['nested'].first.original_filename
    assert_equal 'bar.jpg', params['ie_products']['file'].original_filename
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
    expected  = { "a/b" => {} }
    assert_equal expected, CGIMethods.parse_request_parameters(input)
  end

  def test_parse_params_with_separated_brackets
    input     = { "a/b@[c]d[e]" =>  %w(f) }
    expected  = { "a/b@" => { }}
    assert_equal expected, CGIMethods.parse_request_parameters(input)
  end

  def test_parse_params_with_separated_brackets_and_array
    input     = { "a/b@[c]d[e][]" =>  %w(f) }
    expected  = { "a/b@" => { }}
    assert_equal expected , CGIMethods.parse_request_parameters(input)
  end

  def test_parse_params_with_unmatched_brackets_and_array
    input     = { "a/b@[c][d[e][]" =>  %w(f) }
    expected  = { "a/b@" => { "c" => { }}}
    assert_equal expected, CGIMethods.parse_request_parameters(input)
  end
  
  def test_parse_params_with_nil_key
    input = { nil => nil, "test2" => %w(value1) }
    expected = { "test2" => "value1" }
    assert_equal expected, CGIMethods.parse_request_parameters(input)
  end
end


class MultipartCGITest < Test::Unit::TestCase
  FIXTURE_PATH = File.dirname(__FILE__) + '/../fixtures/multipart'

  def setup
    ENV['REQUEST_METHOD'] = 'POST'
    ENV['CONTENT_LENGTH'] = '0'
    ENV['CONTENT_TYPE']   = 'multipart/form-data, boundary=AaB03x'
  end

  def test_single_parameter
    params = process('single_parameter')
    assert_equal({ 'foo' => 'bar' }, params)
  end

  def test_text_file
    params = process('text_file')
    assert_equal %w(file foo), params.keys.sort
    assert_equal 'bar', params['foo']

    file = params['file']
    assert_kind_of StringIO, file
    assert_equal 'file.txt', file.original_filename
    assert_equal "text/plain\r", file.content_type
    assert_equal 'contents', file.read
  end

  def test_large_text_file
    params = process('large_text_file')
    assert_equal %w(file foo), params.keys.sort
    assert_equal 'bar', params['foo']

    file = params['file']
    assert_kind_of Tempfile, file
    assert_equal 'file.txt', file.original_filename
    assert_equal "text/plain\r", file.content_type
    assert ('a' * 20480) == file.read
  end

  def test_binary_file
    params = process('binary_file')
    assert_equal %w(file flowers foo), params.keys.sort
    assert_equal 'bar', params['foo']

    file = params['file']
    assert_kind_of StringIO, file
    assert_equal 'file.txt', file.original_filename
    assert_equal "text/plain\r", file.content_type
    assert_equal 'contents', file.read

    file = params['flowers']
    assert_kind_of StringIO, file
    assert_equal 'flowers.jpg', file.original_filename
    assert_equal "image/jpeg\r", file.content_type
    assert_equal 19512, file.size
    #assert_equal File.read(File.dirname(__FILE__) + '/../../../activerecord/test/fixtures/flowers.jpg'), file.read
  end

  def test_mixed_files
    params = process('mixed_files')
    assert_equal %w(files foo), params.keys.sort
    assert_equal 'bar', params['foo']

    # Ruby CGI doesn't handle multipart/mixed for us.
    assert_kind_of String, params['files']
    assert_equal 19756, params['files'].size
  end

  # Rewind readable cgi params so others may reread them (such as CGI::Session
  # when passing the session id in a multipart form).
  def test_multipart_param_rewound
    params = process('text_file')
    assert_equal 'bar', @cgi.params['foo'][0].read
  end

  private
    def process(name)
      old_stdin = $stdin
      File.open(File.join(FIXTURE_PATH, name), 'rb') do |file|
        ENV['CONTENT_LENGTH'] = file.stat.size.to_s
        $stdin = file
        @cgi = CGI.new
        CGIMethods.parse_request_parameters @cgi.params
      end
    ensure
      $stdin = old_stdin
    end
end

# Ensures that PUT works with multipart as well as POST.
class PutMultipartCGITest < MultipartCGITest
  def setup
    super
    ENV['REQUEST_METHOD'] = 'PUT'
  end
end


class CGIRequestTest < Test::Unit::TestCase
  def setup
    @request_hash = {"HTTP_MAX_FORWARDS"=>"10", "SERVER_NAME"=>"glu.ttono.us:8007", "FCGI_ROLE"=>"RESPONDER", "HTTP_X_FORWARDED_HOST"=>"glu.ttono.us", "HTTP_ACCEPT_ENCODING"=>"gzip, deflate", "HTTP_USER_AGENT"=>"Mozilla/5.0 (Macintosh; U; PPC Mac OS X; en) AppleWebKit/312.5.1 (KHTML, like Gecko) Safari/312.3.1", "PATH_INFO"=>"", "HTTP_ACCEPT_LANGUAGE"=>"en", "HTTP_HOST"=>"glu.ttono.us:8007", "SERVER_PROTOCOL"=>"HTTP/1.1", "REDIRECT_URI"=>"/dispatch.fcgi", "SCRIPT_NAME"=>"/dispatch.fcgi", "SERVER_ADDR"=>"207.7.108.53", "REMOTE_ADDR"=>"207.7.108.53", "SERVER_SOFTWARE"=>"lighttpd/1.4.5", "HTTP_COOKIE"=>"_session_id=c84ace84796670c052c6ceb2451fb0f2; is_admin=yes", "HTTP_X_FORWARDED_SERVER"=>"glu.ttono.us", "REQUEST_URI"=>"/admin", "DOCUMENT_ROOT"=>"/home/kevinc/sites/typo/public", "SERVER_PORT"=>"8007", "QUERY_STRING"=>"", "REMOTE_PORT"=>"63137", "GATEWAY_INTERFACE"=>"CGI/1.1", "HTTP_X_FORWARDED_FOR"=>"65.88.180.234", "HTTP_ACCEPT"=>"*/*", "SCRIPT_FILENAME"=>"/home/kevinc/sites/typo/public/dispatch.fcgi", "REDIRECT_STATUS"=>"200", "REQUEST_METHOD"=>"GET"}
    # cookie as returned by some Nokia phone browsers (no space after semicolon separator)
    @alt_cookie_fmt_request_hash = {"HTTP_COOKIE"=>"_session_id=c84ace84796670c052c6ceb2451fb0f2;is_admin=yes"}
    @fake_cgi = Struct.new(:env_table).new(@request_hash)
    @request = ActionController::CgiRequest.new(@fake_cgi)
  end
  
  def test_proxy_request
    assert_equal 'glu.ttono.us', @request.host_with_port
  end
  
  def test_http_host
    @request_hash.delete "HTTP_X_FORWARDED_HOST"
    @request_hash['HTTP_HOST'] = "rubyonrails.org:8080"
    assert_equal "rubyonrails.org:8080", @request.host_with_port
    
    @request_hash['HTTP_X_FORWARDED_HOST'] = "www.firsthost.org, www.secondhost.org"
    assert_equal "www.secondhost.org", @request.host
  end
  
  def test_http_host_with_default_port_overrides_server_port
    @request_hash.delete "HTTP_X_FORWARDED_HOST"
    @request_hash['HTTP_HOST'] = "rubyonrails.org"
    assert_equal "rubyonrails.org", @request.host_with_port
  end

  def test_host_with_port_defaults_to_server_name_if_no_host_headers
    @request_hash.delete "HTTP_X_FORWARDED_HOST"
    @request_hash.delete "HTTP_HOST"
    assert_equal "glu.ttono.us:8007", @request.host_with_port
  end

  def test_host_with_port_falls_back_to_server_addr_if_necessary
    @request_hash.delete "HTTP_X_FORWARDED_HOST"
    @request_hash.delete "HTTP_HOST"
    @request_hash.delete "SERVER_NAME"
    assert_equal "207.7.108.53:8007", @request.host_with_port
  end

  def test_cookie_syntax_resilience
    cookies = CGI::Cookie::parse(@request_hash["HTTP_COOKIE"]);
    assert_equal ["c84ace84796670c052c6ceb2451fb0f2"], cookies["_session_id"]
    assert_equal ["yes"], cookies["is_admin"]
    
    alt_cookies = CGI::Cookie::parse(@alt_cookie_fmt_request_hash["HTTP_COOKIE"]);
    assert_equal ["c84ace84796670c052c6ceb2451fb0f2"], alt_cookies["_session_id"]
    assert_equal ["yes"], alt_cookies["is_admin"]
  end
end
