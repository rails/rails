# frozen_string_literal: true

class StreamingController < ActionController::Base
  include ActionController::Live
  def index
    response.headers["Last-Modified"] = Time.now.httpdate
    response.stream.write "hello world\n"
  ensure
    response.stream.close
  end
end
