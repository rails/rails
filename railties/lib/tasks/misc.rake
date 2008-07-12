task :default => :test
task :environment do
  require(File.join(RAILS_ROOT, 'config', 'environment'))
end

require 'rails_generator/secret_key_generator'
desc 'Generate a crytographically secure secret key. This is typically used to generate a secret for cookie sessions. Pass a unique identifier to the generator using ID="some unique identifier" for greater security.'
task :secret do
  puts Rails::SecretKeyGenerator.new(ENV['ID']).generate_secret
end

require 'active_support'
namespace :time do
  namespace :zones do
    desc 'Displays names of all time zones recognized by the Rails TimeZone class, grouped by offset. Results can be filtered with optional OFFSET parameter, e.g., OFFSET=-6'
    task :all do
      build_time_zone_list(:all)
    end
    
    desc 'Displays names of US time zones recognized by the Rails TimeZone class, grouped by offset. Results can be filtered with optional OFFSET parameter, e.g., OFFSET=-6'
    task :us do
      build_time_zone_list(:us_zones)
    end
    
    desc 'Displays names of time zones recognized by the Rails TimeZone class with the same offset as the system local time'
    task :local do
      jan_offset = Time.now.beginning_of_year.utc_offset
      jul_offset = Time.now.beginning_of_year.change(:month => 7).utc_offset
      offset = jan_offset < jul_offset ? jan_offset : jul_offset
      build_time_zone_list(:all, offset)
    end
    
    # to find UTC -06:00 zones, OFFSET can be set to either -6, -6:00 or 21600
    def build_time_zone_list(method, offset = ENV['OFFSET'])
      if offset
        offset = if offset.to_s.match(/(\+|-)?(\d+):(\d+)/)
          sign = $1 == '-' ? -1 : 1
          hours, minutes = $2.to_f, $3.to_f
          ((hours * 3600) + (minutes.to_f * 60)) * sign
        elsif offset.to_f.abs <= 13
          offset.to_f * 3600
        else
          offset.to_f
        end
      end
      previous_offset = nil
      ActiveSupport::TimeZone.__send__(method).each do |zone|
        if offset.nil? || offset == zone.utc_offset
          puts "\n* UTC #{zone.formatted_offset} *" unless zone.utc_offset == previous_offset
          puts zone.name
          previous_offset = zone.utc_offset
        end
      end
      puts "\n"
    end
  end
end