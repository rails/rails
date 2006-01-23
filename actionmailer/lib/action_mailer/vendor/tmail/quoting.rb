module TMail
  class Mail
    def subject(to_charset = 'utf-8')
      Unquoter.unquote_and_convert_to(quoted_subject, to_charset)
    end

    def unquoted_body(to_charset = 'utf-8')
      from_charset = sub_header("content-type", "charset")
      case (content_transfer_encoding || "7bit").downcase
        when "quoted-printable"
          Unquoter.unquote_quoted_printable_and_convert_to(quoted_body,
            to_charset, from_charset, true)
        when "base64"
          Unquoter.unquote_base64_and_convert_to(quoted_body, to_charset,
            from_charset)
        when "7bit", "8bit"
          Unquoter.convert_to(quoted_body, to_charset, from_charset)
        when "binary"
          quoted_body
        else
          quoted_body
      end
    end

    def body(to_charset = 'utf-8', &block)
      attachment_presenter = block || Proc.new { |file_name| "Attachment: #{file_name}\n" }
    
      if multipart?
        parts.collect { |part| 
          header = part["content-type"]

          if part.multipart?
            part.body(to_charset, &attachment_presenter)
          elsif header.nil?
            ""
          elsif !attachment?(part)
            part.unquoted_body(to_charset)
          else
            attachment_presenter.call(header["name"] || "(unnamed)")
          end
        }.join
      else
        unquoted_body(to_charset)
      end
    end
  end

  class Unquoter
    class << self
      def unquote_and_convert_to(text, to_charset, from_charset = "iso-8859-1", preserve_underscores=false)
        return "" if text.nil?
        if text =~ /^=\?(.*?)\?(.)\?(.*)\?=$/
          from_charset = $1
          quoting_method = $2
          text = $3
          case quoting_method.upcase
            when "Q" then
              unquote_quoted_printable_and_convert_to(text, to_charset, from_charset, preserve_underscores)
            when "B" then
              unquote_base64_and_convert_to(text, to_charset, from_charset)
            else
              raise "unknown quoting method #{quoting_method.inspect}"
          end
        else
          convert_to(text, to_charset, from_charset)
        end
      end
 
      def unquote_quoted_printable_and_convert_to(text, to, from, preserve_underscores=false)
        text = text.gsub(/_/, " ") unless preserve_underscores
        convert_to(text.unpack("M*").first, to, from)
      end
 
      def unquote_base64_and_convert_to(text, to, from)
        convert_to(Base64.decode(text).first, to, from)
      end

      begin
        require 'iconv'
        def convert_to(text, to, from)
          return text unless to && from
          text ? Iconv.iconv(to, from, text).first : ""
        rescue Iconv::IllegalSequence, Errno::EINVAL
          # the 'from' parameter specifies a charset other than what the text
          # actually is...not much we can do in this case but just return the
          # unconverted text.
          #
          # Ditto if either parameter represents an unknown charset, like
          # X-UNKNOWN.
          text
        end
      rescue LoadError
        # Not providing quoting support
        def convert_to(text, to, from)
          warn "Action Mailer: iconv not loaded; ignoring conversion from #{from} to #{to} (#{__FILE__}:#{__LINE__})"
          text
        end
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
      assert_equal "[166417]_Bekr=E6ftelse_fra_Rejsefeber", b
    end
  end
end
