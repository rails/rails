if ENV["UNSPRUNG"].nil? && (ENV["RAILS_ENV"].nil? || ENV["RAILS_ENV"] == "development" || ENV["RAILS_ENV"] == "test")
  begin
    load File.expand_path("../../bin/spring", __FILE__)
  rescue LoadError => e
    raise unless e.message.include?("spring")
  end
end

require_relative "boot"
