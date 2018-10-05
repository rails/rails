/// <reference types="Cypress" />

context('Files', () => {
  beforeEach(() => {
    cy.visit('https://example.cypress.io/commands/files')
  })
  it('cy.fixture() - load a fixture', () => {
    // https://on.cypress.io/fixture

    // Instead of writing a response inline you can
    // use a fixture file's content.

    cy.server()
    cy.fixture('example.json').as('comment')
    cy.route('GET', 'comments/*', '@comment').as('getComment')

    // we have code that gets a comment when
    // the button is clicked in scripts.js
    cy.get('.fixture-btn').click()

    cy.wait('@getComment').its('responseBody')
      .should('have.property', 'name')
      .and('include', 'Using fixtures to represent data')

    // you can also just write the fixture in the route
    cy.route('GET', 'comments/*', 'fixture:example.json').as('getComment')

    // we have code that gets a comment when
    // the button is clicked in scripts.js
    cy.get('.fixture-btn').click()

    cy.wait('@getComment').its('responseBody')
      .should('have.property', 'name')
      .and('include', 'Using fixtures to represent data')

    // or write fx to represent fixture
    // by default it assumes it's .json
    cy.route('GET', 'comments/*', 'fx:example').as('getComment')

    // we have code that gets a comment when
    // the button is clicked in scripts.js
    cy.get('.fixture-btn').click()

    cy.wait('@getComment').its('responseBody')
      .should('have.property', 'name')
      .and('include', 'Using fixtures to represent data')
  })

  it('cy.readFile() - read a files contents', () => {
    // https://on.cypress.io/readfile

    // You can read a file and yield its contents
    // The filePath is relative to your project's root.
    cy.readFile('cypress.json').then((json) => {
      expect(json).to.be.an('object')
    })
  })

  it('cy.writeFile() - write to a file', () => {
    // https://on.cypress.io/writefile

    // You can write to a file

    // Use a response from a request to automatically
    // generate a fixture file for use later
    cy.request('https://jsonplaceholder.typicode.com/users')
      .then((response) => {
        cy.writeFile('cypress/fixtures/users.json', response.body)
      })
    cy.fixture('users').should((users) => {
      expect(users[0].name).to.exist
    })

    // JavaScript arrays and objects are stringified
    // and formatted into text.
    cy.writeFile('cypress/fixtures/profile.json', {
      id: 8739,
      name: 'Jane',
      email: 'jane@example.com',
    })

    cy.fixture('profile').should((profile) => {
      expect(profile.name).to.eq('Jane')
    })
  })
})
