Adapter = Ember.RESTAdapter.extend
  ajax: (url, params, method) ->
    Travis.ajax.ajax(url, method || 'get', data: params)

unless window.TravisApplication
  window.TravisApplication = Em.Application.extend(Ember.Evented,
    authStateBinding: 'auth.state'
    signedIn: (-> @get('authState') == 'signed-in' ).property('authState')

    setup: ->
      modelClasses = [Travis.User, Travis.Build, Travis.Job, Travis.Repo, Travis.Commit, Travis.Worker, Travis.Account, Travis.Broadcast]
      modelClasses.forEach (klass) ->
        klass.adapter = Adapter.extend(
          findMany: (klass, records, ids) ->
            debugger
            console.log 'findMany', klass+'', records+'', ids

          mappings:
            broadcasts:   Travis.Broadcast
            repositories: Travis.Repo
            repository:   Travis.Repo
            repos:        Travis.Repo
            repo:         Travis.Repo
            builds:       Travis.Build
            build:        Travis.Build
            commits:      Travis.Commit
            commit:       Travis.Commit
            jobs:         Travis.Job
            job:          Travis.Job
            account:      Travis.Account
            accounts:     Travis.Account
            worker:       Travis.Worker
            workers:      Travis.Worker

          buildURL: ->
            @_super.apply(this, arguments).replace(/\.json$/, '')

          didFind: (record, id, data) ->
            @sideload(record.constructor, data)
            @_super(record, id, data)

          didFindAll: (klass, records, data) ->
            @sideload(klass, data)
            @_super(klass, records, data)

          didFindQuery: (klass, records, params, data) ->
            @sideload(klass, data)
            @_super(klass, records, params, data)

          didCreateRecord: (record, data) ->
            @sideload(record.constructor, data)
            @_super(record, data)

          didSaveRecord: (record, data) ->
            @sideload(record.constructor, data)
            @_super(record, data)

          didDeleteRecord: (record, data) ->
            @sideload(record.constructor, data)
            @_super(record, data)

          sideload: (klass, data) ->
            for name, records of data
              records = [records] unless Ember.isArray(records)

              # we need to skip records of type, which is loaded by adapter already
              if (type = @mappings[name]) != klass
                for record in records
                  type.findFromCacheOrLoad(record)
        ).create()

      Travis.User.url = '/users'
      Travis.Build.url = '/builds'
      Travis.Job.url = '/jobs'
      Travis.Repo.url = '/repos'
      Travis.Build.url = '/builds'


      Travis.SPONSORS.forEach (sponsor) ->
        Travis.Sponsor.findFromCacheOrLoad(sponsor)

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
