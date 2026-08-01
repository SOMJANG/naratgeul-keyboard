import Foundation

/// KeyboardViewController.apply() 를 문자열 버퍼로 흉내 낸 시험용 문서.
final class FakeDocument {
    private(set) var text = ""
    private var preedit = ""
    private let engine = NaratgeulEngine()

    func press(_ keys: [NaratgeulKey]) {
        for key in keys { press(key) }
    }

    func press(_ key: NaratgeulKey) {
        let context = preedit.isEmpty ? text : String(text.dropLast(preedit.count))
        let out = engine.handle(key, contextBefore: context.isEmpty ? nil : context)

        if !preedit.isEmpty { text.removeLast(); preedit = "" }
        for _ in 0 ..< out.deleteCommitted where !text.isEmpty { text.removeLast() }
        text += out.commit
        if !out.preedit.isEmpty { text += out.preedit; preedit = out.preedit }
    }
}

// 키 별칭
let G = NaratgeulKey.consonant("ㄱ")
let N = NaratgeulKey.consonant("ㄴ")
let R = NaratgeulKey.consonant("ㄹ")
let M = NaratgeulKey.consonant("ㅁ")
let S = NaratgeulKey.consonant("ㅅ")
let O = NaratgeulKey.consonant("ㅇ")
let AEO = NaratgeulKey.aeo
let OU = NaratgeulKey.ou
let I = NaratgeulKey.i
let EU = NaratgeulKey.eu
let ST = NaratgeulKey.stroke
let DB = NaratgeulKey.double
let BS = NaratgeulKey.backspace
let SP = NaratgeulKey.space

var failures = 0

func check(_ name: String, _ keys: [NaratgeulKey], _ expected: String) {
    let doc = FakeDocument()
    doc.press(keys)
    let ok = doc.text == expected
    if !ok { failures += 1 }
    print("\(ok ? "✅" : "❌") \(name): \"\(doc.text)\"\(ok ? "" : "  (기대: \"\(expected)\")")")
}

print("── 기본 음절 ──")
check("가", [G, AEO], "가")
check("나", [N, AEO], "나")
check("거 (ㅏㅓ 두 번)", [G, AEO, AEO], "거")
check("고", [G, OU], "고")
check("구 (ㅗㅜ 두 번)", [G, OU, OU], "구")
check("기", [G, I], "기")
check("그", [G, EU], "그")

print("\n── 획 추가 ──")
check("카 (ㄱ+획)", [G, ST, AEO], "카")
check("다 (ㄴ+획)", [N, ST, AEO], "다")
check("타 (ㄴ+획+획)", [N, ST, ST, AEO], "타")
check("바 (ㅁ+획)", [M, ST, AEO], "바")
check("파 (ㅁ+획+획)", [M, ST, ST, AEO], "파")
check("자 (ㅅ+획)", [S, ST, AEO], "자")
check("차 (ㅅ+획+획)", [S, ST, ST, AEO], "차")
check("하 (ㅇ+획)", [O, ST, AEO], "하")
check("갸 (ㅏ+획)", [G, AEO, ST], "갸")
check("겨 (ㅓ+획)", [G, AEO, AEO, ST], "겨")
check("교 (ㅗ+획)", [G, OU, ST], "교")
check("규 (ㅜ+획)", [G, OU, OU, ST], "규")

print("\n── 쌍자음 ──")
check("까", [G, DB, AEO], "까")
check("싸", [S, DB, AEO], "싸")
check("따 (ㄴ+획+쌍)", [N, ST, DB, AEO], "따")
check("빠 (ㅁ+획+쌍)", [M, ST, DB, AEO], "빠")
check("짜 (ㅅ+획+쌍)", [S, ST, DB, AEO], "짜")

print("\n── 복합 모음 ──")
check("개 (ㅏ+ㅣ)", [G, AEO, I], "개")
check("게 (ㅓ+ㅣ)", [G, AEO, AEO, I], "게")
check("과 (ㅗ+ㅏ)", [G, OU, AEO], "과")
check("궈 (ㅜ+ㅓ)", [G, OU, OU, AEO], "궈")
check("괴 (ㅗ+ㅣ)", [G, OU, I], "괴")
check("긔 (ㅡ+ㅣ)", [G, EU, I], "긔")
check("괘 (ㅗ+ㅏ+ㅣ)", [G, OU, AEO, I], "괘")

print("\n── 받침 ──")
check("각", [G, AEO, G], "각")
check("값 (ㄱ+ㅏ+ㅁ→ㅂ+ㅅ)", [G, AEO, M, ST, S], "값")
check("갈기 (받침 이어쓰기)", [G, AEO, R, G, I], "갈기")
check("앉 (ㄴ+ㅅ→ㅈ)", [O, AEO, N, S, ST], "앉")
check("앉아 (겹받침 분해)", [O, AEO, N, S, ST, O, AEO], "앉아")
check("안자 (모음이 오면 갈라짐)", [O, AEO, N, S, ST, AEO], "안자")
check("않 (ㄴ+ㅇ→ㅎ)", [O, AEO, N, O, ST], "않")
check("닭 (ㄹ+ㄱ)", [N, ST, AEO, R, G], "닭")
check("핥 (ㄹ+ㄴ→ㄷ→ㅌ)", [O, ST, AEO, R, N, ST, ST], "핥")
check("밖 (받침 쌍자음)", [M, ST, AEO, G, DB], "밖")
check("읽다", [O, I, R, G, N, ST, AEO], "읽다")

print("\n── 백스페이스 ──")
check("가 → 지우기 → ㄱ", [G, AEO, BS], "ㄱ")
check("각 → 지우기 → 가", [G, AEO, G, BS], "가")
check("개 → 지우기 → 가", [G, AEO, I, BS], "가")
check("가나 → 지우기 → 가ㄴ", [G, AEO, N, AEO, BS], "가ㄴ")

print("\n── 확정 후 획 추가 ──")
check("가 (확정) + 획 → 갸", [G, AEO, SP, BS, ST], "갸")

print("\n── 기호 묶음 키 ──")
let PAREN = NaratgeulKey.cycle(["(", "-", ")"])
let WON = NaratgeulKey.cycle(["₩", "$", "¥"])
let DOT = NaratgeulKey.cycle([".", ",", "?", "!"])

check("한 번 누르면 첫 기호", [PAREN], "(")
check("두 번 누르면 다음 기호", [PAREN, PAREN], "-")
check("세 번 누르면 마지막 기호", [PAREN, PAREN, PAREN], ")")
check("네 번 누르면 처음으로 돌아온다", [PAREN, PAREN, PAREN, PAREN], "(")
check("네 개 묶음도 돈다", [DOT, DOT, DOT, DOT, DOT], ".")
check("다른 기호 키가 오면 새로 시작", [PAREN, WON], "(₩")
check("사이에 다른 키가 끼면 새로 시작", [PAREN, SP, PAREN], "( (")
check("조합 중이던 한글은 확정된다", [G, AEO, PAREN], "가(")
check("바꾼 뒤에도 한글은 이어서 조합", [PAREN, PAREN, G, AEO], "-가")
check("백스페이스로 지운다", [PAREN, PAREN, BS], "")

print("\n── 문장 ──")
check(
    "안녕하세요",
    [O, AEO, N, N, AEO, AEO, ST, O, O, ST, AEO, S, AEO, AEO, I, O, OU, ST],
    "안녕하세요"
)
check("한글", [O, ST, AEO, N, G, EU, R], "한글")
check("나랏글", [N, AEO, R, AEO, S, G, EU, R], "나랏글")

print("\n실패 \(failures)건")
exit(failures == 0 ? 0 : 1)
