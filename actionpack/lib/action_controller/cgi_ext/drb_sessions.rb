#!/usr/local/bin/ruby -w
                                                                                
# This is a session storage daemon which can be shared by multiple FCGI
# processes. It's just a hash which is enabled for DRb access.
                                                                                
require 'drb'
                                                                                
session_data = Hash.new

#def session_data.[]=(k, v)
#  $stderr << "#{k} = #{v}\n"
#  super
#end

#def session_data.[](k)
#  $stderr << "#{k} #{super}\n"
#  super
#end

DRb.start_service('druby://127.0.0.1:9192', session_data)
DRb.thread.join
