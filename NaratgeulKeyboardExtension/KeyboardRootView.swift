import SwiftUI

/// 키보드 전체 화면.
struct KeyboardRootView: View {
    let onAction: (KeyAction) -> Void
    /// 지구본 키를 보여줄지 여부 (다른 키보드가 하나뿐이면 숨긴다)
    let showsNextKeyboardKey: Bool

    @Environment(\.colorScheme) private var scheme
    @State private var layer: KeyboardLayer = .hangul
    @State private var isShifted = false

    var body: some View {
        VStack(spacing: 0) {
            tabBar

            VStack(spacing: KeyboardTheme.rowGap) {
                switch layer {
                case .hangul: hangulLayer
                case .english: englishLayer
                case .numbers: keypadLayer(rows: KeyboardLayout.numberRows)
                case .symbols: keypadLayer(rows: KeyboardLayout.symbolRows)
                case .emoji: emojiLayer
                }
            }
            .frame(maxHeight: .infinity)
            .padding(.horizontal, KeyboardTheme.sidePadding)
            .padding(.top, 9)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // iOS 26 은 키보드를 모서리가 둥근 판 위에 얹어 준다.
        // 여기서 불투명한 배경을 칠하면 그 판과 색·모서리가 어긋나 이음매가 보인다.
        // 시스템 배경이 그대로 비치도록 둔다.
        .background(Color.clear)
        // 키보드 뷰는 자체적으로 safe area 를 신경 쓰지 않는다.
        // 시스템이 이미 홈 인디케이터 여백을 붙여 주기 때문에
        // 여기서 또 붙이면 iOS 17 이후로 아래가 잘려 보인다.
        .ignoresSafeArea(.all, edges: .bottom)
    }

    // MARK: - 탭바

    private var tabBar: some View {
        HStack(spacing: 0) {
            tab("한글", active: layer == .hangul) { perform(.switchLayer(.hangul)) }
            tab("영어", active: layer == .english) { perform(.switchLayer(.english)) }
            // 기호는 숫자 레이어의 #+= 키로 들어가므로 탭에서는 한 칸을 같이 쓴다.
            tab("123", active: layer == .numbers || layer == .symbols) {
                perform(.switchLayer(.numbers))
            }
            tab("이모지", active: layer == .emoji) { perform(.switchLayer(.emoji)) }

            Spacer(minLength: 0)

            if showsNextKeyboardKey {
                Button {
                    onAction(.nextKeyboard)
                } label: {
                    Image(systemName: "globe")
                        .font(.system(size: 15))
                        .foregroundColor(KeyboardTheme.tabLabel(scheme, active: false))
                        .frame(width: 36, height: KeyboardTheme.tabBarHeight)
                }
                .accessibilityLabel("다음 키보드")
            }
        }
        .padding(.horizontal, 6)
        .frame(height: KeyboardTheme.tabBarHeight)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(KeyboardTheme.divider(scheme))
                .frame(height: 0.5)
        }
    }

