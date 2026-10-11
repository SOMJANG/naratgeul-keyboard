import SwiftUI

/// 키보드 색을 어디에 맞출지.
///
/// 기본은 라이트다. 시스템이 다크여도 키는 밝게 그린다.
/// 저장은 확장 자체의 `UserDefaults.standard` 에 한다. App Group 공유 컨테이너는
/// 전체 접근 권한이 없으면 못 읽으므로 컨테이너 앱과 나눠 쓸 수 없다.
/// 그래서 설정 화면도 키보드 안에 둔다.
enum KeyboardAppearance: String, CaseIterable, Identifiable {
    case light
    case dark
    case system

    static let storageKey = "keyboardAppearance"
    static let `default`: KeyboardAppearance = .light

    var id: String { rawValue }

    var title: String {
        switch self {
        case .light: return "라이트"
        case .dark: return "다크"
        case .system: return "시스템 따라가기"
        }
    }

    /// 실제로 그릴 색 체계.
    func resolve(system: ColorScheme) -> ColorScheme {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .system: return system
        }
    }
}

/// 시스템 키보드에 맞춘 색과 치수.
enum KeyboardTheme {

    static func background(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.11, green: 0.11, blue: 0.12)
            : Color(red: 0.82, green: 0.82, blue: 0.84)
    }

    /// 문자 키 (흰색 계열)
    static func characterKey(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.17, green: 0.17, blue: 0.18)
            : Color.white
    }

    /// 기능 키 (회색 계열)
    static func functionKey(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.07, green: 0.07, blue: 0.08)
            : Color(red: 0.68, green: 0.71, blue: 0.74)
    }

    /// 눌린 상태의 키 색.
    ///
    /// `.brightness()` 로 어둡게 만들면 키마다 색 필터가 걸려 오프스크린 패스가 생긴다.
    /// 결과 색을 미리 적어 두고 채우기만 갈아 끼운다.
    static func characterKeyPressed(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.25, green: 0.25, blue: 0.26)
            : Color(red: 0.88, green: 0.88, blue: 0.88)
    }

    static func functionKeyPressed(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.15, green: 0.15, blue: 0.16)
            : Color(red: 0.56, green: 0.59, blue: 0.62)
    }

    static func keyLabel(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? .white : .black
    }

    static func keyNumber(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color.white.opacity(0.45)
            : Color.black.opacity(0.42)
    }

    static func tabBar(_ scheme: ColorScheme) -> Color {
        background(scheme)
    }

    static func tabLabel(_ scheme: ColorScheme, active: Bool) -> Color {
        if active { return scheme == .dark ? .white : .black }
        return scheme == .dark ? Color.white.opacity(0.55) : Color.black.opacity(0.6)
    }

    static func divider(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.14)
    }

    static func keyShadow(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.black.opacity(0.6) : Color.black.opacity(0.3)
    }

    static let keyCornerRadius: CGFloat = 5
    static let keyHeight: CGFloat = 44
    static let keyGap: CGFloat = 6
    static let rowGap: CGFloat = 8
    static let sidePadding: CGFloat = 6
    static let tabBarHeight: CGFloat = 32

    /// 한글 레이어 오른쪽 기능 열(⌫ · 간격 · ↵ · 123/🌐)의 가로 비율.
    ///
    /// 나랏글 원래 배열이 기능 열을 글자 열보다 좁게 잡는다.
    /// 글자 키를 넓게 두는 쪽이 오타가 덜 나기도 한다.
    static let functionColumnRatio: CGFloat = 0.75

    /// 숫자·기호 레이어 오른쪽 기능 열의 가로 비율.
    ///
    /// 한글 쪽보다 더 좁다. 여기 기능 열에는 "간격" 같은 두 글자 라벨이 없고
    /// ⌫ · ↵ · .,?! · 🌐 만 들어가서 원래 배열도 절반 가까이 줄여 잡는다.
    static let keypadFunctionColumnRatio: CGFloat = 0.55

    /// 탭바 + 4행 + 여백.
    ///
    /// `compact` 는 세로 크기 등급이 compact 인 경우, 즉 아이폰 가로 모드다.
    /// 이때 세로로 꽉 차서 화면을 다 덮는 걸 막으려고 키 높이를 줄인다.
    static func totalHeight(compact: Bool) -> CGFloat {
        let row = compact ? 32.0 : keyHeight
        let gap = compact ? 5.0 : rowGap
        let tab = compact ? 28.0 : tabBarHeight
        return tab + 9 + (row * 4) + (gap * 3) + 16
    }
}
