# frozen_string_literal: true

# Build list of Mime types for HTTP responses
# https://www.iana.org/assignments/media-types/

Mime::Type.register 'text/html', :html, %w( application/xhtml+xml ), %w( xhtml )
Mime::Type.register 'text/plain', :text, [], %w(txt)
Mime::Type.register 'text/javascript', :js, %w( application/javascript application/x-javascript )
Mime::Type.register 'text/css', :css
Mime::Type.register 'text/calendar', :ics
Mime::Type.register 'text/csv', :csv
Mime::Type.register 'text/vcard', :vcf
Mime::Type.register 'text/vtt', :vtt, %w(vtt)

Mime::Type.register 'image/png', :png, [], %w(png)
Mime::Type.register 'image/jpeg', :jpeg, [], %w(jpg jpeg jpe pjpeg)
Mime::Type.register 'image/gif', :gif, [], %w(gif)
Mime::Type.register 'image/bmp', :bmp, [], %w(bmp)
Mime::Type.register 'image/tiff', :tiff, [], %w(tif tiff)
Mime::Type.register 'image/svg+xml', :svg

Mime::Type.register 'video/mpeg', :mpeg, [], %w(mpg mpeg mpe)

Mime::Type.register 'audio/mpeg', :mp3, [], %w(mp1 mp2 mp3)
Mime::Type.register 'audio/ogg', :ogg, [], %w(oga ogg spx opus)
Mime::Type.register 'audio/aac', :m4a, %w( audio/mp4 ), %w(m4a mpg4 aac)

Mime::Type.register 'video/webm', :webm, [], %w(webm)
Mime::Type.register 'video/mp4', :mp4, [], %w(mp4 m4v)

Mime::Type.register 'font/otf', :otf, [], %w(otf)
Mime::Type.register 'font/ttf', :ttf, [], %w(ttf)
Mime::Type.register 'font/woff', :woff, [], %w(woff)
Mime::Type.register 'font/woff2', :woff2, [], %w(woff2)

Mime::Type.register 'application/xml', :xml, %w( text/xml application/x-xml )
Mime::Type.register 'application/rss+xml', :rss
Mime::Type.register 'application/atom+xml', :atom
Mime::Type.register 'application/x-yaml', :yaml, %w( text/yaml ), %w(yml yaml)

Mime::Type.register 'multipart/form-data', :multipart_form
Mime::Type.register 'application/x-www-form-urlencoded', :url_encoded_form

# https://www.ietf.org/rfc/rfc4627.txt
# http://www.json.org/JSONRequest.html
Mime::Type.register 'application/json', :json, %w( text/x-json application/jsonrequest )

Mime::Type.register 'application/pdf', :pdf, [], %w(pdf)
Mime::Type.register 'application/zip', :zip, [], %w(zip)
Mime::Type.register 'application/gzip', :gzip, %w(application/x-gzip), %w(gz)
