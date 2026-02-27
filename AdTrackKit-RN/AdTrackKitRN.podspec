# AdTrackKitRN.podspec
#
# CocoaPods 스펙 파일.
# RN 앱의 ios/Podfile 에 아래를 추가하면 이 브릿지가 자동으로 연결됩니다:
#
#   pod 'AdTrackKitRN', :path => '../node_modules/adtrackkit-rn'
#
# (npm install 후 node_modules/adtrackkit-rn 경로를 맞게 수정하세요)

require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))

Pod::Spec.new do |s|
  s.name            = "AdTrackKitRN"
  s.version         = package["version"]
  s.summary         = package["description"]
  s.homepage        = "https://github.com/yourname/AdTrackKit-RN"
  s.license         = { :type => "MIT" }
  s.author          = { "Your Name" => "you@example.com" }
  s.platform        = :ios, "15.0"

  # 소스 파일 위치 (ios/ 디렉토리 내 모든 .h, .m, .swift)
  s.source_files    = "ios/**/*.{h,m,swift}"

  # ObjC-Swift 브릿지 헤더
  s.preserve_paths  = "ios/AdTrackKitRN-Bridging-Header.h"

  # React Native 코어 의존성 (RCTBridgeModule 등)
  s.dependency "React-Core"

  # AdTrackKit.framework 의존성
  # 옵션 A: 로컬 xcodeproj 참조
  # s.dependency 'AdTrackKit'
  #
  # 옵션 B: 직접 프레임워크 경로 지정 (Xcode 프로젝트 설정에서 처리)
  # s.vendored_frameworks = "../AdTrackKit/build/AdTrackKit.framework"

  # Swift 버전 명시
  s.swift_version   = "5.10"
end
