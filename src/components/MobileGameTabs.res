type tabType = MyView | OpponentView | GameBoard

@react.component
let make = (
  ~activeTab: tabType, 
  ~onTabChange: tabType => unit,
  ~myWins: int,
  ~oppWins: int,
  ~currentRound: int,
  ~waiting: bool
) => {
  let tabClass = (isActive) => 
    if isActive { 
      "flex-1 py-3 px-4 text-center font-semibold text-blue-600 border-b-2 border-blue-600 bg-blue-50" 
    } else { 
      "flex-1 py-3 px-4 text-center font-medium text-gray-600 border-b-2 border-transparent hover:text-gray-800" 
    }

  <div className="bg-white border-b border-gray-200">
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
    
    // 게임 상태 정보 표시
    <div className="px-4 py-2 bg-gray-50 text-sm">
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
  </div>
}
