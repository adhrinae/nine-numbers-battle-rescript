@react.component
let make = () => {
  // 전체 카드 생성 및 상태 초기화
  let allCards = Belt.Array.makeBy(9, i => i + 1)
  let (hand, setHand) = React.useState(() => allCards)
  let (myBoard, setMyBoard) = React.useState(() => Belt.Array.make(9, None))
  let (currentRound, setCurrentRound) = React.useState(() => 0)
  // 상대 opponent state
  let (oppBoard, setOppBoard) = React.useState(() => Belt.Array.make(9, None))
  let (oppHand, setOppHand) = React.useState(() => allCards)

  // game start and player colors
  let (gameStarted, setGameStarted) = React.useState(() => false)
  let (playerColor, setPlayerColor) = React.useState(() => "blue")
  let oppColor = if playerColor == "blue" { "red" } else { "blue" }

  let (waiting, setWaiting) = React.useState(() => false)
  let (lastResult, setLastResult) = React.useState(() => "")
  // track each round winner: "You win", "Opponent wins", "Tie"
  let (winners, setWinners) = React.useState(() => Belt.Array.make(9, None))

  // opponent card counts (white=odd, black=even)
  let oppWhiteCount =
    oppHand
    -> Belt.Array.keep(c => mod(c, 2) == 1)
    -> Belt.Array.length

  let oppBlackCount =
    oppHand
    -> Belt.Array.keep(c => mod(c, 2) == 0)
    -> Belt.Array.length

  // 카드 클릭 핸들러
  let onCardClick = n => {
    switch Belt.Array.get(myBoard, currentRound) {
    | Some(None) =>
      // 내가 보드에 카드 제출
      setMyBoard(prevBoard => {
        let newBoard = Belt.Array.copy(prevBoard)
        ignore(Belt.Array.set(newBoard, currentRound, Some(n)))
        newBoard
      })
      // update hand
      setHand(prevHand => Belt.Array.keep(prevHand, c => c != n))
      // advance round
      setCurrentRound(prevRound => prevRound + 1)
      // opponent 준비 메시지
      setWaiting((_) => true)
      let roundIndex = currentRound
      // 3초 후 opponent 보드에 같은 카드 추가
      ignore(Js.Global.setTimeout(() => {
        // opponent plays random card
        let oppMove = int_of_float(Js.Math.random() *. 9.0) + 1
        setOppBoard(prev => {
          let newBoard = Belt.Array.copy(prev)
          ignore(Belt.Array.set(newBoard, roundIndex, Some(oppMove)))
          newBoard
        })
        // remove card from opponent hand
        setOppHand(prev => Belt.Array.keep(prev, c => c != oppMove))
        // determine round result
        let winnerText =
          if n == oppMove {
            "Tie"
          } else if n == 1 && oppMove == 9 {
            // 1 beats 9
            "You win"
          } else if n == 9 && oppMove == 1 {
            // 9 loses to 1
            "Opponent wins"
          } else if n > oppMove {
            "You win"
          } else {
            "Opponent wins"
          }
        setLastResult((_) => winnerText)
        // record winner for this round
        setWinners(prev => {
          let newW = Belt.Array.copy(prev)
          ignore(Belt.Array.set(newW, roundIndex, Some(winnerText)))
          newW
        })
        setWaiting((_) => false)
      }, 3000))
    | _ => ()
    }
  }

  // PeerJS network setup
  module P = PeerJs
  let peer = React.useMemo0(() => P.makePeerNew(Js.Obj.empty()))
  let (localId, setLocalId) = React.useState(() => "")
  let (remoteIdInput, setRemoteIdInput) = React.useState(() => "")
  let (incomingConn, setIncomingConn) = React.useState(() => None)
  let (conn, setConn) = React.useState(() => None)
  let (connStatus, setConnStatus) = React.useState(() => "")
  let (role, setRole) = React.useState(() => "")

  React.useEffect0(() => {
    P.onOpen(peer, "open", id => setLocalId(_ => id))
    P.onError(peer, "error", err => setConnStatus(_ => "Error: " ++ Js.Json.stringify(err)))
    P.onConnection(peer, "connection", c => setIncomingConn(_ => Some(c)))
    None
  })

  // UI flow: select host/join, handle connection, then choose color, then game
  if role == "" {
    <div className="flex flex-col items-center p-4">
      <button className="m-2 px-4 py-2 bg-green-500 text-white rounded" onClick={_ => setRole(_ => "host")}>{React.string("새 게임 시작")}</button>
      <button className="m-2 px-4 py-2 bg-purple-500 text-white rounded" onClick={_ => setRole(_ => "join")}>{React.string("게임 참여")}</button>
    </div>
  } else if role == "host" && conn == None {
    <div className="flex flex-col items-center p-4">
      <div>{React.string("Your ID: " ++ localId)}</div>
      <div>{React.string("이 ID를 친구에게 공유하세요.")}</div>
      {switch incomingConn {
      | Some(c) =>
        <div className="mt-4">
          {React.string("Peer 연결 요청이 도착했습니다. 수락하시겠습니까?")}
          <button className="m-2 px-4 py-2 bg-blue-500 text-white rounded" onClick={_ => { setConn(_=>Some(c)); setConnStatus(_=>"Connected!"); }}>
            {React.string("예")}
          </button>
          <button className="m-2 px-4 py-2 bg-gray-300 rounded" onClick={_ => setIncomingConn(_=>None)}>
            {React.string("아니오")}
          </button>
        </div>
      | None => React.null
      }}
    </div>
  } else if role == "join" && conn == None {
    <div className="flex flex-col items-center p-4">
      <input className="border p-2" value=remoteIdInput onChange={e => { setRemoteIdInput(_ => {
        let target = ReactEvent.Form.target(e);
        let value = target["value"];
        value
      }) }} placeholder="방장 ID 입력" />
      <button className="m-2 px-4 py-2 bg-blue-500 text-white rounded" onClick={_ => {
        setConnStatus(_ => "연결 중...");
        let c = P.connect(peer, remoteIdInput);
        setConn(_ => Some(c));
        P.onConnOpen(c, "open", () => setConnStatus(_ => "Connected!"));
        P.onConnError(c, "error", err => setConnStatus(_ => "연결 실패: " ++ Js.Json.stringify(err)));
      }}>
        {React.string("연결")}
      </button>
      <div>{React.string(connStatus)}</div>
    </div>
  } else if conn == None {
    <div className="flex items-center p-4">{React.string("연결 상태: " ++ connStatus)}</div>
  } else if !gameStarted {
    // after successful connection, choose color
    <div className="flex flex-col items-center p-4">
      <button className="m-2 px-4 py-2 bg-blue-500 text-white rounded" onClick={_ => { setPlayerColor(_ => "blue"); setGameStarted(_ => true) }}>{React.string("Play as Blue")}</button>
      <button className="m-2 px-4 py-2 bg-red-500 text-white rounded" onClick={_ => { setPlayerColor(_ => "red"); setGameStarted(_ => true) }}>{React.string("Play as Red")}</button>
    </div>
  } else {
    <main className="flex flex-col items-center p-4">
      // opponent overview (hidden cards count)
      <section className="flex flex-row mb-2">
        <div className="mr-4">
          {React.string("Opponent: " ++ string_of_int(oppWhiteCount) ++ " white cards")}
        </div>
        <div>
          {React.string(string_of_int(oppBlackCount) ++ " black cards")}
        </div>
      </section>
      // opponent board slots (mirrored)
      <section className="flex flex-row mb-6">
        {React.array(
          Belt.Array.mapWithIndex(oppBoard, (i, cardOpt) => {
            let winnerBgOpp =
              switch Belt.Array.get(winners, i) {
              | Some(Some(w)) when w == "Opponent wins" => " bg-red-200"
              | Some(Some(w)) when w == "You win" => " bg-gray-200"
              | Some(Some(_)) => " bg-yellow-200"
              | _ => ""
              }
            <BoardSlot
              round=(i + 1)
              card=cardOpt
              className={"transform rotate-180" ++ winnerBgOpp}
              teamColor=oppColor
              key={"opp-" ++ string_of_int(i)}
            />
          })
        )}
      </section>
      {waiting ?
        <div className="my-2">{React.string("Waiting for opponent...")}</div>
      :
        React.null
      }
      {lastResult != "" ?
        <div className="my-2">{React.string("Result: " ++ lastResult)}</div>
      :
        React.null
      }
      // my board slots
      <section className="flex flex-row mb-6">
        {React.array(
          Belt.Array.mapWithIndex(myBoard, (i, cardOpt) => {
            let ringClass = if i == currentRound {
              if playerColor == "blue" { "ring-4 ring-blue-400" } else { "ring-4 ring-red-400" }
            } else { "" }
            let winnerBgMy =
              switch Belt.Array.get(winners, i) {
              | Some(Some(w)) when w == "You win" => " bg-green-200"
              | Some(Some(w)) when w == "Opponent wins" => " bg-gray-200"
              | Some(Some(_)) => " bg-yellow-200"
              | _ => ""
              }
            <BoardSlot
              round=(i + 1)
              card=cardOpt
              className={ringClass ++ winnerBgMy}
              teamColor=playerColor
              key={string_of_int(i)}
            />
          })
        )}
      </section>
      // my hand cards
      <section className="flex flex-row">
        {React.array(
          hand->Belt.Array.map(n =>
            <Card
              number=n
              onClick={() => onCardClick(n)}
              disabled=false
              selected=false
              teamColor=playerColor
              key={Js.Int.toString(n)}
            />
          )
        )}
      </section>
    </main>
  }
}