# frozen_string_literal: true

require "rails/application_controller"

class Rails::MailersController < Rails::ApplicationController # :nodoc:
  prepend_view_path ActionDispatch::DebugView::RESCUES_TEMPLATE_PATHS

  around_action :set_locale, only: [:preview, :download]
  before_action :find_preview, only: [:preview, :download]
  before_action :require_local!, unless: :show_previews?

  helper_method :part_query, :locale_query

  content_security_policy(false)

  def index
    @previews = ActionMailer::Preview.all
    @page_title = "Action Mailer Previews"
  end

  def download
    @email_action = File.basename(params[:path])
    if @preview.email_exists?(@email_action)
      @email = @preview.call(@email_action, params)
      send_data @email.to_s, filename: "#{@email_action}.eml"
    else
      raise AbstractController::ActionNotFound, "Email '#{@email_action}' not found in #{@preview.name}"
    end
  end

  def preview
    if params[:path] == @preview.preview_name
      @page_title = "Action Mailer Previews for #{@preview.preview_name}"
      render action: "mailer"
    else
      @email_action = File.basename(params[:path])

      if @preview.email_exists?(@email_action)
        @page_title = "Mailer Preview for #{@preview.preview_name}##{@email_action}"
        @email = @preview.call(@email_action, params)

        if params[:part]
          part_type = Mime::Type.lookup(params[:part])

          if part = find_part(part_type)
            response.content_type = part_type
            render plain: part.respond_to?(:decoded) ? part.decoded : part
          else
            raise AbstractController::ActionNotFound, "Email part '#{part_type}' not found in #{@preview.name}##{@email_action}"
          end
        else
          @part = find_preferred_part(request.format, Mime[:html], Mime[:text])
          render action: "email", layout: false, formats: [:html]
        end
      else
        raise AbstractController::ActionNotFound, "Email '#{@email_action}' not found in #{@preview.name}"
      end
    end
  end

  private
    def show_previews? # :doc:
      ActionMailer::Base.show_previews
    end

    def find_preview # :doc:
      candidates = []
      params[:path].to_s.scan(%r{/|$}) { candidates << $` }
      preview = candidates.detect { |candidate| ActionMailer::Preview.exists?(candidate) }

      if preview
        @preview = ActionMailer::Preview.find(preview)
      else
        raise AbstractController::ActionNotFound, "Mailer preview '#{params[:path]}' not found"
      end
    end

    def find_preferred_part(*formats) # :doc:
      formats.each do |format|
        if part = @email.find_first_mime_type(format)
          return part
        end
      end

      if formats.any? { |f| @email.mime_type == f }
        @email
      end
    end

    def find_part(format) # :doc:
      if part = @email.find_first_mime_type(format)
        part
      elsif @email.mime_type == format
        @email
      end
    end

    def part_query(mime_type)
      request.query_parameters.merge(part: mime_type).to_query
    end

    def locale_query(locale)
      request.query_parameters.merge(locale: locale).to_query
    end

    def set_locale(&block)
      I18n.with_locale(params[:locale] || I18n.default_locale, &block)
    end
end
