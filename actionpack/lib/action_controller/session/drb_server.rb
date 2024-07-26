#!/usr/local/bin/ruby -w
                                                                                
# This is a really simple session storage daemon, basically just a hash, 
# which is enabled for DRb access.
                                                                                
require 'drb'

DRb.start_service('druby://127.0.0.1:9192', Hash.new)
DRb.thread.join