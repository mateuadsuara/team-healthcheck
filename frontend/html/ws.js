class WS {
  constructor(options) {
    options = options || {}
    options.host = options.host || window.location.host
    options.pathname = options.pathname || '/websocket'
    options.protocol = options.protocol || window.location.protocol === 'https:' ? 'wss:' : 'ws:'
    options.retries = options.retries || 60
    options.retryDelay = options.retryDelay || 1000
    options.timeout = options.timeout || 5000
    options.pingInterval = options.pingInterval || 50000
    this.options = options

    this.socket = undefined
  }

  connect() {
    return this._connect(this.options.retries)
  }

  _connect(retriesLeft) {
    const that = this

    const options = that.options
    const uri = `${options.protocol}//${options.host}${options.pathname}`

    return openSocket(uri, options.timeout).then((socket) => {
      that.socket = socket
      that.socket.addEventListener("message", (event) => {
        console.log(event)
      })
      that.socket.addEventListener("close", () => {
        console.log("Websocket closed!")
        that._connect(0).then(() => {
          console.log("Websocket reconnected immediately!")
        }).catch(() => {
          that._connect(that.options.retries -1).then(() => {
            console.log("Websocket reconnected with trouble!")
          }).catch(() => {
            console.log("Websocket FATAL!")
          })
        })
      })
      const pingStrategy = attachPingStrategy(socket, options.pingInterval)
      pingStrategy.addEventListener("tick", (event) => {
        console.log(event.detail)
      })
      return that
    }).catch((error) => {
      if (retriesLeft === 0) {
        console.log("Failed connecting to websocket!")
        throw error
      } else {
        return new Promise((resolve, reject) => {
          const delay = options.retryDelay
          console.log(`Failed connecting to websocket! retrying in ${delay} milliseconds (${retriesLeft} retries left)`)
          setTimeout(() => {
            that._connect(retriesLeft -1).then(resolve, reject)
          }, delay)
        })
      }
    })
  }

  send(payload) {
    this.socket.send(payload)
  }
}

function attachPingStrategy(socket, interval) {
  const eventTarget = new EventTarget()

  const tick = (data) => {
    eventTarget.dispatchEvent(new CustomEvent("tick", {
      detail: data
    }))
  }

  var ping
  ping = () => {
    if (socket.readyState !== WebSocket.OPEN) {
      return
    }

    const startTime = new Date().getTime()
    const id = startTime

    var pingTimeout

    const pongListener = (event) => {
      const data = JSON.parse(event.data)
      if (data.pong === id) {
        clearTimeout(pingTimeout)
        socket.removeEventListener("message", pongListener)
        const endTime = new Date().getTime()
        const latency = endTime - startTime
        tick({
          ping: startTime,
          pong: endTime,
          latency: latency,
          interval: interval
        })
        setTimeout(ping, interval - latency)
      }
    }
    socket.addEventListener("message", pongListener)

    socket.send(JSON.stringify({ping: id}))

    pingTimeout = setTimeout(() => {
      socket.removeEventListener("message", pongListener)
      const endTime = new Date().getTime()
      tick({
        ping: startTime,
        timeout: endTime,
        interval: interval
      })
      ping()
    }, interval)
  }
  ping()

  return eventTarget
}

function openSocket(path, timeout) {
  return new Promise((resolve, reject) => {
    const socket = new WebSocket(path)

    var readyIntervalCheckId

    const connectionTimeoutId = setTimeout(() => {
      clearInterval(readyIntervalCheckId)
      reject(new Error("Connection timeout"))
    }, timeout)

    readyIntervalCheckId = setInterval(() => {
      if (socket.readyState === WebSocket.OPEN) {
        clearTimeout(connectionTimeoutId)
        clearInterval(readyIntervalCheckId)
        resolve(socket)
      } else if (socket.readyState !== WebSocket.CONNECTING) {
        clearTimeout(connectionTimeoutId)
        clearInterval(readyIntervalCheckId)
        reject(new Error("The socket got into an unexpected state: " + socket.readyState))
      }
    }, 10)
  })
}

