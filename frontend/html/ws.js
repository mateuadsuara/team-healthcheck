class WS {
  constructor(options) {
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
    this.listeners = {
      tick: [],
      receive: [],
      disconnect: [],
      reconnect: [],
      error: []
    }
  }

  connect() {
    return this._connect(this.options.retries)
  }

  send(data) {
    this.socket.send(JSON.stringify(data))
  }

  onTick(fn) {
    this.listeners.tick.push(fn)
  }

  onReceive(fn) {
    this.listeners.receive.push(fn)
  }

  onDisconnect(fn) {
    this.listeners.disconnect.push(fn)
  }

  onReconnect(fn) {
    this.listeners.reconnect.push(fn)
  }

  onError(fn) {
    this.listeners.error.push(fn)
  }

  _dispatch(listeners, arg) {
    listeners.forEach((listener) => {
      try {
        listener(arg)
      } catch(e) {
        console.error(e)
      }
    })
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
          that._dispatch(that.listeners.receive, data)
        }
      })
      that.socket.addEventListener("close", () => {
        that._dispatch(that.listeners.disconnect)
        that.connect().then(() => {
          that._dispatch(that.listeners.reconnect)
        }).catch(() => {
          that._dispatch(that.listeners.error)
        })
      })
      const pingStrategy = that._attachPingStrategy(socket, options.pingInterval)
      pingStrategy.addEventListener("tick", (event) => {
        that._dispatch(that.listeners.tick, event.detail)
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

    const tick = (info) => {
      eventTarget.dispatchEvent(new CustomEvent("tick", {
        detail: info
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
