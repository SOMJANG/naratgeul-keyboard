import Foundation

/// 엔진이 한 번의 입력에 대해 내놓는 결과.
///
/// 뷰 컨트롤러는 이 값을 그대로 `UITextDocumentProxy` 에 반영한다.
/// - `deleteCommitted` 만큼 확정된 글자를 지우고
/// - `commit` 을 삽입한 뒤
/// - `preedit`(조합 중인 글자, 항상 0~1자) 를 붙인다.
struct KeyOutput: Equatable {
    var deleteCommitted: Int = 0
    var commit: String = ""
    var preedit: String = ""
}

/// 나랏글 입력 방식의 키.
enum NaratgeulKey: Equatable {
    /// 자음 키 (ㄱ ㄴ ㄹ ㅁ ㅅ ㅇ)
    case consonant(Character)
    /// ㅏ/ㅓ 토글 키
    case aeo
    /// ㅗ/ㅜ 토글 키
    case ou
    /// ㅣ 키
    case i
    /// ㅡ 키
    case eu
    /// 획 추가
    case stroke
    /// 쌍자음
    case double
    case backspace
    case space
    case newline
    /// 한글 조합과 무관한 문자 (영문, 숫자, 기호)
    case literal(String)
    /// 기호가 여러 개 묶인 키. 같은 키를 다시 누르면 다음 기호로 바뀐다.
    case cycle([String])
}

/// 나랏글 한글 오토마타.
///
/// 나랏글은 천지인과 달리 아래아(ㆍ)를 쓰지 않는다.
/// 모음키는 `ㅏㅓ`, `ㅗㅜ`, `ㅣ`, `ㅡ` 네 개뿐이고
/// ㅑㅕㅛㅠ 는 획 추가로, ㅐㅔ 계열은 ㅣ 를 덧붙여 만든다.
final class NaratgeulEngine {

    // MARK: - 조합 규칙

    /// 겹받침 조합: 종성 + 자음 → 겹받침
    private static let compoundJong: [String: Character] = [
        "ㄱ+ㅅ": "ㄳ", "ㄴ+ㅈ": "ㄵ", "ㄴ+ㅎ": "ㄶ",
        "ㄹ+ㄱ": "ㄺ", "ㄹ+ㅁ": "ㄻ", "ㄹ+ㅂ": "ㄼ",
        "ㄹ+ㅅ": "ㄽ", "ㄹ+ㅌ": "ㄾ", "ㄹ+ㅍ": "ㄿ",
        "ㄹ+ㅎ": "ㅀ", "ㅂ+ㅅ": "ㅄ",
    ]

    /// 겹받침 분해: 뒤 자음이 다음 음절의 초성으로 넘어갈 때 사용
    private static let splitJong: [Character: (Character, Character)] = [
        "ㄳ": ("ㄱ", "ㅅ"), "ㄵ": ("ㄴ", "ㅈ"), "ㄶ": ("ㄴ", "ㅎ"),
        "ㄺ": ("ㄹ", "ㄱ"), "ㄻ": ("ㄹ", "ㅁ"), "ㄼ": ("ㄹ", "ㅂ"),
        "ㄽ": ("ㄹ", "ㅅ"), "ㄾ": ("ㄹ", "ㅌ"), "ㄿ": ("ㄹ", "ㅍ"),
        "ㅀ": ("ㄹ", "ㅎ"), "ㅄ": ("ㅂ", "ㅅ"),
    ]

    /// 모음 결합 규칙
    private static let vowelCombine: [String: Character] = [
        "ㅏ+ㅣ": "ㅐ", "ㅓ+ㅣ": "ㅔ", "ㅑ+ㅣ": "ㅒ", "ㅕ+ㅣ": "ㅖ",
        "ㅗ+ㅣ": "ㅚ", "ㅜ+ㅣ": "ㅟ", "ㅡ+ㅣ": "ㅢ",
        "ㅗ+ㅏ": "ㅘ", "ㅘ+ㅣ": "ㅙ",
        "ㅜ+ㅓ": "ㅝ", "ㅝ+ㅣ": "ㅞ",
    ]

