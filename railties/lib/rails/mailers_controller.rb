require 'rails/application_controller'

class Rails::MailersController < Rails::ApplicationController # :nodoc:
  prepend_view_path ActionDispatch::DebugExceptions::RESCUES_TEMPLATE_PATH

  before_action :require_local!
  before_action :find_preview, only: :preview

  def index
    @previews = ActionMailer::Preview.all
    @page_title = "Mailer Previews"
  end

  def preview
    if params[:path] == @preview.preview_name
      @page_title = "Mailer Previews for #{@preview.preview_name}"
      render action: 'mailer'
    else
      email = File.basename(params[:path])

      if @preview.email_exists?(email)
        @email = @preview.call(email)

        if params[:part]
          part_type = Mime::Type.lookup(params[:part])

          if part = find_part(part_type)
            response.content_type = part_type
            render text: part.respond_to?(:decoded) ? part.decoded : part
          else
            raise AbstractController::ActionNotFound, "Email part '#{part_type}' not found in #{@preview.name}##{email}"
          end
        else
          @part = find_preferred_part(request.format, Mime::HTML, Mime::TEXT)
          render action: 'email', layout: false, formats: %w[html]
        end
      else
        raise AbstractController::ActionNotFound, "Email '#{email}' not found in #{@preview.name}"
      end
    end
  end

  protected
    def find_preview
      candidates = []
      params[:path].to_s.scan(%r{/|$}){ candidates << $` }
      preview = candidates.detect{ |candidate| ActionMailer::Preview.exists?(candidate) }

      if preview
        @preview = ActionMailer::Preview.find(preview)
      else
        raise AbstractController::ActionNotFound, "Mailer preview '#{params[:path]}' not found"
      end
    end

    def find_preferred_part(*formats)
      if @email.multipart?
        formats.each do |format|
          return find_part(format) if parts.any?{ |p| p.mime_type == format }
        end
      else
        @email
      end
    end

    def find_part(format)
      if @email.multipart?
        parts.find{ |p| p.mime_type == format }
      elsif @email.mime_type == format
        @email
      end
    end

    def parts
      if @email.mime_type == 'multipart/related'
        parts_with_inline_attachments
      else
        email_parts
      end
    end

    def parts_with_inline_attachments
      multipart_alternative_parts.map do |part|
        inline_cid_attachments(part)
        part
      end
    end

    def inline_cid_attachments(part)
      part.body.raw_source.gsub!(/cid:[^\s'"]+/) do |uri|
        if (referenced_part = content_for_uri(uri))
          encode_base64_data(referenced_part)
        else
          uri
        end
      end
    end

    def encode_base64_data(part)
      encoded = Base64.encode64(part.body.decoded)
      "data:#{part.mime_type};base64,#{encoded}"
    end

    def content_for_uri(cid)
      email_parts.find { |part| part.url == cid }
    end

    # NOTE: `first` call assumes there's only one multipart part in this email,
    # so first returns the only one (and it's subparts)
    def multipart_alternative_parts
      email_parts.find(&:multipart?).body.parts
    end

    def email_parts
      @email_parts ||= @email.parts
    end
end
