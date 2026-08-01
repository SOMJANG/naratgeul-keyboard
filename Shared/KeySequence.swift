import Foundation

/// 글자를 보고 "어떤 키를 어떤 순서로 누르면 되는지" 되짚어 준다.
///
/// `NaratgeulEngine` 이 키를 글자로 만드는 쪽이라면 이쪽은 그 반대다.
/// 연습 화면에서 힌트를 보여 주는 데 쓴다.
///
/// 엔진의 조합 규칙을 손으로 뒤집어 놓은 표라서, 둘이 어긋나면
/// 힌트가 조용히 틀려 있게 된다. 그래서 테스트에서 여기가 내놓은 순서를
/// 다시 엔진에 넣어 원래 글자가 나오는지 전부 확인한다.
enum KeySequence {

    /// 문자열 전체를 치는 키 순서.
    /// - Returns: 나랏글로 칠 수 없는 글자가 하나라도 있으면 `nil`
    static func keys(for text: String) -> [NaratgeulKey]? {
        var result: [NaratgeulKey] = []
        for character in text {
            guard let keys = self.keys(for: character) else { return nil }
            result += keys
        }
        return result
    }

    /// 글자 하나를 치는 키 순서.
    static func keys(for character: Character) -> [NaratgeulKey]? {
        if character == " " { return [.space] }
        if character == "\n" { return [.newline] }

        if let parts = Hangul.decompose(character) {
            guard let cho = consonantKeys[parts.cho],
                  let jung = vowelKeys[parts.jung]
            else { return nil }

            var result = cho + jung
            if let jong = parts.jong {
                guard let jongKeys = jongseongKeys(jong) else { return nil }
                result += jongKeys
            }
            return result
        }

        // 낱자 그대로 (ㄱ, ㅏ 처럼)
        if let keys = consonantKeys[character] ?? vowelKeys[character] { return keys }

        // 숫자와 영문은 제 키를 한 번씩 누르면 그대로 나온다
        if character.isASCII, character.isNumber || character.isLetter {
            return [.literal(String(character))]
        }

        // 묶인 기호 키는 원하는 기호가 나올 때까지 같은 키를 거듭 누른다
        for options in symbolCycles {
            if let index = options.firstIndex(of: String(character)) {
                return Array(repeating: NaratgeulKey.cycle(options), count: index + 1)
            }
        }
        return nil
    }

    /// 받침. 겹받침은 두 자음을 이어서 친다.
    private static func jongseongKeys(_ jong: Character) -> [NaratgeulKey]? {
        if let keys = consonantKeys[jong] { return keys }
        guard let (first, second) = compoundJong[jong],
              let firstKeys = consonantKeys[first],
              let secondKeys = consonantKeys[second]
        else { return nil }
        return firstKeys + secondKeys
    }

    // MARK: - 표

    /// 자음. 획 키는 ㄴ→ㄷ→ㅌ 처럼 3단으로 돌고, 쌍 키는 지금 자음을 된소리로 바꾼다.
    private static let consonantKeys: [Character: [NaratgeulKey]] = [
        "ㄱ": [.consonant("ㄱ")],
        "ㅋ": [.consonant("ㄱ"), .stroke],
        "ㄲ": [.consonant("ㄱ"), .double],
        "ㄴ": [.consonant("ㄴ")],
        "ㄷ": [.consonant("ㄴ"), .stroke],
        "ㅌ": [.consonant("ㄴ"), .stroke, .stroke],
        "ㄸ": [.consonant("ㄴ"), .stroke, .double],
        "ㄹ": [.consonant("ㄹ")],
        "ㅁ": [.consonant("ㅁ")],
        "ㅂ": [.consonant("ㅁ"), .stroke],
        "ㅍ": [.consonant("ㅁ"), .stroke, .stroke],
        "ㅃ": [.consonant("ㅁ"), .stroke, .double],
        "ㅅ": [.consonant("ㅅ")],
        "ㅈ": [.consonant("ㅅ"), .stroke],
        "ㅊ": [.consonant("ㅅ"), .stroke, .stroke],
        "ㅆ": [.consonant("ㅅ"), .double],
        "ㅉ": [.consonant("ㅅ"), .stroke, .double],
        "ㅇ": [.consonant("ㅇ")],
        "ㅎ": [.consonant("ㅇ"), .stroke],
    ]

