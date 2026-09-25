#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint arrangement_layout.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'arrangement_layout'
  s.version          = '0.0.1'
  s.summary          = 'Fold and hinge geometry for Flutter, including iPhone Duo.'
  s.description      = <<-DESC
Reads Flutter display features and, on iPhone Duo, the hinge angle, posture, and reserved regions.
                       DESC
  s.homepage         = 'https://github.com/flutter/flutter'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Arrangement Layout' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'arrangement_layout/Sources/arrangement_layout/**/*.swift'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
