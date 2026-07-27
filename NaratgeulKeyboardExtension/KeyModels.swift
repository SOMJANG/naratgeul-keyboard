import SwiftUI

/// 키 하나가 눌렸을 때 키보드가 할 일.
enum KeyAction: Equatable {
    /// 나랏글 한글 오토마타로 전달
    case hangul(NaratgeulKey)
    /// 조합을 확정하고 문자열을 그대로 삽입
    case insert(String)
    case backspace
    case space
    case newline
    /// 레이어 전환 (한글 / 영문 / 숫자 / 이모지)
    case switchLayer(KeyboardLayer)
    /// 지구본 키: 한글 → 영문 → 이모지 → 한글 순으로 돈다
    case cycleLayer
    /// 다음 키보드로 전환
    case nextKeyboard
    /// 영문 시프트 토글
    case shift
}

/// 키 모양.
enum KeyStyle {
    case character
    case function
}

struct KeyDefinition: Identifiable {
    let id = UUID()
    let label: String
    /// SF Symbol 이름. 있으면 label 대신 이걸 그린다 (VoiceOver 는 label 을 읽는다).
    var symbol: String?
    /// 키 우상단 숫자 표시
    var number: String?
    var style: KeyStyle = .character
    /// 그리드에서 차지하는 가로 비율
    var widthRatio: CGFloat = 1
    var fontSize: CGFloat = 20
    let action: KeyAction
}

enum KeyboardLayer: Equatable {
    case hangul
    case english
    case numbers
    case emoji
}

/// 나랏글 레이아웃 정의.
///
/// ```
/// ㄱ    ㄴ    ㅏㅓ   ⌫
/// ㄹ    ㅁ    ㅗㅜ   간격
/// ㅅ    ㅇ    ㅣ    ↵
/// 획    ㅡ    쌍    123 / 🌐
/// ```
enum KeyboardLayout {

    static let hangulRows: [[KeyDefinition]] = [
        [
            KeyDefinition(label: "ㄱ", number: "1", action: .hangul(.consonant("ㄱ"))),
            KeyDefinition(label: "ㄴ", number: "2", action: .hangul(.consonant("ㄴ"))),
            KeyDefinition(label: "ㅏㅓ", number: "3", fontSize: 19, action: .hangul(.aeo)),
            KeyDefinition(label: "⌫", style: .function, fontSize: 19, action: .backspace),
        ],
        [
            KeyDefinition(label: "ㄹ", number: "4", action: .hangul(.consonant("ㄹ"))),
            KeyDefinition(label: "ㅁ", number: "5", action: .hangul(.consonant("ㅁ"))),
            KeyDefinition(label: "ㅗㅜ", number: "6", fontSize: 19, action: .hangul(.ou)),
            KeyDefinition(label: "간격", style: .function, fontSize: 14, action: .space),
        ],
        [
            KeyDefinition(label: "ㅅ", number: "7", action: .hangul(.consonant("ㅅ"))),
            KeyDefinition(label: "ㅇ", number: "8", action: .hangul(.consonant("ㅇ"))),
            KeyDefinition(label: "ㅣ", number: "9", action: .hangul(.i)),
            KeyDefinition(label: "↵", style: .function, fontSize: 17, action: .newline),
        ],
    ]

    /// 마지막 행의 왼쪽 3개 키 (획 / ㅡ / 쌍)
    static let hangulBottomRow: [KeyDefinition] = [
        KeyDefinition(label: "획", style: .function, fontSize: 14, action: .hangul(.stroke)),
        KeyDefinition(label: "ㅡ", number: "0", action: .hangul(.eu)),
        KeyDefinition(label: "쌍", style: .function, fontSize: 14, action: .hangul(.double)),
    ]

    // MARK: - 영문 (QWERTY)

    static let englishRows: [[String]] = [
        ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"],
        ["a", "s", "d", "f", "g", "h", "j", "k", "l"],
        ["z", "x", "c", "v", "b", "n", "m"],
    ]

    // MARK: - 숫자 / 기호

    static let numberRows: [[String]] = [
        ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"],
        ["-", "/", ":", ";", "(", ")", "₩", "&", "@"],
        [".", ",", "?", "!", "'", "\"", "%"],
    ]

    // MARK: - 이모지

    /// 시스템 이모지 키보드로는 넘어갈 방법이 없어서 (공개 API 가 없다)
    /// 자주 쓰는 것만 골라 직접 담았다. 8열 격자로 그린다.
    static let emojis: [String] = [
        "😀", "😃", "😄", "😁", "😆", "😅", "🤣", "😂",
        "🙂", "🙃", "😉", "😊", "😇", "🥰", "😍", "🤩",
        "😘", "😗", "😚", "😙", "🥲", "😋", "😛", "😜",
        "🤪", "😝", "🤗", "🤭", "🤔", "🤐", "😐", "😑",
        "😶", "😏", "😒", "🙄", "😬", "😔", "😪", "😴",
        "🥱", "😷", "🤒", "🤕", "🥵", "🥶", "😵", "🤯",
        "🤠", "🥳", "😎", "🤓", "🧐", "😕", "😟", "🙁",
        "😮", "😯", "😲", "😳", "🥺", "😦", "😨", "😰",
        "😥", "😢", "😭", "😱", "😖", "😞", "😓", "😩",
        "😫", "😤", "😡", "😠", "🤬", "😈", "💀", "💩",
        "👍", "👎", "👌", "✌️", "🤞", "🤟", "🤙", "👏",
        "🙌", "🙏", "💪", "🫶", "👋", "🤝", "✊", "🙇",
        "👀", "🫠", "🫡", "🤷", "🤦", "💤", "🗣️", "👑",
        "❤️", "🧡", "💛", "💚", "💙", "💜", "🖤", "🤍",
        "💔", "💕", "💖", "💯", "🔥", "✨", "🎉", "🎊",
        "🐶", "🐱", "🐭", "🐹", "🐰", "🦊", "🐻", "🐼",
        "🐨", "🐯", "🦁", "🐮", "🐷", "🐸", "🐵", "🐔",
        "🍎", "🍊", "🍋", "🍉", "🍓", "🍒", "🍑", "🍌",
        "🍕", "🍔", "🍟", "🌭", "🍿", "🍜", "🍣", "🍰",
        "☕️", "🍺", "🍻", "🥂", "🍷", "🧃", "🥤", "🍭",
        "⚽️", "🏀", "🏈", "⚾️", "🎾", "🏐", "🎱", "🏓",
        "🚗", "✈️", "🚀", "🚲", "🏠", "🌈", "☀️", "🌙",
        "⭐️", "⚡️", "❄️", "🌸", "🌹", "🌻", "🍀", "🌍",
        "📱", "💻", "⌚️", "📷", "🎧", "🎵", "📚", "✏️",
        "💰", "🎁", "🔑", "🔔", "⏰", "📅", "✅", "❌",
    ]
}
