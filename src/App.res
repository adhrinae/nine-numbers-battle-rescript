open GameNetwork

@val @scope(("navigator", "clipboard"))
external writeText: string => Js.Promise.t<unit> = "writeText"

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
  let (oppCard, setOppCard) = React.useState(() => None)
  let (gameOver, setGameOver) = React.useState(() => None)

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
        | AnnounceWinner(winner) => setLastResult(_ => winner)
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

  // 라운드 승자 판정 및 다음 라운드 진행
  React.useEffect(() => {
    let myMoveOpt = Belt.Array.get(myBoard, currentRound)
    let oppMoveOpt = oppCard

    switch (myMoveOpt, oppMoveOpt) {
    | (Some(Some(myMove)), Some(oppMove)) =>
      // 승자 판정
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
      setLastResult(_ => winnerText)
      setWinners(prev => {
        let newW = Belt.Array.copy(prev)
        ignore(Belt.Array.set(newW, currentRound, Some(winnerText)))
        newW
      })

      // 상대방 보드 업데이트
      setOppBoard(prev => {
        let newBoard = Belt.Array.copy(prev)
        ignore(Belt.Array.set(newBoard, currentRound, Some(oppMove)))
        newBoard
      })

      // 상태 초기화 및 다음 라운드로
      setOppCard(_ => None)
      setCurrentRound(prev => prev + 1)
      setWaiting(_ => false)
    | _ => ()
    }

    None
  }, (myBoard, oppCard))

  // UI flow: select host/join, handle connection, then choose color, then game
  if role == "" {
    <div className="flex flex-col items-center p-4">
      <button className="m-2 px-4 py-2 bg-green-500 text-white rounded" onClick={_ => setRole(_ => "host")}>{React.string("새 게임 시작")}</button>
      <button className="m-2 px-4 py-2 bg-purple-500 text-white rounded" onClick={_ => setRole(_ => "join")}>{React.string("게임 참여")}</button>
    </div>
  } else if role == "host" && conn == None {
    <div className="flex flex-col items-center p-4">
      <div className="flex items-center space-x-2">
        <span>{React.string("Your ID: " ++ localId)}</span>
        <button className="px-2 py-1 bg-gray-200 rounded text-xs" onClick={_ => handleCopyId(localId, setCopied)}>{React.string("복사")}</button>
        {copied ? <span className="text-green-500 text-xs ml-2">{React.string("복사됨!")}</span> : React.null}
      </div>
      <div>{React.string("이 ID를 친구에게 공유하세요.")}</div>
      <div className="mt-4">{React.string("상대방의 연결을 기다리는 중...")}</div>
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
        let trimmedId = Js.String.trim(remoteIdInput);
        let c = connect(peer, trimmedId);
        setConn(_ => Some(c));
      }}>
        {React.string("연결")}
      </button>
      <div>{React.string(connStatus)}</div>
    </div>
  } else if conn == None {
    <div className="flex items-center p-4">{React.string("연결 상태: " ++ connStatus)}</div>
  } else if oppRand == None || myRand == None {
    <div className="flex flex-col items-center p-4">
      {React.string("팀 결정 중...")}
    </div>
  } else if myTeam == None && oppRand != None && myRand != None {
    // 팀 결정 로직는 useEffect로 이동, 여기선 UI만 표시
    <div className="flex flex-col items-center p-4">
      {React.string("팀 결정 중...")}
    </div>
  } else if myTeam != None && !gameStarted {
    let team = Belt.Option.getExn(myTeam)
    <div className="flex flex-col items-center p-4">
      <div>{React.string("당신은 " ++ (if team == "red" { "Red" } else { "Blue" }) ++ " 팀입니다.")}</div>
      <button className={"m-2 px-4 py-2 rounded " ++ (if team == "red" { "bg-red-500 text-white" } else { "bg-blue-500 text-white" })} onClick={_ => { setPlayerColor(_ => team); setGameStarted(_ => true) }}>{React.string("게임 시작")}</button>
    </div>
  } else {
    <main className="flex flex-col items-center p-4">
      // opponent overview (hidden cards count)
      <section className="flex flex-row mb-2">
        <div className="flex flex-row items-center mr-4">
          <span className="mr-2">{React.string("Opponent's Hand:")}</span>
          {React.array(
            Belt.Array.make(oppWhiteCount, 0)->Belt.Array.mapWithIndex((_, i) =>
              <Card
                key={"opp-white-" ++ string_of_int(i)}
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
            Belt.Array.make(oppBlackCount, 0)->Belt.Array.mapWithIndex((_, i) =>
              <Card
                key={"opp-black-" ++ string_of_int(i)}
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
          {React.string("Game Over: " ++ winner)}
        </div>
      | None => React.null
      }}
    </main>
  }
}
