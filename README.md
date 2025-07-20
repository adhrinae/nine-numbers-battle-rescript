# Nine Numbers Battle (구룡쟁패)

ReScript로 구현된 P2P 카드 배틀 게임

## 🎮 게임 소개

9장의 카드(1-9)를 사용한 실시간 멀티플레이어 전략 게임입니다.
- **P2P 연결**: PeerJS를 사용한 직접적인 플레이어 간 연결
- **모바일 최적화**: 모바일 디바이스에서 최적화된 탭 기반 UI
- **실시간 게임플레이**: 턴 기반 전략 게임

## 🚀 기술 스택

- **ReScript**: 타입 안전한 함수형 프로그래밍
- **React**: UI 컴포넌트
- **PeerJS**: P2P 실시간 통신
- **Tailwind CSS**: 스타일링
- **Vite**: 빌드 도구

## 📱 기능

- 🎯 모바일 친화적인 반응형 UI
- 🌐 P2P 실시간 멀티플레이어
- 🎨 아름다운 카드 게임 UI
- 🏆 게임 결과 모달 및 재시작
- 📊 실시간 스코어 추적

## 🛠 개발 환경 설정

```bash
# 의존성 설치
npm install

# 개발 서버 실행 (2개의 터미널 필요)
npm run res:dev  # ReScript 컴파일러 (별도 터미널)
npm run dev      # Vite 개발 서버
```

## 📦 빌드 및 배포

```bash
# 프로덕션 빌드
npm run build

# 로컬에서 프로덕션 빌드 미리보기
npm run preview

# 빌드 파일 정리
npm run clean
```

## 🌐 배포

이 프로젝트는 Cloudflare Pages 또는 GitHub Pages에 배포할 수 있습니다.

### Cloudflare Pages 배포 설정:
- **Build command**: `npm run build`
- **Build output directory**: `dist`
- **Node.js version**: `18` 또는 `20`

## 🎯 게임 규칙

1. 각 플레이어는 1-9 카드를 가집니다
2. 매 라운드마다 한 장씩 카드를 선택합니다
3. 높은 숫자가 승리합니다 (9는 1에게 집니다)
4. 먼저 5승을 달성하거나 9라운드 후 더 많이 승리한 플레이어가 최종 승리합니다
