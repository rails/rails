# frozen_string_literal: true

require "active_support/core_ext/digest/uuid"

class Rails::DevtoolsController < ActionController::Base # :nodoc:
  def show
    root_path = Rails.root.to_s
    uuid = Digest::UUID.uuid_v5(Digest::UUID::DNS_NAMESPACE, Rails.root.to_s)

    render json: {
      "workspace": {
        "root": root_path,
        "uuid": uuid
      }
    }
  end
end
