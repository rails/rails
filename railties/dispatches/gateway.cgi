#!/usr/bin/ruby

# This is an experimental feature for getting high-speed CGI by using a long-running, DRb-backed server in the background

require 'drb'
require 'cgi'
require 'rbconfig'

VERBOSE = false

AppName = File.split(File.expand_path(File.join(__FILE__, '..'))).last
SocketPath = File.expand_path(File.join(File.dirname(__FILE__), '../log/drb_gateway.sock'))
ConnectionUri = "drbunix:#{SocketPath}"
attempted_start = false

def start_tracker
  tracker_path = File.join(File.dirname(__FILE__), '../script/tracker')
  fork do
    Process.setsid
    STDIN.reopen "/dev/null"
    STDOUT.reopen "/dev/null", "a"
    
    exec(File.join(Config::CONFIG['bin_dir'], Config::CONFIG['RUBY_SO_NAME']), tracker_path, 'start', ConnectionUri)
  end
  
  $stderr.puts "dispatch: waiting for tracker to start..." if VERBOSE
  10.times do
    sleep 0.5
    return if File.exists? SocketPath
  end
  
  $stderr.puts "Can't start tracker!!! Dropping request!"
  Kernel.exit 1
end

unless File.exists?(SocketPath)
  $stderr.puts "tracker not running: starting it..." if VERBOSE
  start_tracker
end

$stderr.puts "dispatch: attempting to contact tracker..." if VERBOSE
tracker = DRbObject.new_with_uri(ConnectionUri)
tracker.ping # Test connection

$stdout.extend DRbUndumped
$stdin.extend DRbUndumped
  
DRb.start_service "drbunix:", $stdin
$stderr.puts "dispatch: publishing stdin..." if VERBOSE

$stderr.puts "dispatch: sending request to tracker" if VERBOSE
puts tracker.process($stdin)

$stdout.flush
[$stdin, $stdout].each {|io| io.close}
$stderr.puts "dispatch: finished..." if VERBOSE


