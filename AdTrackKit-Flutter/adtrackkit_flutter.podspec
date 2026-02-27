#
# adtrackkit_flutter.podspec
#
# Flutter 플러그인의 iOS 의존성을 CocoaPods로 관리합니다.
# flutter pub get → pod install 시 자동으로 이 스펙이 사용됩니다.
#
# 참고: Flutter 앱의 ios/Podfile 에는 별도 추가 불필요.
# Flutter 빌드 시스템이 pubspec.yaml 의 플러그인 선언을 읽고
# 자동으로 이 podspec을 연결합니다.

Pod::Spec.new do |s|
  s.name             = 'adtrackkit_flutter'
  s.version          = '0.1.0'
  s.summary          = 'AdTrackKit iOS SDK Flutter Plugin'
  s.description      = <<-DESC
    AdTrackKit iOS SDK를 Flutter에서 사용하기 위한 플러그인.
    FlutterMethodChannel을 통해 Dart ↔ Swift 통신을 구현합니다.
  DESC
  s.homepage         = 'https://github.com/yourname/AdTrackKit-Flutter'
  s.license          = { :type => 'MIT', :file => '../LICENSE' }
  s.author           = { 'Your Name' => 'you@example.com' }

  # iOS 소스 파일 경로 (이 podspec 기준 상대경로)
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*.{h,m,swift}'

  # iOS 최소 지원 버전
  s.platform         = :ios, '15.0'

  # Flutter 엔진 의존성 (FlutterPlugin 프로토콜, FlutterMethodChannel 등 포함)
  s.dependency 'Flutter'

  # AdTrackKit.framework 의존성
  # 방법 A: 로컬 xcodeproj 직접 참조
  # s.dependency 'AdTrackKit'
  #
  # 방법 B: 빌드된 프레임워크 경로 직접 지정
  # s.vendored_frameworks = '../../AdTrackKit/build/AdTrackKit.xcframework'
  #
  # → 실제 연동 시: Xcode의 Build Phases → Link Binary With Libraries 에서
  #   AdTrackKit.framework 을 수동으로 추가하거나 위 옵션 중 하나를 선택하세요.

  # Swift 버전 명시
  s.swift_version    = '5.10'

  # 정적 프레임워크로 빌드 (Flutter 플러그인 기본 요구사항)
  s.static_framework = true
end