    private func tab(_ title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: active ? .semibold : .medium))
                .foregroundColor(KeyboardTheme.tabLabel(scheme, active: active))
                .padding(.horizontal, 10)
                .frame(height: KeyboardTheme.tabBarHeight)
                .overlay(alignment: .bottom) {
                    if active {
                        Rectangle()
                            .fill(KeyboardTheme.tabLabel(scheme, active: true))
                            .frame(height: 2)
                            .padding(.horizontal, 2)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    // MARK: - 한글 레이어

    private var hangulLayer: some View {
        Group {
            ForEach(Array(KeyboardLayout.hangulRows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: KeyboardTheme.keyGap) {
                    ForEach(row) { key in
                        KeyButton(definition: key, onPress: perform)
                    }
                }
            }

            // 마지막 행: 획 · ㅡ · 쌍 · [123 | 지구본]
            HStack(spacing: KeyboardTheme.keyGap) {
                ForEach(KeyboardLayout.hangulBottomRow) { key in
                    KeyButton(definition: key, onPress: perform)
                }

                HStack(spacing: KeyboardTheme.keyGap) {
                    KeyButton(
                        definition: KeyDefinition(
                            label: "123", style: .function, fontSize: 12,
                            action: .switchLayer(.numbers)
                        ),
                        onPress: perform
                    )
                    globeKey
                }
            }
        }
    }

    // MARK: - 영문 레이어

    private var englishLayer: some View {
        Group {
            ForEach(Array(KeyboardLayout.englishRows.enumerated()), id: \.offset) { index, row in
                HStack(spacing: 5) {
                    if index == 2 {
                        KeyButton(
                            definition: KeyDefinition(
                                label: isShifted ? "⇧" : "⇧", style: .function,
                                widthRatio: 1.4, fontSize: 17, action: .shift
                            ),
                            onPress: { _ in isShifted.toggle() }
                        )
                    }
                    ForEach(row, id: \.self) { letter in
                        KeyButton(
                            definition: KeyDefinition(
                                label: isShifted ? letter.uppercased() : letter,
                                fontSize: 18,
                                action: .insert(isShifted ? letter.uppercased() : letter)
                            ),
                            onPress: perform
                        )
                    }
                    if index == 2 {
                        KeyButton(
                            definition: KeyDefinition(
                                label: "⌫", style: .function,
                                widthRatio: 1.4, fontSize: 19, action: .backspace
                            ),
                            onPress: perform
                        )
                    }
                }
            }
            bottomUtilityRow
        }
    }

    // MARK: - 숫자 / 기호 레이어

    /// 숫자와 기호는 한글 레이어와 똑같은 4×4 격자다.
    ///
    /// 왼쪽 3열만 레이어마다 다르고 오른쪽 열(⌫ · 간격 · ↵ · 한글/🌐)은 고정이다.
    /// 나랏글은 키가 적은 대신 자리가 고정돼 있는 게 핵심이라, 숫자·기호로 넘어갔을 때만
    /// 배열이 달라지면 그 이점이 사라진다.
    private func keypadLayer(rows: [[KeyDefinition]]) -> some View {
        Group {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                HStack(spacing: KeyboardTheme.keyGap) {
                    ForEach(row) { key in
                        KeyButton(definition: key, onPress: perform)
                    }

                    if index < KeyboardLayout.keypadRightColumn.count {
                        KeyButton(
                            definition: KeyboardLayout.keypadRightColumn[index],
                            onPress: perform
                        )
                    } else {
                        // 한글 레이어의 [123 | 🌐] 와 같은 자리를 [한글 | 🌐] 로 쓴다.
                        HStack(spacing: KeyboardTheme.keyGap) {
                            KeyButton(definition: KeyboardLayout.toHangulKey, onPress: perform)
                            globeKey
                        }
                    }
                }
            }
        }
    }

    // MARK: - 이모지 레이어

    /// 시스템 이모지 키보드로 넘어가는 공개 API 가 없어서 직접 그린다.
    private var emojiLayer: some View {
        Group {
            ScrollView(.vertical, showsIndicators: false) {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 8),
                    spacing: 2
                ) {
                    ForEach(KeyboardLayout.emojis, id: \.self) { emoji in
                        Button {
                            perform(.insert(emoji))
                        } label: {
                            Text(emoji)
                                .font(.system(size: 26))
                                .frame(maxWidth: .infinity, minHeight: 38)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxHeight: .infinity)

            HStack(spacing: KeyboardTheme.keyGap) {
                KeyButton(
                    definition: KeyDefinition(
                        label: "한글", style: .function, fontSize: 13,
                        action: .switchLayer(.hangul)
                    ),
                    onPress: perform
                )
                KeyButton(
                    definition: KeyDefinition(label: "간격", style: .function, fontSize: 14, action: .space),
                    onPress: perform
                )
                .frame(maxWidth: .infinity)
                KeyButton(
                    definition: KeyDefinition(
                        label: "⌫", style: .function, fontSize: 19, action: .backspace
                    ),
                    onPress: perform
                )
                globeKey
            }
            .frame(height: KeyboardTheme.keyHeight)
        }
    }

    /// 영문 레이어 하단 행.
    private var bottomUtilityRow: some View {
        HStack(spacing: KeyboardTheme.keyGap) {
            KeyButton(
                definition: KeyDefinition(
                    label: "한글", style: .function, fontSize: 13,
                    action: .switchLayer(.hangul)
                ),
                onPress: perform
            )
            KeyButton(
                definition: KeyDefinition(label: "간격", style: .function, fontSize: 14, action: .space),
                onPress: perform
            )
            .frame(maxWidth: .infinity)
            KeyButton(
                definition: KeyDefinition(label: "↵", style: .function, fontSize: 17, action: .newline),
                onPress: perform
            )
            globeKey
        }
    }

    /// 지구본 키.
    ///
    /// 모든 레이어의 오른쪽 끝 같은 자리에 둔다.
    /// 자리가 고정돼 있어야 "한 번 눌러 영어, 한 번 더 눌러 이모지" 가 성립한다.
    private var globeKey: some View {
        KeyButton(
            definition: KeyDefinition(
                label: "영어·이모지 전환", symbol: "globe", style: .function,
                fontSize: 17, action: .cycleLayer
            ),
            onPress: perform
        )
    }

    // MARK: - 액션 라우팅

    /// 모든 키가 거쳐 가는 자리.
    ///
    /// 레이어 전환은 이 뷰의 `@State` 로만 표현되므로 여기서 직접 처리해야 한다.
    /// 컨트롤러로도 넘겨서 조합 중인 글자를 확정하게 한다.
    private func perform(_ action: KeyAction) {
        switch action {
        case .switchLayer(let target):
            switchTo(target)
        case .cycleLayer:
            cycleLayer()
        case .insert where isShifted:
            isShifted = false
        default:
            break
        }
        onAction(action)
    }

    private func switchTo(_ target: KeyboardLayer) {
        layer = target
        isShifted = false
    }

    /// 한글에서 한 번 누르면 영문, 한 번 더 누르면 이모지, 한 번 더 누르면 한글.
    private func cycleLayer() {
        switch layer {
        case .hangul: layer = .english
        case .english: layer = .emoji
        case .emoji, .numbers, .symbols: layer = .hangul
        }
        isShifted = false
    }
}
