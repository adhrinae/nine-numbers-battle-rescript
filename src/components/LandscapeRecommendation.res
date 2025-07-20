@react.component
let make = (~onDismiss: unit => unit) => {
  <div className="fixed inset-0 bg-black bg-opacity-50 flex items-end justify-center z-50">
    <div className="bg-white rounded-t-2xl p-6 w-full max-w-md mx-4 mb-0 shadow-2xl animate-slide-up">
      <div className="w-12 h-1 bg-gray-300 rounded mx-auto mb-4"></div>
      <div className="text-center">
        <div className="text-4xl mb-4 text-blue-500 font-bold">
          {React.string("↻")}
        </div>
        <h3 className="text-lg font-bold mb-2 text-gray-800">
          {React.string("가로 모드 권장")}
        </h3>
        <p className="text-gray-600 mb-6 text-sm leading-relaxed">
          {React.string("더 나은 게임 경험을 위해 기기를 가로로 회전해주세요.")}
        </p>
        <div className="flex flex-col space-y-3">
          <button 
            className="bg-blue-500 text-white px-6 py-3 rounded-lg font-medium hover:bg-blue-600 transition-colors w-full"
            onClick={_ => onDismiss()}
          >
            {React.string("확인")}
          </button>
          <p className="text-xs text-gray-500">
            {React.string("가로 모드로 변경하면 이 메시지가 자동으로 사라집니다.")}
          </p>
        </div>
      </div>
    </div>
  </div>
}
