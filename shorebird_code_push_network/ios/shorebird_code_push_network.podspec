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
  s.source_files     = 'Classes/**/*.{h,m,swift}'
  s.dependency 'Flutter'
  s.platform = :ios, '12.0'

  # XCFramework for network functions
  s.vendored_frameworks = 'ShorebirdUpdaterNetwork.xcframework'

  # Pod configuration
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386'
  }
  
  s.swift_version = '5.0'
end