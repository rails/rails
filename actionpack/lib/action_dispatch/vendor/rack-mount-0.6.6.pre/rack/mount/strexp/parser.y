class Rack::Mount::StrexpParser
rule
  target: expr { result = anchor ? "\\A#{val.join}\\Z" : "\\A#{val.join}" }

  expr: expr token { result = val.join }
      | token

  token: PARAM {
           name = val[0].to_sym
           requirement = requirements[name]
           result = REGEXP_NAMED_CAPTURE % [name, requirement]
         }
       | GLOB {
           name = val[0].to_sym
           requirement = requirements[name]
           result = REGEXP_NAMED_CAPTURE % [name, '.+' || requirement]
         }
       | LPAREN expr RPAREN { result = "(?:#{val[1]})?" }
       | CHAR { result = Regexp.escape(val[0]) }
end

---- header ----
require 'rack/mount/utils'
require 'rack/mount/strexp/tokenizer'

---- inner

if Regin.regexp_supports_named_captures?
  REGEXP_NAMED_CAPTURE = '(?<%s>%s)'.freeze
else
  REGEXP_NAMED_CAPTURE = '(?:<%s>%s)'.freeze
end

attr_accessor :anchor, :requirements
