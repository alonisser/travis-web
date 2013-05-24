Adapter = Ember.RESTAdapter.extend
  ajax: (url, params, method) ->
    Travis.ajax.ajax(url, method || 'get', data: params)

unless window.TravisApplication
  window.TravisApplication = Em.Application.extend(Ember.Evented,
    LOG_TRANSITIONS: true
    authStateBinding: 'auth.state'
    signedIn: (-> @get('authState') == 'signed-in' ).property('authState')

    setup: ->
      modelClasses = [Travis.User, Travis.Build, Travis.Job, Travis.Repo]
      modelClasses.forEach (klass) ->
        klass.adapter = Adapter.create()

      Travis.User.url = '/users'
      Travis.Build.url = '/builds'
      Travis.Job.url = '/jobs'
      Travis.Repo.url = '/repos'
      Travis.Build.url = '/builds'

      # TODO: fix
      #@store.loadMany(Travis.Sponsor, Travis.SPONSORS)

      @slider = new Travis.Slider()
      @pusher = new Travis.Pusher(Travis.config.pusher_key) if Travis.config.pusher_key
      @tailing = new Travis.Tailing()

      @set('auth', Travis.Auth.create(app: this, endpoint: Travis.config.api_endpoint))

    reset: ->
      @_super.apply(this, arguments);
      @setup()

    lookup: ->
      @__container__.lookup.apply @__container__, arguments

    storeAfterSignInPath: (path) ->
      @get('auth').storeAfterSignInPath(path)

    autoSignIn: (path) ->
      @get('auth').autoSignIn()

    signIn: ->
      @get('auth').signIn()

    signOut: ->
      @get('auth').signOut()

    receive: ->
      # TODO: fix
      #@store.receive.apply(@store, arguments)

    toggleSidebar: ->
      $('body').toggleClass('maximized')
      # TODO gotta force redraws here :/
      element = $('<span></span>')
      $('#top .profile').append(element)
      Em.run.later (-> element.remove()), 10
      element = $('<span></span>')
      $('#repo').append(element)
      Em.run.later (-> element.remove()), 10

    setLocale: (locale) ->
      return unless locale
      I18n.locale = locale
      Travis.set('locale', locale)

    defaultLocale: 'en'

    ready: ->
      location.href = location.href.replace('#!/', '') if location.hash.slice(0, 2) == '#!'
      I18n.fallbacks = true
      @setLocale 'locale', @get('defaultLocale')

    currentDate: ->
      new Date()
  )
