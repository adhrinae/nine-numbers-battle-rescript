type tabType = MyView | OpponentView | GameBoard

@react.component
let make = (
  ~activeTab: tabType, 
  ~onTabChange: tabType => unit,
  ~myWins: int,
  ~oppWins: int,
  ~currentRound: int,
  ~waiting: bool,
  // 게임 데이터 추가
  ~myBoard: array<option<int>>,
  ~oppBoard: array<option<int>>,
  ~hand: array<int>,
  ~oppHand: array<int>,
  ~playerColor: string,
  ~oppColor: string,
  ~winners: array<option<string>>,
  ~gameOver: option<string>,
  ~onCardClick: int => unit
) => {
  let tabClass = (isActive) => 
    if isActive { 
      "flex-1 py-3 px-4 text-center font-semibold text-blue-600 border-b-2 border-blue-600 bg-blue-50" 
    } else { 
      "flex-1 py-3 px-4 text-center font-medium text-gray-600 border-b-2 border-transparent hover:text-gray-800" 
    }

  <div className="bg-white border-b border-gray-200 flex flex-col h-full">
    <div className="flex-shrink-0">
      <div className="flex">
      <button 
        className={tabClass(activeTab == MyView)}
        onClick={_ => onTabChange(MyView)}
      >
        {React.string("내 패")}
      </button>
      <button 
        className={tabClass(activeTab == OpponentView)}
        onClick={_ => onTabChange(OpponentView)}
      >
        {React.string("상대 패")}
      </button>
      <button 
        className={tabClass(activeTab == GameBoard)}
        onClick={_ => onTabChange(GameBoard)}
      >
        {React.string("게임 보드")}
      </button>
      </div>
    </div>
    
    // 게임 상태 정보 표시
    <div className="px-4 py-2 bg-gray-50 text-sm flex-shrink-0">
      <div className="flex justify-between items-center">
        <span className="font-medium">
          {React.string("Score: " ++ string_of_int(myWins) ++ " - " ++ string_of_int(oppWins))}
        </span>
        <span className="text-gray-600">
          {React.string("Round " ++ string_of_int(currentRound + 1) ++ "/9")}
        </span>
      </div>
      {waiting ? 
        <div className="text-center text-blue-600 mt-1">
          {React.string("상대방을 기다리는 중...")}
        </div>
      : React.null}
    </div>
    
    // 탭별 콘텐츠 렌더링
    <div className="flex-1 overflow-y-auto overflow-x-hidden p-4">
      {switch activeTab {
      | MyView => 
        <div className="space-y-6">
          // 내 보드 슬롯들
          <div>
            <h3 className="text-lg font-semibold mb-3 text-center">{React.string("내 보드")}</h3>
            <div className="flex flex-wrap gap-1 justify-center">
              {React.array(
                Belt.Array.mapWithIndex(myBoard, (i, cardOpt) => {
                  let ringClass = if i == currentRound {
                    if playerColor == "blue" { "ring-2 ring-blue-400" } else { "ring-2 ring-red-400" }
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
                    isMobile=true
                  />
                })
              )}
            </div>
          </div>
          
          // 내 패
          <div>
            <h3 className="text-lg font-semibold mb-3 text-center">{React.string("내 패")}</h3>
            <div className="flex flex-wrap gap-1 justify-center">
              {React.array(
                hand->Belt.Array.map(n =>
                  <Card
                    number=n
                    onClick={() => onCardClick(n)}
                    disabled={waiting || Belt.Option.isSome(gameOver)}
                    selected=false
                    teamColor=playerColor
                    key={Js.Int.toString(n)}
                  />
                )
              )}
            </div>
          </div>
        </div>
        
      | OpponentView =>
        <div className="space-y-6">
          // 상대 보드 슬롯들
          <div>
            <h3 className="text-lg font-semibold mb-3 text-center">{React.string("상대 보드")}</h3>
            <div className="flex flex-wrap gap-1 justify-center">
              {React.array(
                Belt.Array.mapWithIndex(oppBoard, (i, cardOpt) => {
                  let winnerBgOpp =
                    switch Belt.Array.get(winners, i) {
                    | Some(Some(w)) when w == "Opponent wins" => " bg-red-200"
                    | Some(Some(w)) when w == "You win" => " bg-gray-200"  
                    | Some(Some(_)) => " bg-yellow-200"
                    | _ => ""
                    }
                  
                  // 게임이 끝났을 때만 카드 공개
                  let showCard = Belt.Option.isSome(gameOver)
                  let displayCard = if showCard { cardOpt } else { None }
                  
                  <BoardSlot
                    round=(i + 1)
                    card=displayCard
                    className={winnerBgOpp}
                    teamColor=oppColor
                    key={"opp-" ++ string_of_int(i)}
                    isMobile=true
                  />
                })
              )}
            </div>
          </div>
          
          // 상대방 패 (숨김 카드 - 홀수/짝수 구분해서 표시)
          <div>
            <h3 className="text-lg font-semibold mb-3 text-center">{React.string("상대방 패")}</h3>
            <div className="flex flex-wrap gap-1 justify-center">
              {React.array(
                oppHand
                -> Belt.Array.keep(c => mod(c, 2) == 1)
                -> Belt.Array.mapWithIndex((card, i) =>
                  <Card
                    key={"opp-white-" ++ string_of_int(card) ++ "-" ++ string_of_int(i)}
                    number=1
                    onClick={() => ()}
                    disabled=true
                    selected=false
                    teamColor="white"
                    isHidden=true
                  />
                )
              )}
              {React.array(
                oppHand
                -> Belt.Array.keep(c => mod(c, 2) == 0)
                -> Belt.Array.mapWithIndex((card, i) =>
                  <Card
                    key={"opp-black-" ++ string_of_int(card) ++ "-" ++ string_of_int(i)}
                    number=2
                    onClick={() => ()}
                    disabled=true
                    selected=false
                    teamColor="black"
                    isHidden=true
                  />
                )
              )}
            </div>
          </div>
        </div>
        
      | GameBoard =>
        <div className="space-y-3 pb-4">
          <h3 className="text-lg font-semibold text-center">{React.string("게임 보드 전체")}</h3>
          
          // 게임 결과 표시
          {switch gameOver {
          | Some(winner) =>
            <div className="bg-blue-50 p-3 rounded-lg text-center">
              <div className="text-lg font-bold text-blue-800 mb-1">
                {React.string("게임 종료!")}
              </div>
              <div className="text-sm">
                {React.string(winner)}
              </div>
            </div>
          | None =>
            if currentRound > 0 {
              switch Belt.Array.get(winners, currentRound - 1) {
              | Some(Some(result)) => 
                <div className="bg-gray-50 p-2 rounded-lg text-center">
                  <div className="text-sm font-medium">
                    {React.string("라운드 " ++ string_of_int(currentRound) ++ " 결과")}
                  </div>
                  <div className="text-xs text-gray-600 mt-1">
                    {React.string(result)}
                  </div>
                </div>
              | _ => React.null
              }
            } else {
              React.null
            }
          }}
          
          // 전체 보드 상황 요약
          <div className="space-y-3">
            <div>
              <div className="text-sm font-medium text-center mb-2">{React.string("상대방")}</div>
              <div className="flex flex-wrap gap-1 justify-center">
                {React.array(
                  Belt.Array.mapWithIndex(oppBoard, (i, cardOpt) => {
                    let showCard = Belt.Option.isSome(gameOver)
                    let displayCard = if showCard { cardOpt } else { None }
                    <BoardSlot
                      round=(i + 1)
                      card=displayCard
                      className="transform scale-75"
                      teamColor=oppColor
                      key={"summary-opp-" ++ string_of_int(i)}
                      isMobile=true
                    />
                  })
                )}
              </div>
            </div>
            
            <div>
              <div className="text-sm font-medium text-center mb-2">{React.string("나")}</div>
              <div className="flex flex-wrap gap-1 justify-center">
                {React.array(
                  Belt.Array.mapWithIndex(myBoard, (i, cardOpt) => {
                    let ringClass = if i == currentRound {
                      if playerColor == "blue" { "ring-1 ring-blue-400" } else { "ring-1 ring-red-400" }
                    } else { "" }
                    <BoardSlot
                      round=(i + 1)
                      card=cardOpt
                      className={ringClass ++ " transform scale-75"}
                      teamColor=playerColor
                      key={"summary-my-" ++ string_of_int(i)}
                      isMobile=true
                    />
                  })
                )}
              </div>
            </div>
          </div>
        </div>
      }}
    </div>
  </div>
}
