// PeerJs.res
// Basic PeerJS bindings for ReScript

// Types
// Abstract types for Peer and DataConnection
// These are opaque to ReScript, but you can use them via FFI

type peer

type dataConnection

@module("peerjs")
@new external makePeerNew: Js.t<{}> => peer = "default"
@module("peerjs")
@new external makePeerWithIdNew: (string, Js.t<{}>) => peer = "default"

// Connect to another peer
@send external connect: (peer, string) => dataConnection = "connect"

// Send data over a connection
external send: (dataConnection, 'a) => unit = "send"

// Event listeners
// Use correct callback signatures for PeerJS events
@send external onOpen: (peer, string, string => unit) => unit = "on"
@send external onConnection: (peer, string, dataConnection => unit) => unit = "on"
@send external onError: (peer, string, Js.Json.t => unit) => unit = "on"
// Event listeners for dataConnection
@send external onConnOpen: (dataConnection, string, unit => unit) => unit = "on"
@send external onConnError: (dataConnection, string, Js.Json.t => unit) => unit = "on"
@send external onData: (dataConnection, string, 'a => unit) => unit = "on"
@send external onClose: (dataConnection, string, unit => unit) => unit = "on"

// For module open/import compatibility
module PeerJs = {
  type t = peer
  type dataConnection = dataConnection
  let makePeerNew = makePeerNew
  let makePeerWithIdNew = makePeerWithIdNew
  let connect = connect
  let send = send
  let onOpen = onOpen
  let onConnection = onConnection
  let onData = onData
  let onClose = onClose
  let onError = onError
  let onConnOpen = onConnOpen
  let onConnError = onConnError
}
