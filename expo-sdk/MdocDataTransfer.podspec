require 'json'

package = JSON.parse(File.read(File.join(__dir__, 'package.json')))

Pod::Spec.new do |s|
  s.name           = 'MdocDataTransfer'
  s.version        = package['version']
  s.summary        = package['description']
  s.description    = package['description']
  s.license        = package['license']
  s.author         = package['author']
  s.homepage       = package['homepage']
  s.platforms      = { :ios => '14.0'}
  s.swift_version  = '5.4'
  s.source         = { :git => "https://github.com/animo/mdoc-data-transfer.git", :tag => "#{s.version}" }

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'SWIFT_COMPILATION_MODE' => 'wholemodule'
  }

  s.source_files = "ios/**/*.{h,m,mm,swift}"

  install_modules_dependencies(s)

  if defined?(:spm_dependency)
    spm_dependency(s,  
      # Currently we use this fork because it adds a manual `sendDeviceResponse` method
      # Which we use as we generate this outside of the library
      url: 'https://github.com/berendsliedrecht/eudi-lib-ios-iso18013-data-transfer.git', 
      requirement: {kind: 'upToNextMinorVersion', minimumVersion: '0.3.12'}, 
      products: ['MdocDataTransfer18013'] 
    ) 
  else 
    raise "Please upgrade React Native to >=0.75.0 to use SPM dependencies." 
  end 
end
