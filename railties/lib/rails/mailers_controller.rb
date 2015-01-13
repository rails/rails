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
          if part = find_part(format)
            return part
          end
        end
      end
      @email
    end

    def find_part(format)
      if @email.multipart?
        all_parts(@email).find{ |p| p.mime_type == format && !p.attachment? }
      elsif @email.mime_type == format
        @email
      end
    end

    def all_parts(email)
      email.parts.flat_map{ |p| p.body.multipart? ? p.body.parts : p }
    end
end
