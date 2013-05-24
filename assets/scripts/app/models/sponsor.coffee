require 'travis/model'

@Travis.Sponsor = Travis.Model.extend
  type:  Ember.attr('string')
  url:   Ember.attr('string')
  link:  Ember.attr('string')
  _image: Ember.attr('string')

  image: (->
    "/images/sponsors/#{@get('_image')}"
  ).property('_image')

Travis.Sponsor.reopenClass
  decks: ->
    @platinum().concat @gold()

  platinum: ->
    platinum = @byType('platinum').toArray()
    [sponsor] for sponsor in platinum

  gold: ->
    gold = @byType('gold').toArray()
    gold.splice(0, 2) while gold.length > 0

  links: ->
    @byType('silver')

  byType: ->
    types = Array.prototype.slice.apply(arguments)
    Travis.Sponsor.filter (sponsor) -> types.indexOf(sponsor.get('type')) != -1

