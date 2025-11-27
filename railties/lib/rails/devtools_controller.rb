# frozen_string_literal: true

class Rails::DevtoolsController < ActionController::Base # :nodoc:
  def show
    root_path = Rails.root.to_s
    hash = Digest::SHA1.hexdigest(root_path)
    uuid = "#{hash[0..7]}-#{hash[8..11]}-#{hash[12..15]}-#{hash[16..19]}-#{hash[20..31]}"

    render json: {
      "workspace": {
        "root": root_path,
        "uuid": uuid
      }
    }
  end
end
