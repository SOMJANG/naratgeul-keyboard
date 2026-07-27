import Foundation

/// 한글 유니코드 음절 조합/분해.
///
/// 완성형 음절 = 0xAC00 + (초성 × 21 + 중성) × 28 + 종성
enum Hangul {

    static let choTable: [Character] = [
        "ㄱ", "ㄲ", "ㄴ", "ㄷ", "ㄸ", "ㄹ", "ㅁ", "ㅂ", "ㅃ", "ㅅ",
        "ㅆ", "ㅇ", "ㅈ", "ㅉ", "ㅊ", "ㅋ", "ㅌ", "ㅍ", "ㅎ",
    ]

    static let jungTable: [Character] = [
        "ㅏ", "ㅐ", "ㅑ", "ㅒ", "ㅓ", "ㅔ", "ㅕ", "ㅖ", "ㅗ", "ㅘ",
        "ㅙ", "ㅚ", "ㅛ", "ㅜ", "ㅝ", "ㅞ", "ㅟ", "ㅠ", "ㅡ", "ㅢ", "ㅣ",
    ]

    /// 종성 테이블. 인덱스 + 1 이 실제 종성 코드가 된다 (0 = 받침 없음).
    static let jongTable: [Character] = [
        "ㄱ", "ㄲ", "ㄳ", "ㄴ", "ㄵ", "ㄶ", "ㄷ", "ㄹ", "ㄺ", "ㄻ",
        "ㄼ", "ㄽ", "ㄾ", "ㄿ", "ㅀ", "ㅁ", "ㅂ", "ㅄ", "ㅅ", "ㅆ",
        "ㅇ", "ㅈ", "ㅊ", "ㅋ", "ㅌ", "ㅍ", "ㅎ",
    ]

    private static let choSet = Set(choTable)
    private static let jungSet = Set(jungTable)
    private static let jongSet = Set(jongTable)

    static let syllableStart = 0xAC00
    static let syllableEnd = 0xD7A3

    // MARK: - 판별

    static func isChoseong(_ c: Character) -> Bool { choSet.contains(c) }
    static func isJungseong(_ c: Character) -> Bool { jungSet.contains(c) }
    static func isJongseong(_ c: Character) -> Bool { jongSet.contains(c) }

    static func isSyllable(_ c: Character) -> Bool {
        guard let scalar = c.unicodeScalars.first, c.unicodeScalars.count == 1 else { return false }
        return (syllableStart...syllableEnd).contains(Int(scalar.value))
    }

    // MARK: - 조합

    /// 초/중/종성을 완성형 음절 한 글자로 조합한다.
    static func compose(cho: Character, jung: Character, jong: Character?) -> Character? {
        guard let ci = choTable.firstIndex(of: cho),
              let vi = jungTable.firstIndex(of: jung)
        else { return nil }

        var ji = 0
        if let jong {
            guard let idx = jongTable.firstIndex(of: jong) else { return nil }
            ji = idx + 1
        }

        let code = syllableStart + (ci * 21 + vi) * 28 + ji
        guard let scalar = UnicodeScalar(code) else { return nil }
        return Character(scalar)
    }

    // MARK: - 분해

    /// 완성형 음절을 초/중/종성으로 분해한다. 음절이 아니면 nil.
    static func decompose(_ c: Character) -> (cho: Character, jung: Character, jong: Character?)? {
        guard isSyllable(c), let scalar = c.unicodeScalars.first else { return nil }

        let offset = Int(scalar.value) - syllableStart
        let ji = offset % 28
        let vi = (offset / 28) % 21
        let ci = offset / 28 / 21

        return (choTable[ci], jungTable[vi], ji > 0 ? jongTable[ji - 1] : nil)
    }
}