    /// 획 추가 규칙. 자음은 3단 순환(ㄴ→ㄷ→ㅌ→ㄴ), 모음은 ㅑㅕㅛㅠ 토글.
    private static let stroke: [Character: Character] = [
        "ㄱ": "ㅋ", "ㅋ": "ㄱ",
        "ㄴ": "ㄷ", "ㄷ": "ㅌ", "ㅌ": "ㄴ",
        "ㅁ": "ㅂ", "ㅂ": "ㅍ", "ㅍ": "ㅁ",
        "ㅅ": "ㅈ", "ㅈ": "ㅊ", "ㅊ": "ㅅ",
        "ㅇ": "ㅎ", "ㅎ": "ㅇ",
        "ㅏ": "ㅑ", "ㅑ": "ㅏ", "ㅓ": "ㅕ", "ㅕ": "ㅓ",
        "ㅗ": "ㅛ", "ㅛ": "ㅗ", "ㅜ": "ㅠ", "ㅠ": "ㅜ",
    ]

    /// 쌍자음 규칙
    private static let doubled: [Character: Character] = [
        "ㄱ": "ㄲ", "ㄲ": "ㄱ", "ㄷ": "ㄸ", "ㄸ": "ㄷ",
        "ㅂ": "ㅃ", "ㅃ": "ㅂ", "ㅅ": "ㅆ", "ㅆ": "ㅅ",
        "ㅈ": "ㅉ", "ㅉ": "ㅈ",
    ]

    // MARK: - 조합 상태

    private var cho: Character?
    private var jung: Character?
    private var jong: Character?
    /// 중성을 만들기까지 눌린 모음 순서. 백스페이스로 한 단계씩 되돌릴 때 쓴다.
    private var vowelSeq: [Character] = []
    private var lastKey: NaratgeulKey?

    /// 기호 묶음 키에서 지금 몇 번째 기호를 넣어 뒀는지.
    private var cycleIndex = 0

    /// 이번 입력에서 확정된 글자들
    private var pendingCommit = ""

    var isComposing: Bool { cho != nil || jung != nil }

    // MARK: - 공개 API

    /// 키 하나를 처리하고 프록시에 반영할 내용을 돌려준다.
    ///
    /// - Parameter contextBefore: 커서 앞 텍스트. 조합 상태가 비었을 때
    ///   백스페이스·획 추가가 이미 확정된 글자를 건드리기 위해 필요하다.
    func handle(_ key: NaratgeulKey, contextBefore: String?) -> KeyOutput {
        pendingCommit = ""
        var deleteCount = 0

        switch key {
        case .consonant(let c):
            input(consonant: c)
        case .aeo:
            inputAeo()
        case .ou:
            inputOu()
        case .i:
            input(vowel: "ㅣ")
        case .eu:
            input(vowel: "ㅡ")
        case .stroke:
            deleteCount = applyStroke(contextBefore: contextBefore)
        case .double:
            applyDouble()
        case .backspace:
            deleteCount = applyBackspace(contextBefore: contextBefore)
        case .space:
            flush()
            pendingCommit += " "
        case .newline:
            flush()
            pendingCommit += "\n"
        case .literal(let text):
            flush()
            pendingCommit += text
        case .cycle(let options):
            deleteCount = inputCycle(options, contextBefore: contextBefore)
        }

        lastKey = key
        return KeyOutput(deleteCommitted: deleteCount, commit: pendingCommit, preedit: composedText)
    }

    /// 조합 중인 내용을 확정하고 상태를 비운다. 키보드가 사라질 때 호출한다.
    func reset() {
        cho = nil
        jung = nil
        jong = nil
        vowelSeq = []
        lastKey = nil
        cycleIndex = 0
        pendingCommit = ""
    }

    /// 현재 조합 중인 글자 (0자 또는 1자)
    var composedText: String {
        if cho == nil && jung == nil { return "" }
        if let cho, jung == nil { return String(cho) }
        if cho == nil, let jung { return String(jung) }
        guard let cho, let jung else { return "" }
        if let syllable = Hangul.compose(cho: cho, jung: jung, jong: jong) {
            return String(syllable)
        }
        return String(cho) + String(jung) + (jong.map(String.init) ?? "")
    }

    // MARK: - 자음

    private func input(consonant c: Character) {
        if cho == nil && jung == nil {
            cho = c
        } else if cho != nil && jung == nil {
            // 초성만 있는 상태에서 자음이 또 오면 앞 자음을 흘려보낸다
            pendingCommit += String(cho!)
            cho = c
            jung = nil
            jong = nil
            vowelSeq = []
        } else if cho == nil, let jung {
            pendingCommit += String(jung)
            cho = c
            self.jung = nil
            jong = nil
            vowelSeq = []
        } else if cho != nil, jung != nil, jong == nil {
            if Hangul.isJongseong(c) {
                jong = c
            } else {
                flush()
                cho = c
            }
        } else if cho != nil, jung != nil, let jong {
            if let compound = Self.compoundJong["\(jong)+\(c)"] {
                self.jong = compound
            } else {
                flush()
                cho = c
            }
        }
    }

