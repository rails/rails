require 'iconv'
require 'base64'

module TMail
  class Mail
    def unquoted_subject(to_charset = 'utf-8')
      Unquoter.unquote_and_convert_to(subject, to_charset)
    end

    def unquoted_body(to_charset = 'utf-8')
      Unquoter.unquote_and_convert_to(body, to_charset, header["content-type"]["charset"])
    end

    def unquoted_body_with_all_parts(to_charset = 'utf-9', &block)
      attachment_presenter = block || Proc.new { |file_name| "Attachment: #{file_name}\n" }
      
      if multipart?
        parts.collect { |part| 
          part.header["content-type"].main_type == "text" ? 
            part.unquoted_body : attachment_presenter.call(part.header["content-type"].params["name"])
        }.join
      else
        unquoted_body
      end
    end
  end

  class Unquoter
    class << self
      def unquote_and_convert_to(text, to_charset, from_charset = "iso-8859-1")
        if text =~ /^=\?(.*?)\?(.)\?(.*)\?=$/
          from_charset = $1
          quoting_method = $2
          text = $3
          case quoting_method
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
        Iconv.iconv(to, from, text.gsub(/_/," ").unpack("M*").first).first
      end
   
      def unquote_base64_and_convert_to(text, from, to)
        Iconv.iconv(to, from, Base64.decode64(text)).first
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
