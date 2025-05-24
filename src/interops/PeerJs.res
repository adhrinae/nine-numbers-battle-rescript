// PeerJs.res
// Basic PeerJS bindings for ReScript

// Types
// Abstract types for Peer and DataConnection
// These are opaque to ReScript, but you can use them via FFI

type peer

type dataConnection

@module("peerjs")
external makePeer: Js.t<{}> => peer = "default"
external makePeerWithId: (string, Js.t<{}>) => peer = "default"

// Connect to another peer
external connect: (peer, string) => dataConnection = "connect"

// Send data over a connection
external send: (dataConnection, 'a) => unit = "send"

// Event listeners
// Use tuple for event name and callback, no attribute needed
external onOpen: (peer, (string, unit => unit)) => unit = "on"
external onConnection: (peer, (string, dataConnection => unit)) => unit = "on"
external onData: (dataConnection, (string, 'a => unit)) => unit = "on"
external onClose: (dataConnection, (string, unit => unit)) => unit = "on"
external onError: (peer, (string, Js.t<{}> => unit)) => unit = "on"

// Usage example (not included in output file):
// let peer = makePeer({})
// onOpen(peer, () => Js.log("Peer open!"))
// let conn = connect(peer, "other-peer-id")
// send(conn, "Hello!")
// onData(conn, data => Js.log(data))
