# Horo RDoc template
# Author: Hongli Lai - http://izumi.plan99.net/blog/
#
# Based on the Jamis template:
# http://weblog.jamisbuck.org/2005/4/8/rdoc-template

if defined?(RDoc::Diagram)
	RDoc::Diagram.class_eval do
		remove_const(:FONT)
		const_set(:FONT, "\"Bitstream Vera Sans\"")
	end
end

require 'rdoc/generator/html'

module RDoc
module Generator
class HTML
class HORO

FONTS = "\"Bitstream Vera Sans\", Verdana, Arial, Helvetica, sans-serif"

STYLE = <<CSS
a {
  color: #00F;
  text-decoration: none;
}

a:hover {
  color: #77F;
  text-decoration: underline;
}

body, td, p {
  font-family: <%= values['fonts'] %>;
  background: #FFF;
  color: #000;
  margin: 0px;
  font-size: small;
}

p {
  margin-top: 0.5em;
  margin-bottom: 0.5em;
}

#content {
  margin: 2em;
  margin-left: 3.5em;
  margin-right: 3.5em;
}

#description p {
  margin-bottom: 0.5em;
}

.sectiontitle {
  margin-top: 1em;
  margin-bottom: 1em;
  padding: 0.5em;
  padding-left: 2em;
  background: #005;
  color: #FFF;
  font-weight: bold;
}

.attr-rw {
  padding-left: 1em;
  padding-right: 1em;
  text-align: center;
  color: #055;
}

.attr-name {
  font-weight: bold;
}

.attr-desc {
}

.attr-value {
  font-family: monospace;
}

.file-title-prefix {
  font-size: large;
}

.file-title {
  font-size: large;
  font-weight: bold;
  background: #005;
  color: #FFF;
}

.banner {
  background: #005;
  color: #FFF;
  border: 1px solid black;
  padding: 1em;
}

.banner td {
  background: transparent;
  color: #FFF;
}

h1 a, h2 a, .sectiontitle a, .banner a {
  color: #FF0;
}

h1 a:hover, h2 a:hover, .sectiontitle a:hover, .banner a:hover {
  color: #FF7;
}

.dyn-source {
  display: none;
  background: #fffde8;
  color: #000;
  border: #ffe0bb dotted 1px;
  margin: 0.5em 2em 0.5em 2em;
  padding: 0.5em;
}

.dyn-source .cmt {
  color: #00F;
  font-style: italic;
}

.dyn-source .kw {
  color: #070;
  font-weight: bold;
}

.method {
  margin-left: 1em;
  margin-right: 1em;
  margin-bottom: 1em;
}

.description pre {
  padding: 0.5em;
  border: #ffe0bb dotted 1px;
  background: #fffde8;
}

.method .title {
  font-family: monospace;
  font-size: large;
  border-bottom: 1px dashed black;
  margin-bottom: 0.3em;
  padding-bottom: 0.1em;
}

.method .description, .method .sourcecode {
  margin-left: 1em;
}

.description p, .sourcecode p {
  margin-bottom: 0.5em;
}

.method .sourcecode p.source-link {
  text-indent: 0em;
  margin-top: 0.5em;
}

.method .aka {
  margin-top: 0.3em;
  margin-left: 1em;
  font-style: italic;
  text-indent: 2em;
}

h1 {
  padding: 1em;
  margin-left: -1.5em;
  font-size: x-large;
  font-weight: bold;
  color: #FFF;
  background: #007;
}

h2 {
  padding: 0.5em 1em 0.5em 1em;
  margin-left: -1.5em;
  font-size: large;
  font-weight: bold;
  color: #FFF;
  background: #009;
}

h3, h4, h5, h6 {
  color: #220088;
  border-bottom: #5522bb solid 1px;
}

.sourcecode > pre {
  padding: 0.5em;
  border: 1px dotted black;
  background: #FFE;
}

dt {
  font-weight: bold
}

dd {
  margin-bottom: 0.7em;
}
CSS