    // MARK: - 모음

    private func input(vowel v: Character) {
        if cho == nil && jung == nil {
            jung = v
            vowelSeq = [v]
        } else if cho != nil && jung == nil {
            jung = v
            vowelSeq = [v]
        } else if cho == nil, let current = jung {
            if let merged = Self.vowelCombine["\(current)+\(v)"] {
                jung = merged
                vowelSeq.append(v)
            } else {
                pendingCommit += String(current)
                jung = v
                vowelSeq = [v]
            }
        } else if cho != nil, let current = jung, jong == nil {
            if let merged = Self.vowelCombine["\(current)+\(v)"] {
                jung = merged
                vowelSeq.append(v)
            } else {
                flush()
                jung = v
                vowelSeq = [v]
            }
        } else if let cho, let jung, let jong {
            // 받침이 있는데 모음이 오면 받침이 다음 음절의 초성으로 넘어간다
            var nextCho = jong
            var keepJong: Character?
            if let (first, second) = Self.splitJong[jong] {
                keepJong = first
                nextCho = second
            }
            if let syllable = Hangul.compose(cho: cho, jung: jung, jong: keepJong) {
                pendingCommit += String(syllable)
            }
            self.cho = nextCho
            self.jung = v
            self.jong = nil
            vowelSeq = [v]
        }
    }

    /// ㅏ/ㅓ 키. 같은 키를 연달아 누르면 ㅏ↔ㅓ 로 토글하고,
    /// ㅗ/ㅜ 뒤에서는 ㅘ/ㅝ 를 만든다.
    private func inputAeo() {
        if lastKey == .aeo, let current = jung, current == "ㅏ" || current == "ㅓ",
           jong == nil, vowelSeq.count == 1 {
            let toggled: Character = current == "ㅏ" ? "ㅓ" : "ㅏ"
            jung = toggled
            vowelSeq = [toggled]
            return
        }
        if jong == nil, jung == "ㅗ" {
            jung = "ㅘ"
            vowelSeq.append("ㅏ")
            return
        }
        if jong == nil, jung == "ㅜ" {
            jung = "ㅝ"
            vowelSeq.append("ㅓ")
            return
        }
        input(vowel: "ㅏ")
    }

    /// ㅗ/ㅜ 키. 같은 키를 연달아 누르면 ㅗ↔ㅜ 로 토글한다.
    private func inputOu() {
        if lastKey == .ou, let current = jung, current == "ㅗ" || current == "ㅜ",
           jong == nil, vowelSeq.count == 1 {
            let toggled: Character = current == "ㅗ" ? "ㅜ" : "ㅗ"
            jung = toggled
            vowelSeq = [toggled]
            return
        }
        input(vowel: "ㅗ")
    }

    // MARK: - 획 추가 / 쌍자음

    /// 획 추가. 조합 중인 자모가 없으면 커서 앞 글자를 대상으로 삼는다.
    /// - Returns: 지워야 할 확정 글자 수
    private func applyStroke(contextBefore: String?) -> Int {
        if let current = jong {
            if let next = Self.stroke[current], Hangul.isJongseong(next) {
                jong = next
            }
            return 0
        }
        if let current = jung {
            if let next = Self.stroke[current], Hangul.isJungseong(next) {
                jung = next
            }
            return 0
        }
        if let current = cho {
            guard let next = Self.stroke[current] else { return 0 }
            cho = next

            // 앞 글자 받침과 겹받침을 이룰 수 있으면 되돌려 붙인다.
            //
            // 예: "안" 뒤에 ㅅ 을 누르면 ㄴ+ㅅ 은 겹받침이 아니라서
            // ㅅ 이 다음 글자의 초성으로 밀려난다. 여기서 획을 눌러 ㅈ 이 되면
            // 그제서야 ㄴ+ㅈ = ㄵ 가 성립하므로 "안ㅈ" 이 아니라 "앉" 이 되어야 한다.
            // 사용자가 "안자" 를 의도했더라도 이어서 모음을 누르면
            // 겹받침이 다시 갈라지므로 손해가 없다.
            if let last = contextBefore?.last,
               let parts = Hangul.decompose(last),
               let previousJong = parts.jong,
               let compound = Self.compoundJong["\(previousJong)+\(next)"] {
                cho = parts.cho
                jung = parts.jung
                jong = compound
                vowelSeq = [parts.jung]
                return 1
            }
            return 0
        }
        // 조합 중인 게 없으면 커서 앞 글자를 되살려 획을 더한다
        guard let last = contextBefore?.last else { return 0 }

        if let parts = Hangul.decompose(last) {
            if let jongChar = parts.jong {
                guard let next = Self.stroke[jongChar], Hangul.isJongseong(next) else { return 0 }
                cho = parts.cho
                jung = parts.jung
                jong = next
            } else {
                guard let next = Self.stroke[parts.jung], Hangul.isJungseong(next) else { return 0 }
                cho = parts.cho
                jung = next
                jong = nil
            }
            vowelSeq = [jung!]
            return 1
        }

        if let next = Self.stroke[last] {
            if Hangul.isChoseong(last) {
                cho = next
                return 1
            }
            if Hangul.isJungseong(last) {
                jung = next
                vowelSeq = [next]
                return 1
            }
        }
        return 0
    }

