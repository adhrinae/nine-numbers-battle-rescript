@react.component
let make = (~round: int, ~card: option<int>) => {
  <div className="w-16 h-24 m-2 flex items-center justify-center border-2 border-dashed rounded-lg bg-gray-100">
    {switch card {
    | Some(n) => React.string(Js.Int.toString(n))
    | None => React.string("")
    }}
  </div>
}