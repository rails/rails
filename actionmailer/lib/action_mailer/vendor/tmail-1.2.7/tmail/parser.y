#
# parser.y
#
# Copyright (c) 1998-2007 Minero Aoki
#
# This program is free software.
# You can distribute/modify this program under the terms of
# the GNU Lesser General Public License version 2.1.
#

class TMail::Parser

  options no_result_var

rule

  content   : DATETIME      datetime   { val[1] }
            | RECEIVED      received   { val[1] }
            | MADDRESS      addrs_TOP  { val[1] }
            | RETPATH       retpath    { val[1] }
            | KEYWORDS      keys       { val[1] }
            | ENCRYPTED     enc        { val[1] }
            | MIMEVERSION   version    { val[1] }
            | CTYPE         ctype      { val[1] }
            | CENCODING     cencode    { val[1] }
            | CDISPOSITION  cdisp      { val[1] }
            | ADDRESS       addr_TOP   { val[1] }
            | MAILBOX       mbox       { val[1] }
  
  datetime  : day DIGIT ATOM DIGIT hour zone
            # 0   1     2    3     4    5
            #     date month year
                {
                  t = Time.gm(val[3].to_i, val[2], val[1].to_i, 0, 0, 0)
                  (t + val[4] - val[5]).localtime
                }
  
  day       :  /* none */
            | ATOM ','
  
  hour      : DIGIT ':' DIGIT
                {
                  (val[0].to_i * 60 * 60) +
                  (val[2].to_i * 60)
                }
            | DIGIT ':' DIGIT ':' DIGIT
                {
                  (val[0].to_i * 60 * 60) +
                  (val[2].to_i * 60) +
                  (val[4].to_i)
                }
  
  zone      : ATOM
                {
                  timezone_string_to_unixtime(val[0])
                }
  
  received  : from by via with id for received_datetime
                {
                  val
                }
  
  from      : /* none */
            | FROM received_domain
                {
                  val[1]
                }
  
  by        :  /* none */
            | BY received_domain
                {
                  val[1]
                }
  
  received_domain
            : domain
                {
                  join_domain(val[0])
                }
            | domain '@' domain
                {
                  join_domain(val[2])
                }
            | domain DOMLIT
                {
                  join_domain(val[0])
                }
  
  via       :  /* none */
            | VIA ATOM
                {
                  val[1]
                }
  
  with      : /* none */
                {
                  []
                }
            | with WITH ATOM
                {
                  val[0].push val[2]
                  val[0]
                }
  
  id        :  /* none */
            | ID msgid
                {
                  val[1]
                }
            | ID ATOM
                {
                  val[1]
                }
  
  for       :  /* none */
            | FOR received_addrspec
                {
                  val[1]
                }

  received_addrspec
            : routeaddr
                {
                  val[0].spec
                }
            | spec
                {
                  val[0].spec
                }
  
  received_datetime
            :  /* none */
            | ';' datetime
                {
                  val[1]
                }
  
  addrs_TOP : addrs
            | group_bare
            | addrs commas group_bare

  addr_TOP  : mbox
            | group
            | group_bare

  retpath   : addrs_TOP
            | '<' '>' { [ Address.new(nil, nil) ] }

  addrs     : addr
                {
                  val
                }
            | addrs commas addr
                {
                  val[0].push val[2]
                  val[0]
                }

  addr      : mbox
            | group

  mboxes    : mbox
                {
                  val
                }
            | mboxes commas mbox
                {
                  val[0].push val[2]
                  val[0]
                }

  mbox      : spec
            | routeaddr
            | addr_phrase routeaddr
                {
                  val[1].phrase = Decoder.decode(val[0])
                  val[1]
                }

  group     : group_bare ';'

  group_bare: addr_phrase ':' mboxes
                {
                  AddressGroup.new(val[0], val[2])
                }
            | addr_phrase ':' { AddressGroup.new(val[0], []) }
  
  addr_phrase
            : local_head             { val[0].join('.') }
            | addr_phrase local_head { val[0] << ' ' << val[1].join('.') }

  routeaddr : '<' routes spec '>'
                {
                  val[2].routes.replace val[1]
                  val[2]
                }
            | '<' spec '>'
                {
                  val[1]
                }
  
  routes    : at_domains ':'
  
  at_domains: '@' domain                { [ val[1].join('.') ] }
            | at_domains ',' '@' domain { val[0].push val[3].join('.'); val[0] }
  
  spec      : local '@' domain { Address.new( val[0], val[2] ) }
            | local            { Address.new( val[0], nil ) }
  
  local: local_head
       | local_head '.' { val[0].push ''; val[0] }

  local_head: word
                { val }
            | local_head dots word
                {
                  val[1].times do
                    val[0].push ''
                  end
                  val[0].push val[2]
                  val[0]
                }
  
  domain    : domword
                { val }
            | domain dots domword
                {
                  val[1].times do
                    val[0].push ''
                  end
                  val[0].push val[2]
                  val[0]
                }

  dots      : '.'      { 0 }
            | dots '.' { val[0] + 1 }

  word      : atom
            | QUOTED
            | DIGIT

  domword   : atom
            | DOMLIT
            | DIGIT

  commas    : ','
            | commas ','

  msgid     : '<' spec '>'
                {
                  val[1] = val[1].spec
                  val.join('')
                }

  keys      : phrase          { val }
            | keys ',' phrase { val[0].push val[2]; val[0] }
  
  phrase    : word
            | phrase word { val[0] << ' ' << val[1] }
  
  enc       : word
                {
                  val.push nil
                  val
                }
            | word word
                {
                  val
                }

  version   : DIGIT '.' DIGIT
                {
                  [ val[0].to_i, val[2].to_i ]
                }

  ctype     : TOKEN '/' TOKEN params opt_semicolon
                {
                  [ val[0].downcase, val[2].downcase, decode_params(val[3]) ]
                }
            | TOKEN params opt_semicolon
                {
                  [ val[0].downcase, nil, decode_params(val[1]) ]
                }
  
  params    : /* none */
                {
                  {}
                }
            | params ';' TOKEN '=' QUOTED
                {
                  val[0][ val[2].downcase ] = ('"' + val[4].to_s + '"')
                  val[0]
                }
            | params ';' TOKEN '=' TOKEN
                {
                  val[0][ val[2].downcase ] = val[4]
                  val[0]
                }

  cencode   : TOKEN
                {
                  val[0].downcase
                }

  cdisp     : TOKEN params opt_semicolon
                {
                  [ val[0].downcase, decode_params(val[1]) ]
                }
  
  opt_semicolon
            :
            | ';'
              
  atom      : ATOM
            | FROM
            | BY
            | VIA
            | WITH
            | ID
            | FOR
  
