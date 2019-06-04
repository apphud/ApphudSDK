Pod::Spec.new do |s|
  s.name             = 'apphud'
  s.version          = '0.0.1'
  s.summary          = 'iOS subscriptions conversion analytics tool.'
 
  s.description      = 'This is a tool to track iOS subscriptions conversion from trial to paid.'
  s.homepage         = 'https://github.com/apphud/apphud'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'apphud' => 'hi@apphud.com' }
  s.source           = { :git => 'https://github.com/apphud/apphud.git', :tag => s.version.to_s }
  s.frameworks = 'StoreKit'
  s.ios.deployment_target = '11.0'
  s.swift_version = '5.0'
  s.source_files = 'Source/*.swift'

end
