import SwiftUI

/// 키 하나가 눌렸을 때 키보드가 할 일.
enum KeyAction: Equatable {
    /// 나랏글 한글 오토마타로 전달
    case hangul(NaratgeulKey)
    /// 조합을 확정하고 문자열을 그대로 삽입
    case insert(String)
    /// 기호 묶음 키. 같은 키를 다시 누르면 다음 기호로 바뀐다
    case cycleSymbol([String])
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
    case symbols
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

    /// 기호가 여러 개 묶인 키.
    ///
    /// 나랏글의 ㅏㅓ·ㅗㅜ 키와 같은 방식이다. 같은 키를 다시 누르면 방금 넣은 기호가
    /// 다음 기호로 바뀐다. 라벨은 들어 있는 순서 그대로 이어 붙여 보여 준다.
    static func cycled(_ options: [String]) -> KeyDefinition {
        KeyDefinition(
            label: options.joined(),
            fontSize: options.count >= 4 ? 13 : 15,
            action: .cycleSymbol(options)
        )
    }

    /// 한글로 돌아가는 키. 숫자·기호 레이어의 오른쪽 아래에서 지구본과 자리를 나눈다.
    static let toHangulKey = KeyDefinition(
        label: "한글", style: .function, fontSize: 12, action: .switchLayer(.hangul)
    )

    /// 숫자·기호 레이어 오른쪽 열.
    ///
    /// 한글 레이어(⌫ · 간격 · ↵)와 같은 자리를 지킨다.
    /// 레이어를 오가도 손이 기억하는 위치가 흐트러지지 않게 하려는 것이다.
    static let keypadRightColumn: [KeyDefinition] = [
        KeyDefinition(label: "⌫", style: .function, fontSize: 19, action: .backspace),
        KeyDefinition(label: "간격", style: .function, fontSize: 14, action: .space),
        KeyDefinition(label: "↵", style: .function, fontSize: 17, action: .newline),
    ]

    /// 숫자 레이어 왼쪽 3열. 전화기 자판과 같은 배열이다.
    ///
    /// ```
    /// 1     2   3    ⌫
    /// 4     5   6    간격
    /// 7     8   9    ↵
    /// .,?!  0   #+=  한글 / 🌐
    /// ```
    static let numberRows: [[KeyDefinition]] = [
        digitRow("1", "2", "3"),
        digitRow("4", "5", "6"),
        digitRow("7", "8", "9"),
        [
            cycled([".", ",", "?", "!"]),
            KeyDefinition(label: "0", action: .insert("0")),
            KeyDefinition(label: "#+=", style: .function, fontSize: 14, action: .switchLayer(.symbols)),
        ],
    ]

    private static func digitRow(_ digits: String...) -> [KeyDefinition] {
        digits.map { KeyDefinition(label: $0, action: .insert($0)) }
    }

    /// 기호 레이어 왼쪽 3열. 한 키에 서너 개씩 묶여 있고 다시 눌러 돌린다.
    ///
    /// ```
    /// (-)   ₩$¥  ^%#  ⌫
    /// {*}   +×÷  <=>  간격
    /// [:]   "';  /\|  ↵
    /// .,?!  ~…•  123  한글 / 🌐
    /// ```
    static let symbolRows: [[KeyDefinition]] = [
        [cycled(["(", "-", ")"]), cycled(["₩", "$", "¥"]), cycled(["^", "%", "#"])],
        [cycled(["{", "*", "}"]), cycled(["+", "×", "÷"]), cycled(["<", "=", ">"])],
        [cycled(["[", ":", "]"]), cycled(["\"", "'", ";"]), cycled(["/", "\\", "|"])],
        [
            cycled([".", ",", "?", "!"]),
            cycled(["~", "…", "•"]),
            KeyDefinition(label: "123", style: .function, fontSize: 14, action: .switchLayer(.numbers)),
        ],
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
