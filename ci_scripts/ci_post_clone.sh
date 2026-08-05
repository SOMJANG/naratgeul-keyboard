#!/bin/sh
#
# Xcode Cloud 가 저장소를 클론한 직후 실행한다.
#
# 팀 ID 는 공개 저장소에 두지 않는다. 대신 워크플로의 환경변수로 받아
# 빌드 직전에 project.pbxproj 에 써넣는다. 이 파일은 클론된 사본이라
# 여기서 고쳐도 저장소에는 남지 않는다.
#
set -eu

if [ -z "${DEVELOPMENT_TEAM:-}" ]; then
	echo "error: DEVELOPMENT_TEAM 환경변수가 없다."
	echo "       App Store Connect > Xcode Cloud > 워크플로 편집 > Environment 에 추가할 것."
	exit 1
fi

PBXPROJ="${CI_PRIMARY_REPOSITORY_PATH}/NaratgeulKeyboard.xcodeproj/project.pbxproj"

if [ ! -f "$PBXPROJ" ]; then
	echo "error: project.pbxproj 를 못 찾았다: $PBXPROJ"
	exit 1
fi

# 자동 서명을 쓰는 빌드 설정 네 곳(앱 Debug/Release, 확장 Debug/Release)에 팀을 붙인다.
sed -i '' \
	"s|CODE_SIGN_STYLE = Automatic;|CODE_SIGN_STYLE = Automatic; DEVELOPMENT_TEAM = ${DEVELOPMENT_TEAM};|g" \
	"$PBXPROJ"

# pbxproj 포맷이 바뀌어 치환이 빗나가면 서명 오류로 뒤늦게 터진다.
# 여기서 건수를 확인해 즉시 실패시킨다.
INJECTED=$(grep -c "DEVELOPMENT_TEAM = ${DEVELOPMENT_TEAM};" "$PBXPROJ" || true)
if [ "$INJECTED" -ne 4 ]; then
	echo "error: 팀 ID 주입이 ${INJECTED}건이다. 4건이어야 한다."
	echo "       project.pbxproj 의 CODE_SIGN_STYLE 항목이 바뀌었는지 확인할 것."
	exit 1
fi

echo "팀 ID 주입 완료 (${INJECTED}건)"
