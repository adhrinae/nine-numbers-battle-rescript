@react.component
let make = (~round: int, ~card: option<int>, ~className: string="", ~teamColor: string="blue", ~isMobile: bool=false) => {
  let textColorClass = if teamColor == "blue" { "text-blue-600" } else { "text-red-600" }
  let sizeClass = if isMobile { "w-12 h-16" } else { "w-16 h-24" }
  let textSizeClass = if isMobile { "text-sm" } else { "text-xl" }
  
  <div className={sizeClass ++ " m-1 flex flex-col items-center justify-center border-2 border-dashed rounded-lg bg-gray-100 " ++ className}>
    <div className="text-xs text-gray-500 mb-1">
      {React.string("R" ++ Js.Int.toString(round))}
    </div>
    {switch card {
    | Some(n) =>
      <span className={textColorClass ++ " " ++ textSizeClass ++ " font-bold"}>
        {React.string(Js.Int.toString(n))}
      </span>
    | None => React.null
    }}
  </div>
}