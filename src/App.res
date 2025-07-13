@react.component
let make = () => {
  // 전체 카드 생성 및 상태 초기화
  let allCards = Belt.Array.makeBy(9, i => i + 1)
  let (hand, setHand) = React.useState(() => allCards)
  let (myBoard, setMyBoard) = React.useState(() => Belt.Array.make(9, None))
  let (currentRound, setCurrentRound) = React.useState(() => 0)
  // 상대 opponent state
  let (oppBoard, setOppBoard) = React.useState(() => Belt.Array.make(9, None))
  let (waiting, setWaiting) = React.useState(() => false)
  // opponent hand state for unknown cards
  let (oppHand, setOppHand) = React.useState(() => allCards)

  // opponent card counts (white=odd, black=even)
  let oppWhiteCount = Belt.Array.length(Belt.Array.keep(oppHand, c => (mod(c, 2)) == 1))
  let oppBlackCount = Belt.Array.length(Belt.Array.keep(oppHand, c => (mod(c, 2)) == 0))

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
        setOppBoard(prev => {
          let newBoard = Belt.Array.copy(prev)
          ignore(Belt.Array.set(newBoard, roundIndex, Some(n)))
          newBoard
        })
        // remove card from opponent hand
        setOppHand(prev => Belt.Array.keep(prev, c => c != n))
        setWaiting((_) => false)
      }, 3000))
    | _ => ()
    }
  }

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
        Belt.Array.mapWithIndex(oppBoard, (i, cardOpt) =>
          <BoardSlot
            round=(i + 1)
            card=cardOpt
            // invert each slot (and its number) for opponent view
            className="transform rotate-180"
            key={"opp-" ++ string_of_int(i)}
          />
        )
      )}
    </section>
    {waiting ?
      <div className="my-2">{React.string("Waiting for opponent...")}</div>
    :
      React.null
    }
    // my board slots
    <section className="flex flex-row mb-6">
      {React.array(
        Belt.Array.mapWithIndex(myBoard, (i, cardOpt) =>
          <BoardSlot
            round=(i + 1)
            card=cardOpt
            className={if i == currentRound { "ring-4 ring-blue-400" } else { "" }}
            key={string_of_int(i)}
          />
        )
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
            key={Js.Int.toString(n)}
          />
        )
      )}
    </section>
  </main>
}