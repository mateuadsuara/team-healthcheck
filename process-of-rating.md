create metrics
* for each:
  * name
  * criteria

register point-of-view
* person giving the point-of-view
* date
* health point-of-view(:shrug: | good/green..mediocre/yellow..bad/red encoded as 1..0..-1)
  - why? :shrug: | reason
* slope point-of-view(:shrug: | bettering/climbing..unchanging/flat..worsening/falling encoded as 1..0..-1)
  - why? :shrug: | reason

- can only see other points-of-view after registering own, to not get influenced by others
- want to give two answers?, then create metrics to represent the new criteria for the two answers

graph points-of-view
- if points-of-view are too different
  - misunderstood criteria?, then create metrics with refined criteria consensus
  - different perspectives on the same criteria?, they are all valid points of view!, maybe register again to add details
- see evolution of metrics

METRIC OPERATIONS TO IMPLEMENT:

* graph -> [metric{[pov{date, point-of-view, health{rating, reason}, slope{rating, reason}}] - SUBSCRIBED TO UPDATES
* create (name, criteria) - PUBLISH UPDATES TO (graph)
* register (date, point-of-view, health{maybe-rating, maybe-reason}, slope{maybe-rating, maybe-reason}) - PUBLISH UPDATES TO (graph)

MAYBE IN THE FUTURE:

link refined metrics to the metrics that inspired it (e.g: when wanting to split a metric into two)

* disable metric
* re-enable metric

team consensus about situation
* root cause of the problem
* plan of improvement(None | keep doing what you're doing | do something else)

many teams and compare them
