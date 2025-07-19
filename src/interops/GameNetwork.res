// GameNetwork.res
// PeerJS 네트워크 통신 모듈

module P = PeerJs

type conn = Js.Json.t // 실제 PeerJs 연결 객체는 외부 JS interop이므로 구체 타입 대신 Js.Json.t 사용
type peer = Js.Json.t

type event =
  | Rand(int)
  | Team(string, int)
  | PlayCard(int)
  | AnnounceWinner(string)
  | ReadyForNextRound
  | GameOver(string)
  | Other(Js.Json.t)

// Peer 생성
let makePeer = () => P.makePeerNew(Js.Obj.empty())

// 연결 요청
let connect = (peer, remoteId) => P.connect(peer, remoteId)

// 이벤트 등록
let onOpen = (peer, cb) => P.onOpen(peer, "open", cb)
let onError = (peer, cb) => P.onError(peer, "error", cb)
let onConnection = (peer, cb) => P.onConnection(peer, "connection", cb)
let onConnOpen = (conn, cb) => P.onConnOpen(conn, "open", cb)
let onConnError = (conn, cb) => P.onConnError(conn, "error", cb)

// 데이터 수신 핸들러
let onData = (conn, cb) =>
  P.onData(conn, "data", data => {
    switch Js.Json.decodeObject(data) {
    | Some(obj) =>
        switch Js.Dict.get(obj, "type") {
        | Some(Js.Json.String("rand")) =>
            switch Js.Dict.get(obj, "rand") {
            | Some(Js.Json.Number(n)) => cb(Rand(int_of_float(n)))
            | _ => ()
            }
        | Some(Js.Json.String("team")) =>
            let teamOpt = Js.Dict.get(obj, "team")
            let randOpt = Js.Dict.get(obj, "rand")
            switch (teamOpt, randOpt) {
            | (Some(Js.Json.String(team)), Some(Js.Json.Number(n))) => cb(Team(team, int_of_float(n)))
            | _ => ()
            }
        | Some(Js.Json.String("playCard")) =>
            switch Js.Dict.get(obj, "card") {
            | Some(Js.Json.Number(n)) => cb(PlayCard(int_of_float(n)))
            | _ => ()
            }
        | Some(Js.Json.String("announceWinner")) =>
            switch Js.Dict.get(obj, "winner") {
            | Some(Js.Json.String(s)) => cb(AnnounceWinner(s))
            | _ => ()
            }
        | Some(Js.Json.String("readyForNextRound")) =>
            cb(ReadyForNextRound)
        | Some(Js.Json.String("gameOver")) =>
            switch Js.Dict.get(obj, "winner") {
            | Some(Js.Json.String(s)) => cb(GameOver(s))
            | _ => ()
            }
        | _ => cb(Other(data))
        }
    | None => cb(Other(data))
    }
  })

// 데이터 전송
let sendRand = (conn, rand) => {
  let obj = Js.Dict.empty()
  Js.Dict.set(obj, "type", Js.Json.string("rand"))
  Js.Dict.set(obj, "rand", Js.Json.number(float_of_int(rand)))
  P.send(conn, Js.Json.object_(obj))
}

let sendTeam = (conn, team, rand) => {
  let obj = Js.Dict.empty()
  Js.Dict.set(obj, "type", Js.Json.string("team"))
  Js.Dict.set(obj, "team", Js.Json.string(team))
  Js.Dict.set(obj, "rand", Js.Json.number(float_of_int(rand)))
  P.send(conn, Js.Json.object_(obj))
}

let sendPlayCard = (conn, card) => {
  let obj = Js.Dict.empty()
  Js.Dict.set(obj, "type", Js.Json.string("playCard"))
  Js.Dict.set(obj, "card", Js.Json.number(float_of_int(card)))
  P.send(conn, Js.Json.object_(obj))
}

let sendAnnounceWinner = (conn, winner) => {
  let obj = Js.Dict.empty()
  Js.Dict.set(obj, "type", Js.Json.string("announceWinner"))
  Js.Dict.set(obj, "winner", Js.Json.string(winner))
  P.send(conn, Js.Json.object_(obj))
}

let sendReadyForNextRound = conn => {
  let obj = Js.Dict.empty()
  Js.Dict.set(obj, "type", Js.Json.string("readyForNextRound"))
  P.send(conn, Js.Json.object_(obj))
}

let sendGameOver = (conn, winner) => {
  let obj = Js.Dict.empty()
  Js.Dict.set(obj, "type", Js.Json.string("gameOver"))
  Js.Dict.set(obj, "winner", Js.Json.string(winner))
  P.send(conn, Js.Json.object_(obj))
}
