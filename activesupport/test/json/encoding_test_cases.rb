# frozen_string_literal: true

require "bigdecimal"
require "date"
require "time"
require "pathname"
require "uri"

module JSONTest
  class Foo
    def initialize(a, b)
      @a, @b = a, b
    end
  end

  class Hashlike
    def to_hash
      { foo: "hello", bar: "world" }
    end
  end

  class Custom
    def initialize(serialized)
      @serialized = serialized
    end

    def as_json(options = nil)
      @serialized
    end
  end

  MyStruct = Struct.new(:name, :value) do
    def initialize(*)
      @unused = "unused instance variable"
      super
    end
  end

  class RomanNumeral < Numeric
    def initialize(str)
      @str = str
    end

    def as_json(options = nil)
      @str
    end
  end

  class CustomNumeric < Numeric
    def initialize(str)
      @str = str
    end

    def to_json(options = nil)
      @str
    end
  end

  class CustomNumericFixed < Numeric
    def initialize(str)
      @str = str
    end

    def as_json
      ::JSON::Fragment.new(@str)
    end
  end

  module EncodingTestCases
    TrueTests     = [[ true,  %(true)  ]].freeze
    FalseTests    = [[ false, %(false) ]].freeze
    NilTests      = [[ nil,   %(null)  ]].freeze
    NumericTests  = [[ 1,     %(1)     ],
                     [ 2.5,   %(2.5)   ],
                     [ 0.0 / 0.0,   %(null) ],
                     [ 1.0 / 0.0,   %(null) ],
                     [ -1.0 / 0.0,  %(null) ],
                     [ BigDecimal("0.0") / BigDecimal("0.0"),  %(null) ],
                     [ BigDecimal("2.5"), %("#{BigDecimal('2.5')}") ],
                     [ RomanNumeral.new("MCCCXXXVII"), %("MCCCXXXVII") ],
                     [ [CustomNumeric.new("123")], %([123]) ],
                     [ [CustomNumericFixed.new("123")], %([123]) ],
    ].freeze

    StringTests   = [[ "this is the <string>",     %("this is the \\u003cstring\\u003e")],
                     [ 'a "string" with quotes & an ampersand', %("a \\"string\\" with quotes \\u0026 an ampersand") ],
                     [ "http://test.host/posts/1", %("http://test.host/posts/1")],
                     [ "Control characters: \x00\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f\x10\x11\x12\x13\x14\x15\x16\x17\x18\x19\x1a\x1b\x1c\x1d\x1e\x1f\u2028\u2029",
                       %("Control characters: \\u0000\\u0001\\u0002\\u0003\\u0004\\u0005\\u0006\\u0007\\b\\t\\n\\u000b\\f\\r\\u000e\\u000f\\u0010\\u0011\\u0012\\u0013\\u0014\\u0015\\u0016\\u0017\\u0018\\u0019\\u001a\\u001b\\u001c\\u001d\\u001e\\u001f\\u2028\\u2029") ]].freeze

    ArrayTests    = [[ ["a", "b", "c"],          %([\"a\",\"b\",\"c\"])        ],
                     [ [1, "a", :b, nil, false], %([1,\"a\",\"b\",null,false]) ]].freeze

    HashTests     = [[ { foo: "bar" }, %({\"foo\":\"bar\"}) ],
                     [ { 1 => 1, 2 => "a", 3 => :b, 4 => nil, 5 => false }, %({\"1\":1,\"2\":\"a\",\"3\":\"b\",\"4\":null,\"5\":false}) ]].freeze

    RangeTests    = [[ 1..2,     %("1..2")],
                     [ 1...2,    %("1...2")],
                     [ 1.5..2.5, %("1.5..2.5")]].freeze

    SymbolTests   = [[ :a,     %("a")    ],
                     [ :this,  %("this") ],
                     [ :"a b", %("a b")  ]].freeze

    ModuleTests   = [[ Module, %("Module") ],
                     [ Class,  %("Class")  ],
                     [ ActiveSupport,                   %("ActiveSupport")                   ],
                     [ ActiveSupport::Testing, %("ActiveSupport::Testing") ]].freeze
    ObjectTests   = [[ Foo.new(1, 2), %({\"a\":1,\"b\":2}) ]].freeze
    HashlikeTests = [[ Hashlike.new, %({\"bar\":\"world\",\"foo\":\"hello\"}) ]].freeze
    StructTests   = [[ MyStruct.new(:foo, "bar"), %({\"name\":\"foo\",\"value\":\"bar\"}) ],
                     [ MyStruct.new(nil, nil), %({\"name\":null,\"value\":null}) ]].freeze
    CustomTests   = [[ Custom.new("custom"), '"custom"' ],
                     [ Custom.new(nil), "null" ],
                     [ Custom.new(:a), '"a"' ],
                     [ Custom.new([ :foo, "bar" ]), '["foo","bar"]' ],
                     [ Custom.new(foo: "hello", bar: "world"), '{"bar":"world","foo":"hello"}' ],
                     [ Custom.new(Hashlike.new), '{"bar":"world","foo":"hello"}' ],
                     [ Custom.new(Custom.new(Custom.new(:a))), '"a"' ]].freeze

    RegexpTests   = [[ /^a/, '"(?-mix:^a)"' ], [/^\w{1,2}[a-z]+/ix, '"(?ix-m:^\\\\w{1,2}[a-z]+)"']].freeze

    URITests      = [[ URI.parse("http://example.com"), %("http://example.com") ]].freeze

    PathnameTests = [[ Pathname.new("lib/index.rb"), %("lib/index.rb") ]].freeze

    IPAddrTests       = [[ IPAddr.new("127.0.0.1"), %("127.0.0.1") ]].freeze
    IPAddrv4CidrTests = [[ IPAddr.new("192.0.2.0/24"), %("192.0.2.0/24") ]].freeze
    IPAddrv6CidrTests = [[ IPAddr.new("2001:db8::/48"), %("2001:db8::/48") ]].freeze

    DateTests     = [[ Date.new(2005, 2, 1), %("2005/02/01") ]].freeze
    TimeTests     = [[ Time.utc(2005, 2, 1, 15, 15, 10), %("2005/02/01 15:15:10 +0000") ]].freeze
    DateTimeTests = [[ DateTime.civil(2005, 2, 1, 15, 15, 10), %("2005/02/01 15:15:10 +0000") ]].freeze

    StandardDateTests     = [[ Date.new(2005, 2, 1), %("2005-02-01") ]].freeze
    StandardTimeTests     = [[ Time.utc(2005, 2, 1, 15, 15, 10), %("2005-02-01T15:15:10.000Z") ]].freeze
    StandardDateTimeTests = [[ DateTime.civil(2005, 2, 1, 15, 15, 10), %("2005-02-01T15:15:10.000+00:00") ]].freeze
    StandardStringTests   = [[ "this is the <string>", %("this is the <string>")]].freeze
  end
end
