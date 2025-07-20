open GameNetwork
open UseViewport
open MobileGameTabs
open LandscapeRecommendation

@val @scope(("navigator", "clipboard"))
external writeText: string => Js.Promise.t<unit> = "writeText"

// True mobile detection (touch capability + mobile screen)
let isTrueMobile = %raw(`
  function() {
    return 'ontouchstart' in window && window.innerWidth < 1024;
  }
`)

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
  // track each round winner: "You win", "Opponent wins", "Tie"
  let (winners, setWinners) = React.useState(() => Belt.Array.make(9, None))
  let (oppCard, setOppCard) = React.useState(() => None)
  let (gameOver, setGameOver) = React.useState(() => None)
  let (showGameOverModal, setShowGameOverModal) = React.useState(() => false)

  // PeerJS network setup
  let peer = React.useMemo0(() => makePeer())
  let (localId, setLocalId) = React.useState(() => "")
  let (remoteIdInput, setRemoteIdInput) = React.useState(() => "")
  let (conn, setConn) = React.useState(() => None)
  let (connStatus, setConnStatus) = React.useState(() => "")
  let (role, setRole) = React.useState(() => "")
  let (myRand, setMyRand) = React.useState(() => None)
  let (oppRand, setOppRand) = React.useState(() => None)
  let (myTeam, setMyTeam) = React.useState(() => None)
  let (copied, setCopied) = React.useState(() => false)

  // Viewport and mobile detection
  let viewport = useViewport()
  let isMobile = isTrueMobile()
  
  // Mobile tab state
  let (activeTab, setActiveTab) = React.useState(() => MobileGameTabs.MyView)

  // 카드 클릭 핸들러
  let onCardClick = n => {
    switch (Belt.Array.get(myBoard, currentRound), conn) {
    | (Some(None), Some(c)) =>
      // 내가 보드에 카드 제출
      setMyBoard(prevBoard => {
        let newBoard = Belt.Array.copy(prevBoard)
        ignore(Belt.Array.set(newBoard, currentRound, Some(n)))
        newBoard
      })
      // update hand
      setHand(prevHand => Belt.Array.keep(prevHand, c => c != n))
      // send card to opponent
      sendPlayCard(c, n)
      // opponent 준비 메시지
      setWaiting(_ => true)
    | _ => ()
    }
  }

  // 호스트 ID 복사 핸들러
  let handleCopyId = (id, setCopied) => {
    ignore(
      writeText(id)
      |>Js.Promise.then_(_ => {
        setCopied(_ => true);
        ignore(Js.Global.setTimeout(() => setCopied(_ => false), 1200));
        Js.Promise.resolve();
      })
    )
  }

  // Peer 객체 기본 이벤트 리스너 설정
  React.useEffect0(() => {
    onOpen(peer, id => setLocalId(_ => id))
    onError(peer, err => setConnStatus(_ => "Error: " ++ Js.Json.stringify(err)))
    None
  })

  // 호스트 역할일 때, 연결 요청 리스너 설정
  React.useEffect1(() => {
    if role == "host" {
      onConnection(peer, c => {
        setConn(_ => Some(c))
        setConnStatus(_ => "Connected!")
        // 호스트는 연결되자마자 바로 랜덤값 생성하여 전송 (호스트에게는 salt +1 추가)
        let baseRand = int_of_float(Js.Math.random() *. 100000.0)
        let rand = baseRand * 2 + 1 // 홀수로 만들어서 호스트임을 표시
        setMyRand(_ => Some(rand))
        sendRand(c, rand)
      })
    }
    None
  }, [role])

  // 연결(conn)이 설정된 후, 해당 연결에 대한 이벤트 리스너 설정
  React.useEffect1(() => {
    switch conn {
    | Some(c) =>
      // 연결 성공시 처리
      onConnOpen(c, () => {
        setConnStatus(_ => "Connected!")
        // 참가자는 짝수로 만들어서 참가자임을 표시
        let baseRand = int_of_float(Js.Math.random() *. 100000.0)
        let rand = baseRand * 2 // 짝수로 만들어서 참가자임을 표시
        setMyRand(_ => Some(rand))
        sendRand(c, rand)
      })

      // 데이터 수신 리스너
      onData(c, event => {
        switch event {
        | Rand(n) => setOppRand(_ => Some(n))
        | Team(teamName, n) => {
            setOppRand(_ => Some(n))
            // 상대방이 보낸 팀의 반대 팀으로 설정
            let myTeamName = if teamName == "red" { "blue" } else { "red" }
            setMyTeam(_ => Some(myTeamName))
          }
        | PlayCard(card) => {
            setOppCard(_ => Some(card))
            setOppHand(prev => Belt.Array.keep(prev, c => c != card))
          }
        | AnnounceWinner(_) => () // 더 이상 사용하지 않음
        | ReadyForNextRound => setWaiting(_ => false)
        | GameOver(winner) => setGameOver(_ => Some(winner))
        | Other(_) => ()
        }
      })

      // 연결 에러 리스너
      onConnError(c, err => setConnStatus(_ => "연결 실패: " ++ Js.Json.stringify(err)))
    | None => ()
    }
    None
  }, [conn])

  // 팀 결정 useEffect - 호스트만 팀을 결정하고 상대방에게 알림
  React.useEffect(() => {
    if myTeam == None && oppRand != None && myRand != None && role == "host" {
      let myR = Belt.Option.getExn(myRand)
      let oppR = Belt.Option.getExn(oppRand)
      // 랜덤값이 높은 쪽이 red, 낮은 쪽이 blue
      let myTeamName = if myR > oppR { "red" } else { "blue" }
      setMyTeam(_ => Some(myTeamName))
      switch conn {
      | Some(c) => sendTeam(c, myTeamName, myR)
      | None => ()
      }
    }
    None
  }, (myTeam, myRand, oppRand, role, conn))

  // 라운드 승자 판정 및 다음 라운드 진행 - 각 라운드 결과는 표시하되 카드는 숨김
  React.useEffect(() => {
    let myMoveOpt = Belt.Array.get(myBoard, currentRound)
    let oppMoveOpt = oppCard

    switch (myMoveOpt, oppMoveOpt) {
    | (Some(Some(myMove)), Some(oppMove)) =>
      // 이번 라운드 승부 판정
      let winnerText =
        if myMove == oppMove {
          "Tie"
        } else if myMove == 1 && oppMove == 9 {
          "You win"
        } else if myMove == 9 && oppMove == 1 {
          "Opponent wins"
        } else if myMove > oppMove {
          "You win"
        } else {
          "Opponent wins"
        }

      // 상대방 보드 업데이트 (카드는 저장하지만 공개하지 않음)
      setOppBoard(prev => {
        let newBoard = Belt.Array.copy(prev)
        ignore(Belt.Array.set(newBoard, currentRound, Some(oppMove)))
        newBoard
      })

      // 이번 라운드 결과 저장
      setWinners(prev => {
        let newWinners = Belt.Array.copy(prev)
        ignore(Belt.Array.set(newWinners, currentRound, Some(winnerText)))
        newWinners
      })

      // 승수 계산 (현재 라운드 포함)
      let currentWins = Belt.Array.keep(winners, w => 
        switch w {
        | Some("You win") => true
        | _ => false
        }
      ) -> Belt.Array.length
      let myWins = currentWins + (winnerText == "You win" ? 1 : 0)

      let currentOppWins = Belt.Array.keep(winners, w => 
        switch w {
        | Some("Opponent wins") => true
        | _ => false
        }
      ) -> Belt.Array.length
      let oppWins = currentOppWins + (winnerText == "Opponent wins" ? 1 : 0)

      // 다음 라운드로 이동
      setOppCard(_ => None)
      let nextRound = currentRound + 1
      setCurrentRound(_ => nextRound)
      setWaiting(_ => false)

      // 5승 달성 시 게임 종료
      if myWins >= 5 || oppWins >= 5 || nextRound >= 9 {
        let finalWinner = if myWins >= 5 {
          "당신이 승리했습니다!"
        } else if oppWins >= 5 {
          "상대방이 승리했습니다!"
        } else if myWins > oppWins {
          "당신이 승리했습니다!"
        } else if oppWins > myWins {
          "상대방이 승리했습니다!"
        } else {
          "무승부입니다!"
        }
        
        setGameOver(_ => Some(finalWinner))
        setShowGameOverModal(_ => true)
      }
    | _ => ()
    }

    None
  }, (myBoard, oppCard))

  // UI flow: select host/join, handle connection, then choose color, then game
  if role == "" {
    <div className="min-h-screen flex flex-col items-center justify-center p-6 bg-gradient-to-b from-blue-50 to-purple-50">
      <div className="text-center mb-8">
        <h1 className="text-3xl font-bold text-gray-800 mb-2">{React.string("구룡쟁패")}</h1>
        <p className="text-gray-600">{React.string("친구와 함께 즐기는 카드 게임")}</p>
      </div>
      <div className="w-full max-w-sm space-y-4">
        <button 
          className="w-full py-4 bg-green-500 hover:bg-green-600 text-white font-semibold rounded-lg shadow-md transition-colors duration-200" 
          onClick={_ => setRole(_ => "host")}
        >
          {React.string("🎮 새 게임 시작")}
        </button>
        <button 
          className="w-full py-4 bg-purple-500 hover:bg-purple-600 text-white font-semibold rounded-lg shadow-md transition-colors duration-200" 
          onClick={_ => setRole(_ => "join")}
        >
          {React.string("🔗 게임 참여")}
        </button>
      </div>
    </div>
  } else if role == "host" && conn == None {
    <div className="min-h-screen flex flex-col items-center justify-center p-6 bg-gradient-to-b from-green-50 to-blue-50">
      <div className="w-full max-w-md bg-white rounded-2xl shadow-lg p-6">
        <div className="text-center mb-6">
          <div className="w-16 h-16 bg-green-100 rounded-full flex items-center justify-center mx-auto mb-4">
            <span className="text-2xl">{React.string("🎮")}</span>
          </div>
          <h2 className="text-xl font-bold text-gray-800 mb-2">{React.string("게임 방 생성됨")}</h2>
          <p className="text-gray-600 text-sm">{React.string("친구가 참여할 수 있도록 ID를 공유하세요")}</p>
        </div>
        
        <div className="bg-gray-50 rounded-lg p-4 mb-4">
          <div className="flex items-center justify-between">
            <div className="flex-1">
              <label className="block text-xs text-gray-500 mb-1">{React.string("게임 ID")}</label>
              <div className="font-mono text-sm text-gray-800 break-all">{React.string(localId)}</div>
            </div>
            <button 
              className="ml-3 px-4 py-2 bg-blue-500 hover:bg-blue-600 text-white text-sm font-medium rounded-lg transition-colors duration-200" 
              onClick={_ => handleCopyId(localId, setCopied)}
            >
              {copied ? React.string("복사됨!") : React.string("복사")}
            </button>
          </div>
        </div>
        
        <div className="text-center">
          <div className="inline-flex items-center px-4 py-2 bg-yellow-50 rounded-lg">
            <div className="animate-spin rounded-full h-4 w-4 border-b-2 border-yellow-500 mr-2"></div>
            <span className="text-yellow-700 text-sm">{React.string("상대방 연결 대기중...")}</span>
          </div>
        </div>
      </div>
    </div>
  } else if role == "join" && conn == None {
    let isInputEmpty = Js.String.trim(remoteIdInput) == ""
    let isConnecting = connStatus == "연결 중..."
    
    <div className="min-h-screen flex flex-col items-center justify-center p-6 bg-gradient-to-b from-purple-50 to-pink-50">
      <div className="w-full max-w-md bg-white rounded-2xl shadow-lg p-6">
        <div className="text-center mb-6">
          <div className="w-16 h-16 bg-purple-100 rounded-full flex items-center justify-center mx-auto mb-4">
            <span className="text-2xl">{React.string("🔗")}</span>
          </div>
          <h2 className="text-xl font-bold text-gray-800 mb-2">{React.string("게임 참여")}</h2>
          <p className="text-gray-600 text-sm">{React.string("친구로부터 받은 게임 ID를 입력하세요")}</p>
        </div>
        
        <div className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">{React.string("게임 ID")}</label>
            <input 
              className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-purple-500 outline-none transition-colors duration-200 font-mono text-sm"
              value=remoteIdInput 
              onChange={e => { 
                setRemoteIdInput(_ => {
                  let target = ReactEvent.Form.target(e);
                  let value = target["value"];
                  value
                }) 
              }} 
              placeholder="예: abc123def456"
              disabled=isConnecting
            />
          </div>
          
          <button 
            className={
              if isInputEmpty || isConnecting {
                "w-full py-3 bg-gray-300 text-gray-500 font-semibold rounded-lg cursor-not-allowed"
              } else {
                "w-full py-3 bg-purple-500 hover:bg-purple-600 text-white font-semibold rounded-lg shadow-md transition-colors duration-200"
              }
            }
            onClick={_ => {
              if !isInputEmpty && !isConnecting {
                setConnStatus(_ => "연결 중...");
                let trimmedId = Js.String.trim(remoteIdInput);
                let c = connect(peer, trimmedId);
                setConn(_ => Some(c));
              }
            }}
            disabled={isInputEmpty || isConnecting}
          >
            {if isConnecting {
              <div className="flex items-center justify-center">
                <div className="animate-spin rounded-full h-4 w-4 border-b-2 border-gray-500 mr-2"></div>
                {React.string("연결 중...")}
              </div>
            } else {
              React.string("게임 참여하기")
            }}
          </button>
          
          {connStatus != "" && connStatus != "연결 중..." ? 
            <div className="text-center">
              <div className={
                if Js.String.includes("연결 실패", connStatus) || Js.String.includes("Error", connStatus) {
                  "inline-block px-3 py-2 bg-red-50 text-red-700 text-sm rounded-lg"
                } else {
                  "inline-block px-3 py-2 bg-blue-50 text-blue-700 text-sm rounded-lg"
                }
              }>
                {React.string(connStatus)}
              </div>
            </div>
          : React.null}
        </div>
      </div>
    </div>
  } else if conn == None {
    <div className="min-h-screen flex flex-col items-center justify-center p-6 bg-gradient-to-b from-gray-50 to-blue-50">
      <div className="w-full max-w-md bg-white rounded-2xl shadow-lg p-6">
        <div className="text-center">
          <div className="w-16 h-16 bg-gray-100 rounded-full flex items-center justify-center mx-auto mb-4">
            <span className="text-2xl">{React.string("⚠️")}</span>
          </div>
          <h2 className="text-xl font-bold text-gray-800 mb-2">{React.string("연결 상태")}</h2>
          <p className="text-gray-600">{React.string(connStatus)}</p>
        </div>
      </div>
    </div>
  } else if oppRand == None || myRand == None {
    <div className="min-h-screen flex flex-col items-center justify-center p-6 bg-gradient-to-b from-blue-50 to-indigo-50">
      <div className="w-full max-w-md bg-white rounded-2xl shadow-lg p-6">
        <div className="text-center">
          <div className="w-16 h-16 bg-blue-100 rounded-full flex items-center justify-center mx-auto mb-4">
            <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-500"></div>
          </div>
          <h2 className="text-xl font-bold text-gray-800 mb-2">{React.string("팀 결정 중...")}</h2>
          <p className="text-gray-600 text-sm">{React.string("랜덤하게 팀을 배정하고 있습니다")}</p>
        </div>
      </div>
    </div>
  } else if myTeam == None && oppRand != None && myRand != None {
    // 팀 결정 로직는 useEffect로 이동, 여기선 UI만 표시
    <div className="min-h-screen flex flex-col items-center justify-center p-6 bg-gradient-to-b from-blue-50 to-indigo-50">
      <div className="w-full max-w-md bg-white rounded-2xl shadow-lg p-6">
        <div className="text-center">
          <div className="w-16 h-16 bg-blue-100 rounded-full flex items-center justify-center mx-auto mb-4">
            <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-500"></div>
          </div>
          <h2 className="text-xl font-bold text-gray-800 mb-2">{React.string("팀 결정 중...")}</h2>
          <p className="text-gray-600 text-sm">{React.string("랜덤하게 팀을 배정하고 있습니다")}</p>
        </div>
      </div>
    </div>
  } else if myTeam != None && !gameStarted {
    let team = Belt.Option.getExn(myTeam)
    let teamName = if team == "red" { "레드" } else { "블루" }
    let bgGradient = if team == "red" { "from-red-50 to-pink-50" } else { "from-blue-50 to-indigo-50" }
    let iconBg = if team == "red" { "bg-red-100" } else { "bg-blue-100" }
    let buttonBg = if team == "red" { "bg-red-500 hover:bg-red-600" } else { "bg-blue-500 hover:bg-blue-600" }
    
    <div className={"min-h-screen flex flex-col items-center justify-center p-6 bg-gradient-to-b " ++ bgGradient}>
      <div className="w-full max-w-md bg-white rounded-2xl shadow-lg p-6">
        <div className="text-center mb-6">
          <div className={"w-16 h-16 " ++ iconBg ++ " rounded-full flex items-center justify-center mx-auto mb-4"}>
            <span className="text-2xl">{React.string(if team == "red" { "🔴" } else { "🔵" })}</span>
          </div>
          <h2 className="text-xl font-bold text-gray-800 mb-2">{React.string("팀 배정 완료!")}</h2>
          <p className="text-gray-600 text-sm mb-4">{React.string("당신은 " ++ teamName ++ " 팀으로 배정되었습니다")}</p>
          <div className={"inline-block px-4 py-2 rounded-full text-white font-medium " ++ (if team == "red" { "bg-red-500" } else { "bg-blue-500" })}>
            {React.string(teamName ++ " 팀")}
          </div>
        </div>
        
        <button 
          className={"w-full py-4 " ++ buttonBg ++ " text-white font-semibold rounded-lg shadow-md transition-colors duration-200"}
          onClick={_ => { 
            setPlayerColor(_ => team); 
            setGameStarted(_ => true) 
          }}
        >
          {React.string("🚀 게임 시작하기")}
        </button>
      </div>
    </div>
  } else {
    // Mobile First Design: 진짜 모바일 디바이스면 탭 기반, 아니면 데스크톱 그리드
    if isMobile {
      <div className="h-screen w-screen overflow-hidden">
        {if viewport.shouldRecommendLandscape {
          <LandscapeRecommendation
            onDismiss={() => ()}
          />
        } else {
          React.null
        }}
        <MobileGameTabs
          activeTab
          onTabChange={tab => setActiveTab(_ => tab)}
          myWins={Belt.Array.keep(winners, w => w == Some("You win")) |> Belt.Array.length}
          oppWins={Belt.Array.keep(winners, w => w == Some("Opponent wins")) |> Belt.Array.length}
          currentRound
          waiting
          myBoard
          oppBoard
          hand
          oppHand
          playerColor
          oppColor
          winners
          gameOver
          onCardClick
        />
        
        // 게임 종료 모달
        {showGameOverModal && Belt.Option.isSome(gameOver) ?
          <div className="absolute inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-6">
            <div className="bg-white rounded-2xl shadow-2xl p-6 w-full max-w-sm mx-4">
              <div className="text-center">
                <div className="w-20 h-20 mx-auto mb-4 rounded-full flex items-center justify-center bg-gradient-to-r from-yellow-400 to-orange-500">
                  <span className="text-3xl">{React.string("🎉")}</span>
                </div>
                <h2 className="text-2xl font-bold text-gray-800 mb-2">{React.string("게임 종료!")}</h2>
                <div className="mb-6">
                  {switch gameOver {
                  | Some(winner) => 
                    let (winnerText, textColor) = 
                      if Js.String.includes("당신이 승리했습니다", winner) {
                        ("🎊 축하합니다! 승리하셨습니다! 🎊", "text-green-600")
                      } else if Js.String.includes("상대방이 승리했습니다", winner) {
                        ("😔 아쉽게도 패배하셨습니다", "text-red-600") 
                      } else {
                        ("🤝 무승부입니다!", "text-blue-600")
                      }
                    <p className={"text-lg font-semibold " ++ textColor}>{React.string(winnerText)}</p>
                  | None => React.null
                  }}
                </div>
                <button 
                  className="w-full py-3 bg-blue-500 hover:bg-blue-600 text-white font-semibold rounded-lg shadow-md transition-colors duration-200"
                  onClick={_ => {
                    setShowGameOverModal(_ => false)
                    setActiveTab(_ => MobileGameTabs.GameBoard)
                  }}
                >
                  {React.string("🏆 결과 확인하기")}
                </button>
              </div>
            </div>
          </div>
        : React.null}
      </div>
    } else {
      // 데스크톱: 기존 레이아웃
      <div className="relative">
        <main className="flex flex-col items-center p-4">
      // opponent overview (hidden cards count)
      <section className="flex flex-row mb-2">
        <div className="flex flex-row items-center mr-4">
          <span className="mr-2">{React.string("Opponent's Hand:")}</span>
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
            ),
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
            ),
          )}
        </div>
      </section>
      // opponent board slots (mirrored) - 게임 종료 전까지는 카드 숨김
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
            
            // 게임이 끝났거나 현재 라운드보다 이전 라운드인 경우만 카드 공개
            let showCard = Belt.Option.isSome(gameOver)
            let displayCard = if showCard { cardOpt } else { None }
            
            <BoardSlot
              round=(i + 1)
              card=displayCard
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
      // 현재 스코어 표시
      {
        let myWins = Belt.Array.keep(winners, w => 
          switch w {
          | Some("You win") => true
          | _ => false
          }
        ) -> Belt.Array.length
        let oppWins = Belt.Array.keep(winners, w => 
          switch w {
          | Some("Opponent wins") => true
          | _ => false
          }
        ) -> Belt.Array.length
        
        <div className="my-2 text-lg font-bold">
          {React.string("Score: You " ++ string_of_int(myWins) ++ " - " ++ string_of_int(oppWins) ++ " Opponent")}
        </div>
      }
      // 지난 라운드 결과 표시
      {
        if currentRound > 0 {
          switch Belt.Array.get(winners, currentRound - 1) {
          | Some(Some(result)) => 
            <div className="my-2">
              {React.string("Round " ++ string_of_int(currentRound) ++ " result: " ++ result)}
            </div>
          | _ => React.null
          }
        } else {
          React.null
        }
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
              disabled={waiting || Belt.Option.isSome(gameOver)}
              selected=false
              teamColor=playerColor
              key={Js.Int.toString(n)}
            />
          )
        )}
      </section>
      {switch gameOver {
      | Some(winner) =>
        <div className="mt-4 text-2xl font-bold">
          {React.string(winner)}
        </div>
      | None => React.null
      }}
    </main>
    
    // 데스크톱용 게임 종료 모달
    {showGameOverModal && Belt.Option.isSome(gameOver) ?
      <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-6">
        <div className="bg-white rounded-2xl shadow-2xl p-8 max-w-md mx-4">
          <div className="text-center">
            <div className="w-24 h-24 mx-auto mb-6 rounded-full flex items-center justify-center bg-gradient-to-r from-yellow-400 to-orange-500">
              <span className="text-4xl">{React.string("🎉")}</span>
            </div>
            <h2 className="text-3xl font-bold text-gray-800 mb-4">{React.string("게임 종료!")}</h2>
            <div className="mb-8">
              {switch gameOver {
              | Some(winner) => 
                let (winnerText, textColor) = 
                  if Js.String.includes("당신이 승리했습니다", winner) {
                    ("🎊 축하합니다! 승리하셨습니다! 🎊", "text-green-600")
                  } else if Js.String.includes("상대방이 승리했습니다", winner) {
                    ("😔 아쉽게도 패배하셨습니다", "text-red-600") 
                  } else {
                    ("🤝 무승부입니다!", "text-blue-600")
                  }
                <p className={"text-xl font-semibold " ++ textColor}>{React.string(winnerText)}</p>
              | None => React.null
              }}
            </div>
            <button 
              className="w-full py-4 bg-blue-500 hover:bg-blue-600 text-white font-semibold rounded-lg shadow-md transition-colors duration-200 text-lg"
              onClick={_ => setShowGameOverModal(_ => false)}
            >
              {React.string("🏆 결과 확인하기")}
            </button>
          </div>
        </div>
      </div>
    : React.null}
      </div>
    }
  }
}