XHTML_PREAMBLE = %{<?xml version="1.0" encoding="<%= values['charset'] %>"?>
<!DOCTYPE html 
     PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
     "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
}

XHTML_FRAMESET_PREAMBLE = %{
<!DOCTYPE html
     PUBLIC "-//W3C//DTD XHTML 1.0 Frameset//EN"
     "http://www.w3.org/TR/xhtml1/DTD/xhtml1-frameset.dtd">    
}

HEADER = XHTML_PREAMBLE + <<ENDHEADER
<html>
  <head>
    <title><%= values['title'] %></title>
    <meta http-equiv="Content-Type" content="text/html; charset=<%= values['charset'] %>" />
    <link rel="stylesheet" href="<%= values['style_url'] %>" type="text/css" media="screen" />

    <script language="JavaScript" type="text/javascript">
    // <![CDATA[

        function toggleSource( id )
        {
          var elem
          var link

          if( document.getElementById )
          {
            elem = document.getElementById( id )
            link = document.getElementById( "l_" + id )
          }
          else if ( document.all )
          {
            elem = eval( "document.all." + id )
            link = eval( "document.all.l_" + id )
          }
          else
            return false;

          if( elem.style.display == "block" )
          {
            elem.style.display = "none"
            link.innerHTML = "show source"
          }
          else
          {
            elem.style.display = "block"
            link.innerHTML = "hide source"
          }
        }

        function openCode( url )
        {
          window.open( url, "SOURCE_CODE", "resizable=yes,scrollbars=yes,toolbar=no,status=no,height=480,width=750" ).focus();
        }
      // ]]>
    </script>
  </head>

  <body>
ENDHEADER

FILE_PAGE = <<HTML
<table border='0' cellpadding='0' cellspacing='0' width="100%" class='banner'>
  <tr><td>
    <table width="100%" border='0' cellpadding='0' cellspacing='0'><tr>
      <td class="file-title" colspan="2"><span class="file-title-prefix">File</span><br /><%= values['short_name'] %></td>
      <td align="right">
        <table border='0' cellspacing="0" cellpadding="2">
          <tr>
            <td>Path:</td>
            <td><%= values['full_path'] %>
<% if values['cvsurl'] %>
				&nbsp;(<a href="<%= values['cvsurl'] %>">CVS</a>)
<% end %>
            </td>
          </tr>
          <tr>
            <td>Modified:</td>
            <td><%= values['dtm_modified'] %></td>
          </tr>
        </table>
      </td></tr>
    </table>
  </td></tr>
</table><br />
HTML

###################################################################

CLASS_PAGE = <<HTML
<table width="100%" border='0' cellpadding='0' cellspacing='0' class='banner'><tr>
  <td class="file-title"><span class="file-title-prefix"><%= values['classmod'] %></span><br /><%= values['full_name'] %></td>
  <td align="right">
    <table cellspacing="0" cellpadding="2">
      <tr valign="top">
        <td>In:</td>
        <td>
<% values['infiles'].each do |infile| %>
<%= href infile['full_path_url'], infile['full_path'] %>:
<% if infile['cvsurl'] %>
&nbsp;(<a href="<%= infile['cvsurl'] %>">CVS</a>)
<% end %>
<% end %>
        </td>
      </tr>
<% if values['parent'] %>
    <tr>
      <td>Parent:</td>
      <td>
<% if values['par_url'] %>
        <a href="<%= values['par_url'] %>">
<% end %>
<%= values['parent'] %>
<% if values['par_url'] %>
         </a>
<% end %>
     </td>
   </tr>
<% end %>
         </table>
        </td>
        </tr>
      </table>
HTML

###################################################################

METHOD_LIST = <<HTML
  <div id="content">
<% if values['diagram'] %>
  <table cellpadding='0' cellspacing='0' border='0' width="100%"><tr><td align="center">
    <%= values['diagram'] %>
  </td></tr></table>
<% end %>

