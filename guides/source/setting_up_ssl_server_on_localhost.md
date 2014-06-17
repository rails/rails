### Setting Up the WEBrick SSL Server on LocalHost

With WEBrick as the default development server, one cannot just configure Rails to enable SSL, because WEBrick must be invoked with SSL support turned on.  This means that modifying `config.ru` is necessary.

WEBrick is a Rack-based server.  The `config.ru` file is used by Rack-based servers to start the application.

Out of the box, Rails with WEBrick server does not provide an easy solution to build an SSL server using HTTPS for development purposes on localhost.

Running an HTTPS WEBrick server on `https://localhost:8080` is not difficult and can be accomplished as described below.  

Open the `config.ru` file which is located in the root directory of the Rails application.  

Insert the following code at the top of the config.ru file above all default `require` code.

```ruby
require 'openssl' # Implements the Secure Sockets Layer protocols.
require 'webrick' # Configures WEBrick.
require 'webrick/https' # Configures WEBrick as an HTTPS server.
```

The application is now ready to create the HTTPS server.

Delete `run Rails.application`.  Insert the code below in place of `run Rails.application`.  

The additional options specifically tell WEBrick to boot up with SSL support and it also provides the SSL private key and SSL certificate name.

```ruby
Rack::Handler::WEBrick.run Rails.application, {
  SSLEnable: true,
  SSLPrivateKey: OpenSSL::PKey::RSA.new(
    File.open('certs/server.key').read
  ),
  SSLCertificate: OpenSSL::X509::Certificate.new(
    File.open('certs/server.crt').read
  )
}
```
WEBrick needs to access the private key and the certificate.  So, the `certs/server.key` and `certs/server.crt` files must  be created.  Note that both files refer to keys and certificates the developer creates on their local environments and are self-signed certificates.

Create the certs directory inside the root directory of the application using the `mkdir certs` command.

Once a certs directory is created then run the following commands.
```ruby
cd certs
ssh-keygen -f server.key
openssl req -new -key server.key -out request.csr
openssl x509 -req -days 365 -in request.csr -signkey server.key -out server.crt
```
Note that the `ssh-keygen` command generates a "self-signed" certificate.  Also note that when running both `openssl` commands, other security related questions will be asked.  Follow the prompts accordingly.

It is time to start the HTTPS server.
Type `rails s`.

When done, the similar output to the output below should be expected.

```ruby
=> Booting WEBrick
...
Certificate:
    Data:
        Version: 1 (0x0)
        Serial Number: 10118111599302972979 (0x8c6ac0e43a369633)
    Signature Algorithm: sha1WithRSAEncryption
        ...
            Public Key Algorithm: rsaEncryption
                Public-Key: (2048 bit)
                Modulus:
                    00:c0:6c:7c:2d:b3:b0:f3:ac:d6:de:84:eb:ea:59:
                    ...
    Signature Algorithm: sha1WithRSAEncryption
         4e:88:c9:7d:a8:0e:77:54:34:94:00:57:23:64:a3:bc:1d:40:
         ...
[2014-05-31 16:42:53] INFO  WEBrick::HTTPServer#start: pid=2443 port=8080
```
If the output above shows up, a successful HTTPS server has been created on port 8080 on localhost.

###Stopping the Rails WEBrick SSL Server

Be aware that `ctrl-c` might not be enough to kill the process, so it may be necessary to stop the process manually through the `ps` or `kill -9 [PID]` commands.

For example, one can run the following commands to kill the process.

`ps aux | grep ruby`

This chained command will provide an output similar to the following.

`$           2443   0.0  1.5  2578296 123204 s000  T     4:42PM   0:02.98 $/.rbenv/versions/2.1.0/bin/ruby bin/rails s`

The first number "2443" is the process id number.  In the example, `kill -9 2443` will shutdown the server.
