module ActionController #:nodoc:
  module Flash
    extend ActiveSupport::Concern

    included do
      delegate :flash, :to => :request
      delegate :alert, :notice, :to => "request.flash"
      helper_method :alert, :notice
    end

    protected
      def redirect_to(options = {}, response_status_and_flash = {}) #:doc:
        if alert = response_status_and_flash.delete(:alert)
          flash[:alert] = alert
        end

        if notice = response_status_and_flash.delete(:notice)
          flash[:notice] = notice
        end

        if other_flashes = response_status_and_flash.delete(:flash)
          flash.update(other_flashes)
        end

        if options.is_a?(Hash)
          if options_alert = options.delete(:alert)
            flash[:alert] = options_alert
          end

          if options_notice = options.delete(:notice)
            flash[:notice] = options_notice
          end

          if options_other_flashes = options.delete(:flash)
            flash.update(options_other_flashes)
          end
        end

        super(options, response_status_and_flash)
      end
  end
end
