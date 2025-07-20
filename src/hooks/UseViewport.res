// 뷰포트 정보를 관리하는 훅
type viewportInfo = {
  width: int,
  height: int,
  isMobile: bool,
  isLandscape: bool,
  shouldRecommendLandscape: bool,
}

@val external innerWidth: int = "window.innerWidth"
@val external innerHeight: int = "window.innerHeight"

let getViewportInfo = () => {
  let width = innerWidth
  let height = innerHeight
  let isMobile = width < 768 // Tailwind의 md breakpoint
  let isLandscape = width > height
  // 모바일이면서 세로 모드이고, 너비가 좁으면 가로 모드 권장
  let shouldRecommendLandscape = isMobile && !isLandscape && width < 640
  
  {
    width,
    height,
    isMobile,
    isLandscape,
    shouldRecommendLandscape,
  }
}

@val external addEventListener: (string, unit => unit) => unit = "window.addEventListener"
@val external removeEventListener: (string, unit => unit) => unit = "window.removeEventListener"

let useViewport = () => {
  let (viewport, setViewport) = React.useState(() => getViewportInfo())
  
  React.useEffect0(() => {
    let handleResize = () => {
      setViewport(_ => getViewportInfo())
    }
    
    addEventListener("resize", handleResize)
    addEventListener("orientationchange", handleResize)
    
    Some(() => {
      removeEventListener("resize", handleResize)
      removeEventListener("orientationchange", handleResize)
    })
  })
  
  viewport
}
