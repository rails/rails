module RailsGuides
  module TextileExtensions
    def notestuff(body)
      body.gsub!(/^(IMPORTANT|CAUTION|WARNING|NOTE|INFO)(?:\.|\:)(.*)$/) do |m|
        css_class = $1.downcase
        css_class = 'warning' if ['caution', 'important'].include?(css_class)

        result = "<div class='#{css_class}'><p>"
        result << $2.strip
        result << '</p></div>'
        result
      end
    end

    def tip(body)
      body.gsub!(/^(TIP)\:(.*)$/) do |m|
        result = "<div class='info'><p>"
        result << $2.strip
        result << '</p></div>'
        result
      end
    end

    def plusplus(body)
      body.gsub!(/\+(.*?)\+/) do |m|
        "<notextile><tt>#{$1}</tt></notextile>"
      end
    end

    def code(body)
      body.gsub!(/\<(yaml|shell|ruby|erb|html|sql)\>(.*?)\<\/\1\>/m) do |m|
        es = ERB::Util.h($2)
        css_class = ['erb', 'shell'].include?($1) ? 'html' : $1
        "<notextile><code class='#{css_class}'>#{es}\n</code></notextile>"
      end
    end
  end
end
