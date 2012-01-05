# Rails Guides on the Kindle


## Synopsis

  1. Obtain `kindlegen` from the link below and put the binary in your path
  2. Run `KINDLE=1 rake generate_guides` to generate the guides and compile the `.mobi` file
  3. Copy `output/kindle/rails_guides.mobi` to your Kindle

## OS X step by step

  1. Download `kindlegen` from the link below ([or click here](http://www.amazon.com/gp/feature.html?ie=UTF8&docId=1000234621) )
  2. In terminal cd to your projects directory and type `git clone https://github.com/rails/rails.git`
  3. Then type `cd rails/railties`
  4. Open a new terminal window and type `echo $PATH` and see if `usr/local/bin` is in it (it should be) if it is type `cd ../../`
  5. Then type in `cd usr/local/bin`
  6. Then `open .`
  7. That will open the directory, just copy the kindlegen binary to it then close the window and that terminal window
  8. Back in the other terminal window which should be in `rails/railties` type `KINDLE=1 rake generate_guides`
  9. It will then tell you where your .mobi is 

## Resources

  * [StackOverflow: Kindle Periodical Format](http://stackoverflow.com/questions/5379565/kindle-periodical-format)
  * Example Periodical [.ncx](https://gist.github.com/808c971ed087b839d462) and [.opf](https://gist.github.com/d6349aa8488eca2ee6d0)
  * [Kindle Publishing guidelines](http://kindlegen.s3.amazonaws.com/AmazonKindlePublishingGuidelines.pdf)
  * [KindleGen & Kindle Previewer](http://www.amazon.com/gp/feature.html?ie=UTF8&docId=1000234621) 

## TODO

### Post release

  * Integrate generated Kindle document in to published HTML guides
  * Tweak heading styles (most docs use h3/h4/h5, which end up being smaller than the text under it)
  * Tweak table styles (smaller text? Many of the tables are unusable on a Kindle in portrait mode)
  * Have the HTML/XML TOC 'drill down' into the TOCs of the individual guides
  * `.epub` generation.

