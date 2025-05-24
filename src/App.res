@react.component
let make = () => {
  // 1~9 패를 배열로 생성
  let myCards = Belt.Array.makeBy(9, i => i + 1)

  // (예시) 각 라운드에 내가 낸 카드 상태
  let (myBoard, setMyBoard) = React.useState(() => Belt.Array.make(9, None))

  <main className="flex flex-col items-center p-4">
    // 보드 슬롯 (윗면)
    <section className="flex flex-row mb-6">
      {React.array(
        Belt.Array.mapWithIndex(myBoard, (i, cardOpt) =>
          <BoardSlot round=(i + 1) card=cardOpt key={string_of_int(i)} />
        )
      )}
    </section>

    // 내 패 (아랫면)
    <section className="flex flex-row">
      {React.array(
        myCards->Belt.Array.map(n =>
          <Card
            number=n
            onClick={() => Js.log2("카드 선택:", n)}
            // 실제로는 선택/사용 여부로 비활성화 처리 필요
            key={Js.Int.toString(n)}
          />
        )
      )}
    </section>
  </main>
}