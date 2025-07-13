@react.component
let make = (~number: int, ~onClick: option<unit => unit>=?, ~selected: bool=false, ~disabled: bool=false, ~teamColor: string="blue") => {
  let cardColor = n =>
    if mod(n, 2) == 1 {
      // 홀수: 흰색(밝은 배경)
      "bg-white text-black border-gray-400"
    } else {
      // 짝수: 검정색(어두운 배경)
      "bg-gray-800 text-white border-gray-700"
    }

  let ringClass = if selected {
    if teamColor == "blue" {
      " ring-4 ring-blue-400"
    } else {
      " ring-4 ring-red-400"
    }
  } else {
    ""
  }

  let classes =
    "rounded-lg border shadow flex items-center justify-center w-16 h-24 m-2 text-2xl transition-all " ++
    cardColor(number) ++
    ringClass ++
    (if disabled { " opacity-40 cursor-not-allowed" } else { " cursor-pointer" })
  <div
    className=classes
    onClick={_ => if !disabled {
      switch onClick {
      | Some(cb) => cb()
      | None => ()
      }
    }}>
    {React.string(Js.Int.toString(number))}
  </div>
}