@plugins/sef-2026/ 플러그인에 'setup' 스킬을 생성합니다. setup 스킬은 프로젝트 초기화를 실행하는 스킬입니다.
현재 플러그인 구조가 @plugins/sef-2026-public/ @plugins/sef-2026-private/ 으로 나뉘어져 있고, 각 플러그인 별로 project-init 스킬이 있습니다.
제가 원하는 건 @plugins/sef-2026-public/ @plugins/sef-2026-private/ 두 플러그인을 @plugins/sef-2026/ 에 통합하는 것입니다.
사용자가 setup 스킬 실행 시 askUserQuestion을 통해 프로젝트 종류(private/public)를 선택할 수 있도록 합니다.
