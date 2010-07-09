class Rack::Mount::StrexpParser
macro
  RESERVED  \(|\)|:|\*
  ALPHA_U   [a-zA-Z_]
rule
  \\({RESERVED})   { [:CHAR,  @ss[1]] }
  \:({ALPHA_U}\w*) { [:PARAM, @ss[1]] }
  \*({ALPHA_U}\w*) { [:GLOB,  @ss[1]] }
  \(               { [:LPAREN, text]  }
  \)               { [:RPAREN, text]  }
  .                { [:CHAR,   text]  }
end
