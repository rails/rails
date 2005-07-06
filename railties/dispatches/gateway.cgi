#!/usr/local/bin/ruby

require 'drb'

# This file includes an experimental gateway CGI implementation. It will work
# only on platforms which support both fork and sockets.
#
# To enable it edit public/.htaccess and replace dispatch.cgi with gateway.cgi.
#
# Next, create the directory log/drb_gateway and grant the apache user rw access
# to said directory.
#
# On the next request to your server, the gateway tracker should start up, along
# with a few listener processes. This setup should provide you with much better
# speeds than dispatch.cgi.
#
# Keep in mind that the first request made to the server will be slow, as the
# tracker and listeners will have to load. Also, the tracker and listeners will
# shutdown after a period if inactivity. You can set this value below -- the
# default is 90 seconds.

TrackerSocket = File.expand_path(File.join(File.dirname(__FILE__), '../log/drb_gateway/tracker.sock'))
DieAfter = 90 # Seconds
Listeners = 3

def message(s)
  $stderr.puts "gateway.cgi: #{s}" if ENV && ENV["DEBUG_GATEWAY"]
end

def listener_socket(number)
  File.expand_path(File.join(File.dirname(__FILE__), "../log/drb_gateway/listener_#{number}.sock"))
end

unless File.exists? TrackerSocket
  message "Starting tracker and #{Listeners} listeners"
  fork do
    Process.setsid
    STDIN.reopen "/dev/null"
    STDOUT.reopen "/dev/null", "a"

    root = File.expand_path(File.dirname(__FILE__) + '/..')

    message "starting tracker"
    fork do
      ARGV.clear
      ARGV << TrackerSocket << Listeners.to_s << DieAfter.to_s
      load File.join(root, 'script', 'tracker')
    end

    message "starting listeners"
    require File.join(root, 'config/environment.rb')
    Listeners.times do |number|
      fork do
        ARGV.clear
        ARGV << listener_socket(number) << DieAfter.to_s
        load File.join(root, 'script', 'listener')
      end
    end
  end

  message "waiting for tracker and listener to arise..."
  ready = false
  10.times do
    sleep 0.5
    break if (ready = File.exists?(TrackerSocket) && File.exists?(listener_socket(0)))
  end

  if ready
    message "tracker and listener are ready"
  else
    message "Waited 5 seconds, listener and tracker not ready... dropping request"
    Kernel.exit 1
  end
end

DRb.start_service

message "connecting to tracker"
tracker = DRbObject.new_with_uri("drbunix:#{TrackerSocket}")

input = $stdin.read
$stdin.close

env = ENV.inspect

output = nil
tracker.with_listener do |number|
  message "connecting to listener #{number}"
  socket = listener_socket(number)
  listener = DRbObject.new_with_uri("drbunix:#{socket}")
  output = listener.process(env, input)
  message "listener #{number} has finished, writing output"
end

$stdout.write output
$stdout.flush
$stdout.close