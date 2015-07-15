require 'rails/application_controller'

class Rails::MailersController < Rails::ApplicationController # :nodoc:
  prepend_view_path ActionDispatch::DebugExceptions::RESCUES_TEMPLATE_PATH

  before_action :require_local!, unless: :show_previews?
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
      @email_action = File.basename(params[:path])

      if @preview.email_exists?(@email_action)
        @email = @preview.call(@email_action)

        if params[:part]
          part_type = Mime::Type.lookup(params[:part])

          if part = find_part(part_type)
            response.content_type = part_type
            render text: part.respond_to?(:decoded) ? part.decoded : part
          else
            raise AbstractController::ActionNotFound, "Email part '#{part_type}' not found in #{@preview.name}##{@email_action}"
          end
        else
          @part = find_preferred_part(request.format, Mime::HTML, Mime::TEXT)
          render action: 'email', layout: false, formats: %w[html]
        end
      else
        raise AbstractController::ActionNotFound, "Email '#{@email_action}' not found in #{@preview.name}"
      end
    end
  end

  protected
    def show_previews?
      ActionMailer::Base.show_previews
    end

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
      formats.each do |format|
        if part = @email.find_first_mime_type(format)
          return part
        end
      end

      if formats.any?{ |f| @email.mime_type == f }
        @email
      end
    end

    def find_part(format)
      if part = @email.find_first_mime_type(format)
        part
      elsif @email.mime_type == format
        @email
      end
    end
end
