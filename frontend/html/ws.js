class WS {
  constructor() {
    this.socket = undefined
  }

  connect(options) {
    options = options || {}
    options.host = options.host || window.location.host
    options.pathname = options.pathname || '/ws'
    options.timeout = options.timeout || 5000
    options.pingInterval = options.pingInterval || 10000
    const uri = `ws://${options.host}${options.pathname}`

    const that = this

    return openSocket(uri, options.timeout).then((socket) => {
      that.socket = socket
      that.socket.addEventListener("message", (event) => {
        console.log(event)
      })
      that.socket.addEventListener("close", () => {
        console.log("CLOSE")
      })
      return attachPingStrategy(socket, options.pingInterval)
        .then((pingEvents) => that)
    })
  }

  send(payload) {
    this.socket.send(payload)
  }
}

function attachPingStrategy(socket, interval) {
  return new Promise((resolve, reject) => {
    if (socket.readyState !== WebSocket.OPEN) {
      reject(new Error("Socket is not open"))
    } else {
      const eventTarget = new EventTarget()

      var ping
      ping = () => {
        if (socket.readyState !== WebSocket.OPEN) {
          return
        }

        const startTime = new Date().getTime()
        const id = startTime
        var pongListener, pingTimeout

        pongListener = (event) => {
          const data = JSON.parse(event.data)
          if (data.pong === id) {
            clearTimeout(pingTimeout)
            const endTime = new Date().getTime()
            const latency = endTime - startTime
            const pongEvent = new Event("pong")
            pongEvent.data = {
              ping: startTime,
              pong: endTime,
              latency: latency,
              interval: interval
            }
            eventTarget.dispatchEvent(pongEvent)
            setTimeout(ping, interval - latency)
          }
        }
        socket.addEventListener("message", pongListener)

        socket.send(JSON.stringify({ping: id}))

        pingTimeout = setTimeout(() => {
          socket.removeEventListener("message", pongListener)
          const endTime = new Date().getTime()
          const timeoutEvent = new Event("timeout")
          timeoutEvent.data = {
            ping: startTime,
            timeout: endTime,
            interval: interval
          }
          eventTarget.dispatchEvent(timeoutEvent)
          ping()
        }, interval)
      }
      ping()

      resolve(eventTarget)
    }
  })
}

function openSocket(path, timeout) {
  return new Promise((resolve, reject) => {
    const socket = new WebSocket(path)

    var connectionTimeoutId, readyIntervalCheckId
    connectionTimeoutId = setTimeout(() => {
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
    }, 0)
  })
}

