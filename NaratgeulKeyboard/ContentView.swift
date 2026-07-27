import SwiftUI

/// 컨테이너 앱. 설치 안내와 시험 입력창만 제공한다.
struct ContentView: View {
    @State private var testText = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(index + 1)")
                                .font(.system(.footnote, design: .rounded).weight(.semibold))
                                .foregroundStyle(.white)
                                .frame(width: 22, height: 22)
                                .background(Circle().fill(.tint))
                            Text(step)
                                .font(.callout)
                        }
                        .padding(.vertical, 2)
                    }
                } header: {
                    Text("설치 방법")
                } footer: {
                    Text("전체 접근 권한은 키 눌림 진동에만 씁니다. 안 켜도 입력은 모두 됩니다. 이 키보드는 네트워크를 쓰지 않고 입력 내용을 밖으로 내보내지 않습니다.")
                }

                Section("시험 입력") {
                    TextField("여기에 입력해 보세요", text: $testText, axis: .vertical)
                        .lineLimit(3 ... 6)
                        .focused($isFocused)

                    if !testText.isEmpty {
                        Button("지우기", role: .destructive) { testText = "" }
                    }
                }

                Section("입력 규칙") {
                    rule("지구본 키", "오른쪽 아래 지구본을 누르면 한글 → 영어 → 이모지 순으로 돕니다")
                    rule("모음", "ㅏㅓ · ㅗㅜ 키를 두 번 누르면 뒤 글자로 바뀝니다")
                    rule("획 추가", "ㄴ → ㄷ → ㅌ, ㅅ → ㅈ → ㅊ 순으로 돕니다")
                    rule("쌍자음", "ㄱ ↔ ㄲ, ㅅ ↔ ㅆ 처럼 토글됩니다")
                    rule("ㅑㅕㅛㅠ", "ㅏㅓㅗㅜ 를 넣고 획 키를 누릅니다")
                    rule("ㅐㅔ", "ㅏㅓ 뒤에 ㅣ 를 붙입니다")
                    rule("ㅘㅝ", "ㅗ 또는 ㅜ 뒤에 ㅏㅓ 키를 누릅니다")
                }

                Section("만든 사람") {
                    LabeledContent("개발") {
                        Text("SOMJANG").font(.subheadline.weight(.semibold))
                    }

                    Link(destination: URL(string: "https://github.com/SOMJANG")!) {
                        HStack(spacing: 10) {
                            Image("GitHubMark")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20)
                            Text("github.com/SOMJANG")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(.primary)
                }
            }
            .navigationTitle("나랏글")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("설정 열기") {
                        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                        UIApplication.shared.open(url)
                    }
                }
            }
        }
    }

    private func rule(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.subheadline.weight(.medium))
            Text(detail).font(.footnote).foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    /// iOS 26부터 타사 키보드 켜는 자리가 설정 → 앱 → (앱 이름) 아래로 옮겨졌다.
    private var steps: [String] {
        [
            "설정 앱에서 앱 → 나랏글 → 키보드를 엽니다",
            "나랏글 스위치를 켭니다",
            "키 누를 때 진동이 오게 하려면 전체 접근 허용도 켭니다 (선택)",
            "아무 앱에서나 지구본 키를 눌러 전환합니다",
            "먼저 뜨게 하려면 설정 → 일반 → 키보드 → 키보드 → 편집에서 맨 위로 옮깁니다",
        ]
    }
}

#Preview {
    ContentView()
}
