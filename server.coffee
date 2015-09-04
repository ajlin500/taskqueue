TaskQueue = new Mongo.Collection 'taskQueue'

TaskQueueSchema = new SimpleSchema
  tasks:
    type: [Object]
  'tasks.$.meteorMethod':
    type: String
  'tasks.$.params':
    type: Object
    blackbox: true
    defaultValue: {}
  'tasks.$.response':
    type: Object
    blackbox: true
    optional: true
  tryAgain:
    type: Date
    optional: true
  canceled:
    type: Boolean
    defaultValue: false
  completed:
    type: Boolean
    defaultValue: false
  createdAt:
    type: Date
    autoValue: ->
      # Insert only
      if @isInsert
        return new Date
      else if @isUpsert
        return {$setOnInsert: new Date}
      else
        @unset()

TaskQueue.attachSchema TaskQueueSchema

processTaskQueue = (doc) ->
  # If tryAgain date is in the future reschedule
  if doc.tryAgain > new Date
    recheduleTaskQueue doc, doc.tryAgain
    return

  # Run tasks in task queue
  for task, index in doc.tasks
    # Skip tasks that have already completed
    if task.response is not undefined then continue

    try
      # Call task method with params and previous response
      previousResponse = doc.tasks[index - 1]?.response
      response = Meteor.call task.meteorMethod, task.params, previousResponse

      # Save response for next task
      # If no response, save blank object
      task.response = response or {}
      TaskQueue.update
        _id: doc._id
      ,
        $set:
          tasks: doc.tasks
      ,
        validate: false

    catch error
      tryAgain = Meteor.call 'taskQueue.getTryAgain', task, error
      isDate = Match.test tryAgain, Date
      if isDate
        console.log "Task Failed: Trying again in #{tryAgain.getTime()}"
        # Set try again time
        TaskQueue.update
          _id: doc._id
        ,
          $set:
            tryAgain: tryAgain
        ,
          validate: false

        # Reschedule task to try again later
        recheduleTaskQueue doc, tryAgain
        return
      else
        # Cancel task queue
        TaskQueue.update
          _id: doc._id
        ,
          $set:
            canceled: true
        ,
          validate: false
        throw new Meteor.Error 'taskQueue-canceled', \
          'taskQuere failed to return valid tryAgain date'

  # Mark taskQueue as complete
  TaskQueue.update
    _id: doc._id
  ,
    completed: true

recheduleTaskQueue = (doc, tryAgain) ->
  # Convert dates to milliseconds
  now = new Date().getTime()
  tryAgain = tryAgain.getTime()

  timeDifference = tryAgain - now

  Meteor.setTimeout ->
    processTaskQueue doc
  , timeDifference


Meteor.startup ->
  # Watch for new tasks
  TaskQueue.find(
    completed: false
    canceled: false
  ).observe
    added: processTaskQueue