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

  // Game start UI
  if !gameStarted {
    <div className="flex flex-col items-center p-4">
      <button
        className="m-2 px-4 py-2 bg-blue-500 text-white rounded"
        onClick={_ => { setPlayerColor((_) => "blue"); setGameStarted((_) => true) }}>
        {React.string("Play as Blue")}
      </button>
      <button
        className="m-2 px-4 py-2 bg-red-500 text-white rounded"
        onClick={_ => { setPlayerColor((_) => "red"); setGameStarted((_) => true) }}>
        {React.string("Play as Red")}
      </button>
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