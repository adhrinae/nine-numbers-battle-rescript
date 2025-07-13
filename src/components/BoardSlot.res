@react.component
let make = (~round: int, ~card: option<int>, ~className: string="", ~teamColor: string="blue") => {
  let textColorClass = if teamColor == "blue" { "text-blue-600" } else { "text-red-600" }
  <div className={"w-16 h-24 m-2 flex items-center justify-center border-2 border-dashed rounded-lg bg-gray-100 " ++ className}>
    {switch card {
    | Some(n) =>
      <span className={textColorClass ++ " text-2xl"}>
        {React.string(Js.Int.toString(n))}
      </span>
    | None => React.null
    }}
  </div>
}