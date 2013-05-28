require 'travis/model'

@Travis.Job = Travis.Model.extend Travis.DurationCalculations,
  repoId:         Ember.attr('number')
  buildId:        Ember.attr('number')
  commitId:       Ember.attr('number')
  logId:          Ember.attr('number')

  queue:          Ember.attr('string')
  state:          Ember.attr('string')
  number:         Ember.attr('string')
  startedAt:      Ember.attr('string')
  finishedAt:     Ember.attr('string')
  allowFailure:   Ember.attr('boolean')

  repositorySlug: Ember.attr('string')
  repo:   Ember.belongsTo('Travis.Repo', key: 'repositoryId')
  build:  Ember.belongsTo('Travis.Build')
  commit: Ember.belongsTo('Travis.Commit')

  _config: Ember.attr('object')

  #repoSlugDidChange: (->
  #  if slug = @get('repoSlug')
  #    @get('store').loadIncomplete(Travis.Repo, {
  #      id: @get('repoId'),
  #      slug: slug
  #    }, { skipIfExists: true })
  #).observes('repoSlug')

  log: ( ->
    @set('isLogAccessed', true)
    Travis.Log.create(job: this)
  ).property()

  repoSlug: (->
    @get('repositorySlug')
  ).property('repositorySlug')

  config: (->
    Travis.Helpers.compact(@get('_config'))
  ).property('_config')

  isFinished: (->
    @get('state') in ['passed', 'failed', 'errored', 'canceled']
  ).property('state')

  clearLog: ->
    # This is needed if we don't want to fetch log just to clear it
    if @get('isLogAccessed')
      @get('log').clear()

  sponsor: (->
    {
      name: "Blue Box"
      url: "http://bluebox.net"
    }
  ).property()

  configValues: (->
    config = @get('config')
    keys   = @get('build.rawConfigKeys')

    if config && keys
      keys.map (key) -> config[key]
    else
      []
  ).property('config', 'build.rawConfigKeys.length')

  canCancel: (->
    @get('state') == 'created' || @get('state') == 'queued' # TODO
  ).property('state')

  cancel: (->
    Travis.ajax.post "/jobs/#{@get('id')}", _method: 'delete'
  )

  requeue: ->
    Travis.ajax.post '/requests', job_id: @get('id')

  appendLog: (part) ->
    @get('log').append part

  subscribe: ->
    return if @get('subscribed')
    @set('subscribed', true)
    if Travis.pusher
      Travis.pusher.subscribe "job-#{@get('id')}"

  unsubscribe: ->
    return unless @get('subscribed')
    @set('subscribed', false)
    if Travis.pusher
      Travis.pusher.unsubscribe "job-#{@get('id')}"

  onStateChange: (->
    if @get('state') == 'finished' && Travis.pusher
      Travis.pusher.unsubscribe "job-#{@get('id')}"
  ).observes('state')

  isAttributeLoaded: (key) ->
    if ['finishedAt'].contains(key) && !@get('isFinished')
      return true
    else if key == 'startedAt' && @get('state') == 'created'
      return true
    else
      @_super(key)

  isFinished: (->
    @get('state') in ['passed', 'failed', 'errored', 'canceled']
  ).property('state')

@Travis.Job.reopenClass
  queued: (queue) ->
    @find()
    Ember.FilteredRecordArray.create(
      modelClass: Travis.Job
      filterFunction: (job) ->
        queued = ['created', 'queued'].indexOf(job.get('state')) != -1
        # TODO: why queue is sometimes just common instead of build.common?
        queued && (!queue || job.get('queue') == "builds.#{queue}" || job.get('queue') == queue)

      filterProperties: ['state', 'queue']
    )

  running: ->
    @find(state: 'started')
    Ember.FilteredRecordArray.create(
      modelClass: Travis.Job
      filterFunction: (job) ->
        job.get('state') == 'started'
      filterProperties: ['state']
    )


