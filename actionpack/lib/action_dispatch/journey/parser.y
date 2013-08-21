class ActionDispatch::Journey::Parser

token SLASH LITERAL SYMBOL LPAREN RPAREN DOT STAR OR

rule
  expressions
    : expressions expression  { result = Cat.new(val.first, val.last) }
    | expression              { result = val.first }
    | or
    ;
  expression
    : terminal
    | group
    | star
    ;
  group
    : LPAREN expressions RPAREN { result = Group.new(val[1]) }
    ;
  or
    : expressions OR expression { result = Or.new([val.first, val.last]) }
    ;
  star
    : STAR       { result = Star.new(Symbol.new(val.last)) }
    ;
  terminal
    : symbol
    | literal
    | slash
    | dot
    ;
  slash
    : SLASH              { result = Slash.new('/') }
    ;
  symbol
    : SYMBOL             { result = Symbol.new(val.first) }
    ;
  literal
    : LITERAL            { result = Literal.new(val.first) }
    ;
  dot
    : DOT                { result = Dot.new(val.first) }
    ;

end

---- header

require 'action_dispatch/journey/parser_extras'
