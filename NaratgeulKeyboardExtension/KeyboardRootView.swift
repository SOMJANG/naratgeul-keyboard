import SwiftUI

/// 키보드 전체 화면.
struct KeyboardRootView: View {
    let onAction: (KeyPress) -> Void
    /// 지구본 키를 보여줄지 여부 (다른 키보드가 하나뿐이면 숨긴다)
    let showsNextKeyboardKey: Bool

    @Environment(\.colorScheme) private var systemScheme
    @AppStorage(KeyboardAppearance.storageKey)
    private var appearanceRaw = KeyboardAppearance.default.rawValue
    @State private var layer: KeyboardLayer = .hangul
    @State private var isShifted = false
    @State private var showsAppearanceMenu = false

    private var appearance: KeyboardAppearance {
        KeyboardAppearance(rawValue: appearanceRaw) ?? .default
    }

    /// 키를 그릴 때 쓰는 색 체계. 설정이 시스템을 덮어쓴다.
    private var scheme: ColorScheme {
        appearance.resolve(system: systemScheme)
    }

    var body: some View {
        VStack(spacing: 0) {
            tabBar

            VStack(spacing: KeyboardTheme.rowGap) {
                switch layer {
                case .hangul: hangulLayer
                case .english: englishLayer
                case .numbers: keypadLayer(KeyboardLayout.numberKeypad)
                case .symbols: keypadLayer(KeyboardLayout.symbolKeypad)
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
        // 그래서 평소에는 시스템 배경이 그대로 비치도록 둔다.
        // 다만 설정으로 시스템과 다른 색을 골랐을 때는 시스템 판 색이 반대라서
        // 그대로 두면 밝은 키가 어두운 판 위에 뜬다. 이때만 우리 배경을 깐다.
        .background(scheme == systemScheme ? Color.clear : KeyboardTheme.background(scheme))
        .overlay { if showsAppearanceMenu { appearanceMenu } }
        // 아래 모든 키가 설정된 색 체계로 그려지게 한다.
        .environment(\.colorScheme, scheme)
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

            Button {
                showsAppearanceMenu.toggle()
            } label: {
                Image(systemName: "circle.lefthalf.filled")
                    .font(.system(size: 15))
                    .foregroundColor(KeyboardTheme.tabLabel(scheme, active: showsAppearanceMenu))
                    .frame(width: 36, height: KeyboardTheme.tabBarHeight)
            }
            .accessibilityLabel("키보드 색")

            if showsNextKeyboardKey {
                Button {
                    perform(.nextKeyboard)
                } label: {
                    Image(systemName: "globe")
                        .font(.system(size: 16))
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
                .font(.system(size: 14, weight: active ? .semibold : .medium))
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

    // MARK: - 키보드 색 설정

    /// 탭바의 반달 버튼을 누르면 뜨는 작은 메뉴.
    ///
    /// 키보드 확장에서는 시트나 팝오버를 띄울 수 없어서 오버레이로 직접 그린다.
    /// 메뉴 바깥을 누르면 닫힌다.
    private var appearanceMenu: some View {
        ZStack(alignment: .topTrailing) {
            // 바깥 탭을 받아 닫기 위한 투명 막. 완전 투명이면 히트 테스트에서 빠진다.
            Color.black.opacity(0.001)
                .ignoresSafeArea()
                .onTapGesture { showsAppearanceMenu = false }

            VStack(alignment: .leading, spacing: 0) {
                Text("키보드 색")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(KeyboardTheme.keyNumber(scheme))
                    .padding(.horizontal, 14)
                    .padding(.top, 10)
                    .padding(.bottom, 6)

                ForEach(KeyboardAppearance.allCases) { option in
                    Button {
                        appearanceRaw = option.rawValue
                        showsAppearanceMenu = false
                    } label: {
                        HStack {
                            Text(option.title)
                                .font(.system(size: 15, weight: option == appearance ? .semibold : .regular))
                            Spacer(minLength: 16)
                            if option == appearance {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                        }
                        .foregroundColor(KeyboardTheme.keyLabel(scheme))
                        .padding(.horizontal, 14)
                        .frame(height: 40)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if option != KeyboardAppearance.allCases.last {
                        Rectangle()
                            .fill(KeyboardTheme.divider(scheme))
                            .frame(height: 0.5)
                            .padding(.leading, 14)
                    }
                }
            }
            .frame(width: 200)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(KeyboardTheme.characterKey(scheme))
                    .shadow(color: Color.black.opacity(0.25), radius: 10, y: 4)
            )
            .padding(.top, KeyboardTheme.tabBarHeight + 4)
            .padding(.trailing, 8)
        }
    }

    // MARK: - 한글 레이어

    private var hangulLayer: some View {
        Group {
            ForEach(Array(KeyboardLayout.hangulRows.enumerated()), id: \.offset) { _, row in
                KeyRow {
                    ForEach(row) { key in
                        KeyButton(definition: key, onPress: perform)
                    }
                }
            }

            // 마지막 행: 획 · ㅡ · 쌍 · [123 | 지구본]
            KeyRow {
                ForEach(KeyboardLayout.hangulBottomRow) { key in
                    KeyButton(definition: key, onPress: perform)
                }
                HStack(spacing: KeyboardTheme.keyGap) {
                    KeyButton(
                        definition: KeyDefinition(
                            label: "123", style: .function, fontSize: 14,
                            action: .switchLayer(.numbers)
                        ),
                        onPress: perform
                    )
                    globeKey()
                }
                .keyWidthRatio(KeyboardTheme.functionColumnRatio)
            }
        }
    }

    // MARK: - 영문 레이어

    private var englishLayer: some View {
        Group {
            ForEach(Array(KeyboardLayout.englishRows.enumerated()), id: \.offset) { index, row in
                KeyRow(spacing: 5) {
                    if index == 2 {
                        KeyButton(
                            definition: KeyDefinition(
                                label: isShifted ? "⇧" : "⇧", style: .function,
                                widthRatio: 1.4, fontSize: 19, action: .shift
                            ),
                            onPress: { _ in isShifted.toggle() }
                        )
                    }
                    ForEach(row, id: \.self) { letter in
                        KeyButton(
                            definition: KeyDefinition(
                                label: isShifted ? letter.uppercased() : letter,
                                // 한글 키(22)보다 조금 크다. 영문 키는 한 글자뿐이고 폭도 좁아서
                                // 같은 크기면 더 작아 보인다.
                                fontSize: 23,
                                action: .insert(isShifted ? letter.uppercased() : letter)
                            ),
                            onPress: perform
                        )
                    }
                    if index == 2 {
                        KeyButton(
                            definition: KeyDefinition(
                                label: "⌫", style: .function,
                                widthRatio: 1.4, fontSize: 21, action: .backspace
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

    /// 숫자와 기호는 한글 레이어와 같은 4×4 격자다.
    ///
    /// 다만 오른쪽 기능 열이 한글 쪽과 다르다. 간격이 여기서는 격자 안쪽
    /// 마지막 행 셋째 칸으로 내려가고, 그 자리를 .,?! 가 받는다.
    /// 마지막 행 왼쪽 칸은 전환 키와 한글 키가 반씩 나눠 쓴다.
    private func keypadLayer(_ keypad: KeyboardLayout.Keypad) -> some View {
        Group {
            ForEach(Array(keypad.rows.enumerated()), id: \.offset) { index, row in
                KeyRow {
                    ForEach(row) { key in
                        KeyButton(definition: key, onPress: perform)
                    }
                    KeyButton(
                        definition: KeyboardLayout.keypadRightColumn[index],
                        onPress: perform
                    )
                }
            }

            // 마지막 행: [#+= | 한글] · 0 · 간격 · 🌐
            KeyRow {
                splitSlot(keypad.switchKey, KeyboardLayout.toHangulKey, ratio: 1)
                KeyButton(definition: keypad.center, onPress: perform)
                KeyButton(definition: KeyboardLayout.keypadSpaceKey, onPress: perform)
                globeKey(ratio: KeyboardTheme.keypadFunctionColumnRatio)
            }
        }
    }

    /// 한 칸을 작은 키 둘로 나눠 쓰는 자리.
    ///
    /// 안쪽 두 키는 반씩 나눠 갖고, 칸 전체 폭은 `ratio` 를 따른다.
    /// 안쪽은 `HStack` 이라 키가 들고 있는 `widthRatio` 는 무시된다.
    private func splitSlot(
        _ left: KeyDefinition, _ right: KeyDefinition, ratio: CGFloat
    ) -> some View {
        HStack(spacing: KeyboardTheme.keyGap) {
            KeyButton(definition: left, onPress: perform)
            KeyButton(definition: right, onPress: perform)
        }
        .keyWidthRatio(ratio)
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
                        label: "한글", style: .function, fontSize: 15,
                        action: .switchLayer(.hangul)
                    ),
                    onPress: perform
                )
                KeyButton(
                    definition: KeyDefinition(label: "간격", style: .function, fontSize: 16, action: .space),
                    onPress: perform
                )
                .frame(maxWidth: .infinity)
                KeyButton(
                    definition: KeyDefinition(
                        label: "⌫", style: .function, fontSize: 21, action: .backspace
                    ),
                    onPress: perform
                )
                globeKey()
            }
            .frame(height: KeyboardTheme.keyHeight)
        }
    }

    /// 영문 레이어 하단 행.
    private var bottomUtilityRow: some View {
        HStack(spacing: KeyboardTheme.keyGap) {
            KeyButton(
                definition: KeyDefinition(
                    label: "한글", style: .function, fontSize: 15,
                    action: .switchLayer(.hangul)
                ),
                onPress: perform
            )
            KeyButton(
                definition: KeyDefinition(label: "간격", style: .function, fontSize: 16, action: .space),
                onPress: perform
            )
            .frame(maxWidth: .infinity)
            KeyButton(
                definition: KeyDefinition(label: "↵", style: .function, fontSize: 19, action: .newline),
                onPress: perform
            )
            globeKey()
        }
    }

    /// 지구본 키.
    ///
    /// 모든 레이어의 오른쪽 끝 같은 자리에 둔다.
    /// 자리가 고정돼 있어야 "한 번 눌러 영어, 한 번 더 눌러 이모지" 가 성립한다.
    private func globeKey(ratio: CGFloat = 1) -> some View {
        KeyButton(
            definition: KeyDefinition(
                label: "영어·이모지 전환", symbol: "globe", style: .function,
                widthRatio: ratio, fontSize: 19, action: .cycleLayer
            ),
            onPress: perform
        )
    }

    // MARK: - 액션 라우팅

    /// 모든 키가 거쳐 가는 자리.
    ///
    /// 레이어 전환은 이 뷰의 `@State` 로만 표현되므로 여기서 직접 처리해야 한다.
    /// 컨트롤러로도 넘겨서 조합 중인 글자를 확정하게 한다.
    private func perform(_ press: KeyPress) {
        switch press.action {
        case .switchLayer(let target):
            switchTo(target)
        case .cycleLayer:
            cycleLayer()
        case .insert where isShifted:
            isShifted = false
        default:
            break
        }
        onAction(press)
    }

    /// 탭바나 이모지처럼 `KeyButton` 을 거치지 않는 자리에서 쓴다.
    private func perform(_ action: KeyAction) {
        perform(KeyPress(action: action))
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
