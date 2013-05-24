require 'travis/model'

@Travis.Hook = Travis.Model.extend
  name:        Ember.attr('string')
  ownerName:   Ember.attr('string')
  description: Ember.attr('string')
  active:      Ember.attr('boolean')

  account: (->
    @get('slug').split('/')[0]
  ).property('slug')

  slug: (->
    "#{@get('ownerName')}/#{@get('name')}"
  ).property('ownerName', 'name')

  urlGithub: (->
    "http://github.com/#{@get('slug')}"
  ).property()

  urlGithubAdmin: (->
    "http://github.com/#{@get('slug')}/settings/hooks#travis_minibucket"
  ).property()

  toggle: ->
    return if @get('isSaving')
    transaction = @get('store').transaction()
    transaction.add this

    @set 'active', !@get('active')

    transaction.commit()