end


---- header
#
# parser.rb
#
# Copyright (c) 1998-2007 Minero Aoki
#
# This program is free software.
# You can distribute/modify this program under the terms of
# the GNU Lesser General Public License version 2.1.
#

require 'tmail/scanner'
require 'tmail/utils'

---- inner

  include TextUtils

  def self.parse( ident, str, cmt = nil )
    str = special_quote_address(str) if ident.to_s =~ /M?ADDRESS/
    new.parse(ident, str, cmt)
  end

  def self.special_quote_address(str) #:nodoc:
    # Takes a string which is an address and adds quotation marks to special
    # edge case methods that the RACC parser can not handle.
    #
    # Right now just handles two edge cases:
    #
    # Full stop as the last character of the display name:
    #   Mikel L. <mikel@me.com>
    # Returns:
    #   "Mikel L." <mikel@me.com>
    #
    # Unquoted @ symbol in the display name:
    #   mikel@me.com <mikel@me.com>
    # Returns:
    #   "mikel@me.com" <mikel@me.com>
    #
    # Any other address not matching these patterns just gets returned as is.
    case
    # This handles the missing "" in an older version of Apple Mail.app
    # around the display name when the display name contains a '@'
    # like 'mikel@me.com <mikel@me.com>'
    # Just quotes it to: '"mikel@me.com" <mikel@me.com>'
    when str =~ /\A([^"].+@.+[^"])\s(<.*?>)\Z/
      return "\"#{$1}\" #{$2}"
    # This handles cases where 'Mikel A. <mikel@me.com>' which is a trailing
    # full stop before the address section.  Just quotes it to
    # '"Mikel A." <mikel@me.com>'
    when str =~ /\A(.*?\.)\s(<.*?>)\s*\Z/
      return "\"#{$1}\" #{$2}"
    else
      str
    end
  end

  MAILP_DEBUG = false

  def initialize
    self.debug = MAILP_DEBUG
  end

  def debug=( flag )
    @yydebug = flag && Racc_debug_parser
    @scanner_debug = flag
  end

  def debug
    @yydebug
  end

  def parse( ident, str, comments = nil )
    @scanner = Scanner.new(str, ident, comments)
    @scanner.debug = @scanner_debug
    @first = [ident, ident]
    result = yyparse(self, :parse_in)
    comments.map! {|c| to_kcode(c) } if comments
    result
  end

  private

  def parse_in( &block )
    yield @first
    @scanner.scan(&block)
  end
  
  def on_error( t, val, vstack )
    raise TMail::SyntaxError, "parse error on token #{racc_token2str t}"
  end

