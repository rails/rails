# Rails Guides on the Kindle


## Synopsis

  1. Obtain `kindlegen` from the link below and put the binary in your path
  2. Run `KINDLE=1 rake generate_guides` to generate the guides and compile the `.mobi` file
  3. Copy `output/kindle/rails_guides.mobi` to your Kindle

## Resources

  * [Stack Overflow: Kindle Periodical Format](http://stackoverflow.com/questions/5379565/kindle-periodical-format)
  * Example Periodical [.ncx](https://gist.github.com/808c971ed087b839d462) and [.opf](https://gist.github.com/d6349aa8488eca2ee6d0)
  * [Kindle Publishing Guidelines](http://kindlegen.s3.amazonaws.com/AmazonKindlePublishingGuidelines.pdf)
  * [KindleGen & Kindle Previewer](http://www.amazon.com/gp/feature.html?ie=UTF8&docId=1000234621) 

## TODO

### Post release

  * Integrate generated Kindle document into published HTML guides
  * Tweak heading styles (most docs use h3/h4/h5, which end up being smaller than the text under it)
  * Tweak table styles (smaller text? Many of the tables are unusable on a Kindle in portrait mode)
  * Have the HTML/XML TOC 'drill down' into the TOCs of the individual guides
  * `.epub` generation.

