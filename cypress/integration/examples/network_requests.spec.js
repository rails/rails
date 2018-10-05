/// <reference types="Cypress" />

context('Network Requests', () => {
  beforeEach(() => {
    cy.visit('https://example.cypress.io/commands/network-requests')
  })

  // Manage AJAX / XHR requests in your app

  it('cy.server() - control behavior of network requests and responses', () => {
    // https://on.cypress.io/server

    cy.server().should((server) => {
      // the default options on server
      // you can override any of these options
      expect(server.delay).to.eq(0)
      expect(server.method).to.eq('GET')
      expect(server.status).to.eq(200)
      expect(server.headers).to.be.null
      expect(server.response).to.be.null
      expect(server.onRequest).to.be.undefined
      expect(server.onResponse).to.be.undefined
      expect(server.onAbort).to.be.undefined

      // These options control the server behavior
      // affecting all requests

      // pass false to disable existing route stubs
      expect(server.enable).to.be.true
      // forces requests that don't match your routes to 404
      expect(server.force404).to.be.false
      // whitelists requests from ever being logged or stubbed
      expect(server.whitelist).to.be.a('function')
    })

    cy.server({
      method: 'POST',
      delay: 1000,
      status: 422,
      response: {},
    })

    // any route commands will now inherit the above options
    // from the server. anything we pass specifically
    // to route will override the defaults though.
  })

  it('cy.request() - make an XHR request', () => {
    // https://on.cypress.io/request
    cy.request('https://jsonplaceholder.typicode.com/comments')
      .should((response) => {
        expect(response.status).to.eq(200)
        expect(response.body).to.have.length(500)
        expect(response).to.have.property('headers')
        expect(response).to.have.property('duration')
      })
  })

  it('cy.route() - route responses to matching requests', () => {
    // https://on.cypress.io/route

    let message = 'whoa, this comment does not exist'
    cy.server()

    // Listen to GET to comments/1
    cy.route('GET', 'comments/*').as('getComment')

    // we have code that gets a comment when
    // the button is clicked in scripts.js
    cy.get('.network-btn').click()

    // https://on.cypress.io/wait
    cy.wait('@getComment').its('status').should('eq', 200)

    // Listen to POST to comments
    cy.route('POST', '/comments').as('postComment')

    // we have code that posts a comment when
    // the button is clicked in scripts.js
    cy.get('.network-post').click()
    cy.wait('@postComment')

    // get the route
    cy.get('@postComment').should((xhr) => {
      expect(xhr.requestBody).to.include('email')
      expect(xhr.requestHeaders).to.have.property('Content-Type')
      expect(xhr.responseBody).to.have.property('name', 'Using POST in cy.route()')
    })

    // Stub a response to PUT comments/ ****
    cy.route({
      method: 'PUT',
      url: 'comments/*',
      status: 404,
      response: { error: message },
      delay: 500,
    }).as('putComment')

    // we have code that puts a comment when
    // the button is clicked in scripts.js
    cy.get('.network-put').click()

    cy.wait('@putComment')

    // our 404 statusCode logic in scripts.js executed
    cy.get('.network-put-comment').should('contain', message)
  })
})
