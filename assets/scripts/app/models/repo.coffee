require 'travis/expandable_record_array'
require 'travis/model'

@Travis.Repo = Travis.Model.extend
  slug:                Ember.attr('string')
  description:         Ember.attr('string')
  lastBuildId:         Ember.attr('number')
  lastBuildNumber:     Ember.attr('string')
  lastBuildState:      Ember.attr('string')
  lastBuildStartedAt:  Ember.attr('string')
  lastBuildFinishedAt: Ember.attr('string')
  _lastBuildDuration:  Ember.attr('number')

#  lastBuild: DS.belongsTo('Travis.Build')

  lastBuildHash: (->
    {
      id: @get('lastBuildId')
      number: @get('lastBuildNumber')
      repo: this
    }
  ).property('lastBuildId', 'lastBuildNumber')

  allBuilds: (->
    Travis.Build.find()
  ).property()

  builds: (->
    id = @get('id')
    builds = Travis.Build.byRepoId id, event_type: 'push'

    # TODO: move to controller
    array  = Travis.ExpandableRecordArray.create
      type: Travis.Build
      content: Ember.A([])
      store: @get('store')

    array.load(builds)

    id = @get('id')
    array.observe(@get('allBuilds'), (build) -> build.get('isLoaded') && build.get('eventType') && build.get('repo.id') == id && !build.get('isPullRequest') )

    array
  ).property()

  pullRequests: (->
    id = @get('id')
    builds = Travis.Build.byRepoId id, event_type: 'pull_request'
    array  = Travis.ExpandableRecordArray.create
      type: Travis.Build
      content: Ember.A([])
      store: @get('store')

    array.load(builds)

    id = @get('id')
    array.observe(@get('allBuilds'), (build) -> build.get('isLoaded') && build.get('eventType') && build.get('repo.id') == id && build.get('isPullRequest') )

    array
  ).property()

  branches: (->
    Travis.Build.branches repoId: @get('id')
  ).property()

  events: (->
    Travis.Event.byRepoId @get('id')
  ).property()

  owner: (->
    (@get('slug') || '').split('/')[0]
  ).property('slug')

  name: (->
    (@get('slug') || '').split('/')[1]
  ).property('slug')

  lastBuildDuration: (->
    duration = @get('_lastBuildDuration')
    duration = Travis.Helpers.durationFrom(@get('lastBuildStartedAt'), @get('lastBuildFinishedAt')) unless duration
    duration
  ).property('_lastBuildDuration', 'lastBuildStartedAt', 'lastBuildFinishedAt')

  sortOrder: (->
    # cuz sortAscending seems buggy when set to false
    if lastBuildFinishedAt = @get('lastBuildFinishedAt')
      - new Date(lastBuildFinishedAt).getTime()
    else
      - new Date('9999').getTime() - parseInt(@get('lastBuildId'))
  ).property('lastBuildFinishedAt', 'lastBuildId')

  stats: (->
    if @get('slug')
      @get('_stats') || $.get("https://api.github.com/repos/#{@get('slug')}", (data) =>
        @set('_stats', data)
        @notifyPropertyChange 'stats'
      ) && {}
  ).property('slug')

  updateTimes: ->
    @notifyPropertyChange 'lastBuildDuration'

  regenerateKey: (options) ->
    Travis.ajax.ajax '/repos/' + @get('id') + '/key', 'post', options

@Travis.Repo.reopenClass
  recent: ->
    @find()

  ownedBy: (login) ->
    @find(owner_name: login, orderBy: 'name')

  accessibleBy: (login) ->
    @find(member: login, orderBy: 'name')

  search: (query) ->
    @find(search: query, orderBy: 'name')

  withLastBuild: ->
    Ember.FilteredRecordArray.create(
      modelClass: Travis.Repo
      filterFunction: (repo) -> console.log(repo+'', repo.get('lastBuildId')); repo.get('lastBuildId')
      # (!repo.get('incomplete') || repo.isAttributeLoaded('lastBuildId'))
      filterProperties: ['lastBuildId']
    )

  bySlug: (slug) ->
    repo = $.select(@find().toArray(), (repo) -> repo.get('slug') == slug)
    if repo.length > 0 then repo else @find(slug: slug)

  # buildURL: (slug) ->
  #   if slug then slug else 'repos'


