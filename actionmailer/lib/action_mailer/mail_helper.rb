require 'action_mailer/vendor/text/format'

module MailHelper#:nodoc:
  def block_format(text)
    formatted = text.split(/\n\r\n/).collect { |paragraph| 
      Text::Format.new(
        :columns => 72, :first_indent => 2, :body_indent => 2, :text => paragraph
      ).format
    }.join("\n")
    
    # Make list points stand on their own line
    formatted.gsub!(/[ ]*([*]+) ([^*]*)/) { |s| "  #{$1} #{$2.strip}\n" }
    formatted.gsub!(/[ ]*([#]+) ([^#]*)/) { |s| "  #{$1} #{$2.strip}\n" }

    formatted
  end
end