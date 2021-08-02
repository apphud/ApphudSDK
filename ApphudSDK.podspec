Pod::Spec.new do |s|
  s.name             = 'ApphudSDK'
  s.version          = '2.3.0'
  s.summary          = 'Track and control iOS auto-renewable subscriptions.' 
  s.description      = 'Track, control and analyze iOS auto-renewable subscriptions with Apphud.'
  s.homepage         = 'https://github.com/apphud/ApphudSDK'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'apphud' => 'hi@apphud.com' }
  s.source           = { :git => 'https://github.com/apphud/ApphudSDK.git', :tag => s.version.to_s }
  s.frameworks = 'StoreKit'
  s.ios.deployment_target = '11.2'
  s.swift_version = '5.0'
  s.source_files = 'ApphudSDK/**/*.{swift,h,m}'

end