    private func applyDouble() {
        if let current = jong {
            if let next = Self.doubled[current], Hangul.isJongseong(next) {
                jong = next
            }
            return
        }
        if jung == nil, let current = cho, let next = Self.doubled[current] {
            cho = next
        }
    }

    // MARK: - 백스페이스

    /// - Returns: 지워야 할 확정 글자 수
    private func applyBackspace(contextBefore: String?) -> Int {
        if let current = jong {
            jong = Self.splitJong[current]?.0
            return 0
        }
        if jung != nil {
            if vowelSeq.count > 1 {
                vowelSeq.removeLast()
                var rebuilt = vowelSeq[0]
                for next in vowelSeq.dropFirst() {
                    rebuilt = Self.vowelCombine["\(rebuilt)+\(next)"] ?? rebuilt
                }
                jung = rebuilt
            } else {
                jung = nil
                vowelSeq = []
            }
            return 0
        }
        if cho != nil {
            cho = nil
            return 0
        }
        // 조합 중인 게 없으면 커서 앞 글자를 조합 상태로 되돌린다
        guard let last = contextBefore?.last else { return 1 }
        guard let parts = Hangul.decompose(last) else { return 1 }

        cho = parts.cho
        jung = parts.jung
        jong = parts.jong
        vowelSeq = [parts.jung]

        // 되살린 글자에서 한 단계 지운다
        if jong != nil {
            jong = Self.splitJong[jong!]?.0
        } else {
            jung = nil
            vowelSeq = []
        }
        return 1
    }

    // MARK: - 기호 묶음

    /// 기호가 여러 개 묶인 키 (`(-)`, `₩$¥` 처럼).
    ///
    /// 나랏글의 ㅏㅓ·ㅗㅜ 키와 같은 방식이다. 같은 키를 연달아 누르면
    /// 방금 넣은 기호를 지우고 다음 기호로 갈아 끼운다.
    /// 다른 키가 한 번이라도 끼어들면 `lastKey` 가 달라져 새로 시작한다.
    /// - Returns: 지워야 할 확정 글자 수
    private func inputCycle(_ options: [String], contextBefore: String?) -> Int {
        guard !options.isEmpty else { return 0 }

        // 방금 넣은 기호가 아직 커서 바로 앞에 그대로 있어야 갈아 끼울 수 있다.
        // 사용자가 화면을 탭해 커서를 옮겼으면 엉뚱한 글자를 지우게 된다.
        // 보안 입력 필드에서는 앞 문맥을 못 읽으므로(nil) 상태를 그대로 믿는다.
        if lastKey == .cycle(options),
           contextBefore.map({ $0.hasSuffix(options[cycleIndex]) }) ?? true {
            cycleIndex = (cycleIndex + 1) % options.count
            pendingCommit += options[cycleIndex]
            return 1
        }

        flush()
        cycleIndex = 0
        pendingCommit += options[0]
        return 0
    }

    // MARK: - 확정

    /// 조합 중인 글자를 확정하고 상태를 비운다.
    private func flush() {
        let text = composedText
        if !text.isEmpty { pendingCommit += text }
        cho = nil
        jung = nil
        jong = nil
        vowelSeq = []
    }
}
