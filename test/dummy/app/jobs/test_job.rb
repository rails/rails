class TestJob < ActiveJob::Base
  queue_as :default

  def perform(x)
    File.open(Rails.root.join("tmp/#{x}"), "w+") do |f|
      f.write x
    end
  end
end
