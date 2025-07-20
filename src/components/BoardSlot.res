@react.component
let make = (~round: int, ~card: option<int>, ~className: string="", ~teamColor: string="blue") => {
  let textColorClass = if teamColor == "blue" { "text-blue-600" } else { "text-red-600" }
  <div className={"w-16 h-24 m-2 flex flex-col items-center justify-center border-2 border-dashed rounded-lg bg-gray-100 " ++ className}>
    <div className="text-xs text-gray-500 mb-1">
      {React.string("R" ++ Js.Int.toString(round))}
    </div>
    {switch card {
    | Some(n) =>
      <span className={textColorClass ++ " text-xl font-bold"}>
        {React.string(Js.Int.toString(n))}
      </span>
    | None => React.null
    }}
  </div>
}