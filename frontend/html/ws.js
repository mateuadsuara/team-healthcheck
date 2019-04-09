class WS extends EventTarget {
  static get TICK() { return "tick" }
  static get RECEIVE() { return "receive" }
  static get DISCONNECT() { return "disconnect" }
  static get RECONNECT() { return "reconnect" }
  static get ERROR() { return "error" }

  constructor(options) {
    super()

    options = options || {}
    options.host = options.host || window.location.host
    options.pathname = options.pathname || '/websocket'
    options.protocol = options.protocol || window.location.protocol === 'https:' ? 'wss:' : 'ws:'
    options.retries = options.retries || 60
    options.retryDelay = options.retryDelay || 1000
    options.timeout = options.timeout || 5000
    options.pingInterval = options.pingInterval || 25000
    this.options = options

    this.socket = undefined
  }

  connect() {
    return this._connect(this.options.retries)
  }

  send(data) {
    this.socket.send(JSON.stringify(data))
  }

  _connect(retriesLeft) {
    const that = this

    const options = that.options
    const uri = `${options.protocol}//${options.host}${options.pathname}`

    return that._openSocket(uri, options.timeout).then((socket) => {
      that.socket = socket
      that.socket.addEventListener("message", (event) => {
        const data = JSON.parse(event.data)
        if (!('pong' in data)) {
          that.dispatchEvent(new CustomEvent(WS.RECEIVE, {detail: data}))
        }
      })
      that.socket.addEventListener("close", () => {
        that.dispatchEvent(new CustomEvent(WS.DISCONNECT))
        that.connect().then(() => {
          that.dispatchEvent(new CustomEvent(WS.RECONNECT))
        }).catch(() => {
          that.dispatchEvent(new CustomEvent(WS.ERROR))
        })
      })
      const pingStrategy = that._attachPingStrategy(socket, options.pingInterval)
      pingStrategy.addEventListener("tick", (event) => {
        that.dispatchEvent(new CustomEvent(WS.TICK, {detail: event.detail}))
      })
      return that
    }).catch((error) => {
      if (retriesLeft === 0) {
        throw error
      } else {
        return new Promise((resolve, reject) => {
          setTimeout(() => {
            that._connect(retriesLeft -1).then(resolve, reject)
          }, options.retryDelay)
        })
      }
    })
  }

  _openSocket(path, timeout) {
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

  _attachPingStrategy(socket, interval) {
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
}
