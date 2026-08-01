import Foundation

/// 연습 모드에 나오는 문제.
struct PracticeItem {
    let text: String
    /// 이 문제로 익히게 되는 것. 화면에 한 줄로 보여 준다.
    let hint: String
}

/// 연습 단계.
///
/// 쉬운 것부터 차례로 올라간다. 처음 쓰는 사람이 낯설어하는 순서대로 —
/// 자음 자리 → 획 → 쌍 → 모음 → 받침 → 실제 문장 — 짜 두었다.
struct PracticeStage: Identifiable {
    let id = UUID()
    let title: String
    let summary: String
    let items: [PracticeItem]
}

enum PracticeCourse {

    static let stages: [PracticeStage] = [
        PracticeStage(
            title: "자음 자리 익히기",
            summary: "키에 찍힌 자음 여덟 개부터. 누른 대로 그냥 나온다.",
            items: [
                PracticeItem(text: "가나", hint: "ㄱ · ㄴ 은 첫 줄 왼쪽 두 칸"),
                PracticeItem(text: "라마", hint: "ㄹ · ㅁ 은 둘째 줄"),
                PracticeItem(text: "사아", hint: "ㅅ · ㅇ 은 셋째 줄"),
                PracticeItem(text: "나라", hint: "여기까지가 그냥 눌러 나오는 자음"),
            ]
        ),

        PracticeStage(
            title: "획 키",
            summary: "가장 중요한 키. 자음에 획을 더해 다른 자음으로 바꾼다.",
            items: [
                PracticeItem(text: "카", hint: "ㄱ 에 획 하나 → ㅋ"),
                PracticeItem(text: "다", hint: "ㄴ 에 획 하나 → ㄷ"),
                PracticeItem(text: "타", hint: "ㄴ 에 획 두 번 → ㄷ → ㅌ"),
                PracticeItem(text: "바", hint: "ㅁ 에 획 하나 → ㅂ"),
                PracticeItem(text: "파", hint: "ㅁ 에 획 두 번 → ㅂ → ㅍ"),
                PracticeItem(text: "자", hint: "ㅅ 에 획 하나 → ㅈ"),
                PracticeItem(text: "차", hint: "ㅅ 에 획 두 번 → ㅈ → ㅊ"),
                PracticeItem(text: "하", hint: "ㅇ 에 획 하나 → ㅎ"),
            ]
        ),

        PracticeStage(
            title: "쌍 키",
            summary: "된소리를 만든다. 자음을 낸 다음 바로 누른다.",
            items: [
                PracticeItem(text: "까", hint: "ㄱ 다음에 쌍"),
                PracticeItem(text: "따", hint: "ㄷ 을 먼저 만들고 쌍"),
                PracticeItem(text: "빠", hint: "ㅂ 을 먼저 만들고 쌍"),
                PracticeItem(text: "싸", hint: "ㅅ 다음에 쌍"),
                PracticeItem(text: "짜", hint: "ㅈ 을 먼저 만들고 쌍"),
                PracticeItem(text: "토끼", hint: "획과 쌍을 섞어 본다"),
            ]
        ),

        PracticeStage(
            title: "모음 만들기",
            summary: "ㅏㅓ · ㅗㅜ 키는 두 번 누르면 뒤 글자가 된다. 획을 더하면 ㅑㅕㅛㅠ.",
            items: [
                PracticeItem(text: "가거", hint: "ㅏㅓ 한 번은 ㅏ, 두 번은 ㅓ"),
                PracticeItem(text: "고구", hint: "ㅗㅜ 도 마찬가지"),
                PracticeItem(text: "야여", hint: "ㅏ · ㅓ 에 획을 더하면 ㅑ · ㅕ"),
                PracticeItem(text: "요유", hint: "ㅗ · ㅜ 에 획을 더하면 ㅛ · ㅠ"),
                PracticeItem(text: "그미", hint: "ㅡ 와 ㅣ 는 제 키가 따로 있다"),
                PracticeItem(text: "개내", hint: "ㅏ 뒤에 ㅣ 를 붙이면 ㅐ"),
                PracticeItem(text: "회사", hint: "ㅗ 뒤에 ㅣ 를 붙이면 ㅚ"),
                PracticeItem(text: "과자", hint: "ㅗ 뒤에 ㅏ 를 붙이면 ㅘ"),
                PracticeItem(text: "의사", hint: "ㅡ 뒤에 ㅣ 를 붙이면 ㅢ"),
            ]
        ),

        PracticeStage(
            title: "받침",
            summary: "모음까지 친 다음 자음을 누르면 받침으로 들어간다.",
            items: [
                PracticeItem(text: "산", hint: "ㅅ · ㅏ · ㄴ 순서 그대로"),
                PracticeItem(text: "밥", hint: "받침에도 획 키를 쓴다"),
                PracticeItem(text: "꽃", hint: "쌍과 획을 받침까지"),
                PracticeItem(text: "앉다", hint: "겹받침은 두 자음을 이어서"),
                PracticeItem(text: "많다", hint: "ㄴ 다음 ㅎ 이면 ㄶ"),
                PracticeItem(text: "닭", hint: "ㄹ 다음 ㄱ 이면 ㄺ"),
                PracticeItem(text: "삶", hint: "ㄹ 다음 ㅁ 이면 ㄻ"),
                PracticeItem(text: "넓다", hint: "ㄻ 에 획을 더하면 ㄼ"),
                PracticeItem(text: "값", hint: "ㅂ 다음 ㅅ 이면 ㅄ"),
            ]
        ),

        PracticeStage(
            title: "낱말",
            summary: "이제 손이 알아서 가는지 본다.",
            items: [
                PracticeItem(text: "안녕", hint: ""),
                PracticeItem(text: "고맙습니다", hint: ""),
                PracticeItem(text: "사랑해요", hint: ""),
                PracticeItem(text: "잘 지내요", hint: "간격 키도 함께"),
                PracticeItem(text: "밥 먹었어요", hint: ""),
                PracticeItem(text: "전화할게요", hint: ""),
            ]
        ),

        PracticeStage(
            title: "문장",
            summary: "실제로 보낼 만한 말들.",
            items: [
                PracticeItem(text: "오늘 날씨가 좋네요", hint: ""),
                PracticeItem(text: "저녁 뭐 드셨어요?", hint: "물음표는 123 탭 오른쪽 아래"),
                PracticeItem(text: "이따가 다시 연락드릴게요", hint: ""),
                PracticeItem(text: "우리 주말에 만나요", hint: ""),
                PracticeItem(text: "건강 잘 챙기세요", hint: ""),
            ]
        ),
    ]

    /// 문제 전부. 테스트에서 키 순서가 제대로 나오는지 훑는 데 쓴다.
    static var allItems: [PracticeItem] { stages.flatMap(\.items) }
}
