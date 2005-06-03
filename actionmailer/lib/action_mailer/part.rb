require 'action_mailer/adv_attr_accessor'

module ActionMailer

  class Part #:nodoc:
    include ActionMailer::AdvAttrAccessor

    adv_attr_accessor :content_type, :content_disposition, :charset, :body
    adv_attr_accessor :filename, :transfer_encoding, :headers

    def initialize(params)
      @content_type = params[:content_type]
      @content_disposition = params[:disposition] || "inline"
      @charset = params[:charset]
      @body = params[:body]
      @filename = params[:filename]
      @transfer_encoding = params[:transfer_encoding] || "quoted-printable"
      @headers = params[:headers] || {}
    end

    def to_mail(defaults)
      part = TMail::Mail.new
      part.set_content_type(content_type || defaults.content_type, nil,
        "charset" => (content_disposition == "attachment" ?
                        nil : (charset || defaults.charset)),
        "name" => filename)
      part.set_content_disposition(content_disposition,
        "filename" => filename)

      part.content_transfer_encoding = transfer_encoding || "quoted-printable"
      case (transfer_encoding || "").downcase
        when "base64" then
          part.body = TMail::Base64.folding_encode(body)
        when "quoted-printable"
          part.body = [body].pack("M*")
        else
          part.body = body
      end

      part
    end
  end

end
