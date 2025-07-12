@react.component
let make = () => {
  // 전체 카드 생성 및 상태 초기화
  let allCards = Belt.Array.makeBy(9, i => i + 1)
  let (hand, setHand) = React.useState(() => allCards)
  let (myBoard, setMyBoard) = React.useState(() => Belt.Array.make(9, None))
  let (currentRound, setCurrentRound) = React.useState(() => 0)

  // 카드 클릭 핸들러
  let onCardClick = n => {
    switch Belt.Array.get(myBoard, currentRound) {
    | Some(None) =>
      // update board immutably via functional setter
      setMyBoard(prevBoard => {
        let newBoard = Belt.Array.copy(prevBoard)
        ignore(Belt.Array.set(newBoard, currentRound, Some(n)))
        newBoard
      })
      // update hand
      setHand(prevHand => Belt.Array.keep(prevHand, c => c != n))
      // advance round
      setCurrentRound(prevRound => prevRound + 1)
    | _ => ()
    }
  }

  <main className="flex flex-col items-center p-4">
    // 보드 슬롯 (윗면)
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

    // 내 패 (아랫면)
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