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

/// 키가 한 번 눌린 사건.
///
/// 처음 누른 것과 꾹 눌러 자동으로 반복된 것을 구분한다.
/// 반복 입력은 소리와 진동을 내지 않는다. 초당 열 번 넘게 딸깍거리면 시끄럽다.
struct KeyPress {
    let action: KeyAction
    /// 꾹 누르고 있어서 자동 반복된 입력이면 true. 지금은 백스페이스만 반복된다.
    var isRepeat = false
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
    var fontSize: CGFloat = 22
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
            KeyDefinition(label: "ㅏㅓ", number: "3", fontSize: 21, action: .hangul(.aeo)),
            functionColumn(label: "⌫", fontSize: 21, action: .backspace),
        ],
        [
            KeyDefinition(label: "ㄹ", number: "4", action: .hangul(.consonant("ㄹ"))),
            KeyDefinition(label: "ㅁ", number: "5", action: .hangul(.consonant("ㅁ"))),
            KeyDefinition(label: "ㅗㅜ", number: "6", fontSize: 21, action: .hangul(.ou)),
            functionColumn(label: "간격", fontSize: 16, action: .space),
        ],
        [
            KeyDefinition(label: "ㅅ", number: "7", action: .hangul(.consonant("ㅅ"))),
            KeyDefinition(label: "ㅇ", number: "8", action: .hangul(.consonant("ㅇ"))),
            KeyDefinition(label: "ㅣ", number: "9", action: .hangul(.i)),
            functionColumn(label: "↵", fontSize: 19, action: .newline),
        ],
    ]

    /// 오른쪽 기능 열에 놓이는 키. 글자 열보다 좁다.
    static func functionColumn(
        label: String,
        fontSize: CGFloat,
        ratio: CGFloat = KeyboardTheme.functionColumnRatio,
        action: KeyAction
    ) -> KeyDefinition {
        KeyDefinition(
            label: label,
            style: .function,
            widthRatio: ratio,
            fontSize: fontSize,
            action: action
        )
    }

    /// 마지막 행의 왼쪽 3개 키 (획 / ㅡ / 쌍)
    static let hangulBottomRow: [KeyDefinition] = [
        KeyDefinition(label: "획", style: .function, fontSize: 16, action: .hangul(.stroke)),
        KeyDefinition(label: "ㅡ", number: "0", action: .hangul(.eu)),
        KeyDefinition(label: "쌍", style: .function, fontSize: 16, action: .hangul(.double)),
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
    static func cycled(
        _ options: [String],
        style: KeyStyle = .character,
        ratio: CGFloat = 1
    ) -> KeyDefinition {
        KeyDefinition(
            label: options.joined(),
            style: style,
            widthRatio: ratio,
            // 좁은 기능 열에 들어가는 .,?! 는 더 줄여야 네 글자가 다 들어간다.
            fontSize: options.count >= 4 ? (ratio < 1 ? 13 : 15) : 17,
            action: .cycleSymbol(options)
        )
    }

    /// 한글로 돌아가는 키. 숫자·기호 레이어 마지막 행 왼쪽 칸을 전환 키와 나눠 쓴다.
    static let toHangulKey = KeyDefinition(
        label: "한글", style: .function, fontSize: 14, action: .switchLayer(.hangul)
    )

    /// 숫자·기호 레이어 오른쪽 기능 열 (위 3칸).
    ///
    /// 한글 레이어와 달리 간격이 여기 없다. 간격은 마지막 행 셋째 칸으로 내려가고
    /// 그 자리를 .,?! 가 받는다. 원래 나랏글 배열이 그렇게 잡혀 있다.
    static let keypadRightColumn: [KeyDefinition] = [
        keypadFunction(label: "⌫", fontSize: 21, action: .backspace),
        keypadFunction(label: "↵", fontSize: 19, action: .newline),
        cycled([".", ",", "?", "!"], style: .function, ratio: KeyboardTheme.keypadFunctionColumnRatio),
    ]

    /// 숫자·기호 레이어 마지막 행 셋째 칸. 글자 열 폭을 그대로 쓰는 넓은 간격 키다.
    static let keypadSpaceKey = KeyDefinition(
        label: "간격", style: .function, fontSize: 16, action: .space
    )

    private static func keypadFunction(
        label: String, fontSize: CGFloat, action: KeyAction
    ) -> KeyDefinition {
        functionColumn(
            label: label,
            fontSize: fontSize,
            ratio: KeyboardTheme.keypadFunctionColumnRatio,
            action: action
        )
    }

    /// 숫자·기호 레이어 한 벌.
    ///
    /// 위 3행은 글자 열 3칸씩이고, 마지막 행만 모양이 다르다.
    /// 왼쪽 칸을 전환 키와 한글 키가 반씩 나눠 쓰고 셋째 칸이 간격이다.
    struct Keypad {
        let rows: [[KeyDefinition]]
        /// 마지막 행 왼쪽 칸의 전환 키 (#+= 또는 123)
        let switchKey: KeyDefinition
        /// 마지막 행 가운데 칸 (0 또는 ~…•)
        let center: KeyDefinition
    }

    /// 숫자 레이어. 전화기 자판과 같은 배열이다.
    ///
    /// ```
    /// 1        2   3    ⌫
    /// 4        5   6    ↵
    /// 7        8   9    .,?!
    /// #+= 한글  0   간격  🌐
    /// ```
    static let numberKeypad = Keypad(
        rows: [digitRow("1", "2", "3"), digitRow("4", "5", "6"), digitRow("7", "8", "9")],
        switchKey: KeyDefinition(
            label: "#+=", style: .function, fontSize: 14, action: .switchLayer(.symbols)
        ),
        center: KeyDefinition(label: "0", action: .insert("0"))
    )

    private static func digitRow(_ digits: String...) -> [KeyDefinition] {
        digits.map { KeyDefinition(label: $0, action: .insert($0)) }
    }

    /// 기호 레이어. 한 키에 서너 개씩 묶여 있고 다시 눌러 돌린다.
    ///
    /// ```
    /// (-)      ₩$¥  ^%#  ⌫
    /// {*}      +×÷  <=>  ↵
    /// [:]      "';  /\|  .,?!
    /// 123 한글  ~…•  간격  🌐
    /// ```
    static let symbolKeypad = Keypad(
        rows: [
            [cycled(["(", "-", ")"]), cycled(["₩", "$", "¥"]), cycled(["^", "%", "#"])],
            [cycled(["{", "*", "}"]), cycled(["+", "×", "÷"]), cycled(["<", "=", ">"])],
            [cycled(["[", ":", "]"]), cycled(["\"", "'", ";"]), cycled(["/", "\\", "|"])],
        ],
        switchKey: KeyDefinition(
            label: "123", style: .function, fontSize: 14, action: .switchLayer(.numbers)
        ),
        center: cycled(["~", "…", "•"])
    )

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
