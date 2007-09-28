#!/usr/bin/env ruby
#--
# Copyright 2004, 2005 by Jim Weirich (jim@weirichhouse.org).
# All rights reserved.

# Permission is granted for use, copying, modification, distribution,
# and distribution of modified versions of this work as long as the
# above copyright notice is included.
#++

# Provide a flexible and easy to use Builder for creating XML markup.
# See XmlBuilder for usage details.

require 'builder/xmlbase'

module Builder

  # Create XML markup easily.  All (well, almost all) methods sent to
  # an XmlMarkup object will be translated to the equivalent XML
  # markup.  Any method with a block will be treated as an XML markup
  # tag with nested markup in the block.
  #
  # Examples will demonstrate this easier than words.  In the
  # following, +xm+ is an +XmlMarkup+ object.
  #
  #   xm.em("emphasized")             # => <em>emphasized</em>
  #   xm.em { xmm.b("emp & bold") }   # => <em><b>emph &amp; bold</b></em>
  #   xm.a("A Link", "href"=>"http://onestepback.org")
  #                                   # => <a href="http://onestepback.org">A Link</a>
  #   xm.div { br }                    # => <div><br/></div>
  #   xm.target("name"=>"compile", "option"=>"fast")
  #                                   # => <target option="fast" name="compile"\>
  #                                   # NOTE: order of attributes is not specified.
  #
  #   xm.instruct!                   # <?xml version="1.0" encoding="UTF-8"?>
  #   xm.html {                      # <html>
  #     xm.head {                    #   <head>
  #       xm.title("History")        #     <title>History</title>
  #     }                            #   </head>
  #     xm.body {                    #   <body>
  #       xm.h1("Header")            #     <h1>Header</h1>
  #       xm.p("paragraph")          #     <p>paragraph</p>
  #     }                            #   </body>
  #   }                              # </html>
  #
  # == Notes:
  #
  # * The order that attributes are inserted in markup tags is
  #   undefined. 
  #
  # * Sometimes you wish to insert text without enclosing tags.  Use
  #   the <tt>text!</tt> method to accomplish this.
  #
  #   Example:
  #
  #     xm.div {                          # <div>
  #       xm.text! "line"; xm.br          #   line<br/>
  #       xm.text! "another line"; xmbr   #    another line<br/>
  #     }                                 # </div>
  #
  # * The special XML characters <, >, and & are converted to &lt;,
  #   &gt; and &amp; automatically.  Use the <tt><<</tt> operation to
  #   insert text without modification.
  #
  # * Sometimes tags use special characters not allowed in ruby
  #   identifiers.  Use the <tt>tag!</tt> method to handle these
  #   cases.
  #
  #   Example:
  #
  #     xml.tag!("SOAP:Envelope") { ... }
  #
  #   will produce ...
  #
  #     <SOAP:Envelope> ... </SOAP:Envelope>"
  #
  #   <tt>tag!</tt> will also take text and attribute arguments (after
  #   the tag name) like normal markup methods.  (But see the next
  #   bullet item for a better way to handle XML namespaces).
  #   
  # * Direct support for XML namespaces is now available.  If the
  #   first argument to a tag call is a symbol, it will be joined to
  #   the tag to produce a namespace:tag combination.  It is easier to
  #   show this than describe it.
  #
  #     xml.SOAP :Envelope do ... end
  #
  #   Just put a space before the colon in a namespace to produce the
  #   right form for builder (e.g. "<tt>SOAP:Envelope</tt>" =>
  #   "<tt>xml.SOAP :Envelope</tt>")
  #
  # * XmlMarkup builds the markup in any object (called a _target_)
  #   that accepts the <tt><<</tt> method.  If no target is given,
  #   then XmlMarkup defaults to a string target.
  # 
  #   Examples:
  #
  #     xm = Builder::XmlMarkup.new
  #     result = xm.title("yada")
  #     # result is a string containing the markup.
  #
  #     buffer = ""
  #     xm = Builder::XmlMarkup.new(buffer)
  #     # The markup is appended to buffer (using <<)
  #
  #     xm = Builder::XmlMarkup.new(STDOUT)
  #     # The markup is written to STDOUT (using <<)
  #
  #     xm = Builder::XmlMarkup.new
  #     x2 = Builder::XmlMarkup.new(:target=>xm)
  #     # Markup written to +x2+ will be send to +xm+.
  #   
  # * Indentation is enabled by providing the number of spaces to
  #   indent for each level as a second argument to XmlBuilder.new.
  #   Initial indentation may be specified using a third parameter.
  #
  #   Example:
  #
  #     xm = Builder.new(:ident=>2)
  #     # xm will produce nicely formatted and indented XML.
  #  
  #     xm = Builder.new(:indent=>2, :margin=>4)
  #     # xm will produce nicely formatted and indented XML with 2
  #     # spaces per indent and an over all indentation level of 4.
  #
  #     builder = Builder::XmlMarkup.new(:target=>$stdout, :indent=>2)
  #     builder.name { |b| b.first("Jim"); b.last("Weirich) }
  #     # prints:
  #     #     <name>
  #     #       <first>Jim</first>
  #     #       <last>Weirich</last>
  #     #     </name>
  #
  # * The instance_eval implementation which forces self to refer to
  #   the message receiver as self is now obsolete.  We now use normal
  #   block calls to execute the markup block.  This means that all
  #   markup methods must now be explicitly send to the xml builder.
  #   For instance, instead of
  #
  #      xml.div { strong("text") }
  #
  #   you need to write:
  #
  #      xml.div { xml.strong("text") }
  #
  #   Although more verbose, the subtle change in semantics within the
  #   block was found to be prone to error.  To make this change a
  #   little less cumbersome, the markup block now gets the markup
  #   object sent as an argument, allowing you to use a shorter alias
  #   within the block.
  #
  #   For example:
  #
  #     xml_builder = Builder::XmlMarkup.new
  #     xml_builder.div { |xml|
  #       xml.strong("text")
  #     }
  #
  class XmlMarkup < XmlBase

    # Create an XML markup builder.  Parameters are specified by an
    # option hash.
    #
    # :target=><em>target_object</em>::
    #    Object receiving the markup.  +out+ must respond to the
    #    <tt><<</tt> operator.  The default is a plain string target.
    #    
    # :indent=><em>indentation</em>::
    #    Number of spaces used for indentation.  The default is no
    #    indentation and no line breaks.
    #    
    # :margin=><em>initial_indentation_level</em>::
    #    Amount of initial indentation (specified in levels, not
    #    spaces).
    #    
    # :escape_attrs=><b>OBSOLETE</em>::
    #    The :escape_attrs option is no longer supported by builder
    #    (and will be quietly ignored).  String attribute values are
    #    now automatically escaped.  If you need unescaped attribute
    #    values (perhaps you are using entities in the attribute
    #    values), then give the value as a Symbol.  This allows much
    #    finer control over escaping attribute values.
    #    
    def initialize(options={})
      indent = options[:indent] || 0
      margin = options[:margin] || 0
      super(indent, margin)
      @target = options[:target] || ""
    end
    
    # Return the target of the builder.
    def target!
      @target
    end

    def comment!(comment_text)
      _ensure_no_block block_given?
      _special("<!-- ", " -->", comment_text, nil)
    end

    # Insert an XML declaration into the XML markup.
    #
    # For example:
    #
    #   xml.declare! :ELEMENT, :blah, "yada"
    #       # => <!ELEMENT blah "yada">
    def declare!(inst, *args, &block)
      _indent
      @target << "<!#{inst}"
      args.each do |arg|
	case arg
	when String
	  @target << %{ "#{arg}"}
	when Symbol
	  @target << " #{arg}"
	end
      end
      if block_given?
	@target << " ["
	_newline
	_nested_structures(block)
	@target << "]"
      end
      @target << ">"
      _newline
    end

    # Insert a processing instruction into the XML markup.  E.g.
    #
    # For example:
    #
    #    xml.instruct!
    #        #=> <?xml version="1.0" encoding="UTF-8"?>
    #    xml.instruct! :aaa, :bbb=>"ccc"
    #        #=> <?aaa bbb="ccc"?>
    #
    def instruct!(directive_tag=:xml, attrs={})
      _ensure_no_block block_given?
      if directive_tag == :xml
	a = { :version=>"1.0", :encoding=>"UTF-8" }
	attrs = a.merge attrs
      end
      _special(
	"<?#{directive_tag}",
	"?>",
	nil,
	attrs,
	[:version, :encoding, :standalone])
    end

    # Insert a CDATA section into the XML markup.
    #
    # For example:
    #
    #    xml.cdata!("text to be included in cdata")
    #        #=> <![CDATA[text to be included in cdata]]>
    #
    def cdata!(text)
      _ensure_no_block block_given?
      _special("<![CDATA[", "]]>", text, nil)
    end
    
    private

    # NOTE: All private methods of a builder object are prefixed when
    # a "_" character to avoid possible conflict with XML tag names.

    # Insert text directly in to the builder's target.
    def _text(text)
      @target << text
    end
    
    # Insert special instruction. 
    def _special(open, close, data=nil, attrs=nil, order=[])
      _indent
      @target << open
      @target << data if data
      _insert_attributes(attrs, order) if attrs
      @target << close
      _newline
    end

    # Start an XML tag.  If <tt>end_too</tt> is true, then the start
    # tag is also the end tag (e.g.  <br/>
    def _start_tag(sym, attrs, end_too=false)
      @target << "<#{sym}"
      _insert_attributes(attrs)
      @target << "/" if end_too
      @target << ">"
    end
    
    # Insert an ending tag.
    def _end_tag(sym)
      @target << "</#{sym}>"
    end

    # Insert the attributes (given in the hash).
    def _insert_attributes(attrs, order=[])
      return if attrs.nil?
      order.each do |k|
	v = attrs[k]
	@target << %{ #{k}="#{_attr_value(v)}"} if v
      end
      attrs.each do |k, v|
	@target << %{ #{k}="#{_attr_value(v)}"} unless order.member?(k)
      end
    end

    def _attr_value(value)
      case value
      when Symbol
	value.to_s
      else
	_escape_quote(value.to_s)
      end
    end

    def _ensure_no_block(got_block)
      if got_block
	fail IllegalBlockError,
	  "Blocks are not allowed on XML instructions"
      end
    end

  end

end