<% if values['description'] %>
  <div class="description"><%= values['description'] %></div>
<% end %>

<% if values['requires'] %>
  <div class="sectiontitle">Required Files</div>
  <ul>
<% values['requires'].each do |require| %>
  <li><%= href require['aref'], require['name'] %>:</li>
<% end %>
  </ul>
<% end %>

<% if values['toc'] %>
  <div class="sectiontitle">Contents</div>
  <ul>
<% values['toc'].each do |toc| %>
  <li><a href="#<%= toc['href'] %>"><%= toc['secname'] %></a></li>
<% end %>
  </ul>
<% end %>

<% if values['methods'] %>
  <div class="sectiontitle">Methods</div>
  <ul>
<% values['methods'].each do |method| %>
  <li><%= href method['aref'], method['name'] %></li>
<% end %>
  </ul>
<% end %>

<% if values['includes'] %>
<div class="sectiontitle">Included Modules</div>
<ul>
<% values['includes'].each do |include| %>
  <li><%= href include['aref'], include['name'] %>:</li>
<% end %>
</ul>
<% end %>

<% values['sections'].each do |section| %>
<% if section['sectitle'] %>
<div class="sectiontitle"><a name="<%= section['secsequence'] %>"><%= section['sectitle'] %></a></div>
<% if section['seccomment'] %>
<div class="description">
<%= section['seccomment'] %>
</div>
<% end %>
<% end %>

<% if section['classlist'] %>
  <div class="sectiontitle">Classes and Modules</div>
  <%= section['classlist'] %>
<% end %>

<% if section['constants'] %>
  <div class="sectiontitle">Constants</div>
  <table border='0' cellpadding='5'>
<% section['constants'].each do |constant| %>
  <tr valign='top'>
    <td class="attr-name"><%= constant['name'] %></td>
    <td>=</td>
    <td class="attr-value"><%= constant['value'] %></td>
  </tr>
<% if constant['desc'] %>
  <tr valign='top'>
    <td>&nbsp;</td>
    <td colspan="2" class="attr-desc"><%= constant['desc'] %></td>
  </tr>
<% end %>
<% end %>
  </table>
<% end %>

<% if section['attributes'] %>
  <div class="sectiontitle">Attributes</div>
  <table border='0' cellpadding='5'>
<% section['attributes'].each do |attribute| %>
  <tr valign='top'>
    <td class='attr-rw'>
<% if attribute['rw'] %>
[<%= attribute['rw'] %>]
<% end %>
    </td>
    <td class='attr-name'><%= attribute['name'] %></td>
    <td class='attr-desc'><%= attribute['a_desc'] %></td>
  </tr>
<% end %>
  </table>
<% end %>

<% if section['method_list'] %>
<% section['method_list'].each do |method_list| %>
<% if method_list['methods'] %>
<div class="sectiontitle"><%= method_list['type'] %> <%= method_list['category'] %> methods</div>
<% method_list['methods'].each do |method| %>
<div class="method">
  <div class="title">
<% if method['callseq'] %>
    <a name="<%= method['aref'] %>"></a><b><%= method['callseq'] %></b>
<% end %>
<% unless method['callseq'] %>
    <a name="<%= method['aref'] %>"></a><b><%= method['name'] %></b><%= method['params'] %>
<% end %>
<% if method['codeurl'] %>
[&nbsp;<a href="<%= method['codeurl'] %>" target="SOURCE_CODE" onclick="javascript:openCode('<%= method['codeurl'] %>'); return false;">source</a>&nbsp;]
<% end %>
  </div>
<% if method['m_desc'] %>
  <div class="description">
  <%= method['m_desc'] %>
  </div>
<% end %>
<% if method['aka'] %>
<div class="aka">
  This method is also aliased as
<% method['aka'].each do |aka| %>
  <a href="<%= aka['aref'] %>"><%= aka['name'] %></a>
