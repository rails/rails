#!/usr/local/bin/ruby

require "address_book_controller"

begin
  AddressBookController.process_cgi(CGI.new)
rescue => e
  CGI.new.out { "#{e.class}: #{e.message}" }
end 