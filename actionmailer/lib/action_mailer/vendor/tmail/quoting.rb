begin
  require 'iconv'
  require 'base64'

  module TMail
    class Mail
      def subject(to_charset = 'utf-8')
        Unquoter.unquote_and_convert_to(quoted_subject, to_charset)
      end

      def unquoted_body(to_charset = 'utf-8')
        Unquoter.unquote_and_convert_to(quoted_body, to_charset, header["content-type"]["charset"])
      end

      def body(to_charset = 'utf-8', &block)
        attachment_presenter = block || Proc.new { |file_name| "Attachment: #{file_name}\n" }
      
        if multipart?
          parts.collect { |part| 
            part.header["content-type"].main_type == "text" ? 
              part.unquoted_body(to_charset) :
              attachment_presenter.call(part.header["content-type"].params["name"])
          }.join
        else
          unquoted_body(to_charset)
        end
      end
    end

    class Unquoter
      class << self
        def unquote_and_convert_to(text, to_charset, from_charset = "iso-8859-1")
          return "" if text.nil?
          if text =~ /^=\?(.*?)\?(.)\?(.*)\?=$/
            from_charset = $1
            quoting_method = $2
            text = $3
            case quoting_method.upcase
              when "Q" then
                unquote_quoted_printable_and_convert_to(text, from_charset, to_charset)
              when "B" then
                unquote_base64_and_convert_to(text, from_charset, to_charset)
              else
                raise "unknown quoting method #{quoting_method.inspect}"
            end
          else
            unquote_quoted_printable_and_convert_to(text, from_charset, to_charset)
          end
        end
   
        def unquote_quoted_printable_and_convert_to(text, from, to)
          text ? Iconv.iconv(to, from || "ISO-8859-1", text.gsub(/_/," ").unpack("M*").first).first : ""
        end
   
        def unquote_base64_and_convert_to(text, from, to)
          text ? Iconv.iconv(to, from || "ISO-8859-1", Base64.decode64(text)).first : ""
        end
      end
    end
  end

  if __FILE__ == $0
    require 'test/unit'
 
    class TC_Unquoter < Test::Unit::TestCase
      def test_unquote_quoted_printable
        a ="=?ISO-8859-1?Q?[166417]_Bekr=E6ftelse_fra_Rejsefeber?=" 
        b = TMail::Unquoter.unquote_and_convert_to(a, 'utf-8')
        assert_equal "[166417] Bekr\303\246ftelse fra Rejsefeber", b
      end
 
      def test_unquote_base64
        a ="=?ISO-8859-1?B?WzE2NjQxN10gQmVrcuZmdGVsc2UgZnJhIFJlanNlZmViZXI=?="
        b = TMail::Unquoter.unquote_and_convert_to(a, 'utf-8')
        assert_equal "[166417] Bekr\303\246ftelse fra Rejsefeber", b
      end
 
      def test_unquote_without_charset
        a ="[166417]_Bekr=E6ftelse_fra_Rejsefeber" 
        b = TMail::Unquoter.unquote_and_convert_to(a, 'utf-8')
        assert_equal "[166417] Bekr\303\246ftelse fra Rejsefeber", b
      end
    end
  end
rescue LoadError => e
  # Not providing quoting support
  module TMail
    class Mail
      def subject
        warn "Action Mailer: iconv couldn't be required, so the charset conversion is skipped"
        quoted_subject
      end
      
      def body
        warn "Action Mailer: iconv couldn't be required, so the charset conversion is skipped"
        quoted_body
      end
    end
  end
end