class ActionDispatch::Journey::Parser
  options no_result_var
token SLASH LITERAL SYMBOL LPAREN RPAREN DOT STAR OR

rule
  expressions
    : expression expressions  { Cat.new(val.first, val.last) }
    | expression              { val.first }
    | or
    ;
  expression
    : terminal
    | group
    | star
    ;
  group
    : LPAREN expressions RPAREN { Group.new(val[1]) }
    ;
  or
    : expression OR expression { Or.new([val.first, val.last]) }
    | expression OR or { Or.new([val.first, val.last]) }
    ;
  star
    : STAR       { Star.new(Symbol.new(val.last)) }
    ;
  terminal
    : symbol
    | literal
    | slash
    | dot
    ;
  slash
    : SLASH              { Slash.new(val.first) }
    ;
  symbol
    : SYMBOL             { Symbol.new(val.first) }
    ;
  literal
    : LITERAL            { Literal.new(val.first) }
    ;
  dot
    : DOT                { Dot.new(val.first) }
    ;

end

---- header
# :stopdoc:

require "action_dispatch/journey/parser_extras"
