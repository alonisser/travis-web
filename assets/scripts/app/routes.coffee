require 'travis/location'
require 'travis/line_number_parser'

Ember.Router.reopen
  location: (if testMode? then Ember.NoneLocation.create() else Travis.Location.create())

  handleURL: (url) ->
    Travis.autoSignIn() unless Travis.__container__.lookup('controller:currentUser').get('content')

    url = url.replace(/#.*?$/, '')
    try
      @_super(url)
    catch error
      if error.message.match(/No route matched the URL/)
        @_super('/not-found')
      else
        throw error

# TODO: don't reopen Ember.Route to add events, there should be
#       a better way (like "parent" resource for everything inside map)
Ember.Route.reopen
  events:
    afterSignIn: (path) ->
      @afterSignIn(path)

    afterSignOut: ->
      @afterSignOut()

  afterSignIn: (path) ->
    @routeTo(path)

  afterSignOut: ->
    @routeTo('/')

  routeTo: (path) ->
    return unless path
    @router.handleURL(path)
    @router.location.setURL(path)

  signedIn: ->
    @controllerFor('currentUser').get('content')

  redirect: ->
    Travis.autoSignIn() unless @signedIn()

    if @get('needsAuth')
      @authorize(@router.location.getURL())
    else
      @_super.apply this, arguments

  authorize: (path) ->
    if !@signedIn()
      Travis.storeAfterSignInPath(path)
      @transitionTo('auth')

Travis.Router.reopen
  transitionTo: ->
    this.container.lookup('controller:repo').set('lineNumber', null)

    @_super.apply this, arguments


Travis.Router.map ->
  @resource 'index', path: '/', ->
    @route 'current', path: '/'
    @resource 'repo', path: '/:owner/:name', ->
      @route 'index', path: '/'
      @resource 'build', path: '/builds/:build_id'
      @resource 'job',   path: '/jobs/:job_id'
      @resource 'builds', path: '/builds'
      @resource 'pullRequests', path: '/pull_requests'
      @resource 'branches', path: '/branches'

  @route 'stats', path: '/stats'
  @route 'auth', path: '/auth'
  @route 'notFound', path: '/not-found'

  @resource 'profile', path: '/profile', ->
    @route 'index', path: '/'
    @resource 'account', path: '/:login', ->
      @route 'index', path: '/'
      @route 'profile', path: '/profile'

Travis.ApplicationRoute = Ember.Route.extend Travis.LineNumberParser,
  setupController: ->
    @_super.apply this, arguments

    this.controllerFor('repo').set('lineNumber', @fetchLineNumber())

Travis.IndexCurrentRoute = Ember.Route.extend
  renderTemplate: ->
    @render 'repo'
    @render 'build', outlet: 'pane', into: 'repo'

  setupController: ->
    console.log 'index current route'
    @container.lookup('controller:repo').activate('index')

Travis.AbstractBuildsRoute = Ember.Route.extend
  renderTemplate: ->
    @render 'builds', outlet: 'pane', into: 'repo'

  setupController: ->
    @container.lookup('controller:repo').activate(@get('contentType'))

Travis.BuildsRoute = Travis.AbstractBuildsRoute.extend(contentType: 'builds')
Travis.PullRequestsRoute = Travis.AbstractBuildsRoute.extend(contentType: 'pull_requests')
Travis.BranchesRoute = Travis.AbstractBuildsRoute.extend(contentType: 'branches')

Travis.BuildRoute = Ember.Route.extend
  renderTemplate: ->
    @render 'build', outlet: 'pane', into: 'repo'

  serialize: (model, params) ->
    id = if model.get then model.get('id') else model

    { build_id: id }

  setupController: (controller, model) ->
    model = Travis.Build.find(model) if model && !model.get

    repo = @container.lookup('controller:repo')
    repo.set('build', model)
    repo.activate('build')

Travis.JobRoute = Ember.Route.extend
  renderTemplate: ->
    @render 'job', outlet: 'pane', into: 'repo'

  serialize: (model, params) ->
    id = if model.get then model.get('id') else model

    { job_id: id }

  setupController: (controller, model) ->
    model = Travis.Job.find(model) if model && !model.get

    repo = @container.lookup('controller:repo')
    repo.set('job', model)
    repo.activate('job')

Travis.RepoIndexRoute = Ember.Route.extend
  setupController: (controller, model) ->
    @container.lookup('controller:repo').activate('current')

  renderTemplate: ->
    @render 'build', outlet: 'pane', into: 'repo'

Travis.RepoRoute = Ember.Route.extend
  renderTemplate: ->
    @render 'repo'

  setupController: (controller, model) ->
    # TODO: if repo is just a data hash with id and slug load it
    #       as incomplete record
    model = Travis.Repo.find(model.id) if model && !model.get
    controller.set('repo', model)

  serialize: (repo) ->
    slug = if repo.get then repo.get('slug') else repo.slug
    [owner, name] = slug.split('/')
    { owner: owner, name: name }

  deserialize: (params) ->
    slug = "#{params.owner}/#{params.name}"
    content = Ember.Object.create slug: slug, isLoaded: false, isLoading: true
    proxy = Ember.ObjectProxy.create(content: content)

    repos = Travis.Repo.bySlug(slug)

    observer = ->
      if repos.get 'isLoaded'
        repos.removeObserver 'isLoaded', observer
        proxy.set 'isLoading', false

        if repos.get('length') == 0
          # isError is also used in DS.Model, but maybe we should use something
          # more focused like notFound later
          proxy.set 'isError', true
        else
          proxy.set 'content', repos.objectAt(0)

    if repos.length
      proxy.set('content', repos[0])
    else
      repos.addObserver 'isLoaded', observer

    proxy

Travis.IndexRoute = Ember.Route.extend
  renderTemplate: ->
    $('body').attr('id', 'home')

    @render 'repos',   outlet: 'left'
    @render 'sidebar', outlet: 'right'
    @render 'top',     outlet: 'top'

  setupController: (controller)->
    @container.lookup('controller:repos').activate()
    @container.lookup('controller:application').connectLayout 'home'

Travis.StatsRoute = Ember.Route.extend
  renderTemplate: ->
    $('body').attr('id', 'stats')

    @render 'top', outlet: 'top'
    @render 'stats'

  setupController: ->
    @container.lookup('controller:application').connectLayout('simple')

Travis.NotFoundRoute = Ember.Route.extend
  renderTemplate: ->
    $('body').attr('id', 'not-found')

    @render 'top', outlet: 'top'
    @render 'not_found'

  setupController: ->
    @container.lookup('controller:application').connectLayout('simple')

Travis.ProfileRoute = Ember.Route.extend
  needsAuth: true

  setupController: ->
    @container.lookup('controller:application').connectLayout('profile')
    @container.lookup('controller:accounts').set('content', Travis.Account.find())

  renderTemplate: ->
    $('body').attr('id', 'profile')

    @render 'top', outlet: 'top'
    @render 'accounts', outlet: 'left'
    @render 'profile'

Travis.ProfileIndexRoute = Ember.Route.extend
  setupController: ->
    @container.lookup('controller:profile').activate 'hooks'

  renderTemplate: ->
    @render 'hooks', outlet: 'pane', into: 'profile', controller: 'profile'

Travis.AccountRoute = Ember.Route.extend
  setupController: (controller, account) ->
    profileController = @container.lookup('controller:profile')
    profileController.activate 'hooks'

    if account
      params = { login: account.get('login') }
      profileController.setParams(params)

  deserialize: (params) ->
    controller = @container.lookup('controller:accounts')
    account = controller.findByLogin(params.login)

    if account
      account
    else
      content = Ember.Object.create(login: params.login)
      proxy = Ember.ObjectProxy.create(content: content)

      observer = ->
        if account = controller.findByLogin(params.login)
          controller.removeObserver 'content.length', observer
          proxy.set('content', account)
      controller.addObserver 'content.length', observer

      proxy

  serialize: (account) ->
    if account
      { login: account.get('login') }
    else
      {}

Travis.AccountIndexRoute = Ember.Route.extend
  setupController: ->
    @container.lookup('controller:profile').activate 'hooks'

  renderTemplate: ->
    @render 'hooks', outlet: 'pane', into: 'profile'

Travis.AccountProfileRoute = Ember.Route.extend
  setupController: ->
    @container.lookup('controller:profile').activate 'user'

  renderTemplate: ->
    @render 'user', outlet: 'pane', into: 'profile'

Travis.AuthRoute = Ember.Route.extend
  renderTemplate: ->
    $('body').attr('id', 'auth')

    @render 'top', outlet: 'top'
    @render 'auth.signin'

  setupController: ->
    @container.lookup('controller:application').connectLayout('simple')
