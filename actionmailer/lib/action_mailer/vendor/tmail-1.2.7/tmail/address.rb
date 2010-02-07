=begin rdoc

= Address handling class

=end
#--
# Copyright (c) 1998-2003 Minero Aoki <aamine@loveruby.net>
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#
# Note: Originally licensed under LGPL v2+. Using MIT license for Rails
# with permission of Minero Aoki.
#++

require 'tmail/encode'
require 'tmail/parser'


module TMail

  # = Class Address
  # 
  # Provides a complete handling library for email addresses. Can parse a string of an
  # address directly or take in preformatted addresses themselves.  Allows you to add
  # and remove phrases from the front of the address and provides a compare function for
  # email addresses.
  # 
  # == Parsing and Handling a Valid Address:
  # 
  # Just pass the email address in as a string to Address.parse:
  # 
  #  email = TMail::Address.parse('Mikel Lindsaar <mikel@lindsaar.net>')
  #  #=> #<TMail::Address mikel@lindsaar.net>
  #  email.address
  #  #=> "mikel@lindsaar.net"
  #  email.local
  #  #=> "mikel"
  #  email.domain
  #  #=> "lindsaar.net"
  #  email.name             # Aliased as phrase as well
  #  #=> "Mikel Lindsaar"
  # 
  # == Detecting an Invalid Address
  # 
  # If you want to check the syntactical validity of an email address, just pass it to
  # Address.parse and catch any SyntaxError:
  # 
  #  begin
  #    TMail::Address.parse("mikel   2@@@@@ me .com")
  #  rescue TMail::SyntaxError
  #    puts("Invalid Email Address Detected")
  #  else
  #    puts("Address is valid")
  #  end
  #  #=> "Invalid Email Address Detected"
  class Address

    include TextUtils #:nodoc:
    
    # Sometimes you need to parse an address, TMail can do it for you and provide you with
    # a fairly robust method of detecting a valid address.
    # 
    # Takes in a string, returns a TMail::Address object.
    # 
    # Raises a TMail::SyntaxError on invalid email format
    def Address.parse( str )
      Parser.parse :ADDRESS, str
    end

    def address_group? #:nodoc:
      false
    end

    # Address.new(local, domain)
    # 
    # Accepts:
    # 
    # * local - Left of the at symbol
    # 
    # * domain - Array of the domain split at the periods.
    # 
    # For example:
    # 
    #  Address.new("mikel", ["lindsaar", "net"])
    #  #=> "#<TMail::Address mikel@lindsaar.net>"
    def initialize( local, domain )
      if domain
        domain.each do |s|
          raise SyntaxError, 'empty word in domain' if s.empty?
        end
      end
      
      # This is to catch an unquoted "@" symbol in the local part of the
      # address.  Handles addresses like <"@"@me.com> and makes sure they
      # stay like <"@"@me.com> (previously were becoming <@@me.com>)
      if local && (local.join == '@' || local.join =~ /\A[^"].*?@.*?[^"]\Z/)
        @local = "\"#{local.join}\""
      else
        @local = local
      end

      @domain = domain
      @name   = nil
      @routes = []
    end

    # Provides the name or 'phrase' of the email address.
    # 
    # For Example:
    # 
    #  email = TMail::Address.parse("Mikel Lindsaar <mikel@lindsaar.net>")
    #  email.name
    #  #=> "Mikel Lindsaar"
    def name
      @name
    end

    # Setter method for the name or phrase of the email
    # 
    # For Example:
    # 
    #  email = TMail::Address.parse("mikel@lindsaar.net")
    #  email.name
    #  #=> nil
    #  email.name = "Mikel Lindsaar"
    #  email.to_s
    #  #=> "Mikel Lindsaar <mikel@me.com>"
    def name=( str )
      @name = str
      @name = nil if str and str.empty?
    end

    #:stopdoc:
    alias phrase  name
    alias phrase= name=
    #:startdoc:
    
    # This is still here from RFC 822, and is now obsolete per RFC2822 Section 4.
    # 
    # "When interpreting addresses, the route portion SHOULD be ignored."
    # 
    # It is still here, so you can access it.
    # 
    # Routes return the route portion at the front of the email address, if any.
    # 
    # For Example:
    #  email = TMail::Address.parse( "<@sa,@another:Mikel@me.com>")
    #  => #<TMail::Address Mikel@me.com>
    #  email.to_s
    #  => "<@sa,@another:Mikel@me.com>"
    #  email.routes
    #  => ["sa", "another"]
    def routes
      @routes
    end
    
    def inspect #:nodoc:
      "#<#{self.class} #{address()}>"
    end

    # Returns the local part of the email address
    # 
    # For Example:
    # 
    #  email = TMail::Address.parse("mikel@lindsaar.net")
    #  email.local
    #  #=> "mikel"
    def local
      return nil unless @local
      return '""' if @local.size == 1 and @local[0].empty?
      # Check to see if it is an array before trying to map it
      if @local.respond_to?(:map)
        @local.map {|i| quote_atom(i) }.join('.')
      else
        quote_atom(@local)
      end
    end

    # Returns the domain part of the email address
    # 
    # For Example:
    # 
    #  email = TMail::Address.parse("mikel@lindsaar.net")
    #  email.local
    #  #=> "lindsaar.net"
    def domain
      return nil unless @domain
      join_domain(@domain)
    end

    # Returns the full specific address itself
    # 
    # For Example:
    # 
    #  email = TMail::Address.parse("mikel@lindsaar.net")
    #  email.address
    #  #=> "mikel@lindsaar.net"
    def spec
      s = self.local
      d = self.domain
      if s and d
        s + '@' + d
      else
        s
      end
    end

    alias address spec

    # Provides == function to the email.  Only checks the actual address
    # and ignores the name/phrase component
    # 
    # For Example
    # 
    #  addr1 = TMail::Address.parse("My Address <mikel@lindsaar.net>")
    #  #=> "#<TMail::Address mikel@lindsaar.net>"
    #  addr2 = TMail::Address.parse("Another <mikel@lindsaar.net>")
    #  #=> "#<TMail::Address mikel@lindsaar.net>"
    #  addr1 == addr2
    #  #=> true
    def ==( other )
      other.respond_to? :spec and self.spec == other.spec
    end

    alias eql? ==

    # Provides a unique hash value for this record against the local and domain
    # parts, ignores the name/phrase value
    # 
    #  email = TMail::Address.parse("mikel@lindsaar.net")
    #  email.hash
    #  #=> 18767598
    def hash
      @local.hash ^ @domain.hash
    end

    # Duplicates a TMail::Address object returning the duplicate
    # 
    #  addr1 = TMail::Address.parse("mikel@lindsaar.net")
    #  addr2 = addr1.dup
    #  addr1.id == addr2.id
    #  #=> false
    def dup
      obj = self.class.new(@local.dup, @domain.dup)
      obj.name = @name.dup if @name
      obj.routes.replace @routes
      obj
    end

    include StrategyInterface #:nodoc:

    def accept( strategy, dummy1 = nil, dummy2 = nil ) #:nodoc:
      unless @local
        strategy.meta '<>'   # empty return-path
        return
      end

      spec_p = (not @name and @routes.empty?)
      if @name
        strategy.phrase @name
        strategy.space
      end
      tmp = spec_p ? '' : '<'
      unless @routes.empty?
        tmp << @routes.map {|i| '@' + i }.join(',') << ':'
      end
      tmp << self.spec
      tmp << '>' unless spec_p
      strategy.meta tmp
      strategy.lwsp ''
    end

  end


  class AddressGroup

    include Enumerable

    def address_group?
      true
    end

    def initialize( name, addrs )
      @name = name
      @addresses = addrs
    end

    attr_reader :name
    
    def ==( other )
      other.respond_to? :to_a and @addresses == other.to_a
    end

    alias eql? ==

    def hash
      map {|i| i.hash }.hash
    end

    def []( idx )
      @addresses[idx]
    end

    def size
      @addresses.size
    end

    def empty?
      @addresses.empty?
    end

    def each( &block )
      @addresses.each(&block)
    end

    def to_a
      @addresses.dup
    end

    alias to_ary to_a

    def include?( a )
      @addresses.include? a
    end

    def flatten
      set = []
      @addresses.each do |a|
        if a.respond_to? :flatten
          set.concat a.flatten
        else
          set.push a
        end
      end
      set
    end

    def each_address( &block )
      flatten.each(&block)
    end

    def add( a )
      @addresses.push a
    end

    alias push add
    
    def delete( a )
      @addresses.delete a
    end

    include StrategyInterface

    def accept( strategy, dummy1 = nil, dummy2 = nil )
      strategy.phrase @name
      strategy.meta ':'
      strategy.space
      first = true
      each do |mbox|
        if first
          first = false
        else
          strategy.puts_meta ','
        end
        strategy.space
        mbox.accept strategy
      end
      strategy.meta ';'
      strategy.lwsp ''
    end

  end

end   # module TMail
