require 'json'

package = JSON.parse(File.read(File.join(__dir__, '..', 'package.json')))

Pod::Spec.new do |s|
  s.name           = 'MdocDataTransfer'
  s.version        = package['version']
  s.summary        = package['description']
  s.description    = package['description']
  s.license        = package['license']
  s.author         = package['author']
  s.homepage       = package['homepage']
  s.platforms      = { :ios => '15.1'}
  s.swift_version  = '5.4'
  s.source         = { :git => "https://github.com/animo/mdoc-data-transfer.git", :tag => "#{s.version}" }

  s.dependency 'ExpoModulesCore'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES'
  }

  s.vendored_frameworks = 'MdocProximity.xcframework'
  s.static_framework = true
  s.source_files = "*.{swift}"
end
