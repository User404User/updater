Pod::Spec.new do |s|
  s.name             = 'shorebird_code_push_network'
  s.version          = '2.0.4'
  s.summary          = 'Shorebird Code Push Network Plugin'
  s.description      = <<-DESC
Network-only version of Shorebird Code Push for downloading patches without engine integration.
                       DESC
  s.homepage         = 'https://shorebird.dev'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Shorebird' => 'hello@shorebird.dev' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*.{h,m,c,swift}'
  s.dependency 'Flutter'
  s.platform = :ios, '12.0'

  # iOS 使用官方 Shorebird 包 + DNS Hook 实现，无需额外库

  # Pod configuration
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386'
  }
  
  # 不再需要 Swift，全部使用 Objective-C
end