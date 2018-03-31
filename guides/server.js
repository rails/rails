const path = require("path")
const express = require("express")

const app = express()
const publicPath = path.join(__dirname, "output")
const port = process.env.PORT || 9000

app.use(express.static(publicPath))
app.listen(port, () => {
  console.log(`Listening on port ${port}`)
})
