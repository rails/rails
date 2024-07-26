#!/usr/local/bin/ruby

require "address_book_controller"
AddressBookController.process_cgi(CGI.new)