    /// 모음. ㅏㅓ·ㅗㅜ 키는 두 번 누르면 뒤 글자가 되고,
    /// 획을 더하면 ㅑㅕㅛㅠ 가 된다. ㅐㅔ 계열은 ㅣ 를 덧붙인다.
    private static let vowelKeys: [Character: [NaratgeulKey]] = [
        "ㅏ": [.aeo],
        "ㅓ": [.aeo, .aeo],
        "ㅑ": [.aeo, .stroke],
        "ㅕ": [.aeo, .aeo, .stroke],
        "ㅗ": [.ou],
        "ㅜ": [.ou, .ou],
        "ㅛ": [.ou, .stroke],
        "ㅠ": [.ou, .ou, .stroke],
        "ㅣ": [.i],
        "ㅡ": [.eu],
        "ㅐ": [.aeo, .i],
        "ㅔ": [.aeo, .aeo, .i],
        "ㅒ": [.aeo, .stroke, .i],
        "ㅖ": [.aeo, .aeo, .stroke, .i],
        "ㅚ": [.ou, .i],
        "ㅟ": [.ou, .ou, .i],
        "ㅢ": [.eu, .i],
        "ㅘ": [.ou, .aeo],
        "ㅙ": [.ou, .aeo, .i],
        "ㅝ": [.ou, .ou, .aeo],
        "ㅞ": [.ou, .ou, .aeo, .i],
    ]

    /// 숫자·기호 레이어의 묶음 키. `KeyboardLayout` 의 배열과 같은 순서여야 한다.
    ///
    /// 같은 키에서 나오는 기호 두 개를 잇달아 칠 수는 없다. "?!" 처럼 치면
    /// 뒤엣것이 앞엣것을 덮어쓴다. 연습 문제에는 그런 조합을 넣지 않는다.
    private static let symbolCycles: [[String]] = [
        ["(", "-", ")"], ["₩", "$", "¥"], ["^", "%", "#"],
        ["{", "*", "}"], ["+", "×", "÷"], ["<", "=", ">"],
        ["[", ":", "]"], ["\"", "'", ";"], ["/", "\\", "|"],
        ["~", "…", "•"], [".", ",", "?", "!"],
    ]

    /// 겹받침을 앞뒤 자음으로 가른다.
    private static let compoundJong: [Character: (Character, Character)] = [
        "ㄳ": ("ㄱ", "ㅅ"), "ㄵ": ("ㄴ", "ㅈ"), "ㄶ": ("ㄴ", "ㅎ"),
        "ㄺ": ("ㄹ", "ㄱ"), "ㄻ": ("ㄹ", "ㅁ"), "ㄼ": ("ㄹ", "ㅂ"),
        "ㄽ": ("ㄹ", "ㅅ"), "ㄾ": ("ㄹ", "ㅌ"), "ㄿ": ("ㄹ", "ㅍ"),
        "ㅀ": ("ㄹ", "ㅎ"), "ㅄ": ("ㅂ", "ㅅ"),
    ]
}

extension NaratgeulKey {
    /// 연습 화면에서 보여 줄 키 이름. 키보드에 찍힌 라벨과 같게 맞춘다.
    var practiceLabel: String {
        switch self {
        case .consonant(let c): return String(c)
        case .aeo: return "ㅏㅓ"
        case .ou: return "ㅗㅜ"
        case .i: return "ㅣ"
        case .eu: return "ㅡ"
        case .stroke: return "획"
        case .double: return "쌍"
        case .backspace: return "⌫"
        case .space: return "간격"
        case .newline: return "↵"
        case .literal(let text): return text
        case .cycle(let options): return options.joined()
        }
    }
}
