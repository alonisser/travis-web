Travis.reopen
  SidebarController: Em.ArrayController.extend
    needs: ['runningJobs']
    jobsBinding: 'controllers.runningJobs'

    init: ->
      @_super.apply this, arguments
      #      @tickables = []
      #Travis.Ticker.create(target: this, interval: Travis.INTERVALS.sponsors)

      #tick: ->
      # tickable.tick() for tickable in @tickables

  QueuesController: Em.ArrayController.extend
    init: ->
      @_super.apply this, arguments

      queues = for queue in Travis.QUEUES
        Travis.LimitedArray.create
          content: Travis.Job.queued(queue.name), limit: 20
          id: "queue_#{queue.name}"
          name: queue.display
      @set 'content', queues

    showAll: (queue) ->
      queue.showAll()

  WorkersController: Em.ArrayController.extend
    init: ->
      @_super.apply this, arguments
      @set 'content', Travis.Worker.find()

    groups: (->
      if content = @get 'arrangedContent'
        groups = {}
        for worker in content.toArray()
          host = worker.get('host')
          unless groups[host]
            groups[host] = Em.ArrayProxy.extend(Em.SortableMixin,
              content: [],
              sortProperties: ['nameForSort']
            ).create()
          groups[host].pushObject(worker)

        $.values(groups)
    ).property('length')

  SponsorsController: Em.ArrayController.extend
    page: 0

    arrangedContent: (->
      @get('shuffled').slice(@start(), @end())
    ).property('shuffled.length', 'page')

    shuffled: (->
      if content = @get('content') then $.shuffle(content) else []
    ).property('content.length')

    tick: ->
      @set('page', if @isLast() then 0 else @get('page') + 1)

    pages: (->
      length = @get('content.length')
      if length then parseInt(length / @get('perPage') + 1) else 1
    ).property('length')

    isLast: ->
      @get('page') == @get('pages') - 1

    start: ->
      @get('page') * @get('perPage')

    end: ->
      @start() + @get('perPage')

Travis.DecksController = Travis.SponsorsController.extend
  needs: ['sidebar']
  perPage: 1

  init: ->
    @_super.apply this, arguments

    #@get('controllers.sidebar').tickables.push(this)
    @set 'content', Travis.Sponsor.decks()

Travis.LinksController = Travis.SponsorsController.extend
  needs: ['sidebar']
  perPage: 6

  init: ->
    @_super.apply this, arguments

    #@get('controllers.sidebar').tickables.push(this)
    @set 'content', Travis.Sponsor.links()