<% end %>
</div>
<% end %>
<% if method['sourcecode'] %>
<div class="sourcecode">
  <p class="source-link">[ <a href="javascript:toggleSource('<%= method['aref'] %>_source')" id="l_<%= method['aref'] %>_source">show source</a> ]</p>
  <div id="<%= method['aref'] %>_source" class="dyn-source">
<pre>
<%= method['sourcecode'] %>
</pre>
  </div>
</div>
<% end %>
</div>
<% end %>
<% end %>
<% end %>
<% end %>
<% end %>
</div>
HTML

FOOTER = <<ENDFOOTER
  </body>
</html>
ENDFOOTER

BODY = HEADER + <<ENDBODY
  <%= template_include %> <!-- banner header -->

  <div id="bodyContent">
    #{METHOD_LIST}
  </div>

  #{FOOTER}
ENDBODY

########################## Source code ##########################

SRC_PAGE = XHTML_PREAMBLE + <<HTML
<html>
<head><title><%= values['title'] %></title>
<meta http-equiv="Content-Type" content="text/html; charset=<%= values['charset'] %>" />
<style type="text/css">
.ruby-comment    { color: green; font-style: italic }
.ruby-constant   { color: #4433aa; font-weight: bold; }
.ruby-identifier { color: #222222;  }
.ruby-ivar       { color: #2233dd; }
.ruby-keyword    { color: #3333FF; font-weight: bold }
.ruby-node       { color: #777777; }
.ruby-operator   { color: #111111;  }
.ruby-regexp     { color: #662222; }
.ruby-value      { color: #662222; font-style: italic }
  .kw { color: #3333FF; font-weight: bold }
  .cmt { color: green; font-style: italic }
  .str { color: #662222; font-style: italic }
  .re  { color: #662222; }
</style>
</head>
<body bgcolor="white">
<pre><%= values['code'] %></pre>
</body>
</html>
HTML

########################## Index ################################

FR_INDEX_BODY = <<HTML
<%= template_include %>
HTML

FILE_INDEX = XHTML_PREAMBLE + <<HTML
<html>
<head>
<meta http-equiv="Content-Type" content="text/html; charset=<%= values['charset'] %>" />
<title>Index</title>
<style type="text/css">
<!--
  body {
    background-color: #EEE;
    font-family: #{FONTS}; 
    color: #000;
    margin: 0px;
  }
  .banner {
    background: #005;
    color: #FFF;
    padding: 0.2em;
    font-size: small;
    font-weight: bold;
    text-align: center;
  }
  .entries {
    margin: 0.25em 1em 0 1em;
    font-size: x-small;
  }
  a {
    color: #00F;
    text-decoration: none;
    white-space: nowrap;
  }
  a:hover {
    color: #77F;
    text-decoration: underline;
  }
-->
</style>
<base target="docwin" />
</head>
<body>
<div class="banner"><%= values['list_title'] %></div>
<div class="entries">
<% values['entries'].each do |entrie| %>
<a href="<%= entrie['href'] %>"><%= entrie['name'] %></a><br />
<% end %>
</div>
</body></html>
HTML

CLASS_INDEX = FILE_INDEX
METHOD_INDEX = FILE_INDEX

INDEX = XHTML_FRAMESET_PREAMBLE + <<HTML
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
<head>
  <title><%= values['title'] %></title>
  <meta http-equiv="Content-Type" content="text/html; charset=<%= values['charset'] %>" />
</head>

<frameset cols="20%,*">
    <frameset rows="15%,55%,30%">
        <frame src="fr_file_index.html"   title="Files" name="Files" />
        <frame src="fr_class_index.html"  name="Classes" />
        <frame src="fr_method_index.html" name="Methods" />
    </frameset>
    <frame  src="<%= values['initial_page'] %>" name="docwin" />
    <noframes>
          <body bgcolor="white">
            Click <a href="html/index.html">here</a> for a non-frames
            version of this page.
          </body>
    </noframes>
</frameset>

</html>
HTML

end
end
end
end
