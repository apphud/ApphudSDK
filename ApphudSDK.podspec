Pod::Spec.new do |s|
  s.name             = 'ApphudSDK'
  s.version          = '4.0.0'
  s.summary          = 'Build and Measure In-App Subscriptions on iOS.'
  s.description      = 'Apphud covers every aspect when it comes to In-App Subscriptions from integration to analytics on iOS and Android.'
  s.homepage         = 'https://github.com/apphud/ApphudSDK'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'apphud' => 'hi@apphud.com' }
  s.source           = { :git => 'https://github.com/apphud/ApphudSDK.git', :tag => s.version.to_s }
  s.frameworks = 'StoreKit'
  s.ios.deployment_target = '15.0'
  s.osx.deployment_target  = '13.0'
  s.tvos.deployment_target = '16.0'
  s.watchos.deployment_target = '9.0'
  s.visionos.deployment_target = '1.0'
  s.swift_version = '5.9'
  s.source_files = 'Sources/**/*.{swift,h,m}'
  s.resource_bundles = {'ApphudSDK' => ['Sources/PrivacyInfo.xcprivacy']}
end
